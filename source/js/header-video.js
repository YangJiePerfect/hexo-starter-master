(function () {
  var blurCooldownUntil = 0

  function isPostPage () {
    return /\/\d{4}\/\d{2}\/\d{2}\//.test(window.location.pathname)
  }

  function isVideoPage () {
    return isVideoPageUrl(window.location.pathname)
  }

  function isVideoPageUrl (pathname) {
    var p = pathname.replace(/\/$/, '') || '/'
    return p === '/' || p === '/archives' ||
      /^\/archives\/\d{4}\/\d{2}/.test(p) ||
      p === '/tags' || p === '/about'
  }

  function getWelcomeText () {
    var pathname = window.location.pathname
    if (/^\/archives\/\d{4}\/\d{2}\//.test(pathname)) {
      return { main: '月度归档', sub: '一月一回首，一步一安然' }
    }
    if (pathname === '/archives/' || pathname === '/archives') {
      return { main: '总归档', sub: '时光知味，岁月沉香' }
    }
    if (pathname === '/tags/' || pathname === '/tags') {
      return { main: '标签', sub: '春有百花秋有月, 夏有凉风冬有雪' }
    }
    if (pathname === '/about/' || pathname === '/about') {
      return { main: '关于', sub: '世界上只有一种英雄主义，就是看清生活的真相之后依然热爱生活' }
    }
    return { main: '阳介的小站', sub: '春有百花秋有月, 夏有凉风冬有雪' }
  }

  function updateWelcomeText () {
    var wrapper = document.querySelector('body > .video-wrapper')
    if (!wrapper) return
    var wt = wrapper.querySelector('.welcome-text')
    var pt = wrapper.querySelector('.poem-text')
    if (!wt || !pt) return
    var t = getWelcomeText()
    wt.textContent = t.main
    pt.textContent = t.sub
  }

  function ensureVideoWrapper () {
    if (document.querySelector('body > .video-wrapper')) return

    var w = document.createElement('div')
    w.className = 'video-wrapper'

    var v = document.createElement('video')
    v.className = 'header-video-bg'
    v.src = '/header-bg.webm'
    v.autoplay = true
    v.loop = true
    v.muted = true
    v.playsInline = true
    v.setAttribute('playsinline', '')
    v.setAttribute('preload', 'metadata')
    v.setAttribute('poster', '/img/pc_bg.jpg')
    v.setAttribute('disableRemotePlayback', '')
    v.addEventListener('canplay', function () {
      // 视频就绪后主动触发滚动检测，确保因视频未就绪而未应用的 frosted 状态能被重新应用
      window.dispatchEvent(new Event('scroll'))
    })
    w.appendChild(v)

    w.appendChild(Object.assign(document.createElement('div'), { className: 'header-video-mask' }))

    var welcome = document.createElement('div')
    welcome.className = 'header-welcome'
    welcome.innerHTML = '<div class="welcome-text"></div><div class="poem-text"></div>'
    w.appendChild(welcome)

    document.body.appendChild(w)
  }

  function updateVideoVisibility () {
    var video = isVideoPage()
    document.body.classList.toggle('is-video-page', video)
    updateWelcomeText()
    var header = document.getElementById('page-header')
    if (header) {
      header.classList.toggle('video-page', video)
    }
  }

  function setStableVideoHeight (force) {
    var wrapper = document.querySelector('body > .video-wrapper')
    if (!wrapper) return

    if (!document.body.classList.contains('is-mobile')) {
      wrapper.style.removeProperty('--header-video-height')
      return
    }

    var current = wrapper.style.getPropertyValue('--header-video-height')
    if (current && !force) return

    var h = window.innerHeight || document.documentElement.clientHeight || 0
    if (window.visualViewport && window.visualViewport.height) {
      h = Math.max(h, window.visualViewport.height)
    }
    if (window.screen && window.screen.height) {
      h = Math.max(h, window.screen.height)
    }
    if (h > 0) {
      wrapper.style.setProperty('--header-video-height', Math.round(h + 96) + 'px')
    }
  }

  function getFrostedTriggerElement () {
    return document.querySelector('#body-wrap > main.layout') ||
      document.querySelector('#content-inner') ||
      document.querySelector('main#content')
  }

  function initScrollDetector () {
    var welcomeEl = document.querySelector('body > .video-wrapper .header-welcome')
    var triggerEl = getFrostedTriggerElement()
    var headerVideo = document.querySelector('body > .video-wrapper .header-video-bg')

    var scrollTicking = false
    var firstCheck = true

    function updateScroll () {
      scrollTicking = false
      var scrollY = window.scrollY || window.pageYOffset

      if (welcomeEl) {
        var parallax = scrollY * -0.5
        var opacity = Math.max(0, 1 - scrollY / 300)
        if (document.body.classList.contains('is-mobile')) {
          welcomeEl.style.transform = 'translate3d(-50%,calc(-50% + ' + parallax + 'px),0)'
        } else {
          welcomeEl.style.transform = 'translate3d(-50%,' + parallax + 'px,0)'
        }
        welcomeEl.style.opacity = opacity
      }

      if (triggerEl && headerVideo) {
        if (firstCheck) {
          firstCheck = false
          var rect0 = triggerEl.getBoundingClientRect()
          applyFrosted(rect0.top <= 0)
        } else {
          var now = Date.now()
          if (now < blurCooldownUntil) {
            applyFrosted(false)
          } else {
            var rect = triggerEl.getBoundingClientRect()
            applyFrosted(rect.top <= 0)
          }
        }
      }
    }

    function onScroll () {
      if (!scrollTicking) {
        scrollTicking = true
        requestAnimationFrame(updateScroll)
      }
    }

    var currentFrosted = false
    function applyFrosted (shouldFrost) {
      if (shouldFrost === currentFrosted) return
      currentFrosted = shouldFrost
      if (!headerVideo) return
      if (shouldFrost) {
        headerVideo.classList.add('frosted')
        document.body.classList.add('is-main-frosted')
      } else {
        headerVideo.classList.remove('frosted')
        headerVideo.classList.add('frosted-out')
        document.body.classList.remove('is-main-frosted')
        var onTransitionEnd = function (e) {
          if (e.propertyName !== 'filter' &&
            e.propertyName !== 'transform') return
          headerVideo.removeEventListener('transitionend', onTransitionEnd)
          headerVideo.classList.remove('frosted-out')
        }
        headerVideo.addEventListener('transitionend', onTransitionEnd)
      }
    }

    if (window.parallaxScrollHandler) {
      window.removeEventListener('scroll', window.parallaxScrollHandler, { passive: true })
    }
    window.parallaxScrollHandler = onScroll
    window.addEventListener('scroll', onScroll, { passive: true })
    requestAnimationFrame(updateScroll)
  }

  function injectMailButton () {
    if (document.querySelector('#card-mail-btn')) return
    var cardInfoBtn = document.getElementById('card-info-btn')
    if (!cardInfoBtn) return

    var mailBtn = document.createElement('a')
    mailBtn.id = 'card-mail-btn'
    mailBtn.target = '_blank'
    mailBtn.rel = 'noopener'
    mailBtn.href = 'https://mymailbox.yangjie520.ccwu.cc/'
    mailBtn.innerHTML = '<i class="fas fa-envelope"></i><span>阳介的邮箱小站</span>'
    cardInfoBtn.parentNode.insertBefore(mailBtn, cardInfoBtn.nextSibling)
  }

  function reorderFooter () {
    var frameworkInfo = document.querySelector('.footer-copyright .framework-info')
    var customText = document.querySelector('.footer_custom_text')
    if (!frameworkInfo || !customText) return
    customText.parentNode.insertBefore(frameworkInfo, customText.nextSibling)
  }

  function setupNavClickInterceptor () {
    document.addEventListener('click', function (e) {
      var link = e.target.closest('#menus a, #nav a[href]')
      if (!link) return
      var href = link.getAttribute('href')
      if (!href || href.startsWith('#') || href.startsWith('http')) return

      var norm = function (p) {
        return p === '/' ? p : p.replace(/\/+$/, '')
      }
      if (norm(window.location.pathname) === norm(href)) {
        e.preventDefault()
        e.stopImmediatePropagation()
        e.stopPropagation()
        var target = document.getElementById('content-inner') || document.querySelector('main#content')
        if (target) {
          var pos = target.getBoundingClientRect().top + window.scrollY
          var nav = document.getElementById('page-header')
          if (nav && nav.classList.contains('fixed')) {
            pos = pos - (nav.offsetHeight || 60)
          }
          window.scrollTo({ top: pos, behavior: 'smooth' })
        } else {
          window.scrollTo({ top: 0, behavior: 'smooth' })
        }
      }
    }, true)
  }

  function setupPjaxTransition () {
    var pendingUrl = null

    document.addEventListener('click', function (e) {
      var link = e.target.closest('a[href]')
      if (!link) return
      var href = link.getAttribute('href')
      if (href && href.startsWith('/') && !href.startsWith('//') && href.indexOf('#') === -1) {
        pendingUrl = href
      }
    }, true)

    document.addEventListener('pjax:send', function () {
      if (pendingUrl) document.body.classList.toggle('is-video-page', isVideoPageUrl(pendingUrl))
      blurCooldownUntil = Date.now() + 500
      var hv = document.querySelector('body > .video-wrapper .header-video-bg')
      if (hv) hv.classList.remove('frosted')
      document.body.classList.remove('is-main-frosted')
    })

    document.addEventListener('pjax:complete', function () {
      pendingUrl = null
      blurCooldownUntil = Date.now() + 300
      window.scrollTo(0, 0)

      var nav = document.getElementById('nav')
      if (nav) {
        nav.style.opacity = '0'
        nav.style.transform = 'translateY(-35px)'
        requestAnimationFrame(function () {
          requestAnimationFrame(function () {
            var a = nav.animate([
              { transform: 'translateY(-35px)', opacity: '0' },
              { transform: 'translateY(0)', opacity: '1' }
            ], { duration: 500, easing: 'ease', fill: 'forwards' })
            a.onfinish = function () {
              nav.style.opacity = ''
              nav.style.transform = ''
            }
          })
        })
      }
    })
  }

  function updatePageType () {
    var header = document.getElementById('page-header')
    if (!header) return

    var p = window.location.pathname
    var isHomepage = p === '/' || p === '/index.html'
    var isMonthlyArchive = /^\/archives\/\d{4}\/\d{2}\//.test(p)
    var isArchiveIndex = p === '/archives/' || p === '/archives'
    var isTagsPage = p === '/tags/' || p === '/tags'
    var isAboutPage = p === '/about/' || p === '/about'

    var cl = document.body.classList
    cl.toggle('is-homepage', isHomepage)
    cl.toggle('is-post-page', header.classList.contains('post-bg'))
    cl.toggle('is-archives-page', isArchiveIndex || isMonthlyArchive)
    cl.toggle('is-tags-page', isTagsPage)
    cl.toggle('is-about-page', isAboutPage)

    updateVideoVisibility()
  }

  function initMobile () {
    var deviceType = window.DeviceDetector.detectDeviceType()
    var isMobile = deviceType === 'mobile'
    document.body.classList.toggle('is-mobile', isMobile)
    document.body.classList.toggle('is-pc', !isMobile)

    if (isMobile) {
      var targetCursor = document.querySelector('.target-cursor-wrapper')
      if (targetCursor) targetCursor.style.display = 'none'
      document.documentElement.classList.remove('target-cursor-enabled')
      document.documentElement.classList.add('target-cursor-disabled')
      if (window.TargetCursorController && window.TargetCursorController.isEnabled()) {
        window.TargetCursorController.disable()
      }
      if (!isPostPage()) {
        document.body.classList.add('mobile-card-unify')
      }
    }

    setStableVideoHeight(false)
  }

  function init () {
    ensureVideoWrapper()
    updatePageType()
    initMobile()
    initScrollDetector()
    injectMailButton()
    reorderFooter()
    setupNavClickInterceptor()
  }

  function onVisibilityChange () {
    var video = document.querySelector('body > .video-wrapper .header-video-bg')
    if (!video) return
    if (!document.hidden) {
      // 后台返回时给页面渲染一段稳定时间，避免立即触发 frosted 滤镜
      blurCooldownUntil = Date.now() + 500
      if (video.paused) {
        video.play().catch(function () {})
      }
    } else {
      if (!video.paused) video.pause()
    }
  }

  setupPjaxTransition()

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init)
  } else {
    init()
  }

  document.addEventListener('pjax:complete', function () {
    updatePageType()
    initMobile()
    initScrollDetector()
    injectMailButton()
    reorderFooter()
  })

  window.addEventListener('orientationchange', function () {
    setTimeout(function () {
      setStableVideoHeight(true)
    }, 300)
  }, { passive: true })

  window.addEventListener('resize', function () {
    if (!document.body.classList.contains('is-mobile')) {
      setStableVideoHeight(true)
    }
  }, { passive: true })

  document.addEventListener('visibilitychange', onVisibilityChange)
})()