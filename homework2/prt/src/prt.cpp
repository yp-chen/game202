#include <nori/integrator.h>
#include <nori/scene.h>
#include <nori/ray.h>
#include <filesystem/resolver.h>
#include <sh/spherical_harmonics.h>
#include <sh/default_image.h>
#include <Eigen/Core>
#include <fstream>
#include <random>
#include <stb_image.h>

NORI_NAMESPACE_BEGIN

namespace ProjEnv
{
    //从指定目录加载立方体贴图的六个面的图像数据
    //返回包含6个浮点数数组的向量，每个数组代表立方体贴图的一个面，以及图像的宽度、高度和通道数
    //channel通道数，也即R、G、B、A
    std::vector<std::unique_ptr<float[]>>
    LoadCubemapImages(const std::string &cubemapDir, int &width, int &height,
                      int &channel)
    {
        std::vector<std::string> cubemapNames{"negx.jpg", "posx.jpg", "posy.jpg",
                                              "negy.jpg", "posz.jpg", "negz.jpg"};
        std::vector<std::unique_ptr<float[]>> images(6);
        for (int i = 0; i < 6; i++)
        {
            std::string filename = cubemapDir + "/" + cubemapNames[i];
            int w, h, c;
            float *image = stbi_loadf(filename.c_str(), &w, &h, &c, 3);
            if (!image)
            {
                std::cout << "Failed to load image: " << filename << std::endl;
                exit(-1);
            }
            if (i == 0)
            {
                width = w;
                height = h;
                channel = c;
            }
            //所有图像具有相同的分辨率和通道数
            else if (w != width || h != height || c != channel)
            {
                std::cout << "Dismatch resolution for 6 images in cubemap" << std::endl;
                exit(-1);
            }
            images[i] = std::unique_ptr<float[]>(image);
            int index = (0 * 128 + 0) * channel;
            // std::cout << images[i][index + 0] << "\t" << images[i][index + 1] << "\t"
            //           << images[i][index + 2] << std::endl;
        }
        return images;
    }

    const Eigen::Vector3f cubemapFaceDirections[6][3] = {
        {{0, 0, 1}, {0, -1, 0}, {-1, 0, 0}},  // negx
        {{0, 0, 1}, {0, -1, 0}, {1, 0, 0}},   // posx
        {{1, 0, 0}, {0, 0, -1}, {0, -1, 0}},  // negy
        {{1, 0, 0}, {0, 0, 1}, {0, 1, 0}},    // posy
        {{-1, 0, 0}, {0, -1, 0}, {0, 0, -1}}, // negz
        {{1, 0, 0}, {0, -1, 0}, {0, 0, 1}},   // posz
    };

    //计算单位球面上的矩形区域，[x,y]-[0,0]
    float CalcPreArea(const float &x, const float &y)
    {
        return std::atan2(x * y, std::sqrt(x * x + y * y + 1.0));
    }

    //计算 cubemap 上每个像素所代表的矩形区域投影到单位球面的面积
    //可参考https://www.rorydriscoll.com/2012/01/15/cubemap-texel-solid-angle/
    float CalcArea(const float &u_, const float &v_, const int &width,
                   const int &height)
    {
        // transform from [0..res - 1] to [- (1 - 1 / res) .. (1 - 1 / res)]
        // ( 0.5 is for texel center addressing)
        float u = (2.0 * (u_ + 0.5) / width) - 1.0;
        float v = (2.0 * (v_ + 0.5) / height) - 1.0;

        // shift from a demi texel, mean 1.0 / size  with u and v in [-1..1]
        float invResolutionW = 1.0 / width;
        float invResolutionH = 1.0 / height;

        // u and v are the -1..1 texture coordinate on the current face.
        // get projected area for this texel
        //通过加减最小变化量来得到当前像素的四个角的纹理坐标 x0, y0, x1, y1
        float x0 = u - invResolutionW;
        float y0 = v - invResolutionH;
        float x1 = u + invResolutionW;
        float y1 = v + invResolutionH;
        float angle = CalcPreArea(x0, y0) - CalcPreArea(x0, y1) -
                      CalcPreArea(x1, y0) + CalcPreArea(x1, y1);

        return angle;
    }

