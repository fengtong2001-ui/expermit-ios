import SwiftUI
import UIKit
import WebKit

struct ContentView: UIViewRepresentable {
  func makeUIView(context: Context) -> WKWebView {
    let config = WKWebViewConfiguration()
    let root = Bundle.main.resourceURL?.appendingPathComponent("www") ?? Bundle.main.bundleURL
    config.setURLSchemeHandler(LocalSchemeHandler(root: root), forURLScheme: "app")
    config.defaultWebpagePreferences.allowsContentJavaScript = true

    let controller = config.userContentController
    controller.add(context.coordinator, name: NativeBridge.saveHandler)
    controller.add(context.coordinator, name: NativeBridge.printHandler)
    controller.add(context.coordinator, name: IOSAdaptation.themeHandler)
    controller.addUserScript(
      WKUserScript(
        source: NativeBridge.bootstrapJS,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
      )
    )
    controller.addUserScript(
      WKUserScript(
        source: IOSAdaptation.injectionJS,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
      )
    )

    let web = WKWebView(frame: .zero, configuration: config)
    web.navigationDelegate = context.coordinator
    web.scrollView.keyboardDismissMode = .interactive
    // 页面本身就是 h-dvh 的单屏应用，禁掉外层滚动/回弹与双指缩放
    web.scrollView.bounces = false
    web.scrollView.alwaysBounceVertical = false
    web.scrollView.alwaysBounceHorizontal = false
    web.scrollView.bouncesZoom = false
    web.scrollView.isDirectionalLockEnabled = true
    web.scrollView.showsHorizontalScrollIndicator = false
    web.scrollView.showsVerticalScrollIndicator = false
    web.scrollView.delaysContentTouches = false
    web.scrollView.contentInsetAdjustmentBehavior = .never
    web.scrollView.minimumZoomScale = 1
    web.scrollView.maximumZoomScale = 1
    web.scrollView.pinchGestureRecognizer?.isEnabled = false
    web.scrollView.delegate = context.coordinator
    web.backgroundColor = .systemBackground
    web.underPageBackgroundColor = .systemBackground
    web.scrollView.backgroundColor = .systemBackground
    web.isOpaque = false
    #if DEBUG
      if #available(iOS 16.4, *) {
        web.isInspectable = true
      }
    #endif
    context.coordinator.webView = web

