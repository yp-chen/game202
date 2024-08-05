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

//这个函数是为了生成Hammersley序列
//Hammersley 是用来生成在单位平方内均匀分布的点序列的。
//Hammersley序列是一个低差异（quasi-random）的序列，与伪随机数相比，在多维采样时能更均匀地覆盖采样区域。
//它常用于计算机图形学中，特别是光照渲染技术如蒙特卡洛积分中，因为它可以减少采样噪声并加快收敛速度。
//返回：[0, 1) x [0, 1),得到的就是公式θ m = arctan((α √ ξ1)/(√ 1 − ξ1))   ϕ h = 2πξ2中的ξ1和ξ2
Vec2f Hammersley(uint32_t i, uint32_t N) { // 0-1
    uint32_t bits = (i << 16u) | (i >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    float rdi = float(bits) * 2.3283064365386963e-10;
    return {float(i) / float(N), rdi};
}

//重要性采样GGX
//通过给定的随机变量 Xi（由Hammersley序列生成）法线 N，以及粗糙度 roughness 来生成一个半球内的采样向量。
Vec3f ImportanceSampleGGX(Vec2f Xi, Vec3f N, float roughness) {
    float a = roughness * roughness;

    //TODO: in spherical space - Bonus 1
    //得到球坐标系下的theta和phi
    float theta = atan(a * sqrt(Xi.x) / sqrt(1.0f - Xi.x));
    float phi = 2.0f * PI * Xi.y;

    //TODO: from spherical space to cartesian space - Bonus 1
    //得到对应的三维坐标
    float sinTheta = sin(theta);
    float cosTheta = cos(theta);
    Vec3f H = Vec3f(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);

    //TODO: tangent coordinates - Bonus 1
    //得到切线坐标系
    Vec3f up = abs(N.z) < 0.999 ? Vec3f(0.0, 0.0, 1.0) : Vec3f(1.0, 0.0, 0.0);
    Vec3f tangent = normalize(cross(up, N));
    Vec3f bitangent = cross(N, tangent);

    //TODO: transform H to tangent space - Bonus 1
    //将H从世界坐标系转换到切线坐标系
    return normalize(tangent * H.x + bitangent * H.y + N * H.z);
}

//得到brdf的FDG项的G项中的Schlick项
//NdotV:法线与视角的夹角 roughness:粗糙度
float GeometrySchlickGGX(float NdotV, float roughness) {
    // TODO: To calculate Schlick G1 here - Bonus 1
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

//V:视角，也就是公式中的o roughness:粗糙度
Vec3f IntegrateBRDF(Vec3f V, float roughness) {

    const int sample_count = 1024;
    float A = 0.0;
    //法线，也就是公式中的n
    Vec3f N = Vec3f(0.0, 0.0, 1.0);
    for (int i = 0; i < sample_count; i++) {
        Vec2f Xi = Hammersley(i, sample_count);
        //也就是公式中的m和h
        Vec3f H = ImportanceSampleGGX(Xi, N, roughness);
        //光照方向，也就是公式中的i
        Vec3f L = normalize(H * 2.0f * dot(V, H) - V);

        float NoL = std::max(L.z, 0.0f);
        float NoH = std::max(H.z, 0.0f);
        float VoH = std::max(dot(V, H), 0.0f);
        float NoV = std::max(dot(N, V), 0.0f);
        
        // TODO: To calculate (fr * ni) / p_o here - Bonus 1'
        float G = GeometrySmith(roughness, NoV, NoL);
        A += (VoH * G) / (NoV * NoH);
        // Split Sum - Bonus 2
        
    }

    return Vec3f(A/sample_count, A/sample_count, A/sample_count); // No split sum version
}

int main() {
    uint8_t data[resolution * resolution * 3];
    float step = 1.0 / resolution;
    for (int i = 0; i < resolution; i++) {
        for (int j = 0; j < resolution; j++) {
            float roughness = step * (static_cast<float>(i) + 0.5f);
            float NdotV = step * (static_cast<float>(j) + 0.5f);
            Vec3f V = Vec3f(std::sqrt(1.f - NdotV * NdotV), 0.f, NdotV);

            Vec3f irr = IntegrateBRDF(V, roughness);

            data[(i * resolution + j) * 3 + 0] = uint8_t((1-irr.x) * 255.0);
            data[(i * resolution + j) * 3 + 1] = uint8_t((1-irr.y) * 255.0);
            data[(i * resolution + j) * 3 + 2] = uint8_t((1-irr.z) * 255.0);
        }
    }
    // stbi_flip_vertically_on_write(true);
    stbi_write_png("GGX_E_LUT_2.png", resolution, resolution, 3, data, resolution * 3);
    
    std::cout << "Finished precomputed!" << std::endl;
    return 0;
}