    // template <typename T> T ProjectSH() {}

    //计算cubemap上每个像素的球谐系数，并存储在SHCoeffiecents中
    template <size_t SHOrder>
    std::vector<Eigen::Array3f> PrecomputeCubemapSH(const std::vector<std::unique_ptr<float[]>> &images,
                                                    const int &width, const int &height,
                                                    const int &channel)
    {
        //cubemapDirs用来存储6个面上所有像素的方向向量,指向cubemap中心点
        std::vector<Eigen::Vector3f> cubemapDirs;
        cubemapDirs.reserve(6 * width * height);
        for (int i = 0; i < 6; i++)
        {
            //获取当前面的三个方向向量
            Eigen::Vector3f faceDirX = cubemapFaceDirections[i][0];
            Eigen::Vector3f faceDirY = cubemapFaceDirections[i][1];
            Eigen::Vector3f faceDirZ = cubemapFaceDirections[i][2];
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    //乘以2并减去1转换到[-1,1]的范围
                    float u = 2 * ((x + 0.5) / width) - 1;
                    float v = 2 * ((y + 0.5) / height) - 1;
                    Eigen::Vector3f dir = (faceDirX * u + faceDirY * v + faceDirZ).normalized();
                    cubemapDirs.push_back(dir);
                }
            }
        }
        constexpr int SHNum = (SHOrder + 1) * (SHOrder + 1);
        //初始化球谐系数
        std::vector<Eigen::Array3f> SHCoeffiecents(SHNum);
        for (int i = 0; i < SHNum; i++)
            SHCoeffiecents[i] = Eigen::Array3f(0);
        float sumWeight = 0;
        //三层 for循环遍历了6个面上每个像素
        for (int i = 0; i < 6; i++)
        {
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    // TODO: here you need to compute light sh of each face of cubemap of each pixel
                    // TODO: 此处你需要计算每个像素下cubemap某个面的球谐系数
                    Eigen::Vector3f dir = cubemapDirs[i * width * height + y * width + x];
                    int index = (y * width + x) * channel;
                    //提取该像素的颜色值RGB，也即Lenv
                    Eigen::Array3f Le(images[i][index + 0], images[i][index + 1],
                                      images[i][index + 2]);

                    //也即delta_w,由于是单位球面，投影面积等于立体角大小
                    auto delta_w = CalcArea(x, y, width, height);

                    //计算该像素的球谐系数
                    for (int l = 0; l < SHOrder; l++) {
                        for (int m = -l; m <= l; m++) {
                            //也即SH(w0),单位立体角在球谐函数上的投影值
                            auto basic_sh_proj = sh::EvalSH(l, m, Eigen::Vector3d(dir.x(), dir.y(), dir.z()).normalized());
                            //SHcoeff = 求和Lenv * SH(w0) * delta_w 
                            SHCoeffiecents[sh::GetIndex(l, m)] += Le * basic_sh_proj * delta_w;
                        }
                    }
                }
            }
        }
        return SHCoeffiecents;
    }
}

class PRTIntegrator : public Integrator
{
public:
    static constexpr int SHOrder = 2;
    static constexpr int SHCoeffLength = (SHOrder + 1) * (SHOrder + 1);

    enum class Type
    {
        Unshadowed = 0,
        Shadowed = 1,
        Interreflection = 2
    };

