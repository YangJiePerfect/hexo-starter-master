(function () {
  if (window.__updateLogInjected) return
  window.__updateLogInjected = true

  function injectUpdateLogWidget () {
    var aside = document.getElementById('aside-content')
    if (!aside || document.getElementById('update-log')) return
    var coloInfo = aside.querySelector('#colo-info')
    if (!coloInfo) return

    var widget = document.createElement('div')
    widget.className = 'card-widget update-log'
    widget.id = 'update-log'
    widget.innerHTML = [
      '<div class="item-headline"><i class="fas fa-clipboard-list"></i><span>更新日志</span></div>',
      '<div class="item-content">',
      '<div class="update-log-preview" id="update-log-preview">加载中...</div>',
      '<div class="update-log-hint"><i class="fas fa-chevron-right"></i> 点击查看详情</div>',
      '</div>'
    ].join('')

    coloInfo.insertAdjacentElement('afterend', widget)
    fetchUpdateLog()
  }

  function fetchUpdateLog () {
    fetch('/update.txt', { cache: 'no-store' })
      .then(function (r) { return r.text() })
      .then(function (t) {
        var lines = t.split('\n')
        var versions = []
        var current = {}

        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim()
          if (!line) continue

          // 检测日期行：YYYY.M.D 或 YYYY.MM.DD
          var dateMatch = line.match(/^(\d{4}\.\d{1,2}\.\d{1,2})$/)
          if (dateMatch) {
            if (current.date) versions.push(current)
            current = { date: dateMatch[1], version: '', items: [] }
            // 下一行如果是版本号，则读取
            if (i + 1 < lines.length && /^v\d+\.\d+\.\d+/.test(lines[i + 1].trim())) {
              i++
              current.version = lines[i].trim()
            }
          } else if (current.date && !current.version && /^v\d+\.\d+\.\d+/.test(line)) {
            current.version = line
          } else if (current.date && current.version && line !== current.version && line !== current.date) {
            current.items.push(line)
          }
        }
        if (current.date) versions.push(current)

        renderPreview(versions)
        setupModal(versions)
      })
      .catch(function () {
        var el = document.getElementById('update-log-preview')
        if (el) el.textContent = '加载失败'
      })
  }

  function renderPreview (versions) {
    var el = document.getElementById('update-log-preview')
    if (!el) return
    if (!versions.length) {
      el.textContent = '暂无更新日志'
      return
    }

    var skipHeaders = { '修复': 1, '新增：': 1, '优化：': 1, '已知问题：': 1 }
    var latest = versions[0]
    var html = '<div class="update-version">' + latest.version + '</div>'
    html += '<div class="update-date">' + latest.date + '</div>'

    var count = 0
    for (var i = 0; i < latest.items.length && count < 4; i++) {
      var item = latest.items[i]
      if (!item) continue
      if (skipHeaders[item]) continue
      html += '<div class="update-item">' + escapeHtml(item) + '</div>'
      count++
    }
    el.innerHTML = html
  }

  function escapeHtml (s) {
    return s.replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
  }

  function setupModal (versions) {
    var widget = document.getElementById('update-log')
    if (!widget) return

    var overlay = document.createElement('div')
    overlay.className = 'update-log-overlay'
    overlay.id = 'update-log-overlay'
    overlay.innerHTML = [
      '<div class="update-log-modal">',
      '<div class="update-log-modal-header">',
      '<span>更新日志</span>',
      '<button class="update-log-close" id="update-log-close"><i class="fas fa-times"></i></button>',
      '</div>',
      '<div class="update-log-modal-body" id="update-log-modal-body"></div>',
      '</div>'
    ].join('')
    document.body.appendChild(overlay)

    function openModal (overlay, modalBody, versions) {
      var html = ''
      for (var i = 0; i < versions.length; i++) {
        var v = versions[i]
        html += '<div class="update-log-version-block">'
        html += '<div class="update-log-version-title">' + v.version + '</div>'
        html += '<div class="update-log-version-date">' + v.date + '</div>'
        for (var j = 0; j < v.items.length; j++) {
          var item = v.items[j]
          if (!item) continue
          html += '<div class="update-log-version-item">' + escapeHtml(item) + '</div>'
        }
        html += '</div>'
      }
      modalBody.innerHTML = html

      var scrollY = window.scrollY || window.pageYOffset
      document.body.style.position = 'fixed'
      document.body.style.top = '-' + scrollY + 'px'
      document.body.style.width = '100%'
      overlay.classList.add('open')
    }

    function closeModal (overlay) {
      overlay.classList.remove('open')
      var scrollY = Math.abs(parseInt(document.body.style.top || '0'))
      document.body.style.position = ''
      document.body.style.top = ''
      document.body.style.width = ''
      window.scrollTo(0, scrollY)
    }

    widget.addEventListener('click', function (e) {
      if (e.target.closest('.update-log-close')) return
      var modalBody = document.getElementById('update-log-modal-body')
      if (!modalBody) return
      openModal(overlay, modalBody, versions)
    })

    document.getElementById('update-log-close').addEventListener('click', function (e) {
      e.stopPropagation()
      closeModal(overlay)
    })

    overlay.addEventListener('click', function (e) {
      if (e.target === overlay) {
        closeModal(overlay)
      }
    })
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', injectUpdateLogWidget)
  } else {
    injectUpdateLogWidget()
  }

  document.addEventListener('pjax:complete', function () {
    window.__updateLogInjected = false
    injectUpdateLogWidget()
  })
})()