import SwiftUI

@main
struct ExPermitApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        // 底部安全区交给网页自己处理（Shell.tsx 的底部导航用 env(safe-area-inset-bottom)）
        .ignoresSafeArea(.container, edges: .bottom)
    }
  }
}
