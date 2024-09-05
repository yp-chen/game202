//通过extends关键字继承Material类
class PhongMaterial extends Material {

    //构造函数传入了以下参数：
    // vec3f color->材质颜色
    // vec3f specular->材质的高光项
    // 类 light ->光源
    // translate&scale -> 根据engine.js定义的setTransform()分别赋值
    constructor(color, specular, light, translate, rotate, scale, lightIndex, vertexShader, fragmentShader) {
        //计算光源的MVP矩阵
        let lightMVP = light.CalcLightMVP(translate, rotate, scale);
        //获取光源的强度
        let lightIntensity = light.mat.GetIntensity();

        //调用父类Material的构造函数
        super({
            // Phong
            'uSampler': { type: 'texture', value: color },
            'uKs': { type: '3fv', value: specular },
            'uLightIntensity': { type: '3fv', value: lightIntensity },
            // Shadow
            'uShadowMap': { type: 'texture', value: light.fbo },
            'uLightMVP': { type: 'matrix4fv', value: lightMVP },

        }, [], vertexShader, fragmentShader, null, lightIndex);
    }
}

async function buildPhongMaterial(color, specular, light, translate, rotate, scale, lightIndex, vertexPath, fragmentPath) {


    let vertexShader = await getShaderString(vertexPath);
    let fragmentShader = await getShaderString(fragmentPath);

    return new PhongMaterial(color, specular, light, translate, rotate, scale, lightIndex, vertexShader, fragmentShader);

}