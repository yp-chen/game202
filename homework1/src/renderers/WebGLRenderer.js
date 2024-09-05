class WebGLRenderer {
    meshes = [];// 保存所有的mesh,三角网格
    shadowMeshes = [];// 保存所有的shadowmap
    lights = [];// 保存所有的光源

    constructor(gl, camera) {
        this.gl = gl;
        this.camera = camera;
    }

    addLight(light) {
        this.lights.push({
            entity: light,
            meshRender: new MeshRender(this.gl, light.mesh, light.mat)
        });
    }
    addMeshRender(mesh) { this.meshes.push(mesh); }
    addShadowMeshRender(mesh) { this.shadowMeshes.push(mesh); }

    render(time, deltaime) {
        const gl = this.gl;

        gl.clearColor(0.0, 0.0, 0.0, 1.0); //清空颜色缓冲区的颜色
        gl.clearDepth(1.0); //设置清空深度缓冲区的值
        gl.enable(gl.DEPTH_TEST); //使能深度测试
        gl.depthFunc(gl.LEQUAL); //指定深度测试函数，LEQUAL表示深度值小于或等于参考值时通过

        console.assert(this.lights.length != 0, "No light");
        //console.assert(this.lights.length == 1, "Multiple lights"); //取消多光源检测

        //Edit Start 角色旋转，地面不转(用顶点数筛选)
        for (let i = 0; i < this.meshes.length; i++) {
            if(this.meshes[i].mesh.count > 10)
            {
                this.meshes[i].mesh.transform.rotate[1] = this.meshes[i].mesh.transform.rotate[1] + degrees2Radians(10) * deltaime;
            }
        }
        //Edit End

        for (let l = 0; l < this.lights.length; l++) {
            //切换光源时，对当前光源的shadowmap的framebuffer做一些清理操作
            gl.bindFramebuffer(gl.FRAMEBUFFER, this.lights[l].entity.fbo); // 绑定到当前光源的framebuffer
            gl.clearColor(1.0, 1.0, 1.0, 1.0); // shadowmap默认白色（无遮挡），解决地面边缘产生阴影的问题（因为地面外采样不到，默认值为0会认为是被遮挡）
            gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT); // 清除shadowmap上一帧的颜色、深度缓存，否则会一直叠加每一帧的结果
            // Draw light
            // TODO: Support all kinds of transform
            //Edit Start 灯光围绕原点旋转
            let lightRotateSpped = [10, 80]
            let lightPos = this.lights[l].entity.lightPos;
            lightPos = vec3.rotateY(lightPos, lightPos, this.lights[l].entity.focalPoint, degrees2Radians(lightRotateSpped[l]) * deltaime);
            this.lights[l].entity.lightPos = lightPos; //给DirectionalLight的lightPos赋值新的位置，CalcLightMVP计算LightMVP需要用到
            this.lights[l].meshRender.mesh.transform.translate = lightPos;
            //Edit End
            this.lights[l].meshRender.draw(this.camera);

            // Shadow pass
            if (this.lights[l].entity.hasShadowMap == true) {
                for (let i = 0; i < this.shadowMeshes.length; i++) {
                    if(this.shadowMeshes[i].material.lightIndex != l)
                        continue;// 是当前光源的材质才绘制，否则跳过
                    // 每帧更新shader中uniforms的LightMVP
                    this.gl.useProgram(this.shadowMeshes[i].shader.program.glShaderProgram);
                    let translation = this.shadowMeshes[i].mesh.transform.translate;
                    let rotation = this.shadowMeshes[i].mesh.transform.rotate;
                    let scale = this.shadowMeshes[i].mesh.transform.scale;
                    let lightMVP = this.lights[l].entity.CalcLightMVP(translation, rotation, scale);
                    this.shadowMeshes[i].material.uniforms.uLightMVP = { type: 'matrix4fv', value: lightMVP };
                    this.shadowMeshes[i].draw(this.camera);
                }
            }
            if(l != 0)
            {
                // 开启混合，把Additional Pass混合到Base Pass结果上，否则会覆盖Base Pass的渲染结果
                gl.enable(gl.BLEND);
                gl.blendFunc(gl.ONE, gl.ONE);
            }


            // Camera pass
            for (let i = 0; i < this.meshes.length; i++) {
                if(this.meshes[i].material.lightIndex != l)
                    continue;// 是当前光源的材质才绘制，否则跳过
                this.gl.useProgram(this.meshes[i].shader.program.glShaderProgram);
                // Edit Start 每帧更新shader中uniforms参数
                // this.gl.uniform3fv(this.meshes[i].shader.program.uniforms.uLightPos, this.lights[l].entity.lightPos); //这里改用下面写法
                let translation = this.meshes[i].mesh.transform.translate;
                let rotation = this.meshes[i].mesh.transform.rotate;
                let scale = this.meshes[i].mesh.transform.scale;
                let lightMVP = this.lights[l].entity.CalcLightMVP(translation, rotation, scale);
                this.meshes[i].material.uniforms.uLightMVP = { type: 'matrix4fv', value: lightMVP };
                this.meshes[i].material.uniforms.uLightPos = { type: '3fv', value: this.lights[l].entity.lightPos }; // 光源方向计算、光源强度衰减
                // Edit End
                this.meshes[i].draw(this.camera);
            }
            gl.disable(gl.BLEND);
        }
    }
}