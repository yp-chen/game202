//相机位置的全局变量
var cameraPosition = [30, 30, 30]

//生成的纹理的分辨率，纹理必须是标准的尺寸 256*256 1024*1024  2048*2048
var resolution = 2048;
var fbo;

GAMES202Main();

function GAMES202Main() {
	// document文档节点（也叫根节点），可以访问整个HTML文档
	// document.querySelector -> 获取文档中id为glcanvas的元素
	const canvas = document.querySelector('#glcanvas');
	// 给当前图形标签添加高宽属性
	canvas.width = window.screen.width;
	canvas.height = window.screen.height;
	// canvas标签的getContext()方法，这里表示：
	// 创建一个WebGLRenderingContext对象作为3D渲染的上下文
	const gl = canvas.getContext('webgl');
	if (!gl) {
		alert('Unable to initialize WebGL. Your browser or machine may not support it.');
		return;
	}

	//创建相机
	const camera = new THREE.PerspectiveCamera(75, gl.canvas.clientWidth / gl.canvas.clientHeight, 1e-2, 1000);
	//设置相机位置
	camera.position.set(cameraPosition[0], cameraPosition[1], cameraPosition[2]);

	//设置相机的长宽比
	function setSize(width, height) {
		camera.aspect = width / height;
		//更新相机的投影矩阵
		camera.updateProjectionMatrix();
	}
	setSize(canvas.clientWidth, canvas.clientHeight);
	//监听窗口大小变化
	window.addEventListener('resize', () => setSize(canvas.clientWidth, canvas.clientHeight));
	
	//相机控制器
	const cameraControls = new THREE.OrbitControls(camera, canvas);
	cameraControls.enableZoom = true;//缩放
	cameraControls.enableRotate = true;//旋转
	cameraControls.enablePan = true;//平移
	cameraControls.rotateSpeed = 0.3;//旋转速度
	cameraControls.zoomSpeed = 1.0;//缩放速度
	cameraControls.panSpeed = 0.8;//平移速度
	cameraControls.target.set(0, 0, 0);//设置相机的视点

	//创建渲染器
	const renderer = new WebGLRenderer(gl, camera);

	//创建方向光
	let lightPos = [0, 80, 80];//光源位置
	let focalPoint = [0, 0, 0];//聚光焦点
	let lightUp = [0, 1, 0]//光源朝上的方向
	const directionLight = new DirectionalLight(5000, [1, 1, 1], lightPos, focalPoint, lightUp, true, renderer.gl);
	renderer.addLight(directionLight);
	
	//加载模型,并设置位置和缩放比例
	let floorTransform = setTransform(0, 0, -30, 4, 4, 4);
	let obj1Transform = setTransform(0, 0, 0, 20, 20, 20);
	let obj2Transform = setTransform(40, 0, -40, 10, 10, 10);

	loadOBJ(renderer, 'assets/mary/', 'Marry', 'PhongMaterial', obj1Transform);
	loadOBJ(renderer, 'assets/mary/', 'Marry', 'PhongMaterial', obj2Transform);
	loadOBJ(renderer, 'assets/floor/', 'floor', 'PhongMaterial', floorTransform);
	

	// let floorTransform = setTransform(0, 0, 0, 100, 100, 100);
	// let cubeTransform = setTransform(0, 50, 0, 10, 50, 10);
	// let sphereTransform = setTransform(30, 10, 0, 10, 10, 10);

	//loadOBJ(renderer, 'assets/basic/', 'cube', 'PhongMaterial', cubeTransform);
	// loadOBJ(renderer, 'assets/basic/', 'sphere', 'PhongMaterial', sphereTransform);
	//loadOBJ(renderer, 'assets/basic/', 'plane', 'PhongMaterial', floorTransform);

	//创建GUI
	function createGUI() {
		const gui = new dat.gui.GUI();
		// const panelModel = gui.addFolder('Model properties');
		// panelModelTrans.add(GUIParams, 'x').name('X');
		// panelModel.open();
	}
	createGUI();

	//定义一个回调函数mainLoop()
	function mainLoop(now) {
		cameraControls.update();//每次递归更新一次控制器
 
		renderer.render();//每次递归都执行一次渲染
		//递归渲染
		requestAnimationFrame(mainLoop);
	}
	//执行第一帧渲染
	requestAnimationFrame(mainLoop);
}

//设置模型的位置和缩放
function setTransform(t_x, t_y, t_z, s_x, s_y, s_z) {
	return {
		modelTransX: t_x,
		modelTransY: t_y,
		modelTransZ: t_z,
		modelScaleX: s_x,
		modelScaleY: s_y,
		modelScaleZ: s_z,
	};
}
