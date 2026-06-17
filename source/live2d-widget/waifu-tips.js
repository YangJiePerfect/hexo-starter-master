! function() {
    "use strict";

    // 随机选择数组元素或返回原值
    function randomPick(arr) {
        return Array.isArray(arr)
            ? arr[Math.floor(Math.random() * arr.length)]
            : arr;
    }

    let tipTimer;

    // 显示提示文字
    function showMessage(msg, timeout, priority) {
        if (
            !msg ||
            (
                sessionStorage.getItem("waifu-text") &&
                sessionStorage.getItem("waifu-text") > priority
            )
        ) return;
        if (tipTimer) {
            clearTimeout(tipTimer);
            tipTimer = null;
        }
        msg = randomPick(msg);
        sessionStorage.setItem("waifu-text", priority);
        const tipsEl = document.getElementById("waifu-tips");
        tipsEl.innerHTML = msg;
        tipsEl.classList.add("waifu-tips-active");
        tipTimer = setTimeout(() => {
            sessionStorage.removeItem("waifu-text");
            tipsEl.classList.remove("waifu-tips-active");
        }, timeout);
    }

    // Live2D 看板娘控制器类
    class Live2DWidget {
        constructor(options) {
            let { apiPath, cdnPath } = options;
            let useCDN = false;
            if (typeof cdnPath === "string") {
                useCDN = true;
                if (!cdnPath.endsWith("/")) cdnPath += "/";
            } else {
                if (typeof apiPath !== "string")
                    throw "Invalid initWidget argument!";
                if (!apiPath.endsWith("/")) apiPath += "/";
            }
            this.useCDN = useCDN;
            this.apiPath = apiPath;
            this.cdnPath = cdnPath;
        }

        async loadModelList() {
            const res = await fetch(`${this.cdnPath}model_list.json`);
            this.modelList = await res.json();
        }

        async loadModel(modelId, texturesId, message) {
            localStorage.setItem("modelId", modelId);
            localStorage.setItem("modelTexturesId", texturesId);
            showMessage(message, 4000, 10);
            if (this.useCDN) {
                if (!this.modelList) await this.loadModelList();
                const modelName = randomPick(this.modelList.models[modelId]);
                loadlive2d(
                    "live2d",
                    `${this.cdnPath}model/${modelName}/index.json`
                );
            } else {
                loadlive2d(
                    "live2d",
                    `${this.apiPath}get/?id=${modelId}-${texturesId}`
                );
                console.log(
                    `Live2D 模型 ${modelId}-${texturesId} 加载完成`
                );
            }
        }

        async loadRandModel() {
            const modelId = localStorage.getItem("modelId");
            const texturesId = localStorage.getItem("modelTexturesId");
            if (this.useCDN) {
                if (!this.modelList) await this.loadModelList();
                const modelName = randomPick(
                    this.modelList.models[modelId]
                );
                const baseUrl = `${this.cdnPath}model/${modelName}/`;
                try {
                    const texRes = await fetch(
                        baseUrl + "textures_order.json"
                    );
                    if (texRes.ok) {
                        const texData = await texRes.json();
                        if (texData.groups && texData.linked) {
                            const indexRes = await (
                                await fetch(baseUrl + "index.json")
                            ).json();
                            const textures = indexRes.textures.slice();

                            // 处理联动纹理组
                            for (const linkedGroup of texData.linked) {
                                const validGroups = linkedGroup.filter(
                                    idx =>
                                        idx >= 0 &&
                                        texData.groups[idx] &&
                                        texData.groups[idx].files.length > 1
                                );
                                if (validGroups.length > 0) {
                                    const randIdx = Math.floor(
                                        Math.random() *
                                        texData.groups[validGroups[0]].files.length
                                    );
                                    for (const idx of validGroups) {
                                        textures[idx] =
                                            `${texData.groups[idx].dir}/` +
                                            `${texData.groups[idx].files[randIdx]}`;
                                    }
                                }
                            }

                            // 处理独立纹理组
                            for (let i = 0; i < texData.groups.length; i++) {
                                const group = texData.groups[i];
                                if (
                                    group &&
                                    group.files.length > 1
                                ) {
                                    textures[i] =
                                        `${group.dir}/` +
                                        `${group.files[Math.floor(Math.random() * group.files.length)]}`;
                                }
                            }

                            indexRes._modelHomeDir = baseUrl;
                            indexRes.textures = textures;
                            loadlive2d("live2d", indexRes);
                            showMessage("我的新衣服好看嘛？", 4000, 10);
                        } else {
                            showMessage(
                                "我还没有其他衣服呢！",
                                4000,
                                10
                            );
                        }
                    } else {
                        showMessage(
                            "我还没有其他衣服呢！",
                            4000,
                            10
                        );
                    }
                } catch (err) {
                    console.error("loadRandModel error:", err);
                    showMessage("我还没有其他衣服呢！", 4000, 10);
                }
            } else {
                fetch(
                    `${this.apiPath}rand_textures/?id=${modelId}-${texturesId}`
                )
                    .then(res => res.json())
                    .then(data => {
                        if (
                            data.textures.id !== 1 ||
                            (texturesId !== "1" && texturesId !== "0")
                        ) {
                            this.loadModel(
                                modelId,
                                data.textures.id,
                                "我的新衣服好看嘛？"
                            );
                        } else {
                            showMessage(
                                "我还没有其他衣服呢！",
                                4000,
                                10
                            );
                        }
                    });
            }
        }

        async loadOtherModel() {
            let modelId = localStorage.getItem("modelId");
            if (this.useCDN) {
                if (!this.modelList) await this.loadModelList();
                const nextId =
                    ++modelId >= this.modelList.models.length
                        ? 0
                        : modelId;
                this.loadModel(
                    nextId,
                    0,
                    this.modelList.messages[nextId]
                );
            } else {
                fetch(`${this.apiPath}switch/?id=${modelId}`)
                    .then(res => res.json())
                    .then(data => {
                        this.loadModel(
                            data.model.id,
                            0,
                            data.model.message
                        );
                    });
            }
        }
    }

    // 工具栏按钮配置
    const toolsConfig = {
        hitokoto: {
            icon: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><!--! Font Awesome Free 6.2.0 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License) Copyright 2022 Fonticons, Inc. --><path d="M512 240c0 114.9-114.6 208-256 208c-37.1 0-72.3-6.4-104.1-17.9c-11.9 8.7-31.3 20.6-54.3 30.6C73.6 471.1 44.7 480 16 480c-6.5 0-12.3-3.9-14.8-9.9c-2.5-6-1.1-12.8 3.4-17.4l0 0 0 0 0 0 0 0 .3-.3c.3-.3 .7-.7 1.3-1.4c1.1-1.2 2.8-3.1 4.9-5.7c4.1-5 9.6-12.4 15.2-21.6c10-16.6 19.5-38.4 21.4-62.9C17.7 326.8 0 285.1 0 240C0 125.1 114.6 32 256 32s256 93.1 256 208z"/></svg>',
            callback: function() {
                fetch("https://v1.hitokoto.cn")
                    .then(res => res.json())
                    .then(data => {
                        const info = `这句一言来自 <span>「${data.from}」</span>，是 <span>${data.creator}</span> 在 hitokoto.cn 投稿的。`;
                        showMessage(data.hitokoto, 6000, 9);
                        setTimeout(() => {
                            showMessage(info, 4000, 9);
                        }, 6000);
                    });
            }
        },
        asteroids: {
            icon: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><!--! Font Awesome Free 6.2.0 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License) Copyright 2022 Fonticons, Inc. --><path d="M498.1 5.6c10.1 7 15.4 19.1 13.5 31.2l-64 416c-1.5 9.7-7.4 18.2-16 23s-18.9 5.4-28 1.6L277.3 424.9l-40.1 74.5c-5.2 9.7-16.3 14.6-27 11.9S192 499 192 488V392c0-5.3 1.8-10.5 5.1-14.7L362.4 164.7c2.5-7.1-6.5-14.3-13-8.4L170.4 318.2l-32 28.9 0 0c-9.2 8.3-22.3 10.6-33.8 5.8l-85-35.4C8.4 312.8 .8 302.2 .1 290s5.5-23.7 16.1-29.8l448-256c10.7-6.1 23.9-5.5 34 1.4z"/></svg>',
            callback: () => {
                if (window.Asteroids) {
                    if (!window.ASTEROIDSPLAYERS)
                        window.ASTEROIDSPLAYERS = [];
                    window.ASTEROIDSPLAYERS.push(new Asteroids());
                } else {
                    const script = document.createElement("script");
                    script.src = "https://fastly.jsdelivr.net/gh/stevenjoezhang/asteroids/asteroids.js";
                    document.head.appendChild(script);
                }
            }
        },
        "switch-model": {
            icon: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><!--! Font Awesome Free 6.2.0 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License) Copyright 2022 Fonticons, Inc. --><path d="M399 384.2C376.9 345.8 335.4 320 288 320H224c-47.4 0-88.9 25.8-111 64.2c35.2 39.2 86.2 63.8 143 63.8s107.8-24.7 143-63.8zM512 256c0 141.4-114.6 256-256 256S0 397.4 0 256S114.6 0 256 0S512 114.6 512 256zM256 272c39.8 0 72-32.2 72-72s-32.2-72-72-72s-72 32.2-72 72s32.2 72 72 72z"/></svg>',
            callback: () => {}
        },
        "switch-texture": {
            icon: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><!--! Font Awesome Free 6.2.0 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License) Copyright 2022 Fonticons, Inc. --><path d="M320 64c0-35.3-28.7-64-64-64s-64 28.7-64 64s28.7 64 64 64s64-28.7 64-64zm-96 96c-35.3 0-64 28.7-64 64v48c0 17.7 14.3 32 32 32h1.8l11.1 99.5c1.8 16.2 15.5 28.5 31.8 28.5h38.7c16.3 0 30-12.3 31.8-28.5L318.2 304H320c17.7 0 32-14.3 32-32V224c0-35.3-28.7-64-64-64H224zM132.3 394.2c13-2.4 21.7-14.9 19.3-27.9s-14.9-21.7-27.9-19.3c-32.4 5.9-60.9 14.2-82 24.8c-10.5 5.3-20.3 11.7-27.8 19.6C6.4 399.5 0 410.5 0 424c0 21.4 15.5 36.1 29.1 45c14.7 9.6 34.3 17.3 56.4 23.4C130.2 504.7 190.4 512 256 512s125.8-7.3 170.4-19.6c22.1-6.1 41.8-13.8 56.4-23.4c13.7-8.9 29.1-23.6 29.1-45c0-13.5-6.4-24.5-14-32.6c-7.5-7.9-17.3-14.3-27.8-19.6c-21-10.6-49.5-18.9-82-24.8c-13-2.4-25.5 6.3-27.9 19.3s6.3 25.5 19.3 27.9c30.2 5.5 53.7 12.8 69 20.5c3.2 1.6 5.8 3.1 7.9 4.5c3.6 2.4 3.6 7.2 0 9.6c-8.8 5.7-23.1 11.8-43 17.3C374.3 457 318.5 464 256 464s-118.3-7-157.7-17.9c-19.9-5.5-34.2-11.6-43-17.3c-3.6-2.4-3.6-7.2 0-9.6c2.1-1.4 4.8-2.9 7.9-4.5c15.3-7.7 38.8-14.9 69-20.5z"/></svg>',
            callback: () => {}
        },
        photo: {
            icon: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><!--! Font Awesome Free 6.2.0 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License) Copyright 2022 Fonticons, Inc. --><path d="M220.6 121.2L271.1 96 448 96v96H333.2c-21.9-15.1-48.5-24-77.2-24s-55.2 8.9-77.2 24H64V128H192c9.9 0 19.7-2.3 28.6-6.8zM0 128V416c0 35.3 28.7 64 64 64H448c35.3 0 64-28.7 64-64V96c0-35.3-28.7-64-64-64H271.1c-9.9 0-19.7 2.3-28.6 6.8L192 64H160V48c0-8.8-7.2-16-16-16H80c-8.8 0-16 7.2-16 16l0 16C28.7 64 0 92.7 0 128zM344 304c0 48.6-39.4 88-88 88s-88-39.4-88-88s39.4-88 88-88s88 39.4 88 88z"/></svg>',
            callback: () => {
                showMessage("照好了嘛，是不是很可爱呢？", 6000, 9);
                Live2D.captureName = "photo.png";
                Live2D.captureFrame = true;
            }
        },
        info: {
            icon: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><!--! Font Awesome Free 6.2.0 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License) Copyright 2022 Fonticons, Inc. --><path d="M256 512c141.4 0 256-114.6 256-256S397.4 0 256 0S0 114.6 0 256S114.6 512 256 512zM216 336h24V272H216c-13.3 0-24-10.7-24-24s10.7-24 24-24h48c13.3 0 24 10.7 24 24v88h8c13.3 0 24 10.7 24 24s-10.7 24-24 24H216c-13.3 0-24-10.7-24-24s10.7-24 24-24zm40-144c-17.7 0-32-14.3-32-32s14.3-32 32-32s32 14.3 32 32s-14.3 32-32 32z"/></svg>',
            callback: () => {
                open("https://github.com/stevenjoezhang/live2d-widget");
            }
        },
        quit: {
            icon: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 512"><!--! Font Awesome Free 6.2.0 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License) Copyright 2022 Fonticons, Inc. --><path d="M310.6 150.6c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0L160 210.7 54.6 105.4c-12.5-12.5-32.8-12.5-45.3 0s-12.5 32.8 0 45.3L114.7 256 9.4 361.4c-12.5 12.5-12.5 32.8 0 45.3s32.8 12.5 45.3 0L160 301.3 265.4 406.6c12.5 12.5 32.8 12.5 45.3 0s12.5-32.8 0-45.3L205.3 256 310.6 150.6z"/></svg>',
            callback: () => {
                localStorage.setItem("waifu-display", Date.now());
                showMessage("愿你有一天能与重要的人重逢。", 2000, 11);
                document.getElementById("waifu").style.bottom = "-500px";
                setTimeout(() => {
                    document.getElementById("waifu").style.display = "none";
                    document.getElementById("waifu-toggle")
                        .classList.add("waifu-toggle-active");
                }, 3000);
            }
        }
    };

    // 初始化看板娘
    function initLive2D(config) {
        const widget = new Live2DWidget(config);

        // 加载提示文字配置并设置交互
        function loadTips(tipsConfig) {
            let hovered = false;
            let idleInterval = null;
            const defaultTips = tipsConfig.message.default;

            window.addEventListener("mousemove", () => (hovered = true));
            window.addEventListener("keydown", () => (hovered = true));

            // 空闲检测：20 秒无操作显示默认提示
            setInterval(() => {
                if (hovered) {
                    hovered = false;
                    if (idleInterval) {
                        clearInterval(idleInterval);
                        idleInterval = null;
                    }
                } else if (!idleInterval) {
                    idleInterval = setInterval(() => {
                        showMessage(defaultTips, 6000, 9);
                    }, 20000);
                }
            }, 1000);

            // 显示欢迎消息
            showMessage(
                (function(tips) {
                    if (location.pathname === "/") {
                        for (let { hour, text } of tips) {
                            const now = new Date();
                            const start = hour.split("-")[0];
                            const end = hour.split("-")[1] || start;
                            if (
                                start <= now.getHours() &&
                                now.getHours() <= end
                            )
                                return text;
                        }
                    }
                    const title = `欢迎阅读<span>「${
                        document.title.split(" - ")[0]
                    }」</span>`;
                    if (document.referrer !== "") {
                        const referrer = new URL(document.referrer);
                        const host = referrer.hostname.split(".")[1];
                        const engineMap = {
                            baidu: "百度",
                            so: "360搜索",
                            google: "谷歌搜索"
                        };
                        if (location.hostname === referrer.hostname)
                            return title;
                        const source =
                            host in engineMap
                                ? engineMap[host]
                                : referrer.hostname;
                        return `Hello！来自 <span>${source}</span> 的朋友<br>${title}`;
                    }
                    return title;
                })(tipsConfig.time),
                7000,
                11
            );

            // 鼠标悬停提示
            window.addEventListener("mouseover", (e) => {
                for (let { selector, text } of tipsConfig.mouseover) {
                    if (e.target.matches(selector)) {
                        text = randomPick(text);
                        text = text.replace(
                            "{text}",
                            e.target.innerText
                        );
                        showMessage(text, 4000, 8);
                        return;
                    }
                }
            });

            // 点击提示
            window.addEventListener("click", (e) => {
                for (let { selector, text } of tipsConfig.click) {
                    if (e.target.matches(selector)) {
                        text = randomPick(text);
                        text = text.replace(
                            "{text}",
                            e.target.innerText
                        );
                        showMessage(text, 4000, 8);
                        return;
                    }
                }
            });

            // 季节性提示
            tipsConfig.seasons.forEach(({ date, text }) => {
                const now = new Date();
                const start = date.split("-")[0];
                const end = date.split("-")[1] || start;
                const startMonth = start.split("/")[0];
                const startDay = start.split("/")[1];
                const endMonth = end.split("/")[0];
                const endDay = end.split("/")[1];
                if (
                    startMonth <= now.getMonth() + 1 &&
                    now.getMonth() + 1 <= endMonth &&
                    startDay <= now.getDate() &&
                    now.getDate() <= endDay
                ) {
                    text = randomPick(text);
                    text = text.replace("{year}", now.getFullYear());
                    tipsArray.push(text);
                }
            });

            // 控制台彩蛋
            const noop = () => {};
            console.log("%c", noop);
            noop.toString = () => {
                showMessage(tipsConfig.message.console, 6000, 9);
            };

            // 复制提示
            window.addEventListener("copy", () => {
                showMessage(tipsConfig.message.copy, 6000, 9);
            });

            // 页面可见性提示
            window.addEventListener("visibilitychange", () => {
                if (!document.hidden) {
                    showMessage(
                        tipsConfig.message.visibilitychange,
                        6000,
                        9
                    );
                }
            });
        }

        // 初始化 DOM
        localStorage.removeItem("waifu-display");
        sessionStorage.removeItem("waifu-text");
        document.body.insertAdjacentHTML(
            "beforeend",
            `<div id="waifu">
                <div id="waifu-tips"></div>
                <canvas id="live2d" width="800" height="800"></canvas>
                <div id="waifu-tool"></div>
            </div>`
        );
        setTimeout(() => {
            document.getElementById("waifu").style.bottom = 0;
        }, 0);

        // 初始化工具栏
        (function() {
            toolsConfig["switch-model"].callback = () =>
                widget.loadOtherModel();
            toolsConfig["switch-texture"].callback = () =>
                widget.loadRandModel();
            if (!Array.isArray(config.tools))
                config.tools = Object.keys(toolsConfig);
            for (let tool of config.tools) {
                if (toolsConfig[tool]) {
                    const { icon, callback } = toolsConfig[tool];
                    document
                        .getElementById("waifu-tool")
                        .insertAdjacentHTML(
                            "beforeend",
                            `<span id="waifu-tool-${tool}">${icon}</span>`
                        );
                    document
                        .getElementById(`waifu-tool-${tool}`)
                        .addEventListener("click", callback);
                }
            }
        })();

        // 加载模型
        (function() {
            let modelId = localStorage.getItem("modelId");
            let texturesId = localStorage.getItem("modelTexturesId");
            if (modelId === null) {
                modelId = config.modelId || 0;
                texturesId = config.modelTexturesId || 0;
            }
            widget.loadModel(modelId, texturesId);
            fetch(config.waifuPath)
                .then(res => res.json())
                .then(loadTips);
        })();
    }

    // 全局初始化入口
    window.initWidget = function(options, legacyApiPath) {
        if (typeof options === "string") {
            options = {
                waifuPath: options,
                apiPath: legacyApiPath
            };
        }
        document.body.insertAdjacentHTML(
            "beforeend",
            `<div id="waifu-toggle">
                <span>看板娘</span>
            </div>`
        );
        const toggleBtn = document.getElementById("waifu-toggle");
        toggleBtn.addEventListener("click", () => {
            toggleBtn.classList.remove("waifu-toggle-active");
            if (toggleBtn.getAttribute("first-time")) {
                initLive2D(options);
                toggleBtn.removeAttribute("first-time");
            } else {
                localStorage.removeItem("waifu-display");
                document.getElementById("waifu").style.display = "";
                setTimeout(() => {
                    document.getElementById("waifu").style.bottom = 0;
                }, 0);
            }
        });
        if (
            localStorage.getItem("waifu-display") &&
            Date.now() - localStorage.getItem("waifu-display") <= 86400000
        ) {
            toggleBtn.setAttribute("first-time", true);
            setTimeout(() => {
                toggleBtn.classList.add("waifu-toggle-active");
            }, 0);
        } else {
            initLive2D(options);
        }
    };
}();
