# ExPermit · iOS 版

ExPermit 实验记录本的 **iOS 壳**。应用源码（网页层 + 数据模型 + 同步）在
[expermit-eln](https://github.com/fengtong2001-ui/expermit-eln)，本仓只负责 iOS 外壳与打包。

结构：SwiftUI + WKWebView，`app://local` 自定义协议加载 App 内置的 `ExPermit/www`
（由核心仓网页包填入），数据存在 iOS 应用沙盒的 IndexedDB 里。

## 出包

1. 装好 Xcode（App Store，免费，约 12GB）
2. 取网页包：

```bash
npm install
node scripts/fetch-www.mjs --ver 0.1.4    # 或 --core ../expermit-eln 用本地构建
```

3. 打开 `ExPermit.xcodeproj` → 目标 ExPermit → Signing & Capabilities → Team 选自己的 Apple ID
4. 选模拟器按 ⌘R 验证；数据线连 iPhone 选设备按 ⌘R 安装

免费 Apple ID 安装的 App 7 天过期，重新 ⌘R 即可；长期使用需要付费开发者账号（$99/年），
上架 App Store 同样需要它。

## CI

Actions → **Build iOS** → 填核心版本号：会拉核心网页包并做模拟器编译校验、产出 `.app` 压缩包。
真机安装仍需本地 Xcode 签名（CI 不持有你的签名证书）。

## 约定

- 网页层与数据模型在核心仓；本仓只改壳（`ExPermit/*.swift`、`Info.plist`、工程设置）。
- 想让 iPhone 免安装先用：Safari 打开线上网页版 → 分享 → 添加到主屏幕。
