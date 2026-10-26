import UIKit

/// iOS 壳独有的网页适配层。
///
/// 所有规则都挂在 `html.ios-shell` 下，只注入 WKWebView，不改核心仓网页源码；
/// 浏览器 / PWA / 桌面版完全不受影响。网页 DOM 结构大改时优先改这里。
enum IOSAdaptation {
  static let themeHandler = "expermitTheme"

  /// 页面背景、安全区、输入控件、弹层滚动锁定等移动端修正
  static let css = """
  html.ios-shell {
    -webkit-text-size-adjust: 100%;
    overflow-x: hidden;
    overscroll-behavior: none;
  }
  html.ios-shell body {
    overflow-x: hidden;
    overscroll-behavior: none;
    background-color: #ffffff;
  }
  html.ios-shell.dark body { background-color: #020617; }
  html.ios-shell #root { min-height: 100dvh; }
  html.ios-shell #main-scroll {
    overflow-x: hidden;
    overscroll-behavior-x: none;
    overscroll-behavior-y: none;
    padding-bottom: calc(4rem + env(safe-area-inset-bottom) + 1rem) !important;
    scrollbar-width: none;
  }
  html.ios-shell #main-scroll::-webkit-scrollbar { width: 0; height: 0; display: none; }
  html.ios-shell #main-scroll > * { max-width: 100vw; }

  /* 顶部延伸到灵动岛/状态栏后面，用页头背景自然填满 */
  html.ios-shell header[data-mac-drag-region] {
    padding-top: env(safe-area-inset-top);
  }
  html.ios-shell header[data-mac-drag-region] h1 {
    font-size: 17px;
    letter-spacing: -0.01em;
  }
  html.ios-shell header[data-mac-drag-region] button[aria-label="搜索"],
  html.ios-shell header[data-mac-drag-region] button[data-ios-settings="true"] {
    min-width: 44px;
    min-height: 44px;
  }

  /* 16px 是 iOS 输入框不自动放大的下限 */
  html.ios-shell input:not([type="checkbox"]):not([type="radio"]):not([type="range"]),
  html.ios-shell textarea,
  html.ios-shell select {
    font-size: 16px !important;
  }
  html.ios-shell .field { min-height: 44px; }

  html.ios-shell button,
  html.ios-shell a,
  html.ios-shell [role="button"] {
    touch-action: manipulation;
  }

  /* 弹层打开时锁住底页滚动，弹层内部照常滚 */
  html.ios-shell.ios-modal-open #main-scroll {
    overflow: hidden !important;
    overscroll-behavior: none !important;
  }
  html.ios-shell [role="dialog"] {
    max-height: calc(100dvh - env(safe-area-inset-top) - 16px);
  }
  html.ios-shell [cmdk-list],
  html.ios-shell [role="dialog"] .overflow-y-auto {
    overscroll-behavior: contain;
  }
  """

  /// 注入脚本：加 ios-shell 标记、上报主题、锁弹层背景滚动、在页头插入设置入口
  static var injectionJS: String {
    """
    (function () {
      var doc = document;
      var html = doc.documentElement;
      if (!html) return;
      html.classList.add('ios-shell');

      var style = doc.createElement('style');
      style.id = 'expermit-ios-style';
      style.textContent = `\(css)`;
      (doc.head || html).appendChild(style);

      function postTheme() {
        var dark = html.classList.contains('dark');
        var meta = doc.querySelector('meta[name="theme-color"]');
        var color = meta ? meta.getAttribute('content') : (dark ? '#020617' : '#ffffff');
        if (window.__expermitThemeKey === dark + color) return;
        window.__expermitThemeKey = dark + color;
        try {
          window.webkit.messageHandlers.expermitTheme.postMessage({ dark: dark, color: color });
        } catch (e) {}
      }

      function syncModal() {
        var open = !!doc.querySelector('[role="dialog"]');
        html.classList.toggle('ios-modal-open', open);
      }

      var gearSvg = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-settings" aria-hidden="true"><path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/></svg>';

      function ensureSettings() {
        var header = doc.querySelector('header[data-mac-drag-region]');
        if (!header) return;
        var search = header.querySelector('button[aria-label="搜索"]');
        if (!search) return;
        var onSettings = location.hash.indexOf('#/settings') === 0;
        var btn = header.querySelector('button[data-ios-settings="true"]');
        if (!btn) {
          if (onSettings) return;
          btn = doc.createElement('button');
          btn.type = 'button';
          btn.setAttribute('data-ios-settings', 'true');
          btn.setAttribute('aria-label', '设置与同步');
          btn.className = search.className;
          btn.innerHTML = gearSvg;
          btn.addEventListener('click', function (e) {
            e.preventDefault();
            location.hash = '#/settings';
          });
          search.insertAdjacentElement('afterend', btn);
        }
        btn.style.display = onSettings ? 'none' : '';
      }

      var scheduled = false;
      function refresh() {
        if (scheduled) return;
        scheduled = true;
        var run = function () {
          scheduled = false;
          postTheme();
          syncModal();
          ensureSettings();
        };
        if (window.requestAnimationFrame) window.requestAnimationFrame(run);
        else setTimeout(run, 16);
      }

      new MutationObserver(refresh).observe(html, {
        attributes: true,
        attributeFilter: ['class']
      });
      new MutationObserver(refresh).observe(html, {
        subtree: true,
        childList: true
      });
      doc.addEventListener('hashchange', refresh);
      refresh();
    })();
    """
  }
}

extension UIColor {
  /// #RRGGBB → UIColor
  convenience init?(hex: String) {
    var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
    self.init(
      red: CGFloat((v >> 16) & 0xFF) / 255,
      green: CGFloat((v >> 8) & 0xFF) / 255,
      blue: CGFloat(v & 0xFF) / 255,
      alpha: 1
    )
  }
}
