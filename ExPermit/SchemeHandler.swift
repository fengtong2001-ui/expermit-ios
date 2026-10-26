import Foundation
import WebKit

/// 把 bundle 里的 www/ 挂到 app://local/，给网页一个真实的源（IndexedDB、fetch 都正常）
final class LocalSchemeHandler: NSObject, WKURLSchemeHandler {
  let root: URL

  init(root: URL) {
    self.root = root
  }

  func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
    let path = task.request.url?.path ?? "/"
    let rel = String(path.dropFirst(path.hasPrefix("/") ? 1 : 0))
    let base = rel.isEmpty || rel.hasSuffix("/") ? rel + "index.html" : rel
    let file = root.appendingPathComponent(base).standardizedFileURL
    guard file.path.hasPrefix(root.path) else {
      task.didFailWithError(NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError))
      return
    }
    guard let data = FileManager.default.contents(atPath: file.path) else {
      task.didFailWithError(NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError))
      return
    }
    let ext = (file.pathExtension as NSString).lowercased
    let mime = LocalSchemeHandler.mime(forExtension: ext)
    let resp = HTTPURLResponse(url: task.request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": mime, "Cache-Control": "no-cache"])!
    task.didReceive(resp)
    task.didReceive(data)
    task.didFinish()
  }

  func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

  static func mime(forExtension ext: String) -> String {
    switch ext {
    case "html": return "text/html"
    case "js", "mjs": return "text/javascript"
    case "css": return "text/css"
    case "json", "map": return "application/json"
    case "webmanifest": return "application/manifest+json"
    case "svg": return "image/svg+xml"
    case "png": return "image/png"
    case "jpg", "jpeg": return "image/jpeg"
    case "gif": return "image/gif"
    case "webp": return "image/webp"
    case "woff": return "font/woff"
    case "woff2": return "font/woff2"
    case "ttf": return "font/ttf"
    case "ico": return "image/x-icon"
    case "txt": return "text/plain"
    case "wasm": return "application/wasm"
    default: return "application/octet-stream"
    }
  }
}