    PRTIntegrator(const PropertyList &props)
    {
        /* No parameters this time */
        m_SampleCount = props.getInteger("PRTSampleCount", 100);
        m_CubemapPath = props.getString("cubemap");
        auto type = props.getString("type", "unshadowed");
        if (type == "unshadowed")
        {
            m_Type = Type::Unshadowed;
        }
        else if (type == "shadowed")
        {
            m_Type = Type::Shadowed;
        }
        else if (type == "interreflection")
        {
            m_Type = Type::Interreflection;
            m_Bounce = props.getInteger("bounce", 1);
        }
        else
        {
            throw NoriException("Unsupported type: %s.", type);
        }
    }
    
    //计算间接反射部分的球谐系数。这个函数使用迭代的方式处理多次反射，并且每次反射都会更新球谐系数
    //参数传输球谐系数矩阵的指针 directTSHCoeffs
    //当前点的位置 pos
    //法线 normal
    //场景对象 scene 
    //当前的反射次数 bounces
    std::unique_ptr<std::vector<double>> computeInterreflectionSH(Eigen::MatrixXf* directTSHCoeffs, const Point3f& pos, const Normal3f& normal, const Scene* scene, int bounces)
    {
        //创建并初始化保存球谐系数的向量
        std::unique_ptr<std::vector<double>> coeffs(new std::vector<double>());
        coeffs->assign(SHCoeffLength, 0.0);

        //如果反射次数大于最大反射次数，则返回空向量
        if (bounces > m_Bounce)
            return coeffs;

        //计算采样侧边长度，即对总的采样点数 m_SampleCount 开平方根并向下取整，以便于创建一个均匀的二维采样格。
        const int sample_side = static_cast<int>(floor(sqrt(m_SampleCount)));
        std::random_device rd; //rd 是一个随机设备，用于产生种子
        std::mt19937 gen(rd()); //gen 是一个随机数引擎，用于产生随机数
        std::uniform_real_distribution<> rng(0.0, 1.0);  //rng 产生 [0.0, 1.0] 范围内的均匀分布随机数
        for (int t = 0; t < sample_side; t++) {
            for (int p = 0; p < sample_side; p++) {
                double alpha = (t + rng(gen)) / sample_side;
                double beta = (p + rng(gen)) / sample_side;
                //正交化的 alpha 和 beta 转换为球坐标系统中的 phi 和 theta
                double phi = 2.0 * M_PI * beta;
                double theta = acos(2.0 * alpha - 1.0);

                //使用 sh::ToVector 函数，将球坐标转换为对应的方向向量 wi
                Eigen::Array3d d = sh::ToVector(phi, theta);
                const auto wi = Vector3f(d.x(), d.y(), d.z());
                double H = wi.normalized().dot(normal);
                Intersection its;
                //如果 H 为正（表示方向位于法线上半球），并且从位置 pos 发出沿 wi 方向的射线与场景中的某些物体相交
                if (H > 0.0 && scene->rayIntersect(Ray3f(pos, wi.normalized()), its))
                {
                    //得到法线、三角形索引、相交点位置和重心坐标
                    MatrixXf normals = its.mesh->getVertexNormals();//所有法线，后根据索引取出对应的法线
                    Point3f idx = its.tri_index;
                    Point3f hitPos = its.p;
                    Vector3f bary = its.bary;

                    //计算相交点的插值法线
                    Normal3f hitNormal =
                        Normal3f(normals.col(idx.x()).normalized() * bary.x() +
                            normals.col(idx.y()).normalized() * bary.y() +
                            normals.col(idx.z()).normalized() * bary.z())
                        .normalized();

                    //递归计算下一级反射的球谐系数
                    auto nextBouncesCoeffs = computeInterreflectionSH(directTSHCoeffs, hitPos, hitNormal, scene, bounces + 1);

                    //对当前的球谐系数进行插值
                    for (int i = 0; i < SHCoeffLength; i++)
                    {
                        auto interpolateSH = (directTSHCoeffs->col(idx.x()).coeffRef(i) * bary.x() +
                            directTSHCoeffs->col(idx.y()).coeffRef(i) * bary.y() +
                            directTSHCoeffs->col(idx.z()).coeffRef(i) * bary.z());

                        (*coeffs)[i] += (interpolateSH + (*nextBouncesCoeffs)[i]) * H;
                    }
                }
            }
        }

        //将累加得到的系数除以总的样本数，得到平均值。
        for (unsigned int i = 0; i < coeffs->size(); i++) {
            (*coeffs)[i] /= sample_side * sample_side;
        }
        
        return coeffs;
    }

