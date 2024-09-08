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

//该函数返回一个0-1随机数，类型为float
//fract函数返回x - floor(x),即返回x的小数部分
float Rand1(inout float p) {
  //几个步骤用来打乱p的值，生成一个伪随机数
  p = fract(p * .1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

//该函数返回一个二维伪随机数，类型为vec2
vec2 Rand2(inout float p) {
  return vec2(Rand1(p), Rand1(p));
}

//这个函数产生一个随机数种子，用于后续的随机数生成
float InitRand(vec2 uv) {
	vec3 p3  = fract(vec3(uv.xyx) * .1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

//均匀采样上半球面，取得采样方向和对应pdf
vec3 SampleHemisphereUniform(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = uv.x;
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(1.0 - z*z);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = INV_TWO_PI;
  return dir;
}

//按照cosine权重采样上半球面，取得采样方向和对应pdf
vec3 SampleHemisphereCos(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = sqrt(1.0 - uv.x);
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(uv.x);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = z * INV_PI;
  return dir;
}

//用于根据传入的法线方向n，建立局部坐标系，并返回b1和b2两个切线向量
void LocalBasis(vec3 n, out vec3 b1, out vec3 b2) {
  float sign_ = sign(n.z);
  if (n.z == 0.0) {
    sign_ = 1.0;//确保后续除法不会由于分母为零而导致问题
  }
  float a = -1.0 / (sign_ + n.z);
  float b = n.x * n.y * a;
  b1 = vec3(1.0 + sign_ * n.x * n.x * a, sign_ * b, -sign_ * n.x);
  b2 = vec3(b, sign_ + n.y * n.y * a, -n.y);
}

vec4 Project(vec4 a) {
  return a / a.w;
}
//得到屏幕空间的深度值
float GetDepth(vec3 posWorld) {
  float depth = (vWorldToScreen * vec4(posWorld, 1.0)).w;
  return depth;
}

/*
 * Transform point from world space to screen space([0, 1] x [0, 1])
 *
 */
//获取屏幕空间的坐标 
vec2 GetScreenCoordinate(vec3 posWorld) {
  vec2 uv = Project(vWorldToScreen * vec4(posWorld, 1.0)).xy * 0.5 + 0.5;
  return uv;
}

//根据uv从纹理处获取深度值
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
  //2.2是gamma校正
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
//fr⋅cos(θi),漫反射，乘上了1/pi
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
//返回着色点位于uv处得到的光源的辐射度,Li⋅V
vec3 EvalDirectionalLight(vec2 uv) {
  vec3 Le = GetGBufferuShadow(uv) * uLightRadiance;
  return Le;
}

//返回是否相交，相交时将hitPos设置为交点
//ori代表光线的起点，dir代表光线的方向
bool RayMarch(vec3 ori, vec3 dir, out vec3 hitPos) {
  float step = 0.05;
  const int maxStep = 150;  //最大步数
  vec3 stepWithDir = step * dir;
  vec3 curPos = ori;
  for (int i = 0; i < maxStep; i++) {
    float depth = GetDepth(curPos);
    vec2 uv = GetScreenCoordinate(curPos);
    float gDepth = GetGBufferDepth(uv);
    if (depth - gDepth > 0.0001) {
      hitPos = curPos;
      return true;
    }
    curPos += stepWithDir;
  }
  return false;
}

#define SAMPLE_NUM 32

void main() {
  float s = InitRand(gl_FragCoord.xy);//初始化随机数种子

  vec3 L = vec3(0.0);
  vec2 uv = GetScreenCoordinate(vPosWorld.xyz);
  vec3 wi = normalize(uLightDir);
  vec3 wo = normalize(uCameraPos - vPosWorld.xyz);
  //直接光照,由于使用的是平行光，所以不需要积分
  L = EvalDiffuse(wi, wo, uv) * EvalDirectionalLight(uv);
 
  vec3 L_ind = vec3(0.0);
  for(int i = 0; i < SAMPLE_NUM; i++){
    float pdf;
    vec3 localDir = SampleHemisphereCos(s, pdf);//得到一个随机方向和pdf
    vec3 b1,b2;
    vec3 normal = GetGBufferNormalWorld(uv);
    LocalBasis(normal, b1, b2);
    //TBN矩阵，N放最后面
    vec3 dir = normalize(mat3(b1, b2, normal) * localDir);//将随机方向转换到世界坐标系

    vec3 hitPos;
    if (RayMarch(vPosWorld.xyz, dir, hitPos)) {
      vec2 hitPosuv = GetScreenCoordinate(hitPos);
      //两次反射
      L_ind += EvalDiffuse(dir, wo, uv) / pdf * EvalDiffuse(wi, dir, hitPosuv) * EvalDirectionalLight(hitPosuv);
    }
  }

  //间接光照
  L_ind /= float(SAMPLE_NUM);

  L = L + L_ind;
  //使用 clamp 函数将向量 L 的每个分量限制在0.0和1.0之间
  //使用 pow 函数对限制后的颜色 L 进行伽马校正，使用了伽马值2.2
  vec3 color = pow(clamp(L, vec3(0.0), vec3(1.0)), vec3(1.0 / 2.2));
  gl_FragColor = vec4(vec3(color.rgb), 1.0);
}
