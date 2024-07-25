//相机位置的全局变量
var cameraPosition = [-20, 180, 250];

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
	const camera = new THREE.PerspectiveCamera(75, gl.canvas.clientWidth / gl.canvas.clientHeight, 0.1, 1000);
	//相机控制器
	const cameraControls = new THREE.OrbitControls(camera, canvas);
	cameraControls.enableZoom = true;//缩放
	cameraControls.enableRotate = true;//旋转
	cameraControls.enablePan = true;//平移
	cameraControls.rotateSpeed = 0.3;//旋转速度
	cameraControls.zoomSpeed = 1.0;//缩放速度
	cameraControls.panSpeed = 2.0;//平移速度

	//设置相机的长宽比
	function setSize(width, height) {
		camera.aspect = width / height;
		//更新相机的投影矩阵
		camera.updateProjectionMatrix();
	}
	setSize(canvas.clientWidth, canvas.clientHeight);
	//监听窗口大小变化
	window.addEventListener('resize', () => setSize(canvas.clientWidth, canvas.clientHeight));

	//设置相机位置
	camera.position.set(cameraPosition[0], cameraPosition[1], cameraPosition[2]);
	//设置相机的视点
	cameraControls.target.set(0, 1, 0);

	//创建点光源
	const pointLight = new PointLight(250, [1, 1, 1]);

	//创建渲染器
	const renderer = new WebGLRenderer(gl, camera);
	renderer.addLight(pointLight);
	//加载模型
	loadOBJ(renderer, 'assets/mary/', 'Marry');

	//GUI参数
	var guiParams = {
		modelTransX: 0,
		modelTransY: 0,
		modelTransZ: 0,
		modelScaleX: 52,
		modelScaleY: 52,
		modelScaleZ: 52,
	}
	//创建GUI
	function createGUI() {
		const gui = new dat.gui.GUI();
		const panelModel = gui.addFolder('Model properties');
		const panelModelTrans = panelModel.addFolder('Translation');
		const panelModelScale = panelModel.addFolder('Scale');
		panelModelTrans.add(guiParams, 'modelTransX').name('X');
		panelModelTrans.add(guiParams, 'modelTransY').name('Y');
		panelModelTrans.add(guiParams, 'modelTransZ').name('Z');
		panelModelScale.add(guiParams, 'modelScaleX').name('X');
		panelModelScale.add(guiParams, 'modelScaleY').name('Y');
		panelModelScale.add(guiParams, 'modelScaleZ').name('Z');
		panelModel.open();
		panelModelTrans.open();
		panelModelScale.open();
	}

	createGUI();

	function mainLoop(now) {
		cameraControls.update();

		renderer.render(guiParams);
		requestAnimationFrame(mainLoop);
	}
	requestAnimationFrame(mainLoop);
}