    //在实际渲染之前预处理场景数据。此方法加载立方体贴图并计算其球谐系数，还会计算场景中每个顶点的transfrom球谐系数
    virtual void preprocess(const Scene *scene) override
    {

        // Here only compute one mesh
        const auto mesh = scene->getMeshes()[0];
        // Projection environment
        auto cubePath = getFileResolver()->resolve(m_CubemapPath);
        auto lightPath = cubePath / "light.txt";
        auto transPath = cubePath / "transport.txt";
        std::ofstream lightFout(lightPath.str());
        std::ofstream fout(transPath.str());
        int width, height, channel;
        std::vector<std::unique_ptr<float[]>> images =
            ProjEnv::LoadCubemapImages(cubePath.str(), width, height, channel);
        //计算环境光照的球谐系数
        auto envCoeffs = ProjEnv::PrecomputeCubemapSH<SHOrder>(images, width, height, channel);
        m_LightCoeffs.resize(3, SHCoeffLength);
        for (int i = 0; i < envCoeffs.size(); i++)
        {
            lightFout << (envCoeffs)[i].x() << " " << (envCoeffs)[i].y() << " " << (envCoeffs)[i].z() << std::endl;
            m_LightCoeffs.col(i) = (envCoeffs)[i];
        }
        std::cout << "Computed light sh coeffs from: " << cubePath.str() << " to: " << lightPath.str() << std::endl;
        // Projection transport
        //行数 SHCoeffLength 等于球谐系数的数量（9），列数等于网格中顶点的数量。
        m_TransportSHCoeffs.resize(SHCoeffLength, mesh->getVertexCount());
        fout << mesh->getVertexCount() << std::endl;
        for (int i = 0; i < mesh->getVertexCount(); i++)
        {
            //得到每个顶点的位置和法线
            const Point3f &v = mesh->getVertexPositions().col(i);
            const Normal3f &n = mesh->getVertexNormals().col(i);
            auto shFunc = [&](double phi, double theta) -> double {
                Eigen::Array3d d = sh::ToVector(phi, theta);
                const auto wi = Vector3f(d.x(), d.y(), d.z());
                double H = wi.normalized().dot(n.normalized());
                if (m_Type == Type::Unshadowed)
                {
                    // TODO: here you need to calculate unshadowed transport term of a given direction
                    // TODO: 此处你需要计算给定方向下的unshadowed传输项球谐函数值
                    return H > 0.0? H : 0;
                }
                else
                {
                    // TODO: here you need to calculate shadowed transport term of a given direction
                    // TODO: 此处你需要计算给定方向下的shadowed传输项球谐函数值
                    //shadowed需要判断是否有遮挡物
                    if (H > 0.0 && !scene->rayIntersect(Ray3f(v,wi.normalized()))) {
                        return H;
                    }
                    return 0;
                }
            };
            //该函数用来计算给定球谐阶数、投影函数、采样数下的球谐系数，
            //并返回一个 std::unique_ptr 存储的表示为 std::vector<double>的球谐系数，
            //投影函数为用户自定义的 lambda 函数，签名为 double(double,double)
            auto shCoeff = sh::ProjectFunction(SHOrder, shFunc, m_SampleCount);
            for (int j = 0; j < shCoeff->size(); j++)
            {
                m_TransportSHCoeffs.col(i).coeffRef(j) = (*shCoeff)[j];
            }
        }
        if (m_Type == Type::Interreflection)
        {
            // TODO: leave for bonus

            for (int i = 0; i < mesh->getVertexCount(); i++)
            {
                //得到每个顶点的位置和法线
                const Point3f& v = mesh->getVertexPositions().col(i);
                const Normal3f& n = mesh->getVertexNormals().col(i).normalized();
                auto indirectCoeffs = computeInterreflectionSH(&m_TransportSHCoeffs, v, n, scene, 1);
                for (int j = 0; j < SHCoeffLength; j++)
                {
                    m_TransportSHCoeffs.col(i).coeffRef(j) += (*indirectCoeffs)[j];
                }
                std::cout << "computing interreflection light sh coeffs, current vertex idx: " << i << " total vertex idx: " << mesh->getVertexCount() << std::endl;
            }
        }

        // Save in face format
        for (int f = 0; f < mesh->getTriangleCount(); f++)
        {
            const MatrixXu &F = mesh->getIndices();
            //对于三角形每个顶点都存储对应的球谐系数
            //coeffRef用于修改系数值，coeff用于读取系数值
            uint32_t idx0 = F(0, f), idx1 = F(1, f), idx2 = F(2, f);
            for (int j = 0; j < SHCoeffLength; j++)
            {
                fout << m_TransportSHCoeffs.col(idx0).coeff(j) << " ";
            }
            fout << std::endl;
            for (int j = 0; j < SHCoeffLength; j++)
            {
                fout << m_TransportSHCoeffs.col(idx1).coeff(j) << " ";
            }
            fout << std::endl;
            for (int j = 0; j < SHCoeffLength; j++)
            {
                fout << m_TransportSHCoeffs.col(idx2).coeff(j) << " ";
            }
            fout << std::endl;
        }
        std::cout << "Computed SH coeffs"
                  << " to: " << transPath.str() << std::endl;
    }

