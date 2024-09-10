#include "denoiser.h"

Denoiser::Denoiser() : m_useTemportal(false) {}

//Screen[i−1] = P[i−1] * V[i−1] * M[i−1] * (M[i]^−1) * World[i]
void Denoiser::Reprojection(const FrameInfo &frameInfo) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    //世界坐标系到屏幕坐标系的矩阵,也就是P[i−1] * V[i−1]
    Matrix4x4 preWorldToScreen =
        m_preFrameInfo.m_matrix[m_preFrameInfo.m_matrix.size() - 1];
    //世界坐标系到摄像机坐标系的矩阵
    Matrix4x4 preWorldToCamera =
        m_preFrameInfo.m_matrix[m_preFrameInfo.m_matrix.size() - 2];
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Reproject
            m_valid(x, y) = false;
            m_misc(x, y) = Float3(0.f);

            int id = frameInfo.m_id(x,y);
            if (id == -1) {
                continue;
            }
            Float3 position = frameInfo.m_position(x, y);
            //也就是M[i]^−1
            Matrix4x4 worldToLocal = Inverse(frameInfo.m_matrix[id]);
            //也就是M[i−1]
            Matrix4x4 preLocalToWorld = m_preFrameInfo.m_matrix[id];
            Float3 localPosition = worldToLocal(position, Float3::EType::Point);
            Float3 preWorldPosition = preLocalToWorld(localPosition, Float3::EType::Point);
            //也就是P[i−1]
            Float3 preScreenPosition = preWorldToScreen(preWorldPosition, Float3::EType::Point);
            if (preScreenPosition.x < 0 || preScreenPosition.x >= width ||
                preScreenPosition.y < 0 || preScreenPosition.y >= height) {
                continue;
            } else {
                int preId = m_preFrameInfo.m_id(preScreenPosition.x, preScreenPosition.y);
                //如果当前像素的id和前一帧的id相同，表示是同一个物体，则将当前像素标记为有效
                //相当于V[i−1]
                if (preId == id) {
                    m_valid(x, y) = true;
                    m_misc(x, y) = m_accColor(preScreenPosition.x, preScreenPosition.y);
                }
            }

        }
    }
    std::swap(m_misc, m_accColor);
}

void Denoiser::TemporalAccumulation(const Buffer2D<Float3> &curFilteredColor) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    int kernelRadius = 3;
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Temporal clamp
            Float3 color = m_accColor(x, y);
            // TODO: Exponential moving average
            float alpha = 1.0f;            
            if (m_valid(x, y)) {
                alpha = m_alpha;
                int x_start = std::max(x - kernelRadius, 0);
                int x_end = std::min(x + kernelRadius, width - 1);
                int y_start = std::max(y - kernelRadius, 0);
                int y_end = std::min(y + kernelRadius, height - 1);

                Float3 mu(0.f);
                Float3 sigma(0.f);
                for (int m = x_start; m <= x_end; m++) {
                    for (int n = y_start; n <= y_end; n++) {
                        mu += curFilteredColor(m, n);
                        sigma += Sqr(curFilteredColor(x, y) - curFilteredColor(m, n));
                    }
                }
                int count = (x_end - x_start + 1) * (y_end - y_start + 1);
                //µ均值
                mu /= float(count);
                //σ标准差
                sigma = SafeSqrt(sigma / float(count));
                // C[i−1] Clamp 在 (µ − kσ,µ + kσ) 范围内
                color = Clamp(color, mu - sigma * m_colorBoxK, mu + sigma * m_colorBoxK);
            }
            m_misc(x, y) = Lerp(color, curFilteredColor(x, y), alpha);
        }
    }
    std::swap(m_misc, m_accColor);
}

Buffer2D<Float3> Denoiser::Filter(const FrameInfo &frameInfo) {
    int height = frameInfo.m_beauty.m_height;
    int width = frameInfo.m_beauty.m_width;
    Buffer2D<Float3> filteredImage = CreateBuffer2D<Float3>(width, height);
    int kernelRadius = 16;
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Joint bilateral filter
            int x_start = std::max(x - kernelRadius, 0);
            int x_end = std::min(x + kernelRadius, width - 1);
            int y_start = std::max(y - kernelRadius, 0);
            int y_end = std::min(y + kernelRadius, height - 1);

            Float3 center_color = frameInfo.m_beauty(x, y);
            Float3 center_normal = frameInfo.m_normal(x, y);
            Float3 center_position = frameInfo.m_position(x, y);

            float total_weight = 0.0f;
            Float3 final_color(0.0f);
            for (int m = x_start; m <= x_end; m++) {
                for (int n = y_start; n <= y_end; n++) {
                    Float3 cur_color = frameInfo.m_beauty(m, n);
                    Float3 cur_normal = frameInfo.m_normal(m, n);
                    Float3 cur_position = frameInfo.m_position(m, n);

                    float d_position = SqrDistance(cur_position, center_position);
                    d_position /= (2.0 * m_sigmaCoord * m_sigmaCoord);
                    
                    float d_color = SqrDistance(cur_color, center_color);
                    d_color /= (2.0 * m_sigmaColor * m_sigmaColor);

                    float d_normal = SafeAcos(Dot(cur_normal, center_normal));
                    d_normal *= d_normal;
                    d_normal /= (2.0 * m_sigmaNormal * m_sigmaNormal);

                    float d_plane = .0f;
                    if (d_position > 0.f) {
                        d_plane = Dot(center_normal, Normalize(cur_position - center_position));
                    }
                    d_plane *= d_plane;
                    d_plane /= (2.0 * m_sigmaPlane * m_sigmaPlane);

                    float weight = std::exp(-d_position - d_color - d_normal - d_plane);
                    total_weight += weight;
                    final_color +=  cur_color * weight;
                }
            }
            if (total_weight == 0.0f) {
                filteredImage(x, y) = center_color;
            } else {
                filteredImage(x, y) = final_color / total_weight;
            }
        }
    }
    return filteredImage;
}

