# 博客网页全面测试报告

> 测试日期：2026-06-06
> 测试范围：所有自定义 JS、CSS、Pug 模板、配置文件
> 测试方法：静态代码审查 + 逻辑分析

---

## 一、严重 Bug（Critical）

### B1. 文章卡片点击导致整页刷新，破坏 PJAX 过渡

- **文件**：[target-cursor.js](file:///c:/Users/阳介/Desktop/myblog/source/js/target-cursor.js#L38)
- **问题**：`contentClickHandler` 拦截了 `.recent-post-info .content` 的点击事件，但使用 `window.location.href = titleLink.href` 进行整页跳转，完全不经过 PJAX 路由。这会导致：
  - 视频背景重新加载（闪烁）
  - 导航栏动画丢失
  - 所有 JS 状态丢失（目标光标、模糊状态等）
  - 用户体验严重割裂
- **建议**：使用 PJAX 方式导航，或至少触发 `<a>` 标签的原生点击事件，让 Butterfly 主题的 PJAX 拦截器处理。

### B2. 首页检测逻辑错误：归档页被误判为首页

- **文件**：[header-video.js](file:///c:/Users/阳介/Desktop/myblog/source/js/header-video.js#L15)
- **问题**：`updatePageType()` 通过 `#page-header.classList.contains('full_page')` 判断首页。但 Butterfly 主题的 [index.pug](file:///c:/Users/阳介/Desktop/myblog/source/_layout/includes/header/index.pug#L27) 中，`home` 和 `archive` 类型都被赋予 `full_page` 类名。这导致归档页（`/archives/`）同时拥有 `is-homepage` 和 `is-archives-page` 两个 body class。
- **影响**：CSS 中 `.is-homepage` 和 `.is-archives-page` 选择器同时生效，可能产生样式冲突，且 `is-homepage` 的某些样式行为（如 100vh 高度）可能不适用于归档页。
- **建议**：改用 `window.location.pathname` 判断首页（`pathname === '/'`），而不是依赖 header 的 CSS class。

### B3. 导航栏滚动偏移量硬编码错误

- **文件**：[header-video.js](file:///c:/Users/阳介/Desktop/myblog/source/js/header-video.js#L13)
- **问题**：`setupNavClickInterceptor` 中，当导航栏固定时，滚动偏移量硬编码为 `pos - 70`。但 Butterfly 主题的导航栏实际高度为 `60px`（见 [index.css](file:///c:/Users/阳介/Desktop/myblog/source/css/index.css#L4581)），导致滚动位置偏移 10px。
- **建议**：动态获取导航栏高度 `nav.offsetHeight` 替代硬编码值。

### B4. 头像路径错误

- **文件**：[_config.butterfly.yml](file:///c:/Users/阳介/Desktop/myblog/_config.butterfly.yml#L16)
- **问题**：`avatar.img: /img/球面化宵宫头像.png` 指向不存在的路径。实际文件位于 `资源/服务器资源/球面化宵宫头像.png`，而 `source/img/` 下只有 `201F192ED21B64EFCCDACC75D4182698.png`。
- **影响**：头像显示为 404 或默认占位图。
- **建议**：将头像路径修正为 `/img/201F192ED21B64EFCCDACC75D4182698.png` 或正确引用资源目录下的文件。

### B5. 光标切换按钮在 PJAX 导航后消失

- **文件**：[_config.butterfly.yml](file:///c:/Users/阳介/Desktop/myblog/_config.butterfly.yml#L135)
- **问题**：创建光标切换按钮的内联脚本只监听 `DOMContentLoaded` 事件，但 PJAX 导航不会触发 `DOMContentLoaded`。`cursor-toggle.js` 虽然监听了 `pjax:complete` 来绑定事件，但不会重新创建按钮 DOM 元素。
- **影响**：PJAX 页面切换后，按钮可能消失或因 DOM 重建而丢失。
- **建议**：将按钮创建逻辑移入 `cursor-toggle.js` 中，并在 `pjax:complete` 时也执行创建逻辑。

---

## 二、中等级别 Bug（Medium）

### B6. 导航栏双重 backdrop-filter 叠加，VRAM 风险

- **文件**：[header-video.css](file:///c:/Users/阳介/Desktop/myblog/source/css/header-video.css#L11) 和 [header-video.css](file:///c:/Users/阳介/Desktop/myblog/source/css/header-video.css#L40)
- **问题**：
  - `#nav::before` 伪元素使用了 `backdrop-filter: blur(8px) brightness(.7)`
  - `#page-header.nav-fixed #nav` 自身也使用了 `backdrop-filter: blur(5px)`
  - 当导航栏固定时，同一元素上叠加了两层 backdrop-filter，根据项目经验，集成显卡下会导致 VRAM 纹理爆炸。
- **建议**：固定导航时只保留一个 backdrop-filter 层，或使用 `isolation: isolate` 创建独立合成层。

### B7. mouseover 全局监听性能开销大

- **文件**：[target-cursor.js](file:///c:/Users/阳介/Desktop/myblog/source/js/target-cursor.js#L42)
- **问题**：`window.addEventListener('mouseover', mouseOverHandler)` 监听全局 mouseover 事件。`mouseover` 事件冒泡且触发频率极高（每次鼠标进入新元素都触发）。`mouseOverHandler` 调用 `findTarget()` 遍历 DOM 树并调用 `matches()` 方法，在高密度 DOM 页面上会造成明显性能开销。
- **建议**：使用 `mousemove` 上的节流检测，或使用 `IntersectionObserver` 预注册目标元素，减少每次事件的计算量。

### B8. MutationObserver 监听整个 document.body 过于激进

- **文件**：[target-cursor.js](file:///c:/Users/阳介/Desktop/myblog/source/js/target-cursor.js#L41)
- **问题**：`layerObserver` 监听 `document.body` 的 `childList: true, subtree: true, attributes: true`，这意味着 **任何** DOM 变化都会触发 `scheduleCursorLayerUpdate()`。对于有频繁 DOM 更新的页面（如 Live2D、代码高亮、动画），这会持续消耗 CPU。
- **建议**：限制 `subtree` 范围，或使用更具体的 observer 配置。

### B9. 颜色采样开销高，低端设备可能卡顿

- **文件**：[target-cursor.js](file:///c:/Users/阳介/Desktop/myblog/source/js/target-cursor.js#L30)
- **问题**：`mouseMoveHandler` 中每 80ms 执行一次 `sampleRingColors()`，每次调用 `document.elementFromPoint()` 21 次 + `getComputedStyle()` 21 次。这是同步的强制重排操作，在低端设备上会明显掉帧。
- **建议**：增加采样间隔到 150-200ms，或使用 `requestIdleCallback` 在空闲时执行。

### B10. 漩涡粒子系统 GSAP 动画过多

- **文件**：[target-cursor.js](file:///c:/Users/阳介/Desktop/myblog/source/js/target-cursor.js#L16-L17)
- **问题**：每次启动漩涡（`startVortex`）创建 20-36 个粒子，每个粒子有一个 position tween 和一个 opacity timeline（2-3 个 tween），总计约 40-108 个活跃 GSAP tween。加上 ring 和 glow 的动画，动画数量极易超过 100 个。
- **影响**：`gsap.ticker` 每帧需要更新所有 tween，在集成显卡下可能掉帧。
- **建议**：减少粒子数量（8-15 个），使用 CSS animation 替代 GSAP 处理简单动画。

---

## 三、轻微 Bug（Minor）

### B11. 大量死代码和重复资源

- **目录**：`scraped_resources/` 和 `source/live2d-widget/`
- **问题**：
  - `scraped_resources/cursor-ui/` 中的 CSS 文件（`mycustom.css`, `maple_new.css`, `rightmenu.css`, `iconfont.css`, `target-cursor.css`）均未在配置中引用，属于死代码。
  - `scraped_resources/live2d-widget/` 和 `source/live2d-widget/` 中的文件与 CDN 加载的 live2d 库重复，本地模型文件未被使用。
  - `资源/f05dcc5c4edd27ad3e53652f30860949_2634727400205205479.webm` 未在任何地方引用。
  - `source/img/201F192ED21B64EFCCDACC75D4182698.png` 和 `资源/服务器资源/201F192ED21B64EFCCDACC75D4182698.png` 是同一文件的两份拷贝。
- **建议**：清理死代码和重复资源，减少项目体积和混淆。

### B12. pendingUrl 竞态条件

- **文件**：[header-video.js](file:///c:/Users/阳介/Desktop/myblog/source/js/header-video.js#L14)
- **问题**：`pendingUrl` 在 `click` 事件中设置，在 `pjax:send` 中使用。如果用户快速点击多个链接，只有最后一个点击的 URL 会被使用。更严重的是，如果某个链接点击后没有触发 PJAX（如外部链接被拦截），`pendingUrl` 不会被清除，导致下次 PJAX 时使用错误的 URL。
- **建议**：在 `pjax:send` 中直接读取 `event` 中的目标 URL，或使用更可靠的状态管理。

### B13. video.play() 空错误处理

- **文件**：[header-video.js](file:///c:/Users/阳介/Desktop/myblog/source/js/header-video.js#L17)
- **问题**：`video.play().catch(function(){})` 完全静默了错误。如果视频因网络问题加载失败，用户不会有任何感知。
- **建议**：至少记录一个 console.warn 或设置重试逻辑。

### B14. 渐变动画在页面不可见时仍运行

- **文件**：[header-video.css](file:///c:/Users/阳介/Desktop/myblog/source/css/header-video.css#L7-L8) 和 [header-video.css](file:///c:/Users/阳介/Desktop/myblog/source/css/header-video.css#L19)
- **问题**：`gradientShift` 动画（欢迎文字、网站名称）持续运行，即使页面不可见（切换到其他标签页）。虽然浏览器会降低不可见标签页的动画帧率，但不会完全停止，浪费 GPU 资源。
- **建议**：使用 `animation-play-state` 结合 `visibilitychange` 事件暂停动画。

### B15. mouseDown/mouseUp 未检查光标状态

- **文件**：[target-cursor.js](file:///c:/Users/阳介/Desktop/myblog/source/js/target-cursor.js#L33-L34)
- **问题**：`mouseDownHandler` 和 `mouseUpHandler` 无条件缩放 ring，即使光标当前已吸附（snap）到目标元素上。在吸附状态下点击会导致 ring 缩放动画与吸附动画冲突，产生视觉抖动。
- **建议**：在吸附状态下跳过缩放，或使用不同的动画参数。

### B16. snapStrength 动画时长不匹配

- **文件**：[target-cursor.js](file:///c:/Users/阳介/Desktop/myblog/source/js/target-cursor.js#L28)
- **问题**：`enterTarget()` 中 ring 的尺寸变化动画使用 `config.hoverDuration`（默认 0.2s），但 `snapStrength` 的吸附强度动画使用 `duration: 0.25`。两个动画时长不一致，导致视觉上 ring 先变形完成，吸附动画还在进行中，产生不协调感。
- **建议**：统一两个动画的时长。

### B17. isVideoPage 和 isVideoPageUrl 路径规范化不一致

- **文件**：[header-video.js](file:///c:/Users/阳介/Desktop/myblog/source/js/header-video.js#L4-L5)
- **问题**：`isVideoPage()` 直接比较 `pathname`，而 `isVideoPageUrl()` 先 `replace(/\/$/,'')` 去除尾部斜杠。两个函数对同一路径的判断逻辑不一致，可能导致边缘情况下的行为差异。
- **建议**：统一两个函数的实现，或让 `isVideoPage()` 复用 `isVideoPageUrl()`。

### B18. mask-image 非标准属性

- **文件**：[header-video.css](file:///c:/Users/阳介/Desktop/myblog/source/css/header-video.css#L11)
- **问题**：`#nav::before` 使用了 `mask-image` 和 `-webkit-mask-image`。`mask-image` 在 Chromium 中需要 `-webkit-` 前缀，但属性名 `mask-image`（无前缀）在部分浏览器中不被支持。同时使用了非标准的 `mask-image` 属性但未提供 `-webkit-mask-image` 的完整回退。
- **建议**：确保 `-webkit-mask-image` 在前，标准 `mask-image` 在后作为渐进增强。

### B19. 搜索对话框关闭后 isPinkMode 状态未正确清理

- **文件**：[target-cursor.js](file:///c:/Users/阳介/Desktop/myblog/source/js/target-cursor.js#L37)
- **问题**：`initSearchDialogObserver` 中，当搜索对话框关闭时，如果 `!isArticlePage()` 且 `isPinkMode` 为 true，则重置粉色模式。但如果在搜索结果页的搜索对话框中打开了粉色模式，关闭对话框后粉色模式被重置，但此时仍处于文章页，应该保持粉色模式。
- **建议**：检查当前的 `colorSampleEnabled` 状态而不是仅检查 `isArticlePage()`。

### B20. favicon 和 SEO 相关

- **文件**：[header-video.css](file:///c:/Users/阳介/Desktop/myblog/source/css/header-video.css#L9)
- **问题**：`#page-header #site-title{display:none}` 隐藏了所有页面的标题。虽然视频页面有自定义欢迎文字，但原始的 `<h1>` 标题被隐藏会影响 SEO。搜索引擎爬虫可能无法正确抓取页面标题。
- **建议**：使用 `visibility: hidden` 或 `position: absolute` + `clip` 方式隐藏，保留 DOM 结构和 SEO 价值。

---

## 四、动画相关 Bug

### A1. PJAX 导航动画不可靠

- **文件**：[header-video.js](file:///c:/Users/阳介/Desktop/myblog/source/js/header-video.js#L14)
- **问题**：`pjax:complete` 中使用双层 `requestAnimationFrame` 来做导航栏动画。但 PJAX 完成后 DOM 可能尚未完全渲染，双层 rAF 不能保证 100% 可靠。如果 Butterfly 主题的 PJAX 完成回调在 DOM 更新前触发，动画可能不生效。
- **建议**：使用 `MutationObserver` 监听 `#nav` 的出现，或在 `setTimeout(fn, 100)` 中执行动画以确保 DOM 已更新。

### A2. 模糊过渡与 PJAX 冷却时间冲突

- **文件**：[header-video.js](file:///c:/Users/阳介/Desktop/myblog/source/js/header-video.js#L18) 和 [header-video.js](file:///c:/Users/阳介/Desktop/myblog/source/js/header-video.js#L14)
- **问题**：模块初始化时 `blurCooldownUntil = Date.now() + 500`，但 `pjax:send` 也设置 `blurCooldownUntil = Date.now() + 500`。如果页面初始加载不到 500ms，用户滚动时会跳过模糊检测。但 `pjax:complete` 设置为 `Date.now() + 300`，这意味着 PJAX 完成后只有 300ms 冷却。初始加载和 PJAX 加载的冷却时间不一致。
- **建议**：统一冷却时间常量。

### A3. 视频模糊效果在 PJAX 后可能不恢复

- **文件**：[header-video.js](file:///c:/Users/阳介/Desktop/myblog/source/js/header-video.js#L14)
- **问题**：`pjax:send` 中移除 `frosted` class，但 `pjax:complete` 中只重置冷却时间，没有重新检查滚动位置来恢复模糊。用户需要手动滚动才能触发模糊效果的重新评估。
- **建议**：`pjax:complete` 中主动调用一次 `updateFrosted()` 检查当前滚动位置。

### A4. 欢迎文字渐变动画在非视频页面仍运行

- **文件**：[header-video.css](file:///c:/Users/阳介/Desktop/myblog/source/css/header-video.css#L7-L8)
- **问题**：`.header-welcome` 的渐变动画始终运行，即使页面不是视频页面（`.video-wrapper` 被 `display:none` 隐藏）。隐藏元素中的 CSS 动画仍然会消耗 GPU 合成资源。
- **建议**：在非视频页面时暂停动画，使用 `animation-play-state: paused` 配合 `.is-video-page` 选择器。

### A5. 光标吸附动画在 leave 时可能残留

- **文件**：[target-cursor.js](file:///c:/Users/阳介/Desktop/myblog/source/js/target-cursor.js#L28)
- **问题**：`enterTarget` 中注册的 `leaveHandler` 使用 80ms 延迟的 `setTimeout` 来重置 ring。如果用户在 80ms 内快速移入另一个目标，新的 `enterTarget` 调用会清除 `resumeTimeout`，但如果旧目标的 `mouseleave` 和新目标的 `mouseover` 在极短时间内交错触发，可能导致 ring 动画状态不一致。
- **建议**：使用 `debounce` 或 `requestAnimationFrame` 替代 `setTimeout`。

### A6. vortex 粒子在 cursor 不可见时仍然生成

- **文件**：[target-cursor.js](file:///c:/Users/阳介/Desktop/myblog/source/js/target-cursor.js#L16)
- **问题**：`startVortex` 创建粒子动画，但当 `cursor-enabled` 为 false 或设备为移动端时，cursor 本身不可见，粒子仍然在后台运行，浪费 CPU/GPU。
- **建议**：在 `startVortex` 中检查 `readCursorEnabledState()` 和 `isMobileDevice()`。

### A7. `will-change: transform` 导致 GPU 层永久分配

- **文件**：[target-cursor.css](file:///c:/Users/阳介/Desktop/myblog/source/css/target-cursor.css#L3) 和 [target-cursor.css](file:///c:/Users/阳介/Desktop/myblog/source/css/target-cursor.css#L7)
- **问题**：`.target-cursor-ring` 和 `.vortex-particle` 使用了 `will-change: transform`。根据项目经验，`will-change` 会创建永久 GPU 合成层，在集成显卡上可能导致 VRAM 泄漏。
- **建议**：在动画开始前动态添加 `will-change`，动画结束后移除，而非始终保留。

---

## 五、资源 / 配置问题

### R1. Live2D 加载路径混乱

- **文件**：[_config.butterfly.yml](file:///c:/Users/阳介/Desktop/myblog/_config.butterfly.yml#L129)
- **问题**：配置中加载 `https://fastly.jsdelivr.net/npm/live2d-widgets@1.0.1/dist/autoload.js`，但该 autoload.js 内部又使用 `live2d_path = "https://fastly.jsdelivr.net/gh/stevenjoezhang/live2d-widget@latest/"` 加载资源。两个不同的 CDN 源可能导致版本不一致。
- **影响**：如果 npm 包版本和 GitHub 版本不同步，Live2D 功能可能异常。
- **建议**：统一使用一个 CDN 源，或直接使用本地 `source/live2d-widget/autoload.js`。

### R2. 视频资源硬链接可能失效

- **文件**：[header-video.js](file:///c:/Users/阳介/Desktop/myblog/source/js/header-video.js#L8)
- **问题**：视频路径硬编码为 `/header-bg.webm`。根据项目约定，`source/header-bg.webm` 是 `资源/服务器资源/header-bg.webm` 的 NTFS 硬链接。如果硬链接因文件系统操作（如复制、移动）而断开，视频将无法加载且无错误提示。
- **建议**：添加视频加载失败的回退处理（如显示静态背景图）。

### R3. GSAP 加载无 fallback

- **文件**：[_config.butterfly.yml](file:///c:/Users/阳介/Desktop/myblog/_config.butterfly.yml#L131)
- **问题**：GSAP 从 jsdelivr CDN 加载，如果 CDN 不可用，`target-cursor.js` 会输出 `console.warn` 并退出，但 UI 上不会显示任何替代方案，用户会看到默认光标且无任何提示。
- **建议**：提供一个 CSS-only 的降级光标样式。

---

## 六、总结

| 严重程度 | 数量 | 关键影响 |
|----------|------|----------|
| Critical | 5 | PJAX 破坏、页面类型误判、导航偏移、头像 404、按钮消失 |
| Medium   | 5 | VRAM 泄漏风险、性能瓶颈、动画过度 |
| Minor    | 10 | 死代码、竞态条件、动画细节、SEO |
| 动画     | 7 | 动画时序、状态不一致、GPU 资源浪费 |
| 资源     | 3 | 路径混乱、CDN 依赖、硬链接风险 |

**总计：30 个问题**

### 优先修复建议

1. **立即修复**：B1（PJAX 破坏）、B2（首页误判）、B4（头像 404）
2. **尽快修复**：B3（导航偏移）、B5（按钮消失）、B6（VRAM 风险）
3. **计划修复**：B7-B10（性能优化）、A1-A7（动画优化）
4. **可选清理**：B11（死代码）、R1-R3（资源路径）