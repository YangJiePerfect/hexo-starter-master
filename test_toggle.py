"""Test: toggle 按钮是否在退出 Live2D 后正确出现"""
from playwright.sync_api import sync_playwright
import time

with sync_playwright() as p:
    browser = p.chromium.launch(headless=False)
    context = browser.new_context(
        viewport={"width": 1280, "height": 800},
        # 模拟首次访问——清除所有 local/session storage
        storage_state=None
    )
    page = context.new_page()

    # 监听 console 错误
    errors = []
    page.on("console", lambda msg: (
        errors.append(f"[{msg.type}] {msg.text}")
        if msg.type in ("error", "warning") else None
    ))
    page.on("pageerror", lambda err: errors.append(f"[PAGE] {err.message}"))

    print("=== Step 1: 导航到首页（模拟首次访问）===")
    page.goto("http://localhost:4000/", wait_until="networkidle", timeout=30000)
    page.wait_for_timeout(2000)  # 等 Live2D 加载

    print("=== Step 2: 查找 quit 按钮（X 图标）===")
    # waifu-tool 在 waifu hover 时才显示 opacity:1
    waifu = page.locator("#waifu")
    waifu.hover()
    page.wait_for_timeout(500)

    # 查找 quit 按钮 span
    quit_span = page.locator("#waifu-tool span").last  # quit 是最后一个 span
    if quit_span.count() > 0:
        print("    找到 quit 按钮，点击退出...")
        quit_span.click(force=True)
    else:
        print("    未找到 quit 按钮！检查 waifu-tool 结构")
        page.screenshot(path="debug_no_quit.png", full_page=True)
        # 备用：直接用 ID
        quit_direct = page.locator("#waifu-tool-quit")
        if quit_direct.count() > 0:
            quit_direct.click(force=True)
        else:
            print("    ❌ 无法找到 quit 按钮，终止测试")
            browser.close()
            exit(1)

    print("=== Step 3: 等待 3.5 秒（setTimeout 3000 + 缓冲）===")
    page.wait_for_timeout(3500)

    print("=== Step 4: 检查 toggle 按钮状态 ===")
    toggle = page.locator("#waifu-toggle")

    if toggle.count() == 0:
        print("    ❌ FAIL: #waifu-toggle 不存在于 DOM 中！")
    else:
        print(f"    DOM 中存在, HTML: {toggle.inner_html()}")
        classes = toggle.get_attribute("class") or ""
        print(f"    class 属性: '{classes}'")
        display = toggle.evaluate("el => window.getComputedStyle(el).display")
        print(f"    computed display: '{display}'")
        margin_left = toggle.evaluate("el => window.getComputedStyle(el).marginLeft")
        print(f"    computed margin-left: '{margin_left}'")
        opacity = toggle.evaluate("el => window.getComputedStyle(el).opacity")
        print(f"    computed opacity: '{opacity}'")

        if "waifu-toggle-active" in classes:
            print("    ✅ toggle 已正确显示 (waifu-toggle-active)")
        else:
            print("    ❌ FAIL: toggle 存在但未添加 waifu-toggle-active 类")

    print("=== Step 5: 检查 waifu 状态 ===")
    waifu_div = page.locator("#waifu")
    if waifu_div.count() > 0:
        w_display = waifu_div.evaluate("el => window.getComputedStyle(el).display")
        w_bottom = waifu_div.evaluate("el => window.getComputedStyle(el).bottom")
        print(f"    waifu display: '{w_display}', bottom: '{w_bottom}'")
    else:
        print("    waifu 不存在于 DOM")

    print("=== Step 6: 检查 localStorage ===")
    wd = page.evaluate("() => localStorage.getItem('waifu-display')")
    print(f"    waifu-display: '{wd}'")

    print("\n=== Console 错误 ===")
    for err in errors[:20]:
        print(f"  {err}")
    if len(errors) > 20:
        print(f"  ... 还有 {len(errors)-20} 条")

    page.screenshot(path="toggle_test_result.png", full_page=True)
    print("\n截图保存到 toggle_test_result.png")

    browser.close()