    Color3f Li(const Scene *scene, Sampler *sampler, const Ray3f &ray) const
    {
        Intersection its;
        if (!scene->rayIntersect(ray, its))
            return Color3f(0.0f);

        const Eigen::Matrix<Vector3f::Scalar, SHCoeffLength, 1> sh0 = m_TransportSHCoeffs.col(its.tri_index.x()),
                                                                sh1 = m_TransportSHCoeffs.col(its.tri_index.y()),
                                                                sh2 = m_TransportSHCoeffs.col(its.tri_index.z());
        const Eigen::Matrix<Vector3f::Scalar, SHCoeffLength, 1> rL = m_LightCoeffs.row(0), gL = m_LightCoeffs.row(1), bL = m_LightCoeffs.row(2);

        Color3f c0 = Color3f(rL.dot(sh0), gL.dot(sh0), bL.dot(sh0)),
                c1 = Color3f(rL.dot(sh1), gL.dot(sh1), bL.dot(sh1)),
                c2 = Color3f(rL.dot(sh2), gL.dot(sh2), bL.dot(sh2));

        const Vector3f &bary = its.bary;
        Color3f c = bary.x() * c0 + bary.y() * c1 + bary.z() * c2;
        // TODO: you need to delete the following four line codes after finishing your calculation to SH,
        //       we use it to visualize the normals of model for debug.
        // TODO: 在完成了球谐系数计算后，你需要删除下列四行，这四行代码的作用是用来可视化模型法线
        // if (c.isZero()) {
        //     auto n_ = its.shFrame.n.cwiseAbs();
        //     return Color3f(n_.x(), n_.y(), n_.z());
        // }
        return c;

    }

    std::string toString() const
    {
        return "PRTIntegrator[]";
    }

private:
    Type m_Type;
    int m_Bounce = 1;
    int m_SampleCount = 100;
    std::string m_CubemapPath;
    Eigen::MatrixXf m_TransportSHCoeffs;  // 存储传输球谐系数的矩阵
    Eigen::MatrixXf m_LightCoeffs; // 存储环境光照球谐系数的矩阵
};

NORI_REGISTER_CLASS(PRTIntegrator, "prt");
NORI_NAMESPACE_END