import SwiftUI

@main
struct ExPermitApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        // 上下都铺到屏幕边缘：顶部由页头背景填满灵动岛区域，底部导航自己处理安全区
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        // 键盘出现时不让 SwiftUI 改视图尺寸，交给网页自己滚动
        .ignoresSafeArea(.keyboard)
    }
  }
}
