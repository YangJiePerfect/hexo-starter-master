(function () {
  if (window.DeviceDetector) return

  function detectDeviceType () {
    var ua = (navigator.userAgent || '').toLowerCase()
    var isIPad = /ipad/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1 && !window.MSStream)
    if (isIPad) return 'pc'

    var mobileRegex = /android|webos|iphone|ipod|blackberry|iemobile|opera mini/i
    if (mobileRegex.test(ua)) return 'mobile'

    var hasTouch = 'ontouchstart' in window || navigator.maxTouchPoints > 0
    var isSmallScreen = window.innerWidth <= 768
    if (hasTouch && isSmallScreen) return 'mobile'

    return 'pc'
  }

  function isMobileDevice () {
    return detectDeviceType() === 'mobile'
  }

  window.DeviceDetector = {
    detectDeviceType: detectDeviceType,
    isMobileDevice: isMobileDevice
  }
})()
