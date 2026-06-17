// live2d_path 建议使用绝对路径
// 使用本地资源，零延迟加载
const live2d_path = "/live2d-widget/";
// 如需从 CDN 加载，取消下面注释
//const live2d_path = "https://fastly.jsdelivr.net/gh/stevenjoezhang/live2d-widget@latest/";

// 封装异步加载资源的方法
function loadExternalResource(url, type) {
	return new Promise((resolve, reject) => {
		let tag;

		if (type === "css") {
			tag = document.createElement("link");
			tag.rel = "stylesheet";
			tag.href = url;
		}
		else if (type === "js") {
			tag = document.createElement("script");
			tag.src = url;
		}
		if (tag) {
			tag.onload = () => resolve(url);
			tag.onerror = () => reject(url);
			document.head.appendChild(tag);
		}
	});
}

// waifu-tips 文字颜色自适应：30fps 采样背景色
function startWaifuTipsColorAdapt() {
	var TARGET_FPS = 30;
	var frameInterval = Math.round(1000 / TARGET_FPS);
	var lastFrameTime = 0;
	var canvas = document.createElement('canvas');
	var ctx = canvas.getContext('2d', { willReadFrequently: true });
	canvas.width = 1;
	canvas.height = 1;
	var sampling = false;

	function getLuminance(r, g, b) {
		return 0.299 * r + 0.587 * g + 0.114 * b;
	}

	function sampleBackground() {
		var tips = document.getElementById('waifu-tips');
		if (!tips || !tips.classList.contains('waifu-tips-active')) return;

		var rect = tips.getBoundingClientRect();
		var sampleX = Math.round(rect.left + rect.width / 2);
		var sampleY = Math.round(rect.top + rect.height / 2);

		// 采样视频背景（如果可见）
		var video = document.querySelector('.header-video-bg');
		if (video && video.videoWidth > 0 && document.body.classList.contains('is-video-page')) {
			try {
				ctx.drawImage(video, sampleX, sampleY, 1, 1, 0, 0, 1, 1);
				var pixel = ctx.getImageData(0, 0, 1, 1).data;
				var lum = getLuminance(pixel[0], pixel[1], pixel[2]);
				tips.style.color = lum > 128 ? '#1a1a1a' : '#ffffff';
				return;
			} catch (e) { /* fallback below */ }
		}

		// 采样页面背景色
		var bodyBg = getComputedStyle(document.body).backgroundColor;
		var match = bodyBg.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
		if (match) {
			var lum = getLuminance(parseInt(match[1]), parseInt(match[2]), parseInt(match[3]));
			tips.style.color = lum > 128 ? '#1a1a1a' : '#ffffff';
		}
	}

	function tick(now) {
		if (!sampling) return;
		if (now - lastFrameTime >= frameInterval) {
			lastFrameTime = now;
			sampleBackground();
		}
		requestAnimationFrame(tick);
	}

	// 开始采样（延迟启动，等待 DOM 就绪）
	setTimeout(function () {
		sampling = true;
		requestAnimationFrame(tick);
	}, 1500);
}

// 加载 waifu.css live2d.min.js waifu-tips.js
if (screen.width >= 768) {
	Promise.all([
		loadExternalResource(live2d_path + "waifu.css", "css"),
		loadExternalResource(live2d_path + "live2d.min.js", "js"),
		loadExternalResource(live2d_path + "waifu-tips.js", "js")
	]).then(() => {
		// 模型列表版本号，更新 model_list.json 后手动递增
		// 旧版本 localStorage 中的 modelId 会被自动清除
		var modelListVersion = "v7";
		if (localStorage.getItem("modelListVersion") !== modelListVersion) {
			localStorage.removeItem("modelId");
			localStorage.removeItem("modelTexturesId");
			localStorage.setItem("modelListVersion", modelListVersion);
		}
		// 配置选项的具体用法见 README.md
		initWidget({
			waifuPath: live2d_path + "waifu-tips.json",
			//apiPath: "https://live2d.fghrsh.net/api/",
			// 本地模型路径（widget 会自动拼接 model/ 子目录）
			cdnPath: live2d_path,
			tools: ["hitokoto", "asteroids", "switch-model", "switch-texture", "photo", "info", "quit"],

			//指定默认加载的模型ID=
			modelId: 8,
			//可选：同时指定默认皮肤ID
			modelTexturesId: 0
		});
		// 启动 waifu-tips 文字颜色自适应
		startWaifuTipsColorAdapt();
	});
}

console.log(`
  く__,.ヘヽ.        /  ,ー､ 〉
           ＼ ', !-─‐-i  /  /´
           ／｀ｰ'       L/／｀ヽ､
         /   ／,   /|   ,   ,       ',
       ｲ   / /-‐/  ｉ  L_ ﾊ ヽ!   i
        ﾚ ﾍ 7ｲ｀ﾄ   ﾚ'ｧ-ﾄ､!ハ|   |
          !,/7 '0'     ´0iソ|    |
          |.从"    _     ,,,, / |./    |
          ﾚ'| i＞.､,,__  _,.イ /   .i   |
            ﾚ'| | / k_７_/ﾚ'ヽ,  ﾊ.  |
              | |/i 〈|/   i  ,.ﾍ |  i  |
             .|/ /  ｉ：    ﾍ!    ＼  |
              kヽ>､ﾊ    _,.ﾍ､    /､!
              !'〈//｀Ｔ´', ＼ ｀'7'ｰr'
              ﾚ'ヽL__|___i,___,ンﾚ|ノ
                  ﾄ-,/  |___./
                  'ｰ'    !_,.:
`);
