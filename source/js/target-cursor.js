(function () {
  if (window.__targetCursorHexoBootstrapped) return
  window.__targetCursorHexoBootstrapped = true
  window.__targetCursorHexoLoaded = false

  var config = Object.assign({
    targetSelector: '#article-container img, #article-container a:not([data-fancybox]):not([href^="mailto:"]), #nav a, #aside-content a:not(.thumbnail):not(.title), #aside-content .aside-list-item, button, .cursor-target, .article-title, .recent-post-info .content, .update-log-hint',
    spinDuration: 3,
    hoverDuration: 0.2,
    targetGap: 8,
    hideDefaultCursor: true,
    parallaxOn: true,
    storageKey: 'target-cursor-enabled',
    defaultEnabled: true
  }, window.TargetCursorOptions || {})

  function readCursorEnabledState () {
    var fallback = config.defaultEnabled !== false
    try {
      var storedValue = window.localStorage.getItem(config.storageKey)
      if (storedValue === null) return fallback
      return storedValue !== '0' && storedValue !== 'false'
    } catch (error) {
      return fallback
    }
  }

  function writeCursorEnabledState (enabled) {
    try {
      window.localStorage.setItem(config.storageKey, enabled ? '1' : '0')
    } catch (error) {}
  }

  function syncCursorEnabledState (enabled) {
    document.documentElement.classList.toggle('target-cursor-enabled', enabled)
    document.documentElement.classList.toggle('target-cursor-disabled', !enabled)
    document.dispatchEvent(new CustomEvent('target-cursor:change', { detail: { enabled: enabled } }))
  }

  function isMobileDevice () {
    var ua = (navigator.userAgent || navigator.vendor || window.opera || '').toLowerCase()
    var isIPad = /ipad/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1 && !window.MSStream)
    if (isIPad) return false
    var hasTouchScreen = 'ontouchstart' in window || navigator.maxTouchPoints > 0
    var isSmallScreen = window.innerWidth <= 768
    var mobileRegex = /android|webos|iphone|ipod|blackberry|iemobile|opera mini/i
    return (hasTouchScreen && isSmallScreen) || mobileRegex.test(ua)
  }

  function isArticlePage () {
    return /\/\d{4}\/\d{2}\/\d{2}\//.test(window.location.pathname)
  }

  function parseRgbFromStr (str) {
    if (!str || str === 'transparent' || str === 'rgba(0, 0, 0, 0)') return null
    var match = str.match(/rgba?\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/)
    return match ? { r: parseInt(match[1]), g: parseInt(match[2]), b: parseInt(match[3]) } : null
  }

  function getEffectiveBackgroundColor (element) {
    var el = element
    while (el && el !== document.body && el !== document.documentElement) {
      var bg = window.getComputedStyle(el).backgroundColor
      var rgb = parseRgbFromStr(bg)
      if (rgb) return rgb
      el = el.parentElement
    }
    return parseRgbFromStr(window.getComputedStyle(document.body).backgroundColor) || { r: 255, g: 255, b: 255 }
  }

  var sampleOffsets = []
  for (var so = 0; so < 5; so++) {
    for (var sj = 0; sj < 5; sj++) {
      var sdx = (so / 4 - 0.5) * 28
      var sdy = (sj / 4 - 0.5) * 28
      if (sdx * sdx + sdy * sdy <= 196) {
        sampleOffsets.push([sdx, sdy])
      }
    }
  }

  function sampleRingColors (cursorX, cursorY) {
    var whiteCount = 0
    for (var i = 0; i < sampleOffsets.length; i++) {
      var sx = cursorX + sampleOffsets[i][0]
      var sy = cursorY + sampleOffsets[i][1]
      var el = document.elementFromPoint(sx, sy)
      if (el) {
        var rgb = getEffectiveBackgroundColor(el)
        if (rgb.r >= 240 && rgb.g >= 240 && rgb.b >= 240) whiteCount++
      }
    }
    return whiteCount / sampleOffsets.length
  }

  function injectWaveFilter () {
    if (document.getElementById('cursor-wave-filter')) return
    var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
    svg.id = 'cursor-wave-filter'
    svg.setAttribute('width', '0')
    svg.setAttribute('height', '0')
    svg.setAttribute('style', 'position:absolute;pointer-events:none;')

    var filter = document.createElementNS('http://www.w3.org/2000/svg', 'filter')
    filter.setAttribute('id', 'cursor-wave')
    filter.setAttribute('x', '-50%')
    filter.setAttribute('y', '-50%')
    filter.setAttribute('width', '200%')
    filter.setAttribute('height', '200%')

    var turbulence = document.createElementNS('http://www.w3.org/2000/svg', 'feTurbulence')
    turbulence.setAttribute('type', 'fractalNoise')
    turbulence.setAttribute('baseFrequency', '0.05')
    turbulence.setAttribute('numOctaves', '2')
    turbulence.setAttribute('result', 'noise')

    var animate = document.createElementNS('http://www.w3.org/2000/svg', 'animate')
    animate.setAttribute('attributeName', 'baseFrequency')
    animate.setAttribute('values', '0.05;0.065;0.05')
    animate.setAttribute('dur', '2.5s')
    animate.setAttribute('repeatCount', 'indefinite')
    turbulence.appendChild(animate)

    var displacement = document.createElementNS('http://www.w3.org/2000/svg', 'feDisplacementMap')
    displacement.setAttribute('in', 'SourceGraphic')
    displacement.setAttribute('in2', 'noise')
    displacement.setAttribute('scale', '2')
    displacement.setAttribute('xChannelSelector', 'R')
    displacement.setAttribute('yChannelSelector', 'G')

    filter.appendChild(turbulence)
    filter.appendChild(displacement)
    svg.appendChild(filter)
    document.body.appendChild(svg)
  }

  function createCursor () {
    injectWaveFilter()
    var wrapper = document.createElement('div')
    wrapper.className = 'target-cursor-wrapper'
    wrapper.innerHTML = '<div class="target-cursor-ring"><div class="target-cursor-ring-inner"></div><div class="target-cursor-glow"></div></div>'

    var vortex = document.createElement('div')
    vortex.className = 'target-cursor-vortex'
    for (var i = 0; i < 35; i++) {
      var p = document.createElement('div')
      p.className = 'vortex-particle'
      p.style.setProperty('--base-scale', (0.6 + Math.random() * 0.6).toFixed(2))
      vortex.appendChild(p)
    }
    wrapper.appendChild(vortex)
    document.body.appendChild(wrapper)
    return { wrapper: wrapper, vortex: vortex }
  }

  function setupTargetCursor () {
    if (window.__targetCursorHexoLoaded || !readCursorEnabledState()) return
    if (isMobileDevice()) return
    if (!window.gsap) {
      console.warn('[target-cursor] gsap is required.')
      return
    }
    window.__targetCursorHexoLoaded = true
    var gsap = window.gsap

    var existingWrapper = document.querySelector('.target-cursor-wrapper')
    var existingGlow = existingWrapper && existingWrapper.querySelector('.target-cursor-glow')
    var cursorObj = existingWrapper && existingGlow
      ? { wrapper: existingWrapper, vortex: existingWrapper.querySelector('.target-cursor-vortex') }
      : createCursor()

    var cursor = cursorObj.wrapper
    var vortex = cursorObj.vortex
    var vortexParticles = vortex.querySelectorAll('.vortex-particle')
    var ring = cursor.querySelector('.target-cursor-ring')
    var ringInner = ring.querySelector('.target-cursor-ring-inner')
    var glow = ring.querySelector('.target-cursor-glow')

    var activeTarget = null
    var leaveHandler = null
    var isSnapped = false
    var resumeTimeout = null
    var layerObserver = null
    var layerRaf = null
    var originalCursor = document.body.style.cursor

    var ringDefaults = { width: 28, height: 28, borderRadius: '50%', scaleX: 1, scaleY: 1 }
    var glowDefaults = { size: 26, borderRadius: '50%', x: 0, y: 0 }

    var vortexActive = true
    var vortexParticleTweens = []
    var snapMouseX = 0
    var snapMouseY = 0
    var snapStrength = { current: 0 }
    var tickerFn = null
    var colorSampleEnabled = isArticlePage()
    var lastColorSampleTime = 0
    var isPinkMode = false
    var searchDialogOpen = false
    var searchDialogObserver = null

    function updateColorSampleEnabled () {
      colorSampleEnabled = isArticlePage() || searchDialogOpen
    }

    gsap.set(glow, { xPercent: -50, yPercent: -50 })

    function startVortex () {
      vortexActive = true
      vortex.style.display = ''
      stopAllVortexParticles()
      var count = 20 + Math.floor(Math.random() * 16)
      var selected = []
      for (var i = 0; i < count; i++) selected.push(vortexParticles[i])
      selected.forEach(function (p, idx) {
        gsap.delayedCall(idx * 0.015 + Math.random() * 0.04, function () {
          if (!vortexActive) return
          spawnVortexParticle(p)
        })
      })
    }

    function spawnVortexParticle (p) {
      if (!vortexActive) return
      var spawnRadius = 35 + Math.random() * 14
      var targetRadius = 14 + Math.random() * 2
      var startAngle = Math.random() * Math.PI * 2
      var totalRotation = (1.5 + Math.random() * 1.5) * Math.PI * 2
      var duration = 5 + Math.random() * 4
      var proxy = { radius: spawnRadius, angle: startAngle }

      gsap.killTweensOf(p)
      gsap.set(p, { opacity: 0, scale: 0.2, x: 0, y: 0 })

      var tween = gsap.to(proxy, {
        radius: targetRadius,
        angle: startAngle + totalRotation,
        duration: duration,
        ease: 'none',
        onUpdate: function () {
          gsap.set(p, {
            x: proxy.radius * Math.cos(proxy.angle),
            y: proxy.radius * Math.sin(proxy.angle)
          })
        },
        onComplete: function () {
          var idx = vortexParticleTweens.indexOf(tween)
          if (idx > -1) vortexParticleTweens.splice(idx, 1)
          if (vortexActive) spawnVortexParticle(p)
        }
      })
      vortexParticleTweens.push(tween)

      var fadeInDur = duration * 0.25
      var holdDur = duration * 0.55
      var fadeOutDur = duration * 0.2
      var opacityTl = gsap.timeline()
      opacityTl.to(p, { opacity: 0.9, scale: 0.8, duration: fadeInDur, ease: 'power2.in' })
      opacityTl.to(p, { opacity: 0.85, scale: 0.6, duration: holdDur, ease: 'none' })
      opacityTl.to(p, { opacity: 0, scale: 0.15, duration: fadeOutDur, ease: 'power2.in' })
      vortexParticleTweens.push(opacityTl)
    }

    function stopAllVortexParticles () {
      vortexParticleTweens.forEach(function (t) {
        if (t && t.kill) t.kill()
      })
      vortexParticleTweens = []
      vortexParticles.forEach(function (p) {
        gsap.killTweensOf(p)
        gsap.set(p, { opacity: 0, scale: 0.2 })
      })
    }

    function stopVortex () {
      vortexActive = false
      stopAllVortexParticles()
      vortex.style.display = 'none'
    }

    function cleanupActiveTarget () {
      if (activeTarget && leaveHandler) activeTarget.removeEventListener('mouseleave', leaveHandler)
      activeTarget = null
      leaveHandler = null
    }

    function isUsableLayerHost (element) {
      if (!element || !document.body.contains(element)) return false
      if (element.tagName === 'DIALOG' && !element.open) return false
      var style = window.getComputedStyle(element)
      return style.display !== 'none' && style.visibility !== 'hidden'
    }

    function findCursorLayerHost () {
      var dialogs = document.querySelectorAll('.fancybox__dialog')
      for (var i = dialogs.length - 1; i >= 0; i--) {
        if (isUsableLayerHost(dialogs[i])) return dialogs[i]
      }
      return document.body
    }

    function placeCursorOnTop () {
      var host = findCursorLayerHost()
      if (!host) return
      if (cursor.parentNode !== host || host.lastElementChild !== cursor) {
        host.appendChild(cursor)
      }
    }

    function scheduleCursorLayerUpdate () {
      if (layerRaf) return
      layerRaf = window.requestAnimationFrame(function () {
        layerRaf = null
        placeCursorOnTop()
      })
    }

    function clearSnapState () {
      if (tickerFn) {
        gsap.ticker.remove(tickerFn)
        tickerFn = null
      }
      gsap.killTweensOf(snapStrength)
      snapStrength.current = 0
    }

    function resetRing () {
      gsap.killTweensOf(ring)
      gsap.killTweensOf(ringInner)
      gsap.killTweensOf(glow)
      clearSnapState()
      gsap.to(ring, {
        width: ringDefaults.width,
        height: ringDefaults.height,
        borderRadius: ringDefaults.borderRadius,
        scaleX: ringDefaults.scaleX,
        scaleY: ringDefaults.scaleY,
        duration: 0.2,
        ease: 'power2.out',
        overwrite: 'auto'
      })
      gsap.to(ringInner, {
        borderRadius: ringDefaults.borderRadius,
        duration: 0.2,
        ease: 'power2.out',
        overwrite: 'auto'
      })
      gsap.to(glow, {
        x: glowDefaults.x,
        y: glowDefaults.y,
        width: glowDefaults.size,
        height: glowDefaults.size,
        borderRadius: '50%',
        duration: 0.2,
        ease: 'power2.out',
        overwrite: 'auto'
      })
      if (!vortexActive) startVortex()
    }

    function moveCursor (x, y) {
      gsap.to(cursor, { x: x, y: y, duration: 0.1, ease: 'power3.out', overwrite: 'auto' })
    }

    function enterTarget (target) {
      if (!target || activeTarget === target) return
      cleanupActiveTarget()
      if (resumeTimeout) {
        clearTimeout(resumeTimeout)
        resumeTimeout = null
      }
      isSnapped = true
      activeTarget = target
      stopVortex()
      snapMouseX = Number(gsap.getProperty(cursor, 'x'))
      snapMouseY = Number(gsap.getProperty(cursor, 'y'))

      gsap.killTweensOf(ring)
      gsap.killTweensOf(ringInner)
      gsap.killTweensOf(glow)
      gsap.killTweensOf(snapStrength)
      clearSnapState()

      var rect = target.getBoundingClientRect()
      var tw = rect.width
      var th = rect.height

      gsap.to(ring, {
        width: tw,
        height: th,
        borderRadius: '8px',
        duration: config.hoverDuration,
        ease: 'power2.out',
        overwrite: 'auto'
      })
      gsap.to(ringInner, {
        borderRadius: '8px',
        duration: config.hoverDuration,
        ease: 'power2.out',
        overwrite: 'auto'
      })
      gsap.to(glow, {
        width: Math.min(tw, th) * 0.5,
        height: Math.min(tw, th) * 0.5,
        duration: config.hoverDuration,
        ease: 'power2.out',
        overwrite: 'auto'
      })

      tickerFn = function () {
        if (!activeTarget) return
        var rect = activeTarget.getBoundingClientRect()
        var targetCenterX = rect.left + rect.width / 2
        var targetCenterY = rect.top + rect.height / 2
        var strength = snapStrength.current

        var cursorX = Number(gsap.getProperty(cursor, 'x'))
        var cursorY = Number(gsap.getProperty(cursor, 'y'))
        var targetRingX = targetCenterX - cursorX
        var targetRingY = targetCenterY - cursorY
        var currentRingX = Number(gsap.getProperty(ring, 'x'))
        var currentRingY = Number(gsap.getProperty(ring, 'y'))
        var finalRingX = currentRingX + (targetRingX - currentRingX) * strength
        var finalRingY = currentRingY + (targetRingY - currentRingY) * strength

        var dur = strength >= 0.99 ? 0.2 : 0.05
        gsap.to(ring, {
          x: finalRingX,
          y: finalRingY,
          duration: dur,
          ease: 'power1.out',
          overwrite: 'auto'
        })

        var dx = snapMouseX - targetCenterX
        var dy = snapMouseY - targetCenterY
        var halfW = rect.width / 2
        var halfH = rect.height / 2
        var normX = halfW > 0 ? Math.max(-1, Math.min(1, dx / halfW)) : 0
        var normY = halfH > 0 ? Math.max(-1, Math.min(1, dy / halfH)) : 0
        var stretchAmt = Math.min(1, Math.sqrt(normX * normX + normY * normY))
        var angle = Math.atan2(dy, dx)
        var stretchFactor = 0.08 * stretchAmt * strength
        var sx = 1 + Math.abs(Math.cos(angle)) * stretchFactor
        var sy = 1 + Math.abs(Math.sin(angle)) * stretchFactor

        gsap.to(ring, {
          scaleX: sx,
          scaleY: sy,
          duration: dur,
          ease: 'power1.out',
          overwrite: 'auto'
        })

        var ringHalfW = rect.width / 2
        var ringHalfH = rect.height / 2
        var glowMaxX = Math.max(0, ringHalfW - 13)
        var glowMaxY = Math.max(0, ringHalfH - 13)
        var glowX = normX * strength * glowMaxX
        var glowY = normY * strength * glowMaxY

        gsap.to(glow, {
          x: glowX,
          y: glowY,
          duration: dur,
          ease: 'power1.out',
          overwrite: 'auto'
        })
      }

      gsap.ticker.add(tickerFn)
      tickerFn()

      gsap.to(snapStrength, {
        current: 1,
        duration: config.hoverDuration,
        ease: 'power2.out',
        overwrite: 'auto'
      })

      leaveHandler = function () {
        isSnapped = false
        cleanupActiveTarget()
        clearSnapState()
        gsap.to(ring, {
          x: 0,
          y: 0,
          scaleX: 1,
          scaleY: 1,
          width: ringDefaults.width,
          height: ringDefaults.height,
          borderRadius: ringDefaults.borderRadius,
          duration: 0.35,
          ease: 'elastic.out(1,0.6)',
          overwrite: 'auto'
        })
        gsap.to(ringInner, {
          borderRadius: ringDefaults.borderRadius,
          duration: 0.35,
          ease: 'elastic.out(1,0.6)',
          overwrite: 'auto'
        })
        gsap.to(glow, {
          x: 0,
          y: 0,
          width: glowDefaults.size,
          height: glowDefaults.size,
          borderRadius: '50%',
          duration: 0.35,
          ease: 'elastic.out(1,0.6)',
          overwrite: 'auto'
        })
        resumeTimeout = window.setTimeout(function () {
          if (!activeTarget) {
            gsap.set(ring, { scaleX: 1, scaleY: 1, x: 0, y: 0 })
            gsap.set(glow, { x: 0, y: 0 })
            if (!vortexActive) startVortex()
          }
          resumeTimeout = null
        }, 50)
      }
      target.addEventListener('mouseleave', leaveHandler)
    }

    function findTarget (startNode) {
      var current = startNode
      while (current && current !== document.body) {
        if (current.matches && current.matches(config.targetSelector)) return current
        current = current.parentElement
      }
      return null
    }

    function mouseMoveHandler (event) {
      moveCursor(event.clientX, event.clientY)
      if (isSnapped) {
        snapMouseX = event.clientX
        snapMouseY = event.clientY
      }
      if (colorSampleEnabled) {
        var now = performance.now()
        if (now - lastColorSampleTime >= 120) {
          lastColorSampleTime = now
          var whiteRatio = sampleRingColors(event.clientX, event.clientY)
          var shouldBePink = whiteRatio > 0.6
          if (shouldBePink !== isPinkMode) {
            isPinkMode = shouldBePink
            cursor.classList.toggle('target-cursor-pink', shouldBePink)
          }
        }
      }
    }

    function mouseOverHandler (event) {
      enterTarget(findTarget(event.target))
    }

    function scrollHandler () {
      if (!activeTarget) return
      var ringRect = ring.getBoundingClientRect()
      var centerX = ringRect.left + ringRect.width / 2
      var centerY = ringRect.top + ringRect.height / 2
      var elementUnderMouse = document.elementFromPoint(centerX, centerY)
      var stillOverTarget = elementUnderMouse &&
        (elementUnderMouse === activeTarget || elementUnderMouse.closest(config.targetSelector) === activeTarget)
      if (!stillOverTarget && leaveHandler) leaveHandler()
    }

    function mouseDownHandler () {
      gsap.to(ring, { scaleX: 0.85, scaleY: 0.85, duration: 0.15, ease: 'power2.out', overwrite: 'auto' })
    }

    function mouseUpHandler () {
      gsap.to(ring, { scaleX: 1, scaleY: 1, duration: 0.15, ease: 'power2.out', overwrite: 'auto' })
    }

    function pjaxSendHandler () {
      isSnapped = false
      cleanupActiveTarget()
      resetRing()
    }

    function pjaxCompleteHandler () {
      placeCursorOnTop()
      initSearchDialogObserver()
    }

    function initSearchDialogObserver () {
      if (searchDialogObserver) {
        searchDialogObserver.disconnect()
        searchDialogObserver = null
      }
      var mask = document.getElementById('search-mask')
      if (!mask) return
      searchDialogObserver = new MutationObserver(function (mutations) {
        mutations.forEach(function (m) {
          if (m.attributeName === 'style') {
            var display = mask.style.display
            if (display === 'block') {
              searchDialogOpen = true
              updateColorSampleEnabled()
            } else {
              searchDialogOpen = false
              updateColorSampleEnabled()
              if (isPinkMode && !isArticlePage()) {
                isPinkMode = false
                cursor.classList.remove('target-cursor-pink')
              }
            }
          }
        })
      })
      searchDialogObserver.observe(mask, { attributes: true, attributeFilter: ['style'] })
    }

    function contentClickHandler (event) {
      var target = event.target
      if (target.matches && target.matches('.recent-post-info .content')) {
        var postInfo = target.closest('.recent-post-info')
        if (postInfo) {
          var titleLink = postInfo.querySelector('.article-title')
          if (titleLink && titleLink.href) {
            event.preventDefault()
            titleLink.click()
          }
        }
      }
    }

    // --- Init ---
    if (config.hideDefaultCursor) document.body.style.cursor = 'none'

    gsap.set(cursor, {
      xPercent: -50,
      yPercent: -50,
      x: window.innerWidth / 2,
      y: window.innerHeight / 2
    })
    placeCursorOnTop()

    if (window.MutationObserver) {
      layerObserver = new MutationObserver(scheduleCursorLayerUpdate)
      layerObserver.observe(document.body, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['class', 'open']
      })
    }

    window.addEventListener('mousemove', mouseMoveHandler)
    window.addEventListener('mouseover', mouseOverHandler, { passive: true })
    window.addEventListener('scroll', scrollHandler, { passive: true })
    window.addEventListener('mousedown', mouseDownHandler)
    window.addEventListener('mouseup', mouseUpHandler)
    document.addEventListener('pjax:send', pjaxSendHandler)
    document.addEventListener('pjax:complete', pjaxCompleteHandler)
    document.addEventListener('click', contentClickHandler)

    startVortex()
    initSearchDialogObserver()

    window.__targetCursorHexoDestroy = function () {
      if (resumeTimeout) clearTimeout(resumeTimeout)
      if (layerRaf) window.cancelAnimationFrame(layerRaf)
      if (layerObserver) layerObserver.disconnect()
      if (searchDialogObserver) searchDialogObserver.disconnect()
      isSnapped = false
      cleanupActiveTarget()
      clearSnapState()
      gsap.killTweensOf(ring)
      gsap.killTweensOf(ringInner)
      gsap.killTweensOf(glow)
      window.removeEventListener('mousemove', mouseMoveHandler)
      window.removeEventListener('mouseover', mouseOverHandler)
      window.removeEventListener('scroll', scrollHandler)
      window.removeEventListener('mousedown', mouseDownHandler)
      window.removeEventListener('mouseup', mouseUpHandler)
      document.removeEventListener('pjax:send', pjaxSendHandler)
      document.removeEventListener('pjax:complete', pjaxCompleteHandler)
      document.removeEventListener('click', contentClickHandler)
      document.body.style.cursor = originalCursor
      if (cursor.parentNode) cursor.parentNode.removeChild(cursor)
      var filter = document.getElementById('cursor-wave-filter')
      if (filter && filter.parentNode) filter.parentNode.removeChild(filter)
      window.__targetCursorHexoDestroy = null
      window.__targetCursorHexoLoaded = false
    }
  }

  function enableTargetCursor () {
    writeCursorEnabledState(true)
    syncCursorEnabledState(true)
    setupTargetCursor()
  }

  function disableTargetCursor () {
    writeCursorEnabledState(false)
    if (window.__targetCursorHexoDestroy) {
      window.__targetCursorHexoDestroy()
    } else {
      window.__targetCursorHexoLoaded = false
    }
    syncCursorEnabledState(false)
  }

  function toggleTargetCursor (forceState) {
    var nextState = typeof forceState === 'boolean' ? forceState : !readCursorEnabledState()
    if (nextState) enableTargetCursor()
    else disableTargetCursor()
    return nextState
  }

  window.TargetCursorController = {
    enable: enableTargetCursor,
    disable: disableTargetCursor,
    toggle: toggleTargetCursor,
    isEnabled: readCursorEnabledState
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      syncCursorEnabledState(readCursorEnabledState())
      setupTargetCursor()
    }, { once: true })
  } else {
    syncCursorEnabledState(readCursorEnabledState())
    setupTargetCursor()
  }
})()