class Material {
    //#表示私有字段，类似cpp里的private
    #flatten_uniforms;//统一属性
    #flatten_attribs;//额外属性
    #vsSrc;//顶点着色器
    #fsSrc;//片元着色器
    // Uniforms is a map, attribs is a Array
    //构造函数constructor()————创建和初始化在类中创建的对象
    constructor(uniforms, attribs, vsSrc, fsSrc, frameBuffer, lightIndex) {
        this.uniforms = uniforms;
        this.attribs = attribs;
        this.#vsSrc = vsSrc;
        this.#fsSrc = fsSrc;
        
        this.#flatten_uniforms = ['uViewMatrix','uModelMatrix', 'uProjectionMatrix', 'uCameraPos', 'uLightPos'];
        for (let k in uniforms) {
            this.#flatten_uniforms.push(k);
        }
        this.#flatten_attribs = attribs;

        this.frameBuffer = frameBuffer;
        this.lightIndex = lightIndex;
    }

    //创建一个方法，用以储存mesh的额外属性
    setMeshAttribs(extraAttribs) {
        for (let i = 0; i < extraAttribs.length; i++) {
            this.#flatten_attribs.push(extraAttribs[i]);
        }
    }

    //创建一个方法，以实现调用Shader类以编译shader
    compile(gl) {
        return new Shader(gl, this.#vsSrc, this.#fsSrc,
            {
                uniforms: this.#flatten_uniforms,
                attribs: this.#flatten_attribs
            });
    }
}