//使用ATrousWavelet加速滤波
Buffer2D<Float3> Denoiser::ATrousWaveletFilter(const FrameInfo &frameInfo) {
    int height = frameInfo.m_beauty.m_height;
    int width = frameInfo.m_beauty.m_width;
    Buffer2D<Float3> filteredImage = CreateBuffer2D<Float3>(width, height);
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Joint bilateral filter

            Float3 center_color = frameInfo.m_beauty(x, y);
            Float3 center_normal = frameInfo.m_normal(x, y);
            Float3 center_position = frameInfo.m_position(x, y);

            float total_weight = 0.0f;
            Float3 final_color(0.0f);
            for (int pass = 0; pass < 5; pass++) {
                for (int filterX = -2; filterX <= 2; filterX++) {
                    for (int filterY = -2; filterY <= 2; filterY++) {

                        int m = x + std::pow(2, pass) * filterX;
                        int n = y + std::pow(2, pass) * filterY;
                        if (m < 0 || m >= width || n < 0 || n >= height) {
                            continue;
                        }
                        Float3 cur_color = frameInfo.m_beauty(m, n);
                        Float3 cur_normal = frameInfo.m_normal(m, n);
                        Float3 cur_position = frameInfo.m_position(m, n);

                        float d_position = SqrDistance(cur_position, center_position);
                        d_position /= (2.0 * m_sigmaCoord * m_sigmaCoord);
                        
                        float d_color = SqrDistance(cur_color, center_color);
                        d_color /= (2.0 * m_sigmaColor * m_sigmaColor);

                        float d_normal = SafeAcos(Dot(cur_normal, center_normal));
                        d_normal *= d_normal;
                        d_normal /= (2.0 * m_sigmaNormal * m_sigmaNormal);

                        float d_plane = .0f;
                        if (d_position > 0.f) {
                            d_plane = Dot(center_normal, Normalize(cur_position - center_position));
                        }
                        d_plane *= d_plane;
                        d_plane /= (2.0 * m_sigmaPlane * m_sigmaPlane);

                        float weight = std::exp(-d_position - d_color - d_normal - d_plane);
                        total_weight += weight;
                        final_color +=  cur_color * weight;
                    }
                }
            }
            if (total_weight == 0.0f) {
                filteredImage(x, y) = center_color;
            } else {
                filteredImage(x, y) = final_color / total_weight;
            }
        }
    }
    return filteredImage;
}
//对于第一帧数据，初始化降噪器的状态，即初始化m_accColor、m_misc、m_valid
void Denoiser::Init(const FrameInfo &frameInfo, const Buffer2D<Float3> &filteredColor) {
    m_accColor.Copy(filteredColor);
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    m_misc = CreateBuffer2D<Float3>(width, height);
    m_valid = CreateBuffer2D<bool>(width, height);
}

//存储前一帧的帧信息，用于插值
void Denoiser::Maintain(const FrameInfo &frameInfo) { m_preFrameInfo = frameInfo; }

//处理当前帧，返回降噪后的图像
Buffer2D<Float3> Denoiser::ProcessFrame(const FrameInfo &frameInfo) {
    //用于存储当前帧的滤波后的图像
    Buffer2D<Float3> filteredColor;
    //对当前帧进行滤波降噪，返回降噪后的图像
    filteredColor = Filter(frameInfo);

    if (m_useTemportal) {
        //对当前帧进行重投影和时序数据融合
        Reprojection(frameInfo);
        TemporalAccumulation(filteredColor);
    } else {
        //第一帧时，初始化降噪器的状态
        Init(frameInfo, filteredColor);
    }

    //存储当前帧信息
    Maintain(frameInfo);
    //将m_useTemportal设置为true,第一帧之后的帧都会使用时序数据进行降噪 
    if (!m_useTemportal) {
        m_useTemportal = true;
    }
    //返回降噪后的图像
    return m_accColor;
}
