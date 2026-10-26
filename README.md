# ExPermit · iOS 版

ExPermit 实验记录本的 **iOS 壳**。网页层、数据模型、同步协议都在
[expermit-eln](https://github.com/fengtong2001-ui/expermit-eln)，本仓只放 WKWebView 壳与打包流水线。

- 网页资源来自核心仓 Release 的 `www-<ver>.zip`，本仓不复制源码。
- 壳用 `app://local` 协议加载本地网页：IndexedDB、离线、GitHub/WebDAV 同步都能用，数据存在应用自己的沙盒里。
- 与浏览器版、桌面版的数据互不相通；换设备先用「设置与备份」导出/导入，或开多设备同步。

## 本地运行（模拟器）

前提：Xcode（App Store 安装），核心仓已 `npm run build` 生成 `dist/`。

```bash
npm install
node scripts/fetch-www.mjs --core ../expermit-eln   # 或 --ver 0.1.4 从核心 Release 下载
open ExPermit.xcodeproj                             # 选模拟器，⌘R
```

一键编译并装进模拟器：

```bash
./scripts/run-sim.sh                    # 同级核心仓：../expermit-eln
./scripts/run-sim.sh /path/to/core      # 指定核心仓
SIM_DEVICE="iPhone 16 Pro" ./scripts/run-sim.sh
```

## 真机安装（免费 Apple ID 即可）

1. Xcode → Settings → Accounts 添加 Apple ID。
2. 选中 ExPermit 目标 → Signing & Capability → Team 选自己的账号（Bundle ID 已是 `com.fengtong.expermit.ios`，若冲突改后缀即可）。
3. 数据线连 iPhone，选中设备按 ⌘R。

免费账号安装的应用 7 天过期，重新 ⌘R 即可；付费开发者账号（$99/年）可长期使用。

## 发版

GitHub → Actions → **Build iOS** → Run workflow，填核心版本号。产出：

- `ExPermit-simulator-<ver>.zip`：模拟器 App，仅用于校验；
- `ExPermit-unsigned-<ver>.ipa`：未签名真机包，需本地 Xcode / AltStore / Sideloadly 签名安装；
- 手动触发时同时在本仓 Release 发布上述两个文件。

核心仓发布后若 Release 里还没有 `www-<ver>.zip`，先到核心仓 Actions → **Core artifacts** 跑一次。

## 壳里做了什么

| 能力 | 说明 |
|---|---|
| 本地源 | `LocalSchemeHandler` 把 bundle 内 `www/` 挂到 `app://local/`，IndexedDB 正常持久化 |
| 保存 / 导出 | 网页的 `window.expermitMac.saveFile` 同契约注入：备份 zip、实验导出、附件下载都走系统分享面板（可存到「文件」、AirDrop） |
| 打印 | `window.print()` 接到系统打印 |
| 拍照 / 相册 | 已声明相机、相册权限（内容块的拍照与选图） |
| 外链 | http(s)、mailto、tel 交给系统打开 |
| 下载兜底 | 未走桥接的文件链接由 `WKDownloadDelegate` 接住，完成后同样弹分享面板 |
| 局域网 | 已声明本地网络权限（WebDAV 同步） |

## 目录

```
ExPermit.xcodeproj/        Xcode 工程（含共享 scheme）
ExPermit/                  Swift 壳：入口 / WebView / SchemeHandler / 原生桥
ExPermit/www/              核心网页制品（gitignore，fetch 得到）
scripts/fetch-www.mjs      取核心仓 www 制品
scripts/run-sim.sh         一键模拟器运行
.github/workflows/         CI：模拟器编译校验 + 未签名 IPA
```

## 注意

- 本仓不修改网页层；网页问题回核心仓改，改完发核心版本，本仓重新 fetch + 编译。
- `ExPermit/www/` 与 `build/` 不进 git。
- 开发自检（DEBUG）：`xcrun simctl launch <udid> com.fengtong.expermit.ios --selftest`
  会在页面加载完后调一次原生保存桥，弹出分享面板即链路正常。
