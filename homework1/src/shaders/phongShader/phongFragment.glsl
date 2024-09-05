#ifdef GL_ES
precision mediump float;
#endif

// Phong related variables
uniform sampler2D uSampler;  //采样器
uniform vec3 uKd; //漫反射系数
uniform vec3 uKs; //镜面反射系数
uniform vec3 uLightPos;  //光源位置
uniform vec3 uCameraPos; //相机位置
uniform vec3 uLightIntensity; //光照强度

varying highp vec2 vTextureCoord; //纹理坐标
varying highp vec3 vFragPos;  //片元在世界空间的位置
varying highp vec3 vNormal;   //片元法线

// Shadow map related variables
#define NUM_SAMPLES 80
#define BLOCKER_SEARCH_NUM_SAMPLES NUM_SAMPLES
#define PCF_NUM_SAMPLES NUM_SAMPLES
#define NUM_RINGS 10

//Edit Start
#define SHADOW_MAP_SIZE 2048.
#define FILTER_RADIUS 10.
#define FRUSTUM_SIZE 400.
#define NEAR_PLANE 0.01
#define LIGHT_WORLD_SIZE 5.
#define LIGHT_SIZE_UV LIGHT_WORLD_SIZE / FRUSTUM_SIZE
//Edit End

#define EPS 1e-3
#define PI 3.141592653589793
#define PI2 6.283185307179586

uniform sampler2D uShadowMap;   //阴影贴图

varying vec4 vPositionFromLight;  //片元相对于光源视角的位置

//生成随机数
highp float rand_1to1(highp float x ) { 
  // -1 1
  return fract(sin(x)*10000.0);
}

highp float rand_2to1(vec2 uv ) { 
  // 0 - 1
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract(sin(sn) * c);
}

//将深度值从rgba格式转换成float
float unpack(vec4 rgbaDepth) {
    const vec4 bitShift = vec4(1.0, 1.0/256.0, 1.0/(256.0*256.0), 1.0/(256.0*256.0*256.0));
    return dot(rgbaDepth, bitShift);
}

//泊松采样点
vec2 poissonDisk[NUM_SAMPLES];

//三维点云泊松圆盘采样
void poissonDiskSamples( const in vec2 randomSeed ) {

  float ANGLE_STEP = PI2 * float( NUM_RINGS ) / float( NUM_SAMPLES );
  float INV_NUM_SAMPLES = 1.0 / float( NUM_SAMPLES );

  float angle = rand_2to1( randomSeed ) * PI2;
  float radius = INV_NUM_SAMPLES;
  float radiusStep = radius;

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( cos( angle ), sin( angle ) ) * pow( radius, 0.75 );
    radius += radiusStep;
    angle += ANGLE_STEP;
  }
}

//均匀圆盘采样
void uniformDiskSamples( const in vec2 randomSeed ) {

  float randNum = rand_2to1(randomSeed);
  float sampleX = rand_1to1( randNum ) ;
  float sampleY = rand_1to1( sampleX ) ;

  float angle = sampleX * PI2;
  float radius = sqrt(sampleY);

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( radius * cos(angle) , radius * sin(angle)  );

    sampleX = rand_1to1( sampleY ) ;
    sampleY = rand_1to1( sampleX ) ;

    angle = sampleX * PI2;
    radius = sqrt(sampleY);
  }
}

float findBlocker(sampler2D shadowMap, vec2 uv, float zReceiver) {
  int blockerNum = 0;
  float blockDepth = 0.;

  float posZFromLight = vPositionFromLight.z;

  float searchRadius = LIGHT_SIZE_UV * (posZFromLight - NEAR_PLANE) / posZFromLight;

  poissonDiskSamples(uv);
  for(int i = 0; i < NUM_SAMPLES; i++){
    float shadowDepth = unpack(texture2D(shadowMap, uv + poissonDisk[i] * searchRadius));
    if(zReceiver > shadowDepth){
      blockerNum++;
      blockDepth += shadowDepth;
    }
  }

  if(blockerNum == 0)
    return -1.;
  else
    return blockDepth / float(blockerNum);
}

float getShadowBias(float c, float filterRadiusUV){
  vec3 normal = normalize(vNormal);
  vec3 lightDir = normalize(uLightPos - vFragPos);
  float fragSize = (1. + ceil(filterRadiusUV)) * (FRUSTUM_SIZE / SHADOW_MAP_SIZE / 2.);
  return max(fragSize, fragSize * (1.0 - dot(normal, lightDir))) * c;
}

