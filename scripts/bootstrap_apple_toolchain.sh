#!/usr/bin/env bash
# bootstrap_apple_toolchain.sh — 为本机 Flutter iOS/macOS 构建补齐 Xcode + CocoaPods
#
# 用法：
#   ./scripts/bootstrap_apple_toolchain.sh
#   XCODES_USERNAME=you@icloud.com XCODES_PASSWORD='…' ./scripts/bootstrap_apple_toolchain.sh --auto
#
# --auto：若已安装 xcodes 且提供 Apple ID，则自动下载安装最新正式版 Xcode（需 ~12–15GB 空间）

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTO=0
OPEN_STORE=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto) AUTO=1; shift ;;
    --no-open) OPEN_STORE=0; shift ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

log()  { printf '\n\033[1;36m==>\033[0m %s\n' "$*" >&2; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

has_full_xcode() {
  local p
  p="$(xcode-select -p 2>/dev/null || true)"
  [[ -n "$p" && "$p" != *"CommandLineTools"* ]] && xcodebuild -version >/dev/null 2>&1
}

select_xcode() {
  local app
  for app in /Applications/Xcode.app /Applications/Xcode-*.app; do
    if [[ -d "$app/Contents/Developer" ]]; then
      log "切换 xcode-select → $app"
      sudo xcode-select -s "$app/Contents/Developer"
      sudo xcodebuild -license accept 2>/dev/null || true
      sudo xcodebuild -runFirstLaunch 2>/dev/null || true
      return 0
    fi
  done
  return 1
}

ensure_cocoapods() {
  if command -v pod >/dev/null 2>&1; then
    ok "CocoaPods: $(pod --version 2>/dev/null | tr -d '\n' | head -c 40)"
    return 0
  fi
  if ! command -v brew >/dev/null 2>&1; then
    fail "未找到 Homebrew，无法自动安装 CocoaPods。请先安装 brew 或: sudo gem install cocoapods"
  fi
  log "安装 CocoaPods（brew）…"
  brew install cocoapods
  ok "CocoaPods 已安装"
}

ensure_xcodes_cli() {
  if command -v xcodes >/dev/null 2>&1; then
    return 0
  fi
  command -v brew >/dev/null 2>&1 || return 1
  log "安装 xcodes CLI…"
  brew install xcodes
}

if has_full_xcode; then
  ok "已检测到完整 Xcode: $(xcodebuild -version | head -1)"
  ensure_cocoapods
  echo "就绪。可执行: ./build_all.sh --only flutter"
  exit 0
fi

# 已有 Xcode.app 但未 select
if select_xcode && has_full_xcode; then
  ok "已切换到完整 Xcode: $(xcodebuild -version | head -1)"
  ensure_cocoapods
  echo "就绪。可执行: ./build_all.sh --only flutter"
  exit 0
fi

warn "当前仅为 Command Line Tools，Flutter 无法编译 iOS / macOS。"
ensure_cocoapods || true

if [[ "$AUTO" -eq 1 ]]; then
  if [[ -z "${XCODES_USERNAME:-}" || -z "${XCODES_PASSWORD:-}" ]]; then
    fail "自动安装需要环境变量 XCODES_USERNAME 与 XCODES_PASSWORD（Apple ID）"
  fi
  ensure_xcodes_cli || fail "无法安装 xcodes"
  free_gb="$(df -g / | awk 'NR==2{print $4}')"
  if [[ "${free_gb:-0}" -lt 20 ]]; then
    warn "磁盘可用约 ${free_gb}GB，安装 Xcode 建议 ≥20GB"
  fi
  log "使用 xcodes 安装最新正式版 Xcode（耗时长，需 Apple ID）…"
  xcodes install --latest --experimental-unxip \
    --username "$XCODES_USERNAME" \
    --password "$XCODES_PASSWORD"
  select_xcode || true
  if has_full_xcode; then
    ok "Xcode 安装完成: $(xcodebuild -version | head -1)"
    ensure_cocoapods
    exit 0
  fi
  fail "Xcode 安装后仍不可用，请手动打开 Xcode 完成首次启动"
fi

cat <<EOF

请任选一种方式安装完整 Xcode：

1) App Store（推荐）
   open macappstore://apps.apple.com/app/xcode/id497799835
   安装完成后：
     sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
     sudo xcodebuild -license accept
     ./scripts/bootstrap_apple_toolchain.sh
     ./build_all.sh --only flutter

2) 命令行自动下载（需 Apple ID）
     brew install xcodes
     XCODES_USERNAME=you@icloud.com XCODES_PASSWORD='…' \\
       ./scripts/bootstrap_apple_toolchain.sh --auto

3) 无本机 Xcode 时走 CI（见 .github/workflows/build-native-apps.yml）
     ./scripts/fetch_ci_native_artifacts.sh

仓库路径: $ROOT
EOF

if [[ "$OPEN_STORE" -eq 1 ]]; then
  open "macappstore://apps.apple.com/app/xcode/id497799835" 2>/dev/null || true
fi
exit 2
