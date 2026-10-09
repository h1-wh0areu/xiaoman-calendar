#!/usr/bin/env bash
# package_macos_dmg.sh — 将 .app 打成可分发 DMG
# 用法: ./scripts/package_macos_dmg.sh <App.app> <out.dmg> [volume_name]

set -euo pipefail

APP="${1:?用法: $0 <App.app> <out.dmg> [volume_name]}"
DMG="${2:?需要输出 .dmg 路径}"
VOL="${3:-小满}"

[[ -d "$APP" ]] || { echo "不是 .app 目录: $APP" >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# 尽量生成可双击安装的 UDZO 镜像
hdiutil create \
  -volname "$VOL" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

echo "DMG → $DMG"
