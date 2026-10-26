#!/bin/bash
# 取核心网页 → 编译 → 装进 iOS 模拟器并启动
# 用法：
#   ./scripts/run-sim.sh                  # 默认用同级 ../expermit-eln 的 dist/
#   ./scripts/run-sim.sh /path/to/core    # 指定核心仓路径
#   SIM_DEVICE="iPhone 16 Pro" ./scripts/run-sim.sh
set -euo pipefail
cd "$(dirname "$0")/.."

CORE="${1:-../expermit-eln}"
node scripts/fetch-www.mjs --core "$CORE"

echo "—— 编译（模拟器）——"
xcodebuild -project ExPermit.xcodeproj -scheme ExPermit -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build

APP="build/Build/Products/Debug-iphonesimulator/ExPermit.app"
if [ -n "${SIM_DEVICE:-}" ]; then
  UDID=$(xcrun simctl list devices available | grep -m1 "$SIM_DEVICE" | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/' || true)
else
  UDID=$(xcrun simctl list devices available | grep -m1 "iPhone" | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/' || true)
fi
if [ -z "${UDID:-}" ]; then
  echo "✗ 没找到可用的 iPhone 模拟器，先在 Xcode → Settings → Platforms 安装 iOS 运行时"
  exit 1
fi

echo "—— 启动模拟器 $UDID ——"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
open -a Simulator --args -CurrentDeviceUDID "$UDID"

echo "—— 安装并启动 ——"
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" com.fengtong.expermit.ios
echo "✓ 已在模拟器运行（改完网页后重跑本脚本即可）"
