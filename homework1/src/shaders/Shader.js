class Shader {

    constructor(gl, vsSrc, fsSrc, shaderLocations) {
        this.gl = gl;
        const vs = this.compileShader(vsSrc, gl.VERTEX_SHADER);
        const fs = this.compileShader(fsSrc, gl.FRAGMENT_SHADER);

        this.program = this.addShaderLocations({
            glShaderProgram: this.linkShader(vs, fs),
        }, shaderLocations);
    }

    //用于编译shader
    //shaderSource: 字符串类型的变量，包含了GLSL(OpenGL Shading Language)着色器代码。
    //shaderType: 指定着色器的类型，通常是 gl.VERTEX_SHADER 或 gl.FRAGMENT_SHADER。
    compileShader(shaderSource, shaderType) {
        const gl = this.gl;
        //创建一个着色器对象
        var shader = gl.createShader(shaderType);
        //将着色器源码写入着色器对象
        gl.shaderSource(shader, shaderSource);
        //编译着色器
        gl.compileShader(shader);

        if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
            console.error(shaderSource);
            console.error('shader compiler error:\n' + gl.getShaderInfoLog(shader));
        }

        //返回编译好的着色器对象
        return shader;
    };

    //用于链接shader
    //vs: 顶点着色器
    //fs: 片元着色器
    linkShader(vs, fs) {
        const gl = this.gl;
        //创建一个着色器程序
        var prog = gl.createProgram();
        //将顶点着色器和片元着色器挂载到着色器程序上
        gl.attachShader(prog, vs);
        gl.attachShader(prog, fs);
        //链接着色器程序,将已经附加的顶点和片元着色器合并起来，确保它们可以共同工作，创建出最终的可执行程序
        gl.linkProgram(prog);

        if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) {
            abort('shader linker error:\n' + gl.getProgramInfoLog(prog));
        }
        return prog;
    };

    //用于获取shader的uniform和attribute的位置
    addShaderLocations(result, shaderLocations) {
        const gl = this.gl;
        result.uniforms = {};
        result.attribs = {};

        //如果shaderLocations存在，且uniforms和attribs存在
        if (shaderLocations && shaderLocations.uniforms && shaderLocations.uniforms.length) {
            for (let i = 0; i < shaderLocations.uniforms.length; ++i) {
                //将uniforms的位置存储到result.uniforms对象中
                //对象的键是attribute的名称，值是其位置
                result.uniforms = Object.assign(result.uniforms, {
                    [shaderLocations.uniforms[i]]: gl.getUniformLocation(result.glShaderProgram, shaderLocations.uniforms[i]),
                });
            }
        }
        if (shaderLocations && shaderLocations.attribs && shaderLocations.attribs.length) {
            for (let i = 0; i < shaderLocations.attribs.length; ++i) {
                //将attribs的位置存储到result.attribs中
                result.attribs = Object.assign(result.attribs, {
                    [shaderLocations.attribs[i]]: gl.getAttribLocation(result.glShaderProgram, shaderLocations.attribs[i]),
                });
            }
        }

        return result;
    }
}
