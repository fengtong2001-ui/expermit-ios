import Foundation
import WebKit

/// 把 bundle 里的 www/ 挂到 app://local/，给网页一个真实的源（IndexedDB、fetch 都正常）
final class LocalSchemeHandler: NSObject, WKURLSchemeHandler {
  let root: URL

  init(root: URL) {
    self.root = root
  }

  func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
    let path = task.request.url?.path.removingPercentEncoding ?? "/"
    let rel = String(path.dropFirst(path.hasPrefix("/") ? 1 : 0))
    let base = rel.isEmpty || rel.hasSuffix("/") ? rel + "index.html" : rel
    // 真机上 Bundle 路径是 /private/var/...，standardizedFileURL 会变成 /var/...；
    // 两边都解析符号链接后再比较，否则会被误判成路径穿越。
    let rootResolved = root.resolvingSymlinksInPath()
    let file = rootResolved.appendingPathComponent(base).standardizedFileURL.resolvingSymlinksInPath()
    let rootPrefix = rootResolved.path.hasSuffix("/") ? rootResolved.path : rootResolved.path + "/"
    guard file.path.hasPrefix(rootPrefix) else {
      task.didFailWithError(NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError))
      return
    }
    guard let data = FileManager.default.contents(atPath: file.path) else {
      task.didFailWithError(NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError))
      return
    }
    let mime = LocalSchemeHandler.mime(forExtension: file.pathExtension.lowercased())
    let resp = HTTPURLResponse(
      url: task.request.url!,
      statusCode: 200,
      httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": mime, "Cache-Control": "no-cache"]
    )!
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
    case "avif": return "image/avif"
    case "ico": return "image/x-icon"
    case "mp4": return "video/mp4"
    case "woff": return "font/woff"
    case "woff2": return "font/woff2"
    case "ttf": return "font/ttf"
    case "txt": return "text/plain"
    case "wasm": return "application/wasm"
    default: return "application/octet-stream"
    }
  }
}
