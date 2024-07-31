attribute vec3 aVertexPosition;
attribute vec3 aNormalPosition;
attribute mat3 aPrecomputeLT;

uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;

//存储了预计算光照的球谐系数，通常包含9个系数，这里表现为三个mat3类型的矩阵
uniform mat3 uPrecomputeL[3];

varying highp vec3 vNormal;
varying highp mat3 vPrecomputeLT;
varying highp vec3 vColor;

float L_dot_LT(mat3 PrecomputeL, mat3 PrecomputeLT) {
  vec3 L_0 = PrecomputeL[0];
  vec3 L_1 = PrecomputeL[1];
  vec3 L_2 = PrecomputeL[2];
  vec3 LT_0 = PrecomputeLT[0];
  vec3 LT_1 = PrecomputeLT[1];
  vec3 LT_2 = PrecomputeLT[2];
  return dot(L_0, LT_0) + dot(L_1, LT_1) + dot(L_2, LT_2);
}

void main(void) {
  // 无实际作用，避免aNormalPosition被优化后产生警告
  vNormal = (uModelMatrix * vec4(aNormalPosition, 0.0)).xyz;

  for(int i = 0; i < 3; i++)
  {
    vColor[i] = L_dot_LT(aPrecomputeLT, uPrecomputeL[i]);
  }

  //在渲染管线中，每个顶点最终传递给片元着色器之前，其位置必须被指定到 gl_Position 中
  gl_Position = uProjectionMatrix * uViewMatrix * uModelMatrix * vec4(aVertexPosition, 1.0);
}