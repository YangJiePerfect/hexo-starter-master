// 标签页离开变身功能配置
const tabAwayConfig = {
    // 离开多少毫秒后变身（1000ms=1秒，推荐10-30秒）
    awayTimeout: 15000,

    // 正常状态
    normal: {
        // 留空表示使用页面原始标题
        title: '',
        // 正常图标，留空使用主题默认favicon
        icon: ''
    },

    // 离开状态
    away: {
        // 离开时显示的标题
        title: 'Ciallo～(∠・ω< )⌒☆',
        // 离开时显示的图标（建议尺寸：32×32px PNG格式）
        icon: '/img/Collei avatar.png'
    }
};

// 全局变量
let awayTimer = null;
let originalTitle = document.title;
let originalIcon = '';

// 获取当前favicon元素
function getFaviconElement() {
    return document.querySelector('link[rel="icon"]') ||
        document.querySelector('link[rel="shortcut icon"]');
}

// 初始化原始图标
function initOriginalIcon() {
    const favicon = getFaviconElement();
    if (favicon) {
        originalIcon = favicon.href;
    }
}

// 更新标签页标题
function updateTabTitle(title) {
    document.title = title || originalTitle;
}

// 更新favicon图标
function updateFavicon(iconUrl) {
    const favicon = getFaviconElement();
    if (favicon && iconUrl) {
        favicon.href = iconUrl;
    }
}

// 切换到离开状态
function goAway() {
    console.log('用户离开页面，标签页变身');
    updateTabTitle(tabAwayConfig.away.title);
    updateFavicon(tabAwayConfig.away.icon);
}

// 恢复到正常状态
function comeBack() {
    console.log('用户回来，标签页恢复');
    updateTabTitle(tabAwayConfig.normal.title);
    updateFavicon(tabAwayConfig.normal.icon || originalIcon);
}

// 页面可见性变化处理
function handleVisibilityChange() {
    if (document.hidden) {
        // 页面隐藏，开始计时
        awayTimer = setTimeout(goAway, tabAwayConfig.awayTimeout);
    } else {
        // 页面可见，清除计时器并立即恢复
        clearTimeout(awayTimer);
        comeBack();
    }
}

// 初始化
document.addEventListener('DOMContentLoaded', function () {
    // 保存原始图标
    initOriginalIcon();

    // 如果配置了正常标题，覆盖原始标题
    if (tabAwayConfig.normal.title) {
        originalTitle = tabAwayConfig.normal.title;
    }

    // 监听页面可见性变化
    document.addEventListener('visibilitychange', handleVisibilityChange);

    // 页面卸载时清理
    window.addEventListener('beforeunload', function () {
        clearTimeout(awayTimer);
    });
});
(function () {
    if (window.__cursorToggleBootstrapped) return; window.__cursorToggleBootstrapped = true;
function renderCursorToggle(){var button=document.getElementById('cursor-toggle');if(!button||!window.TargetCursorController)return;var enabled=window.TargetCursorController.isEnabled();var icon=button.querySelector('i');button.setAttribute('aria-pressed',enabled?'true':'false');button.setAttribute('title',enabled?'关闭鼠标特效':'开启鼠标特效');button.classList.toggle('is-disabled',!enabled);if(icon){icon.classList.toggle('fa-mouse-pointer',enabled);icon.classList.toggle('fa-ban',!enabled)}}
function bindCursorToggle(){var button=document.getElementById('cursor-toggle');if(!button||!window.TargetCursorController)return;if(button.dataset.cursorToggleBound!=='1'){button.dataset.cursorToggleBound='1';button.addEventListener('click',function(){window.TargetCursorController.toggle();renderCursorToggle()})}renderCursorToggle()}
document.addEventListener('target-cursor:change',renderCursorToggle);document.addEventListener('pjax:complete',bindCursorToggle);
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',bindCursorToggle,{once:true});else bindCursorToggle()})();