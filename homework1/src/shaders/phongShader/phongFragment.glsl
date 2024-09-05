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

  float searchRadius = 0.2 * (posZFromLight - 0.01) / posZFromLight;

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

float PCF(sampler2D shadowMap, vec4 coords) {
  float lengthscale = 10.0;
  float shadowmapSize = 2048.0;
  float curDepth = coords.z;
  float visibility = 0.0;
  float filterRange = lengthscale / shadowmapSize;
  poissonDiskSamples(coords.xy);
  for (int i = 0; i < NUM_SAMPLES; i++) {
    float sampleDepth = unpack(texture2D(shadowMap, coords.xy + poissonDisk[i]*filterRange));
    if (curDepth < sampleDepth + EPS) {
      visibility += 1.0;
    }
  }
  float avgVisibility = visibility / float(NUM_SAMPLES);
  return avgVisibility;
}

#define WeightOfLight 10.0
float PCSS(sampler2D shadowMap, vec4 coords){
  float visibility = 0.0;
  poissonDiskSamples(coords.xy);
  // STEP 1: avgblocker depth
  float avgblockerdepth = findBlocker(shadowMap, coords.xy, coords.z);
  // STEP 2: penumbra size
  float penumbraSize = WeightOfLight*(coords.z - avgblockerdepth) / avgblockerdepth;
  // STEP 3: filtering
  float lengthscale = 10.0;
  float shadowmapSize = 2048.0;
  float curDepth = coords.z;
  float filterRange = penumbraSize*lengthscale / shadowmapSize;
  for (int i = 0; i < NUM_SAMPLES; i++) {
    float sampleDepth = unpack(texture2D(shadowMap, coords.xy + poissonDisk[i]*filterRange));
    if (curDepth < sampleDepth + EPS) {
      visibility += 1.0;
    }
  }
  float avgVisibility = visibility / float(NUM_SAMPLES);
  return avgVisibility;
}

float Bias(){
  vec3 lightDir1 = normalize(uLightPos);
  vec3 normal1 = normalize(vNormal);
  float bias1 = max(0.08 * (1.0-dot(normal1,lightDir1)),0.08);
  return bias1;
}

float useShadowMap(sampler2D shadowMap, vec4 shadowCoord){
  float mapDepth = unpack(texture2D(shadowMap,shadowCoord.xy));//shadow map中各点的最小深度，unpack将RGBA值转换成[0,1]的float
  float shadingDepth = shadowCoord.z; //当前着色点的深度
  float bias = Bias();
  float visibility1 = ((mapDepth + EPS) < (shadingDepth - bias)) ? 0.2 : 0.9;  
  return visibility1;
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

  float visibility;
  vec3 shadowCoord = vPositionFromLight.xyz / vPositionFromLight.w;
  //将 NDC 的范围从 [-1, 1] 映射到 [0, 1],可以直接用来作为纹理坐标去访问阴影贴图
  shadowCoord = shadowCoord * 0.5 + 0.5;

  //visibility = useShadowMap(uShadowMap, vec4(shadowCoord, 1.0));
  //visibility = PCF(uShadowMap, vec4(shadowCoord, 1.0));
  visibility = PCSS(uShadowMap, vec4(shadowCoord, 1.0));

  vec3 phongColor = blinnPhong();

  gl_FragColor = vec4(phongColor * visibility, 1.0);
  //gl_FragColor = vec4(phongColor, 1.0);
}