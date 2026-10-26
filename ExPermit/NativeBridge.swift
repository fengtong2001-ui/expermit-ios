import Foundation

/// 网页层 ↔ iOS 壳的桥接约定。
///
/// 网页层（src/lib/native.ts）只认 `window.expermitMac`，macOS / iOS 两个壳共用同一份接口：
/// 下载备份、导出实验、下载附件都会先找这个对象，找到就不走浏览器下载。
/// 这里用同名对象注入，核心仓的网页代码不需要为 iOS 改任何一行。
enum NativeBridge {
  static let saveHandler = "expermitSave"
  static let printHandler = "expermitPrint"

  /// 在网页脚本执行前注入：保存文件走原生分享面板，打印走系统打印
  static let bootstrapJS = """
  (function () {
    if (!window.expermitMac) {
      window.expermitMac = {
        isNative: true,
        saveFile: function (filename, content, isBase64) {
          try {
            window.webkit.messageHandlers.expermitSave.postMessage({
              filename: String(filename || 'ExPermit'),
              content: String(content || ''),
              isBase64: !!isBase64
            });
          } catch (e) {}
        }
      };
    }
    var nativePrint = window.print ? window.print.bind(window) : null;
    window.print = function () {
      try {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.expermitPrint) {
          window.webkit.messageHandlers.expermitPrint.postMessage({});
          return;
        }
      } catch (e) {}
      if (nativePrint) nativePrint();
    };
  })();
  """

  /// 文件名用于写入临时目录，去掉路径分隔符等非法字符，保留中文
  static func sanitize(_ name: String) -> String {
    let illegal = CharacterSet(charactersIn: "/\\:?*|\"<>")
    var out = name.components(separatedBy: illegal).joined(separator: "_")
    out = out.trimmingCharacters(in: .whitespacesAndNewlines)
    if out.isEmpty { out = "ExPermit" }
    if out.count > 120 { out = String(out.prefix(120)) }
    return out
  }
}
