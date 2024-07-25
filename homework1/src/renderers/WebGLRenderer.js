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

    render() {
        const gl = this.gl;

        gl.clearColor(0.0, 0.0, 0.0, 1.0); //清空颜色缓冲区的颜色
        gl.clearDepth(1.0); //设置清空深度缓冲区的值
        gl.enable(gl.DEPTH_TEST); //使能深度测试
        gl.depthFunc(gl.LEQUAL); //指定深度测试函数，LEQUAL表示深度值小于或等于参考值时通过

        console.assert(this.lights.length != 0, "No light");
        console.assert(this.lights.length == 1, "Multiple lights");

        //对于每一个光源，这里好像只支持一个光源
        for (let l = 0; l < this.lights.length; l++) {
            // Draw light
            // TODO: Support all kinds of transform
            this.lights[l].meshRender.mesh.transform.translate = this.lights[l].entity.lightPos;
            this.lights[l].meshRender.draw(this.camera);

            // 第一趟pass，Shadow pass
            //从光源生成一个shadow map储存(draw)到shadowMeshes[]中
            if (this.lights[l].entity.hasShadowMap == true) {
                for (let i = 0; i < this.shadowMeshes.length; i++) {
                    this.shadowMeshes[i].draw(this.camera);
                }
            }

            // 第二趟pass，Camera pass
            for (let i = 0; i < this.meshes.length; i++) {
                this.gl.useProgram(this.meshes[i].shader.program.glShaderProgram);
                this.gl.uniform3fv(this.meshes[i].shader.program.uniforms.uLightPos, this.lights[l].entity.lightPos);
                this.meshes[i].draw(this.camera);
            }
        }
    }
}