float useShadowMap(sampler2D shadowMap, vec4 shadowCoord, float biasC, float filterRadiusUV){
  float mapDepth = unpack(texture2D(shadowMap,shadowCoord.xy));//shadow map中各点的最小深度，unpack将RGBA值转换成[0,1]的float
  float shadingDepth = shadowCoord.z; //当前着色点的深度
  float bias = getShadowBias(biasC, filterRadiusUV);
  float visibility1 = ((mapDepth + EPS) < (shadingDepth - bias)) ? 0.0 : 1.0;  
  return visibility1;
}

float PCF(sampler2D shadowMap, vec4 coords, float biasC, float filterRadiusUV) {
  float curDepth = coords.z;
  float visibility = 0.0;
  poissonDiskSamples(coords.xy);
  for (int i = 0; i < NUM_SAMPLES; i++) {
    vec2 offset = poissonDisk[i] * filterRadiusUV;
    float sampleDepth = useShadowMap(shadowMap, coords + vec4(offset, 0., 0.), biasC, filterRadiusUV);
    if (curDepth < sampleDepth + EPS) {
      visibility += 1.0;
    }
  }
  float avgVisibility = visibility / float(NUM_SAMPLES);
  return avgVisibility;
}

#define WeightOfLight 10.0
float PCSS(sampler2D shadowMap, vec4 coords, float biasC){
  float visibility = 0.0;
  poissonDiskSamples(coords.xy);
  // STEP 1: avgblocker depth
  float avgblockerdepth = findBlocker(shadowMap, coords.xy, coords.z);
  // STEP 2: penumbra size
  float penumbraSize = WeightOfLight*(coords.z - avgblockerdepth) / avgblockerdepth;
  // STEP 3: filtering
  return PCF(shadowMap, coords, biasC, penumbraSize);
}

vec3 blinnPhong() {
  vec3 color = texture2D(uSampler, vTextureCoord).rgb;
  color = pow(color, vec3(2.2));

  vec3 ambient = 0.05 * color;

  vec3 lightDir = normalize(uLightPos);
  vec3 normal = normalize(vNormal);
  float diff = max(dot(lightDir, normal), 0.0);
  vec3 light_atten_coff =
      uLightIntensity / pow(length(uLightPos - vFragPos), 2.0);
  vec3 diffuse = diff * light_atten_coff * color;

  vec3 viewDir = normalize(uCameraPos - vFragPos);
  vec3 halfDir = normalize((lightDir + viewDir));
  float spec = pow(max(dot(halfDir, normal), 0.0), 32.0);
  vec3 specular = uKs * light_atten_coff * spec;

  vec3 radiance = (ambient + diffuse + specular);
  vec3 phongColor = pow(radiance, vec3(1.0 / 2.2));
  return phongColor;
}

void main(void) {

  float visibility = 1.;
  vec3 shadowCoord = vPositionFromLight.xyz / vPositionFromLight.w;
  //将 NDC 的范围从 [-1, 1] 映射到 [0, 1],可以直接用来作为纹理坐标去访问阴影贴图
  shadowCoord = shadowCoord * 0.5 + 0.5;

  // 无PCF时的Shadow Bias
  float nonePCFBiasC = .4;
  // 有PCF时的Shadow Bias
  float pcfBiasC = .08;
  // PCF的采样范围，因为是在Shadow Map上采样，需要除以Shadow Map大小，得到uv坐标上的范围
  float filterRadiusUV = FILTER_RADIUS / SHADOW_MAP_SIZE;

  // 硬阴影无PCF，最后参数传0
  //visibility = useShadowMap(uShadowMap, vec4(shadowCoord, 1.0), nonePCFBiasC, 0.);
  //visibility = PCF(uShadowMap, vec4(shadowCoord, 1.0), pcfBiasC, filterRadiusUV);
  visibility = PCSS(uShadowMap, vec4(shadowCoord, 1.0), pcfBiasC);

  vec3 phongColor = blinnPhong();

  gl_FragColor = vec4(phongColor * visibility, 1.0);
  //gl_FragColor = vec4(phongColor, 1.0);
}