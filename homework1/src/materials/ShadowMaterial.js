class ShadowMaterial extends Material {

    constructor(light, translate, scale, vertexShader, fragmentShader) {
        let lightMVP = light.CalcLightMVP(translate, scale);

        super({
            'uLightMVP': { type: 'matrix4fv', value: lightMVP }
        }, [], vertexShader, fragmentShader, light.fbo);
    }
}

//用于创建一个ShadowMaterial实例
async function buildShadowMaterial(light, translate, scale, vertexPath, fragmentPath) {


    let vertexShader = await getShaderString(vertexPath);
    let fragmentShader = await getShaderString(fragmentPath);

    return new ShadowMaterial(light, translate, scale, vertexShader, fragmentShader);

}