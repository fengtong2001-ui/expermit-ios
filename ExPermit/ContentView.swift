import SwiftUI
import WebKit

struct ContentView: UIViewRepresentable {
  func makeUIView(context: Context) -> WKWebView {
    let config = WKWebViewConfiguration()
    let root = Bundle.main.resourceURL?.appendingPathComponent("www") ?? Bundle.main.bundleURL
    config.setURLSchemeHandler(LocalSchemeHandler(root: root), forURLScheme: "app")
    config.defaultWebpagePreferences.allowsContentJavaScript = true

    let web = WKWebView(frame: .zero, configuration: config)
    web.navigationDelegate = context.coordinator
    web.scrollView.keyboardDismissMode = .interactive
    web.backgroundColor = .systemBackground
    web.load(URLRequest(url: URL(string: "app://local/index.html")!))
    return web
  }

  func updateUIView(_ uiView: WKWebView, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  final class Coordinator: NSObject, WKNavigationDelegate {
    /// 外链交给系统浏览器，应用内只装 app://local 的页面
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
      guard let url = navigationAction.request.url else {
        decisionHandler(.allow)
        return
      }
      if url.scheme == "app" || url.scheme == "about" || url.scheme == "data" {
        decisionHandler(.allow)
      } else if url.scheme?.hasPrefix("http") == true {
        if navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == true {
          UIApplication.shared.open(url)
          decisionHandler(.cancel)
        } else {
          decisionHandler(.cancel)
        }
      } else {
        decisionHandler(.allow)
      }
    }
  }
}
