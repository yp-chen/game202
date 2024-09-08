#include <iostream>
#include <vector>
#include <algorithm>
#include <cmath>
#include <sstream>
#include <fstream>
#include <random>
#include "vec.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION

#include "stb_image_write.h"

const int resolution = 128;

typedef struct samplePoints {
    std::vector<Vec3f> directions;
	std::vector<float> PDFs;//这里的PDFs是pdf的缩写
}samplePoints;

//采样cosine半球
samplePoints squareToCosineHemisphere(int sample_count){
    samplePoints samlpeList;
    const int sample_side = static_cast<int>(floor(sqrt(sample_count)));

    //这里需要使用static，否则每次调用函数都会重新初始化随机数生成器，导致得到的图与要求不符
    static std::random_device rd;
    static std::mt19937 gen(rd());
    static std::uniform_real_distribution<> rng(0.0, 1.0);
    for (int t = 0; t < sample_side; t++) {
        for (int p = 0; p < sample_side; p++) {
            double samplex = (t + rng(gen)) / sample_side;
            double sampley = (p + rng(gen)) / sample_side;
            
            double theta = 0.5f * acos(1 - 2*samplex);
            double phi =  2 * PI * sampley;
            Vec3f wi = Vec3f(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
            float pdf = wi.z / PI;
            
            samlpeList.directions.push_back(wi);
            samlpeList.PDFs.push_back(pdf);
        }
    }
    return samlpeList;
}

//得到brdf的FDG项的D项
//N:法线 H:半程向量 roughness:粗糙度
float DistributionGGX(Vec3f N, Vec3f H, float roughness)
{
    float a = roughness*roughness;
    float a2 = a*a;
    float NdotH = std::max(dot(N, H), 0.0f);
    float NdotH2 = NdotH*NdotH;

    float nom   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return nom / std::max(denom, 0.0001f);
}

//得到brdf的FDG项的G项中的Schlick项
//NdotV:法线与视角的夹角 roughness:粗糙度
float GeometrySchlickGGX(float NdotV, float roughness) {
    //这里好像和ppt上的公式不太一样，ppT上是k = (a + 1)^2 / 8，这里是k = (a * a) / 2.0f
    float a = roughness;
    float k = (a * a) / 2.0f;

    float nom = NdotV;
    float denom = NdotV * (1.0f - k) + k;

    return nom / denom;
}

//得到brdf的FDG项的G项
//roughness:粗糙度 NoV:法线与视角的夹角 NoL:法线与光线的夹角
float GeometrySmith(float roughness, float NoV, float NoL) {
    float ggx2 = GeometrySchlickGGX(NoV, roughness);
    float ggx1 = GeometrySchlickGGX(NoL, roughness);

    return ggx1 * ggx2;
}

Vec3f IntegrateBRDF(Vec3f V, float roughness, float NdotV) {
    float A = 0.0;
    float B = 0.0;
    float C = 0.0;
    const int sample_count = 1024;
    //法线
    Vec3f N = Vec3f(0.0, 0.0, 1.0);
    
    samplePoints sampleList = squareToCosineHemisphere(sample_count);
    for (int i = 0; i < sample_count; i++) {
        // TODO: To calculate (fr * ni) / p_o here
        Vec3f L = normalize(sampleList.directions[i]); //这里的L是wi
        Vec3f H = normalize(V + L);
        float PDF = sampleList.PDFs[i];
        float NdotL = std::max(dot(N, L), 0.0f);

        //考虑全反射，这里的F是1.0
        float F = 1.0f;
        float D = DistributionGGX(N, H, roughness);
        float G = GeometrySmith(roughness, NdotV, NdotL);
        float FGD = F * G * D;
        float brdf = FGD / (4.0 * NdotV * NdotL);
        A = B = C += brdf / PDF * NdotL;//这里的NdotL是mu,是cosine项
    }

    return {A / sample_count, B / sample_count, C / sample_count};
}

//预计算一个BRDF的查找表（Lookup Table，简称LUT）
int main() {
    //这里的resolution是128，是生成的lut的分辨率,存储RGB值，所以乘3
    uint8_t data[resolution * resolution * 3];
    float step = 1.0 / resolution;
    for (int i = 0; i < resolution; i++) {
        for (int j = 0; j < resolution; j++) {
            //线性插值得到，在生成LUT时
            //考虑从完全光滑（roughness = 0）到完全粗糙（roughness = 1）的不同级别，且每个级别要能够通过插值得到。这样，在实际渲染时，可以使用这些预计算的值来加速复杂的BRDF计算。
            float roughness = step * (static_cast<float>(i) + 0.5f);
            float NdotV = step * (static_cast<float>(j) + 0.5f);
            //V向量代表了从表面法线指向观察者的单位向量，并且在这个场景中忽略了在y轴的任何分量。这是因为我们假设BRDF是各向同性的，而且只依赖于角度差，而不是具体的方向。
            Vec3f V = Vec3f(std::sqrt(1.f - NdotV * NdotV), 0.f, NdotV);

            Vec3f irr = IntegrateBRDF(V, roughness, NdotV);

            //将结果转换为0到255范围内的颜色值，并存入 data 数组。
            data[(i * resolution + j) * 3 + 0] = uint8_t(irr.x * 255.0);
            data[(i * resolution + j) * 3 + 1] = uint8_t(irr.y * 255.0);
            data[(i * resolution + j) * 3 + 2] = uint8_t(irr.z * 255.0);
        }
    }
    stbi_flip_vertically_on_write(true);
    stbi_write_png("GGX_E_MC_LUT.png", resolution, resolution, 3, data, resolution * 3);
    
    std::cout << "Finished precomputed!" << std::endl;
    return 0;
}