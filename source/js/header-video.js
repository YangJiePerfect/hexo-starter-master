(function () {
  function initScrollDetector() {
    var firstPost = document.querySelector('.recent-post-item');
    if (!firstPost) return;

    var headerVideo = document.querySelector('#page-header .header-video-bg');
    var globalVideo = document.querySelector('.global-bg-video');
    var overlay = document.querySelector('.frosted-overlay');

    var ticking = false;

    function updateFrosted() {
      var rect = firstPost.getBoundingClientRect();
      var shouldFrost = rect.top <= 0;

      if (headerVideo) {
        headerVideo.classList.toggle('frosted', shouldFrost);
      }
      if (globalVideo) {
        globalVideo.classList.toggle('frosted', shouldFrost);
      }
      if (overlay) {
        overlay.classList.toggle('active', shouldFrost);
      }
      ticking = false;
    }

    function onScroll() {
      if (!ticking) {
        requestAnimationFrame(updateFrosted);
        ticking = true;
      }
    }

    if (window.frostedScrollHandler) {
      window.removeEventListener('scroll', window.frostedScrollHandler, { passive: true });
    }

    window.frostedScrollHandler = onScroll;
    window.addEventListener('scroll', onScroll, { passive: true });

    updateFrosted();
  }

  function injectGlobalBg() {
    if (document.querySelector('.global-bg-video')) return;

    var video = document.createElement('video');
    video.className = 'global-bg-video';
    video.src = '/bg.webm';
    video.autoplay = true;
    video.loop = true;
    video.muted = true;
    video.playsInline = true;
    video.setAttribute('playsinline', '');

    var overlay = document.createElement('div');
    overlay.className = 'frosted-overlay';

    document.body.insertBefore(overlay, document.body.firstChild);
    document.body.insertBefore(video, document.body.firstChild);
  }

  function injectHeaderVideo() {
    var header = document.getElementById('page-header');
    if (!header) return;

    if (!header.querySelector('.header-video-bg')) {
      var video = document.createElement('video');
      video.className = 'header-video-bg';
      video.src = '/header-bg.webm';
      video.autoplay = true;
      video.loop = true;
      video.muted = true;
      video.playsInline = true;
      video.setAttribute('playsinline', '');

      var mask = document.createElement('div');
      mask.className = 'header-video-mask';

      header.insertBefore(mask, header.firstChild);
      header.insertBefore(video, header.firstChild);
    }

    if (!header.querySelector('.header-welcome')) {
      var welcome = document.createElement('div');
      welcome.className = 'header-welcome';

      var welcomeText = document.createElement('div');
      welcomeText.className = 'welcome-text';
      welcomeText.textContent = '欢迎来到阳介的小站';

      var poemText = document.createElement('div');
      poemText.className = 'poem-text';
      poemText.textContent = '春有百花秋有月, 夏有凉风冬有雪';

      welcome.appendChild(welcomeText);
      welcome.appendChild(poemText);
      header.appendChild(welcome);
    }
  }

  function injectMailButton() {
    if (document.querySelector('#card-mail-btn')) return;

    var cardInfoBtn = document.getElementById('card-info-btn');
    if (!cardInfoBtn) return;

    var mailBtn = document.createElement('a');
    mailBtn.id = 'card-mail-btn';
    mailBtn.target = '_blank';
    mailBtn.rel = 'noopener';
    mailBtn.href = 'https://mymailbox.yangjie520.ccwu.cc/';
    mailBtn.innerHTML = '<i class="fas fa-envelope"></i><span>阳介的邮箱小站</span>';

    cardInfoBtn.parentNode.insertBefore(mailBtn, cardInfoBtn.nextSibling);
  }

  function reorderFooter() {
    var frameworkInfo = document.querySelector('.footer-copyright .framework-info');
    var customText = document.querySelector('.footer_custom_text');
    if (!frameworkInfo || !customText) return;

    customText.parentNode.insertBefore(frameworkInfo, customText.nextSibling);
  }

  function updatePageType() {
    var header = document.getElementById('page-header');
    if (!header) return;

    var isHomepage = header.classList.contains('full_page');
    document.body.classList.toggle('is-homepage', isHomepage);
    document.body.classList.toggle('is-post-page', header.classList.contains('post-bg'));

    var globalVideo = document.querySelector('.global-bg-video');
    var overlay = document.querySelector('.frosted-overlay');

    if (globalVideo) {
      globalVideo.style.display = isHomepage ? '' : 'none';
    }
    if (overlay) {
      overlay.style.display = isHomepage ? '' : 'none';
    }
  }

  function init() {
    injectGlobalBg();
    injectHeaderVideo();
    updatePageType();
    initScrollDetector();
    injectMailButton();
    reorderFooter();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  document.addEventListener('pjax:complete', function () {
    injectGlobalBg();
    injectHeaderVideo();
    updatePageType();
    initScrollDetector();
    injectMailButton();
    reorderFooter();
  });
})();