    let index = root.appendingPathComponent("index.html")
    if FileManager.default.fileExists(atPath: index.path) {
      web.load(URLRequest(url: URL(string: "app://local/index.html")!))
    } else {
      web.loadHTMLString(ContentView.missingWWWPage, baseURL: nil)
    }
    return web
  }

  func updateUIView(_ uiView: WKWebView, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  /// 克隆后还没取网页包时的提示页，避免一片空白
  static let missingWWWPage = """
  <!doctype html><html><meta name="viewport" content="width=device-width,initial-scale=1">
  <body style="font:16px -apple-system,PingFang SC;padding:28px;color:#0f172a;background:#fff;line-height:1.6">
  <h2 style="margin:0 0 16px">还没有网页资源</h2>
  <p>在仓库根目录运行下面两行，把核心仓的 www 取进来：</p>
  <pre style="background:#f1f5f9;padding:12px;border-radius:10px;overflow:auto">npm install
  node scripts/fetch-www.mjs --core ../expermit-eln</pre>
  <p style="color:#64748b">核心仓需先执行 npm run build 生成 dist/。</p>
  </body></html>
  """

  final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKDownloadDelegate, UIScrollViewDelegate {
    weak var webView: WKWebView?
    /// 下载任务 → (临时文件, 临时目录)，分享面板关闭后清目录
    private var downloads: [WKDownload: (file: URL, dir: URL)] = [:]

    // MARK: - 网页 ↔ 原生

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
      switch message.name {
      case NativeBridge.saveHandler:
        handleSave(message.body)
      case NativeBridge.printHandler:
        handlePrint()
      case IOSAdaptation.themeHandler:
        applyTheme(message.body)
      default:
        break
      }
    }

    /// 网页主题变化时同步原生背景/界面风格：灵动岛、键盘、过度滚动区域都跟随页面
    private func applyTheme(_ body: Any) {
      guard let dict = body as? [String: Any] else { return }
      let dark = dict["dark"] as? Bool ?? false
      let fallback = dark
        ? UIColor(red: CGFloat(2) / 255, green: CGFloat(6) / 255, blue: CGFloat(23) / 255, alpha: 1)
        : UIColor.white
      let color = (dict["color"] as? String).flatMap(UIColor.init(hex:)) ?? fallback
      DispatchQueue.main.async {
        guard let web = self.webView else { return }
        web.backgroundColor = color
        web.scrollView.backgroundColor = color
        web.underPageBackgroundColor = color
        web.overrideUserInterfaceStyle = dark ? .dark : .light
        web.window?.backgroundColor = color
        web.window?.overrideUserInterfaceStyle = dark ? .dark : .light
      }
    }

    /// 网页把 Blob 转成 base64 传来（与 macOS 壳同契约），写进临时目录后弹系统分享面板
    private func handleSave(_ body: Any) {
      guard
        let dict = body as? [String: Any],
        let filename = dict["filename"] as? String,
        let content = dict["content"] as? String,
        let isBase64 = dict["isBase64"] as? Bool, isBase64,
        let data = Data(base64Encoded: content)
      else { return }

      let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("ExPermitShare-\(UUID().uuidString)", isDirectory: true)
      do {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(NativeBridge.sanitize(filename))
        try data.write(to: file, options: .atomic)
        presentShare(for: file, cleanupDir: dir)
      } catch {
        alert(title: "保存失败", message: error.localizedDescription)
      }
    }

    private func handlePrint() {
      DispatchQueue.main.async {
        guard let webView = self.webView else { return }
        let info = UIPrintInfo.printInfo()
        info.outputType = .general
        info.jobName = "ExPermit"
        let printer = UIPrintInteractionController.shared
        printer.printInfo = info
        printer.printFormatter = webView.viewPrintFormatter()
        if UIDevice.current.userInterfaceIdiom == .pad, let view = self.topViewController()?.view {
          printer.present(
            from: CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0),
            in: view,
            animated: true,
            completionHandler: nil
          )
        } else {
          printer.present(animated: true, completionHandler: nil)
        }
      }
    }

    private func presentShare(for file: URL, cleanupDir: URL) {
      DispatchQueue.main.async {
        guard let host = self.topViewController() else { return }
        let activity = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        activity.completionWithItemsHandler = { _, _, _, _ in
          try? FileManager.default.removeItem(at: cleanupDir)
        }
        if let popover = activity.popoverPresentationController {
          popover.sourceView = host.view
          popover.sourceRect = CGRect(
            x: host.view.bounds.midX,
            y: host.view.bounds.midY,
            width: 0,
            height: 0
          )
          popover.permittedArrowDirections = []
        }
        host.present(activity, animated: true)
      }
    }

    private func alert(title: String, message: String) {
      DispatchQueue.main.async {
        guard let host = self.topViewController() else { return }
        let sheet = UIAlertController(title: title, message: message, preferredStyle: .alert)
        sheet.addAction(UIAlertAction(title: "好", style: .default))
        host.present(sheet, animated: true)
      }
    }

    private func topViewController() -> UIViewController? {
      let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
      guard let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first else {
        return nil
      }
      var top = window.rootViewController
      while let presented = top?.presentedViewController {
        top = presented
      }
      return top
    }

    // MARK: - 导航

    /// 外链交给系统浏览器，应用内只装 app://local 的页面
    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
      guard let url = navigationAction.request.url else {
        decisionHandler(.allow)
        return
      }
      let scheme = url.scheme?.lowercased() ?? ""
      if scheme == "app" || scheme == "about" || scheme == "data" || scheme == "blob" {
        decisionHandler(navigationAction.shouldPerformDownload ? .download : .allow)
        return
      }
      if scheme == "http" || scheme == "https" || scheme == "mailto" || scheme == "tel" {
        if navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == true {
          UIApplication.shared.open(url)
          decisionHandler(.cancel)
        } else {
          decisionHandler(.cancel)
        }
        return
      }
      decisionHandler(.allow)
    }

    /// 网页里直接指向文件的链接（没有走 expermitMac.saveFile 的情况）走系统下载
    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationResponse: WKNavigationResponse,
      decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
      decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
      download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
      download.delegate = self
    }

    // MARK: - 缩放/横向平移

    /// 输入框聚焦时 WebKit 会尝试缩放页面露出光标；返回 nil 直接禁用缩放
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { nil }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
      guard abs(scrollView.zoomScale - 1) > 0.01 else { return }
      scrollView.setZoomScale(1, animated: false)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
      guard abs(scrollView.contentOffset.x) > 0.5 else { return }
      scrollView.contentOffset.x = 0
    }

    #if DEBUG
      private var didRunSelftest = false
      private var didApplyDebugLaunch = false
    #endif

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if !didApplyDebugLaunch {
          didApplyDebugLaunch = true
          // 验证用：--theme=dark|light / --route=settings / --open-search
          if let themeArg = args.first(where: { $0.hasPrefix("--theme=") }) {
            let theme = String(themeArg.dropFirst("--theme=".count))
            webView.evaluateJavaScript("localStorage.setItem('eln-theme','\(theme)'); location.reload()")
            return
          }
          if let routeArg = args.first(where: { $0.hasPrefix("--route=") }) {
            let route = String(routeArg.dropFirst("--route=".count))
            webView.evaluateJavaScript("location.hash = '#/\(route)'")
          }
          if args.contains("--open-search") {
            webView.evaluateJavaScript(
              #"setTimeout(function () { document.querySelector('button[aria-label="搜索"]')?.click() }, 900)"#
            )
          }
          if args.contains("--open-settings") {
            webView.evaluateJavaScript(
              #"setTimeout(function () { document.querySelector('button[data-ios-settings="true"]')?.click() }, 900)"#
            )
          }
          if args.contains("--new-experiment") {
            webView.evaluateJavaScript(
              #"setTimeout(function () { document.querySelector('button[aria-label="新建实验"]')?.click() }, 900)"#
            )
          }
          if args.contains("--open-schedule") {
            webView.evaluateJavaScript(
              #"setTimeout(function () { var b = Array.prototype.find.call(document.querySelectorAll('button'), function (x) { return x.textContent && x.textContent.indexOf('添加安排') > -1 }); b && b.click() }, 900)"#
            )
          }
          if args.contains("--fake-keyboard") {
            webView.evaluateJavaScript(
              #"setTimeout(function () { document.documentElement.style.setProperty('--ios-kb', '320px') }, 1600)"#
            )
          }
        }
        guard args.contains("--selftest"), !didRunSelftest else { return }
        didRunSelftest = true
        webView.evaluateJavaScript(
          "window.expermitMac.saveFile('selftest.txt', btoa('SELFTEST OK'), true)"
        )
      #endif
    }

    // MARK: - 下载兜底

    func download(
      _ download: WKDownload,
      decideDestinationUsing response: URLResponse,
      suggestedFilename: String,
      completionHandler: @escaping (URL?) -> Void
    ) {
      let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("ExPermitDownload-\(UUID().uuidString)", isDirectory: true)
      do {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(NativeBridge.sanitize(suggestedFilename))
        downloads[download] = (file, dir)
        completionHandler(file)
      } catch {
        completionHandler(nil)
      }
    }

    func downloadDidFinish(_ download: WKDownload) {
      guard let entry = downloads.removeValue(forKey: download) else { return }
      presentShare(for: entry.file, cleanupDir: entry.dir)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
      if let entry = downloads.removeValue(forKey: download) {
        try? FileManager.default.removeItem(at: entry.dir)
      }
      alert(title: "下载失败", message: error.localizedDescription)
    }
  }
}
