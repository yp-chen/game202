class DirectionalLight {

    constructor(lightIntensity, lightColor, lightPos, focalPoint, lightUp, hasShadowMap, gl) {
        this.mesh = Mesh.cube(setTransform(0, 0, 0, 0.2, 0.2, 0.2, 0));//创建一个立方体
        this.mat = new EmissiveMaterial(lightIntensity, lightColor);//创建一个发光材质
        this.lightPos = lightPos;//光源位置
        this.focalPoint = focalPoint;//聚光点
        this.lightUp = lightUp//光源朝向

        this.hasShadowMap = hasShadowMap;//方向光是否有ShadowMap
        this.fbo = new FBO(gl);//class FBO里创建了framebuffer
        if (!this.fbo) {
            console.log("无法设置帧缓冲区对象");
            return;
        }
    }

    //计算光源的MVP矩阵,为了实现第一趟pass
    //参数translate: 光源位置
    //参数scale: 光源缩放
    CalcLightMVP(translate, scale) {
        let lightMVP = mat4.create();
        let modelMatrix = mat4.create();
        let viewMatrix = mat4.create();
        let projectionMatrix = mat4.create();

        // Model transform
        mat4.translate(modelMatrix, modelMatrix, translate);//光源位置
        mat4.scale(modelMatrix, modelMatrix, scale);//光源缩放
        // View transform
        //位置、朝向、上方向
        mat4.lookAt(viewMatrix, this.lightPos, this.focalPoint, this.lightUp);//光源朝向
        // Projection transform
        mat4.ortho(projectionMatrix,-100,100,-100,100,1e-2,400);//正交投影
        //将b*c存储在a中
        mat4.multiply(lightMVP, projectionMatrix, viewMatrix);
        mat4.multiply(lightMVP, lightMVP, modelMatrix);

        return lightMVP;
    }
}
