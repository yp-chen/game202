#ifdef GL_ES
precision highp float;
#endif

uniform vec3 uLightDir;  //光线方向
uniform vec3 uCameraPos;  //摄像机位置
uniform vec3 uLightRadiance;  //光源辐射度
uniform sampler2D uGDiffuse;  //漫反射纹理
uniform sampler2D uGDepth;    //深度纹理
uniform sampler2D uGNormalWorld;   //世界空间法线纹理
uniform sampler2D uGShadow;   //阴影纹理
uniform sampler2D uGPosWorld;   //世界空间位置纹理

varying mat4 vWorldToScreen;  //世界空间到屏幕空间的变换矩阵
varying highp vec4 vPosWorld;  //世界空间位置

#define M_PI 3.1415926535897932384626433832795
#define TWO_PI 6.283185307   //2*M_PI
#define INV_PI 0.31830988618  //1/M_PI
#define INV_TWO_PI 0.15915494309   //1/(2*M_PI)

//用于从半球面采样一个方向，并返回pdf,类型为float
float Rand1(inout float p) {
  p = fract(p * .1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

//用于从单位球面采样一个方向，并返回pdf,类型为vec2
vec2 Rand2(inout float p) {
  return vec2(Rand1(p), Rand1(p));
}

//这个函数用于
float InitRand(vec2 uv) {
	vec3 p3  = fract(vec3(uv.xyx) * .1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec3 SampleHemisphereUniform(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = uv.x;
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(1.0 - z*z);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = INV_TWO_PI;
  return dir;
}

vec3 SampleHemisphereCos(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = sqrt(1.0 - uv.x);
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(uv.x);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = z * INV_PI;
  return dir;
}

void LocalBasis(vec3 n, out vec3 b1, out vec3 b2) {
  float sign_ = sign(n.z);
  if (n.z == 0.0) {
    sign_ = 1.0;
  }
  float a = -1.0 / (sign_ + n.z);
  float b = n.x * n.y * a;
  b1 = vec3(1.0 + sign_ * n.x * n.x * a, sign_ * b, -sign_ * n.x);
  b2 = vec3(b, sign_ + n.y * n.y * a, -n.y);
}

vec4 Project(vec4 a) {
  return a / a.w;
}

float GetDepth(vec3 posWorld) {
  float depth = (vWorldToScreen * vec4(posWorld, 1.0)).w;
  return depth;
}

/*
 * Transform point from world space to screen space([0, 1] x [0, 1])
 *
 */
vec2 GetScreenCoordinate(vec3 posWorld) {
  vec2 uv = Project(vWorldToScreen * vec4(posWorld, 1.0)).xy * 0.5 + 0.5;
  return uv;
}

float GetGBufferDepth(vec2 uv) {
  float depth = texture2D(uGDepth, uv).x;
  if (depth < 1e-2) {
    depth = 1000.0;
  }
  return depth;
}

vec3 GetGBufferNormalWorld(vec2 uv) {
  vec3 normal = texture2D(uGNormalWorld, uv).xyz;
  return normal;
}

vec3 GetGBufferPosWorld(vec2 uv) {
  vec3 posWorld = texture2D(uGPosWorld, uv).xyz;
  return posWorld;
}

float GetGBufferuShadow(vec2 uv) {
  float visibility = texture2D(uGShadow, uv).x;
  return visibility;
}

vec3 GetGBufferDiffuse(vec2 uv) {
  vec3 diffuse = texture2D(uGDiffuse, uv).xyz;
  diffuse = pow(diffuse, vec3(2.2));
  return diffuse;
}

/*
 * Evaluate diffuse bsdf value.
 *
 * wi, wo 为世界坐标系中的值
 * wi为入射方向
 * wo为出射方向
 * uv:着色点的屏幕空间坐标[0, 1] x [0, 1].
 *
 */
vec3 EvalDiffuse(vec3 wi, vec3 wo, vec2 uv) {
  vec3 diffuse = GetGBufferDiffuse(uv);
  vec3 normal = GetGBufferNormalWorld(uv);
  //这里需要写0.，写0显示不出来
  float cosTheta = max(0., dot(wi, normal));
  return diffuse * cosTheta * INV_PI;
}

/*
 * Evaluate directional light with shadow map
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
//返回着色点位于uv处得到的光源的辐射度
vec3 EvalDirectionalLight(vec2 uv) {
  vec3 Le = GetGBufferuShadow(uv) * uLightRadiance;
  return Le;
}

bool RayMarch(vec3 ori, vec3 dir, out vec3 hitPos) {
  return false;
}

#define SAMPLE_NUM 1

void main() {
  float s = InitRand(gl_FragCoord.xy);

  vec3 L = vec3(0.0);
  vec2 uv = GetScreenCoordinate(vPosWorld.xyz);
  vec3 wi = normalize(uLightDir);
  vec3 wo = normalize(uCameraPos - vPosWorld.xyz);
  L = EvalDiffuse(wi, wo, uv) * EvalDirectionalLight(uv);
  //使用 clamp 函数将向量 L 的每个分量限制在0.0和1.0之间
  //使用 pow 函数对限制后的颜色 L 进行伽马校正，使用了伽马值2.2
  vec3 color = pow(clamp(L, vec3(0.0), vec3(1.0)), vec3(1.0 / 2.2));
  gl_FragColor = vec4(vec3(color.rgb), 1.0);
}
