class ShadowMaterial extends Material {

    constructor(light, translate, scale, lightIndex, vertexShader, fragmentShader) {
        let lightMVP = light.CalcLightMVP(translate, scale);

        super({
            'uLightMVP': { type: 'matrix4fv', value: lightMVP }
        }, [], vertexShader, fragmentShader, light.fbo, lightIndex);
    }
}

async function buildShadowMaterial(light, translate, scale, lightIndex, vertexPath, fragmentPath) {

    let vertexShader = await getShaderString(vertexPath);
    let fragmentShader = await getShaderString(fragmentPath);

    return new ShadowMaterial(light, translate, scale, lightIndex, vertexShader, fragmentShader);

}