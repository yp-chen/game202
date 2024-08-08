#pragma once

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <string>

#include "filesystem/path.h"

#include "util/image.h"
#include "util/mathutil.h"

struct FrameInfo {
  public:
    Buffer2D<Float3> m_beauty;//渲染结果
    Buffer2D<float> m_depth;  //深度
    Buffer2D<Float3> m_normal; //法线
    Buffer2D<Float3> m_position; //位置
    Buffer2D<float> m_id;  //每个像素对应的物体标号，对于没有物体的部分标号为-1
    std::vector<Matrix4x4> m_matrix; //矩阵，m_matrix[i] 表示标号为 i 的物体从物体坐
                                    //标系到世界坐标系的矩阵。
                                    //此外，m_matrix 中的倒数第 2 个和倒数第 1 个分别为
                                    //世界坐标系到摄像机坐标系和世界坐标系到屏幕坐标系 
                                    //([0, W)×[0,H)) 的矩阵。
};

class Denoiser {
  public:
    Denoiser();

    //初始化函数，用于设置降噪器的初始状态，其中包括传入的帧信息和预过滤的颜色缓冲区
    void Init(const FrameInfo &frameInfo, const Buffer2D<Float3> &filteredColor);
    //维护当前和之前帧间的相关数据，以便进行时序降噪操作
    void Maintain(const FrameInfo &frameInfo);
    //重投影功能，用于将前一帧的像素映射到当前帧中，以便进行时序稳定性的处理
    void Reprojection(const FrameInfo &frameInfo);
    //时序累积功能，用于将当前帧的降噪结果与之前帧的累积结果进行融合，以实现时序稳定性
    void TemporalAccumulation(const Buffer2D<Float3> &curFilteredColor);
    //滤波功能，用于对当前帧的图像进行降噪处理
    Buffer2D<Float3> Filter(const FrameInfo &frameInfo);
    Buffer2D<Float3> ATrousWaveletFilter(const FrameInfo &frameInfo);
    //处理当前帧，返回降噪后的图像
    Buffer2D<Float3> ProcessFrame(const FrameInfo &frameInfo);

  public:
    FrameInfo m_preFrameInfo;  //前一帧的帧信息
    Buffer2D<Float3> m_accColor;  //颜色累积缓冲区
    Buffer2D<Float3> m_misc;   //临时缓冲区
    Buffer2D<bool> m_valid;    //像素有效性标记
    bool m_useTemportal;      //表示是否使用时序数据进行降噪的布尔变量

    float m_alpha = 0.2f;   //时序稳定性参数,控制时序累积中新旧数据融合程度的参数
    float m_sigmaPlane = 0.1f;  //平面方差参数，用于指定几何平滑程度
    float m_sigmaColor = 0.6f;  //颜色方差参数，用于确定颜色平滑程度
    float m_sigmaNormal = 0.1f; //法向量方差参数，用于几何边缘检测
    float m_sigmaCoord = 32.0f; //坐标方差参数，与空间滤波相关
    float m_colorBoxK = 1.0f;   //颜色箱参数，可能用于决定颜色滤波的范围
};