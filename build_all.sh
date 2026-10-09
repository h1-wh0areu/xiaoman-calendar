#!/usr/bin/env bash
# build_all.sh — 小满 · 一键编译打包全平台可安装/可部署产物
#
# 产出目录：dist/release/<version>-<timestamp>/
#   xiaoman-api-*.zip          NestJS 可部署包（含生产 node_modules + start.sh）
#   xiaoman-web-*.zip          PC/H5 静态站点（Nginx/CDN）
#   xiaoman-miniprogram-*.zip  微信小程序 dist（导入开发者工具）
#   flutter/android/*.apk      Android 可安装包（缺 SDK 时自动装到 .tools/）
#   flutter/ios/*              ipa 或 Runner.app.zip（需完整 Xcode）
#   flutter/macos/*            .app.zip（需完整 Xcode）
#   flutter/windows/*          Release zip（需 Windows 宿主）
#
# 用法：
#   ./build_all.sh
#   ./build_all.sh --skip-flutter
#   ./build_all.sh --only api,web
#   ./build_all.sh --continue-on-error
#   ./build_all.sh --android-apk --android-aab
#   ./build_all.sh --no-android-sdk-bootstrap
#   ./build_all.sh --bootstrap-xcode          # 缺 Xcode 时引导/自动安装（需 Apple ID 环境变量）
#   ./build_all.sh --fetch-ci                 # 从 GitHub Actions 拉取 iOS/macOS/Windows 产物
#   ./build_all.sh --macos-dmg                # macOS 额外打 DMG
#   FLUTTER_ROOT=~/flutter ./build_all.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

VERSION="$(node -p "require('./package.json').version" 2>/dev/null || echo "0.1.0")"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_ROOT="${OUT_ROOT:-$ROOT/dist/release}"
OUT="$OUT_ROOT/${VERSION}-${STAMP}"
LOG_DIR="$OUT/logs"

SKIP_FLUTTER=0
CONTINUE_ON_ERROR=0
ANDROID_APK=1
ANDROID_AAB=0
IOS_IPA=1
BOOTSTRAP_ANDROID=1
BOOTSTRAP_XCODE=0
FETCH_CI=0
MACOS_DMG=1
ONLY=""
FAILS=()
OKS=()

usage() {
  sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    --skip-flutter) SKIP_FLUTTER=1; shift ;;
    --continue-on-error) CONTINUE_ON_ERROR=1; shift ;;
    --android-apk) ANDROID_APK=1; shift ;;
    --no-android-apk) ANDROID_APK=0; shift ;;
    --android-aab) ANDROID_AAB=1; shift ;;
    --no-ios-ipa) IOS_IPA=0; shift ;;
    --no-android-sdk-bootstrap) BOOTSTRAP_ANDROID=0; shift ;;
    --bootstrap-xcode) BOOTSTRAP_XCODE=1; shift ;;
    --fetch-ci) FETCH_CI=1; shift ;;
    --macos-dmg) MACOS_DMG=1; shift ;;
    --no-macos-dmg) MACOS_DMG=0; shift ;;
    --only) ONLY="$2"; shift 2 ;;
    --out) OUT_ROOT="$2"; OUT="$OUT_ROOT/${VERSION}-${STAMP}"; LOG_DIR="$OUT/logs"; shift 2 ;;
    *) echo "未知参数: $1"; usage ;;
  esac
done

# CocoaPods / Xcode 脚本需要 UTF-8
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

should_build() {
  local name="$1"
  [[ -z "$ONLY" ]] && return 0
  [[ ",$ONLY," == *",$name,"* ]]
}

log()  { printf '\n\033[1;36m==>\033[0m %s\n' "$*" >&2; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*" >&2; OKS+=("$*"); }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*" >&2; }
fail() {
  printf '\033[1;31m✗\033[0m %s\n' "$*" >&2
  FAILS+=("$*")
  if [[ "$CONTINUE_ON_ERROR" -eq 0 ]]; then
    exit 1
  fi
}

run_logged() {
  local name="$1"; shift
  local logfile="$LOG_DIR/${name}.log"
  mkdir -p "$LOG_DIR"
  log "[$name] $*"
  if "$@" >"$logfile" 2>&1; then
    ok "$name"
    return 0
  else
    fail "$name（详见 $logfile）"
    return 1
  fi
}

run_optional() {
  local name="$1"; shift
  local logfile="$LOG_DIR/${name}.log"
  mkdir -p "$LOG_DIR"
  log "[$name] $*"
  if "$@" >"$logfile" 2>&1; then
    ok "$name"
    return 0
  else
    warn "$name 跳过（详见 $logfile）"
    return 1
  fi
}

TOOLS_FLUTTER="${TOOLS_FLUTTER:-$ROOT/.tools/flutter}"
TOOLS_JDK="${TOOLS_JDK:-$ROOT/.tools/jdk}"
TOOLS_ANDROID="${TOOLS_ANDROID:-$ROOT/.tools/android-sdk}"
FLUTTER_MIRROR="${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}"
# Android cmdline-tools / 平台包：优先 Google，失败可改 ANDROID_REPO_URL
# 国内优先腾讯云镜像，失败再回落 Google
ANDROID_REPO_URL="${ANDROID_REPO_URL:-https://mirrors.cloud.tencent.com/AndroidSDK}"
ANDROID_REPO_FALLBACK="${ANDROID_REPO_FALLBACK:-https://dl.google.com/android/repository}"
ANDROID_CMDLINE_ZIP="${ANDROID_CMDLINE_ZIP:-commandlinetools-mac-11076708_latest.zip}"

# ── 工具链探测 / 自动安装 ────────────────────────────────

find_android_home() {
  local roots=(
    "${ANDROID_HOME:-}"
    "${ANDROID_SDK_ROOT:-}"
    "$TOOLS_ANDROID"
    /opt/homebrew/share/android-commandlinetools
    /usr/local/share/android-commandlinetools
    "$HOME/Library/Android/sdk"
    "$HOME/Android/Sdk"
    /usr/local/share/android-sdk
    /opt/android-sdk
  )
  local r
  for r in "${roots[@]}"; do
    if [[ -n "$r" && -d "$r/platform-tools" && -d "$r/platforms" ]]; then
      echo "$r"
      return 0
    fi
  done
  # platform-tools 在 brew cask 单独安装时也可能可用
  for r in "${roots[@]}"; do
    if [[ -n "$r" && -d "$r/platform-tools" ]]; then
      echo "$r"
      return 0
    fi
  done
  return 1
}

has_android_sdk() {
  find_android_home >/dev/null 2>&1
}

# 预下载 Gradle 发行包到 GRADLE_USER_HOME（国内腾讯云镜像，避免 GitHub CDN 极慢）
ensure_gradle_dist() {
  local props="$ROOT/apps/flutter_app/android/gradle/wrapper/gradle-wrapper.properties"
  [[ -f "$props" ]] || return 0
  local url ver zip_name hash_dir dest_dir
  url="$(grep -E '^distributionUrl=' "$props" | sed 's/^distributionUrl=//; s/\\//g')"
  [[ -n "$url" ]] || return 0
  zip_name="$(basename "$url")"
  ver="$(echo "$zip_name" | sed 's/^gradle-//; s/-all\.zip$//; s/-bin\.zip$//')"
  export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$ROOT/.tools/gradle}"
  # wrapper 用 URL 路径的 hash 子目录；与现有 wrapper 实现兼容：扫描已有目录或用固定算法生成
  dest_dir="$(find "$GRADLE_USER_HOME/wrapper/dists" -type d -name "${zip_name%.zip}" -path '*/gradle-*' 2>/dev/null | head -1 || true)"
  if [[ -z "$dest_dir" ]]; then
    # 沿用 Flutter/Gradle wrapper 常见布局：gradle-<ver>-all/<hash>/
    hash_dir="$(find "$GRADLE_USER_HOME/wrapper/dists/gradle-${ver}-all" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1 || true)"
    if [[ -n "$hash_dir" ]]; then
      dest_dir="$hash_dir"
    else
      # 若尚无 hash，先跑一次 wrapper 让它创建目录名；否则用预计算路径（9.3.1-all 常见 hash）
      dest_dir="$GRADLE_USER_HOME/wrapper/dists/gradle-${ver}-all/9ot9r568e8zfvvd4mn8rbu1j0"
    fi
  fi
  mkdir -p "$dest_dir"
  if [[ -x "$dest_dir/gradle-${ver}/bin/gradle" ]]; then
    ok "Gradle ${ver} 已就绪: $dest_dir"
    return 0
  fi
  if [[ ! -f "$dest_dir/$zip_name" ]] || [[ "$(wc -c <"$dest_dir/$zip_name" | tr -d ' ')" -lt 100000000 ]]; then
    local mirror_url="https://mirrors.cloud.tencent.com/gradle/$zip_name"
    log "预下载 Gradle ${ver} ← $mirror_url"
    if ! curl -fL --retry 3 --retry-delay 2 --connect-timeout 30 \
        -o "$dest_dir/$zip_name" "$mirror_url"; then
      warn "腾讯云 Gradle 下载失败，尝试官方源"
      if ! curl -fL --retry 2 --retry-delay 2 -o "$dest_dir/$zip_name" "$url"; then
        return 1
      fi
    fi
  fi
  if [[ ! -d "$dest_dir/gradle-${ver}" ]]; then
    log "解压 Gradle ${ver}…"
    (cd "$dest_dir" && unzip -q -o "$zip_name") || return 1
  fi
  touch "$dest_dir/${zip_name}.ok" 2>/dev/null || true
  ok "Gradle ${ver} 已安装到 $dest_dir"
}

resolve_java_home() {
  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
    if "$JAVA_HOME/bin/java" -version >/dev/null 2>&1; then
      echo "$JAVA_HOME"; return 0
    fi
  fi
  if [[ -x "$TOOLS_JDK/bin/java" ]]; then
    echo "$TOOLS_JDK"; return 0
  fi
  local candidate
  for candidate in \
    /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
    /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home \
    /opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
    /usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
    /usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
  do
    if [[ -x "$candidate/bin/java" ]] && "$candidate/bin/java" -version >/dev/null 2>&1; then
      echo "$candidate"; return 0
    fi
  done
  # macOS java_home helper（需已安装正式 JDK）
  if [[ "$(uname -s)" == "Darwin" ]]; then
    candidate="$(/usr/libexec/java_home 2>/dev/null || true)"
    if [[ -n "$candidate" && -x "$candidate/bin/java" ]]; then
      echo "$candidate"; return 0
    fi
  fi
  return 1
}

ensure_jdk() {
  local home
  if home="$(resolve_java_home)"; then
    if "$home/bin/java" -version >/dev/null 2>&1; then
      echo "$home"
      return 0
    fi
  fi

  log "未检测到可用 JDK，开始自动安装 Temurin 17 → $TOOLS_JDK …"
  mkdir -p "$ROOT/.tools"
  local arch os api_os archive
  case "$(uname -m)" in
    arm64|aarch64) arch="aarch64" ;;
    x86_64|amd64) arch="x64" ;;
    *) fail "不支持的 CPU 架构（JDK）: $(uname -m)"; return 1 ;;
  esac
  case "$(uname -s | tr '[:upper:]' '[:lower:]')" in
    darwin) api_os="mac"; archive="jdk17-mac-${arch}.tar.gz" ;;
    linux) api_os="linux"; archive="jdk17-linux-${arch}.tar.gz" ;;
    *) fail "当前系统不支持自动安装 JDK，请手动设置 JAVA_HOME"; return 1 ;;
  esac

  local url zip_path extract_dir
  url="https://api.adoptium.net/v3/binary/latest/17/ga/${api_os}/${arch}/jdk/hotspot/normal/eclipse?project=jdk"
  zip_path="$ROOT/.tools/${archive}"
  log "下载 Temurin 17: $url"
  if ! curl -fL --retry 3 --retry-delay 2 -o "$zip_path" "$url"; then
    fail "JDK 下载失败，请手动安装 JDK 17 并设置 JAVA_HOME"
    return 1
  fi

  rm -rf "$TOOLS_JDK"
  mkdir -p "$TOOLS_JDK"
  extract_dir="$(mktemp -d)"
  if ! tar -xzf "$zip_path" -C "$extract_dir"; then
    fail "JDK 解压失败"
    rm -rf "$extract_dir"
    return 1
  fi
  # macOS: *.jdk/Contents/Home ；Linux: jdk-17* /
  local found
  found="$(find "$extract_dir" -type f -path '*/bin/java' | head -1 || true)"
  if [[ -z "$found" ]]; then
    fail "解压后未找到 java"
    rm -rf "$extract_dir"
    return 1
  fi
  local jhome
  jhome="$(cd "$(dirname "$found")/.." && pwd)"
  # 整棵 JDK 树挪到 TOOLS_JDK
  rm -rf "$TOOLS_JDK"
  mkdir -p "$(dirname "$TOOLS_JDK")"
  mv "$jhome" "$TOOLS_JDK"
  # 若 mac 包带 Contents/Home，统一成 TOOLS_JDK 即 Home
  if [[ -x "$TOOLS_JDK/Contents/Home/bin/java" ]]; then
    local real="$TOOLS_JDK/Contents/Home"
    local tmp_move="$ROOT/.tools/jdk-home-tmp"
    rm -rf "$tmp_move"
    mv "$real" "$tmp_move"
    rm -rf "$TOOLS_JDK"
    mv "$tmp_move" "$TOOLS_JDK"
  fi
  rm -rf "$extract_dir"

  if [[ ! -x "$TOOLS_JDK/bin/java" ]]; then
    fail "JDK 安装后不可用: $TOOLS_JDK"
    return 1
  fi
  ok "JDK 已安装: $TOOLS_JDK ($("$TOOLS_JDK/bin/java" -version 2>&1 | head -1))"
  echo "$TOOLS_JDK"
}

ensure_android_sdk() {
  local home
  if home="$(find_android_home)"; then
    echo "$home"
    return 0
  fi
  if [[ "$BOOTSTRAP_ANDROID" -eq 0 ]]; then
    return 1
  fi

  log "未检测到 Android SDK，开始自动安装到 $TOOLS_ANDROID …"
  local jhome
  if ! jhome="$(ensure_jdk)"; then
    fail "安装 Android SDK 需要 JDK"
    return 1
  fi
  export JAVA_HOME="$jhome"
  export PATH="$JAVA_HOME/bin:$PATH"

  mkdir -p "$TOOLS_ANDROID/cmdline-tools"
  local zip_name="$ANDROID_CMDLINE_ZIP"
  # 非 mac 宿主换 zip 名
  case "$(uname -s | tr '[:upper:]' '[:lower:]')" in
    linux) zip_name="${ANDROID_CMDLINE_ZIP/mac/linux}" ;;
  esac
  local zip_path="$ROOT/.tools/$zip_name"
  local url="$ANDROID_REPO_URL/$zip_name"
  log "下载 Android cmdline-tools: $url"
  if ! curl -fL --retry 3 --retry-delay 2 --connect-timeout 30 -o "$zip_path" "$url"; then
    warn "主镜像失败，回落: $ANDROID_REPO_FALLBACK/$zip_name"
    if ! curl -fL --retry 3 --retry-delay 2 --connect-timeout 30 \
        -o "$zip_path" "$ANDROID_REPO_FALLBACK/$zip_name"; then
      fail "Android cmdline-tools 下载失败"
      return 1
    fi
  fi

  local tmp
  tmp="$(mktemp -d)"
  if ! unzip -q "$zip_path" -d "$tmp"; then
    fail "解压 cmdline-tools 失败"
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$TOOLS_ANDROID/cmdline-tools/latest"
  mkdir -p "$TOOLS_ANDROID/cmdline-tools"
  if [[ -d "$tmp/cmdline-tools" ]]; then
    mv "$tmp/cmdline-tools" "$TOOLS_ANDROID/cmdline-tools/latest"
  else
    # 某些包直接是 bin/lib
    mkdir -p "$TOOLS_ANDROID/cmdline-tools/latest"
    mv "$tmp"/* "$TOOLS_ANDROID/cmdline-tools/latest/" 2>/dev/null || true
  fi
  rm -rf "$tmp"

  local sdkmanager="$TOOLS_ANDROID/cmdline-tools/latest/bin/sdkmanager"
  if [[ ! -x "$sdkmanager" ]]; then
    fail "未找到 sdkmanager: $sdkmanager"
    return 1
  fi

  export ANDROID_HOME="$TOOLS_ANDROID"
  export ANDROID_SDK_ROOT="$TOOLS_ANDROID"

  log "sdkmanager 安装 platform-tools / platforms / build-tools …"
  # 接受许可证 + 安装构建所需组件
  yes | "$sdkmanager" --sdk_root="$TOOLS_ANDROID" --licenses >/dev/null 2>&1 || true
  if ! "$sdkmanager" --sdk_root="$TOOLS_ANDROID" \
      "platform-tools" \
      "platforms;android-35" \
      "platforms;android-34" \
      "build-tools;35.0.0" \
      "build-tools;34.0.0" \
      >"$LOG_DIR/android-sdkmanager.log" 2>&1; then
    fail "sdkmanager 安装组件失败（详见 $LOG_DIR/android-sdkmanager.log）"
    return 1
  fi

  if [[ ! -d "$TOOLS_ANDROID/platform-tools" ]]; then
    fail "Android SDK 安装不完整"
    return 1
  fi
  ok "Android SDK 已安装: $TOOLS_ANDROID"
  echo "$TOOLS_ANDROID"
}

resolve_flutter() {
  if [[ -n "${FLUTTER_BIN:-}" && -x "$FLUTTER_BIN" ]]; then
    echo "$FLUTTER_BIN"; return 0
  fi
  if command -v flutter >/dev/null 2>&1; then
    command -v flutter; return 0
  fi
  for candidate in \
    "$TOOLS_FLUTTER/bin/flutter" \
    "${FLUTTER_ROOT:-}/bin/flutter" \
    "$HOME/flutter/bin/flutter" \
    "$HOME/development/flutter/bin/flutter" \
    /opt/homebrew/Caskroom/flutter/*/flutter/bin/flutter
  do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"; return 0
    fi
  done
  return 1
}

ensure_flutter() {
  local bin
  if bin="$(resolve_flutter)"; then
    echo "$bin"
    return 0
  fi

  log "未检测到 Flutter SDK，开始自动安装到 $TOOLS_FLUTTER …"
  mkdir -p "$ROOT/.tools"
  local arch os_key archive zip_name zip_path releases_json

  case "$(uname -m)" in
    arm64|aarch64) arch="arm64" ;;
    x86_64|amd64) arch="x64" ;;
    *) fail "不支持的 CPU 架构: $(uname -m)"; return 1 ;;
  esac

  local host="${HOST_OS:-$(uname -s | tr '[:upper:]' '[:lower:]')}"
  case "$host" in
    darwin) os_key="macos" ;;
    linux) os_key="linux" ;;
    mingw*|msys*|cygwin*) os_key="windows" ;;
    *) fail "不支持的宿主系统: $host"; return 1 ;;
  esac

  releases_json="$(mktemp)"
  if ! curl -fsSL "$FLUTTER_MIRROR/flutter_infra_release/releases/releases_${os_key}.json" -o "$releases_json"; then
    fail "无法拉取 Flutter 发布列表（镜像: $FLUTTER_MIRROR）"
    rm -f "$releases_json"
    return 1
  fi

  archive="$(python3 - "$releases_json" "$arch" <<'PY'
import json, sys
path, arch = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f:
    d = json.load(f)
h = d["current_release"]["stable"]
for r in d["releases"]:
    if r.get("hash") != h or r.get("channel") != "stable":
        continue
    a = r.get("archive", "")
    if arch == "arm64" and "arm64" in a:
        print(a); raise SystemExit(0)
    if arch == "x64" and "arm64" not in a:
        print(a); raise SystemExit(0)
for r in d["releases"]:
    if r.get("hash") == h:
        print(r["archive"]); raise SystemExit(0)
raise SystemExit("no archive")
PY
)" || {
    fail "解析 Flutter 发布列表失败"
    rm -f "$releases_json"
    return 1
  }
  rm -f "$releases_json"

  zip_name="$(basename "$archive")"
  zip_path="$ROOT/.tools/$zip_name"
  log "下载 $FLUTTER_MIRROR/flutter_infra_release/releases/$archive"
  if ! curl -fL --retry 3 --retry-delay 2 \
      -o "$zip_path" \
      "$FLUTTER_MIRROR/flutter_infra_release/releases/$archive"; then
    fail "Flutter SDK 下载失败。可手动设置 FLUTTER_ROOT，或改用: ./build_all.sh --skip-flutter"
    return 1
  fi

  rm -rf "$TOOLS_FLUTTER"
  log "解压 Flutter SDK…"
  if ! unzip -q "$zip_path" -d "$ROOT/.tools"; then
    fail "解压 Flutter SDK 失败"
    return 1
  fi
  if [[ ! -x "$TOOLS_FLUTTER/bin/flutter" ]]; then
    fail "解压后未找到 $TOOLS_FLUTTER/bin/flutter"
    return 1
  fi

  export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"
  export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-$FLUTTER_MIRROR}"

  log "执行 flutter precache（首次较慢）…"
  if ! "$TOOLS_FLUTTER/bin/flutter" precache --no-android --no-ios >/dev/null 2>&1; then
    "$TOOLS_FLUTTER/bin/flutter" --version >/dev/null 2>&1 || true
  fi

  ok "Flutter 已安装: $TOOLS_FLUTTER"
  echo "$TOOLS_FLUTTER/bin/flutter"
}

has_full_xcode() {
  local p
  p="$(xcode-select -p 2>/dev/null || true)"
  [[ -n "$p" && "$p" != *"CommandLineTools"* ]] && xcodebuild -version >/dev/null 2>&1
}

ensure_xcode() {
  if has_full_xcode; then
    ok "Xcode: $(xcodebuild -version 2>/dev/null | head -1)"
    return 0
  fi
  # 已安装但未 select
  local app
  for app in /Applications/Xcode.app /Applications/Xcode-*.app; do
    if [[ -d "${app}/Contents/Developer" ]]; then
      log "检测到 $app，尝试 xcode-select…"
      if sudo -n xcode-select -s "$app/Contents/Developer" 2>/dev/null \
        || xcode-select -s "$app/Contents/Developer" 2>/dev/null; then
        sudo -n xcodebuild -license accept 2>/dev/null || true
        sudo -n xcodebuild -runFirstLaunch 2>/dev/null || true
        if has_full_xcode; then
          ok "已切换 Xcode: $(xcodebuild -version 2>/dev/null | head -1)"
          return 0
        fi
      fi
    fi
  done

  if [[ "$BOOTSTRAP_XCODE" -eq 1 ]]; then
    log "尝试 bootstrap Apple 工具链…"
    if [[ -x "$ROOT/scripts/bootstrap_apple_toolchain.sh" ]]; then
      if [[ -n "${XCODES_USERNAME:-}" && -n "${XCODES_PASSWORD:-}" ]]; then
        "$ROOT/scripts/bootstrap_apple_toolchain.sh" --auto --no-open || true
      else
        "$ROOT/scripts/bootstrap_apple_toolchain.sh" --no-open || true
      fi
    fi
    if has_full_xcode; then
      return 0
    fi
  fi
  return 1
}

ensure_cocoapods() {
  export LANG="${LANG:-en_US.UTF-8}"
  export LC_ALL="${LC_ALL:-en_US.UTF-8}"
  if command -v pod >/dev/null 2>&1; then
    ok "CocoaPods: $(pod --version 2>/dev/null | head -1)"
    return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    log "安装 CocoaPods…"
    brew install cocoapods >/dev/null 2>&1 || brew install cocoapods
  fi
  if command -v pod >/dev/null 2>&1; then
    ok "CocoaPods 已就绪"
    return 0
  fi
  warn "CocoaPods 未安装，iOS/macOS pod install 可能失败"
  return 1
}

package_macos_artifacts() {
  local app_path="$1"
  local dest_dir="$2"
  mkdir -p "$dest_dir"
  rm -rf "$dest_dir/xiaoman.app"
  cp -R "$app_path" "$dest_dir/xiaoman.app"
  ditto -c -k --sequesterRsrc --keepParent \
    "$dest_dir/xiaoman.app" \
    "$dest_dir/xiaoman-${VERSION}-macos.app.zip"
  ok "macOS App → flutter/macos/xiaoman-${VERSION}-macos.app.zip"

  if [[ "$MACOS_DMG" -eq 1 ]]; then
    if [[ -x "$ROOT/scripts/package_macos_dmg.sh" ]]; then
      if "$ROOT/scripts/package_macos_dmg.sh" \
          "$dest_dir/xiaoman.app" \
          "$dest_dir/xiaoman-${VERSION}-macos.dmg" \
          "小满" >"$LOG_DIR/macos-dmg.log" 2>&1; then
        ok "macOS DMG → flutter/macos/xiaoman-${VERSION}-macos.dmg"
      else
        warn "DMG 打包失败（详见 $LOG_DIR/macos-dmg.log）"
      fi
    fi
  fi

  cat >"$dest_dir/INSTALL.md" <<EOF
# macOS 安装

## 方式 A：App 压缩包
解压 \`xiaoman-${VERSION}-macos.app.zip\`，将 \`xiaoman.app\` 拖到「应用程序」。

## 方式 B：DMG
打开 \`xiaoman-${VERSION}-macos.dmg\`，拖入 Applications。

首次打开若提示未签名：系统设置 → 隐私与安全性 → 仍要打开。
EOF
}

HOST_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
mkdir -p "$OUT" "$LOG_DIR"

cat >"$OUT/BUILD_INFO.txt" <<EOF
product: xiaoman (小满 · 日程分身)
version: $VERSION
built_at: $(date -Iseconds)
host: $HOST_OS $(uname -m)
node: $(node -v 2>/dev/null || echo n/a)
pnpm: $(pnpm -v 2>/dev/null || echo n/a)
flutter: $(resolve_flutter 2>/dev/null || echo 'not found')
java: $(resolve_java_home 2>/dev/null || echo 'not found')
android_sdk: $(find_android_home 2>/dev/null || echo 'not found')
only: ${ONLY:-all}
EOF

log "输出目录: $OUT"

# ── 0. 依赖 ──────────────────────────────────────────────
if should_build deps || should_build api || should_build web || should_build miniprogram || should_build core; then
  if ! command -v pnpm >/dev/null 2>&1; then
    fail "未找到 pnpm，请先安装: corepack enable && corepack prepare pnpm@9.15.0 --activate"
  else
    mkdir -p "$LOG_DIR"
    log "[deps] pnpm install"
    if pnpm install --frozen-lockfile >"$LOG_DIR/deps.log" 2>&1 || pnpm install >>"$LOG_DIR/deps.log" 2>&1; then
      ok "deps"
    else
      fail "deps（详见 $LOG_DIR/deps.log）"
    fi
  fi
fi

# ── 1. 共享引擎测试（可选门禁） ──────────────────────────
if should_build core || should_build test; then
  run_logged core-test pnpm --filter @xiaoman/core test || true
fi

# ── 2. API（可独立部署：dist + @xiaoman/core + 生产依赖） ─
package_api() {
  local stage="$OUT/api"
  rm -rf "$stage"
  mkdir -p "$stage/dist" "$stage/vendor/xiaoman-core" "$LOG_DIR"

  log "编译 @xiaoman/core → CJS（部署用）"
  if ! (cd "$ROOT/packages/core" && pnpm exec tsc -p tsconfig.build.json) \
      >"$LOG_DIR/core-build.log" 2>&1; then
    fail "core 编译失败（详见 $LOG_DIR/core-build.log）"
    return 1
  fi

  cp -R "$ROOT/packages/core/dist/." "$stage/vendor/xiaoman-core/"
  cat >"$stage/vendor/xiaoman-core/package.json" <<EOF
{
  "name": "@xiaoman/core",
  "version": "$VERSION",
  "main": "index.js",
  "types": "index.d.ts"
}
EOF

  cp -R "$ROOT/apps/api/dist/." "$stage/dist/"

  # 生成可独立 npm install 的 package.json（workspace → file:）
  python3 - "$ROOT/apps/api/package.json" "$stage/package.json" "$VERSION" <<'PY'
import json, sys
src, dst, ver = sys.argv[1], sys.argv[2], sys.argv[3]
with open(src, encoding="utf-8") as f:
    pkg = json.load(f)
deps = dict(pkg.get("dependencies") or {})
deps["@xiaoman/core"] = "file:./vendor/xiaoman-core"
out = {
    "name": "xiaoman-api",
    "version": ver,
    "private": True,
    "main": "dist/main.js",
    "scripts": {"start": "node dist/main.js"},
    "dependencies": deps,
    "engines": {"node": ">=20"},
}
with open(dst, "w", encoding="utf-8") as f:
    json.dump(out, f, indent=2)
    f.write("\n")
PY

  if [[ ! -f "$stage/package.json" ]]; then
    fail "未生成 API package.json"
    return 1
  fi

  log "安装 API 生产依赖…"
  if ! (cd "$stage" && npm install --omit=dev --no-fund --no-audit) \
      >"$LOG_DIR/api-npm-install.log" 2>&1; then
    fail "API npm install 失败（详见 $LOG_DIR/api-npm-install.log）"
    return 1
  fi

  cat >"$stage/start.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export PORT="${PORT:-3000}"
exec node dist/main.js
EOF
  chmod +x "$stage/start.sh"

  cat >"$stage/README.md" <<EOF
# Xiaoman API（可部署包）

## 运行

\`\`\`bash
# 需要 Node.js >= 20
./start.sh
# 或
PORT=3000 node dist/main.js
\`\`\`

- 健康检查：\`GET /v1/health\`
- 开发验证码：\`000000\`
- 默认端口：\`3000\`（可用 \`PORT\` 覆盖）
EOF

  # 冒烟：能否加载入口（不长期监听）
  if ! (cd "$stage" && node -e "require('./dist/app.module.js'); console.log('api-load-ok')") \
      >"$LOG_DIR/api-smoke.log" 2>&1; then
    warn "API 冒烟加载失败（详见 $LOG_DIR/api-smoke.log），仍继续打包"
  else
    ok "API 冒烟加载通过"
  fi

  (cd "$OUT" && zip -qr "xiaoman-api-${VERSION}.zip" api)
  ok "api 已打包 → xiaoman-api-${VERSION}.zip"
}

if should_build api; then
  if run_logged api pnpm --filter @xiaoman/api build; then
    package_api || fail "api 打包失败"
  fi
fi

# ── 3. Web（PC / H5） ────────────────────────────────────
if should_build web; then
  if run_logged web pnpm --filter @xiaoman/web build; then
    mkdir -p "$OUT/web"
    rsync -a --delete apps/web/dist/ "$OUT/web/" 2>/dev/null || cp -R apps/web/dist/. "$OUT/web/"
    cat >"$OUT/web/README.md" <<'EOF'
# Xiaoman Web

将本目录内容部署到任意静态服务器（Nginx / CDN / GitHub Pages）。

示例 Nginx：
```
root /var/www/xiaoman;
try_files $uri $uri/ /index.html;
```
EOF
    (cd "$OUT" && zip -qr "xiaoman-web-${VERSION}.zip" web)
    ok "web 已打包 → xiaoman-web-${VERSION}.zip"
  fi
fi

# ── 4. 微信小程序 ────────────────────────────────────────
package_miniprogram() {
  mkdir -p "$OUT/miniprogram"
  if [[ -d apps/miniprogram/dist ]] && [[ -n "$(ls -A apps/miniprogram/dist 2>/dev/null)" ]]; then
    rsync -a --delete apps/miniprogram/dist/ "$OUT/miniprogram/" 2>/dev/null \
      || cp -R apps/miniprogram/dist/. "$OUT/miniprogram/"
  else
    warn "miniprogram dist 为空，打包 Taro 源码工程作为回退产物"
    rsync -a --delete \
      --exclude node_modules --exclude dist \
      apps/miniprogram/ "$OUT/miniprogram-src/"
    cat >"$OUT/miniprogram/README.md" <<'EOF'
Taro 编译产物未生成。请在仓库执行：

```bash
pnpm --filter @xiaoman/miniprogram build:weapp
```

或用微信开发者工具打开 `miniprogram-src/` 后本地编译。
EOF
  fi
  cp apps/miniprogram/project.config.json "$OUT/miniprogram/" 2>/dev/null || true
  cat >"$OUT/miniprogram/INSTALL.md" <<'EOF'
# 安装 / 导入

1. 打开微信开发者工具 → 导入项目
2. 目录选择本 `miniprogram/` 文件夹
3. 关闭域名校验（开发阶段）
4. 确保 API 已启动（默认 http://localhost:3000）
EOF
  (cd "$OUT" && zip -qr "xiaoman-miniprogram-${VERSION}.zip" miniprogram)
  [[ -d "$OUT/miniprogram-src" ]] && (cd "$OUT" && zip -qr "xiaoman-miniprogram-src-${VERSION}.zip" miniprogram-src)
  ok "miniprogram 已打包 → xiaoman-miniprogram-${VERSION}.zip"
}

if should_build miniprogram; then
  if run_logged miniprogram pnpm --filter @xiaoman/miniprogram build:weapp; then
    package_miniprogram
  else
    warn "Taro 构建失败，启用源码回退打包"
    package_miniprogram || fail "miniprogram 打包失败"
  fi
fi

# ── 5. Flutter 多端 App ──────────────────────────────────
build_flutter_apps() {
  local flutter_bin
  if ! flutter_bin="$(ensure_flutter)"; then
    fail "Flutter SDK 不可用。可设置 FLUTTER_ROOT / FLUTTER_BIN，或使用 --skip-flutter"
    return 1
  fi
  if [[ ! -x "$flutter_bin" ]]; then
    fail "Flutter 路径无效: $flutter_bin"
    return 1
  fi
  ok "使用 Flutter: $flutter_bin"
  export PATH="$(dirname "$flutter_bin"):$PATH"
  export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"
  export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-$FLUTTER_MIRROR}"
  # 避免 analytics 写 ~/.dart-tool 失败导致整条命令崩溃
  export CI=true
  export FLUTTER_SUPPRESS_ANALYTICS=true
  mkdir -p "${HOME}/.dart-tool" 2>/dev/null || true
  "$flutter_bin" config --no-analytics >/dev/null 2>&1 || true

  # Flutter 子步骤失败不退出整脚本（Node 产物已打好）
  local _prev_continue="$CONTINUE_ON_ERROR"
  CONTINUE_ON_ERROR=1

  local app_dir="$ROOT/apps/flutter_app"
  pushd "$app_dir" >/dev/null

  local need_create=0
  [[ ! -d android || ! -d ios || ! -d macos || ! -d windows ]] && need_create=1
  if [[ "$need_create" -eq 1 ]]; then
    run_logged flutter-create \
      "$flutter_bin" create . --project-name xiaoman --platforms=ios,android,macos,windows \
      || true
  fi

  if ! run_logged flutter-pub "$flutter_bin" pub get; then
    CONTINUE_ON_ERROR="$_prev_continue"
    popd >/dev/null
    return 1
  fi

  mkdir -p "$OUT/flutter/android" "$OUT/flutter/ios" "$OUT/flutter/macos" "$OUT/flutter/windows"

  # Android：自动补齐 JDK + SDK 后打 APK
  if [[ "$ANDROID_APK" -eq 1 || "$ANDROID_AAB" -eq 1 ]]; then
    local android_home jhome
    android_home="$(find_android_home 2>/dev/null || true)"
    if [[ -z "${android_home:-}" ]]; then
      if android_home="$(ensure_android_sdk)"; then
        :
      else
        warn "Android SDK 不可用，跳过 APK/AAB"
        echo "自动安装失败时：安装 Android Studio 或设置 ANDROID_HOME，再执行 ./build_all.sh --only flutter" \
          >"$OUT/flutter/android/README.txt"
        android_home=""
      fi
    fi
    if [[ -n "${android_home:-}" ]]; then
      if ! jhome="$(ensure_jdk)"; then
        warn "JDK 不可用，跳过 Android 打包"
      else
        export JAVA_HOME="$jhome"
        export ANDROID_HOME="$android_home"
        export ANDROID_SDK_ROOT="$android_home"
        export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
        # 避开 Cursor sandbox 的 Gradle 缓存锁；预置国内 Gradle 发行包
        export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$ROOT/.tools/gradle}"
        mkdir -p "$GRADLE_USER_HOME"
        ensure_gradle_dist || warn "Gradle 发行包预置失败，将改由 wrapper 自行下载"
        # Flutter includeBuild：注入阿里云（勿用 init.gradle 改 repositoriesMode，会与 Flutter 冲突）
        local ft_settings="$TOOLS_FLUTTER/packages/flutter_tools/gradle/settings.gradle.kts"
        if [[ -f "$ft_settings" ]] && ! grep -q 'maven.aliyun.com' "$ft_settings"; then
          cat >"$ft_settings" <<'FTS'
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        maven(url = "https://maven.aliyun.com/repository/google")
        maven(url = "https://maven.aliyun.com/repository/central")
        maven(url = "https://maven.aliyun.com/repository/public")
        maven(url = "https://maven.aliyun.com/repository/gradle-plugin")
    }
}
FTS
        fi
        rm -f "$GRADLE_USER_HOME/init.gradle"
        printf 'sdk.dir=%s\nflutter.sdk=%s\n' "$android_home" "$(cd "$(dirname "$flutter_bin")/.." && pwd)" >android/local.properties

        if [[ "$ANDROID_APK" -eq 1 ]]; then
          if run_optional flutter-android-apk \
              "$flutter_bin" build apk --release; then
            local apk
            apk="$(find build/app/outputs/flutter-apk -name '*.apk' 2>/dev/null | head -1 || true)"
            if [[ -n "$apk" ]]; then
              cp "$apk" "$OUT/flutter/android/xiaoman-${VERSION}.apk"
              ok "Android APK → flutter/android/xiaoman-${VERSION}.apk"
              cat >"$OUT/flutter/android/INSTALL.md" <<EOF
# Android 安装

\`\`\`bash
adb install -r xiaoman-${VERSION}.apk
\`\`\`

或将 APK 传到手机后直接打开安装。
EOF
            else
              warn "Android APK 产物未找到"
            fi
          fi
        fi

        if [[ "$ANDROID_AAB" -eq 1 ]]; then
          if run_optional flutter-android-aab "$flutter_bin" build appbundle --release; then
            local aab
            aab="$(find build/app/outputs/bundle -name '*.aab' 2>/dev/null | head -1 || true)"
            if [[ -n "$aab" ]]; then
              cp "$aab" "$OUT/flutter/android/xiaoman-${VERSION}.aab"
              ok "Android AAB → flutter/android/xiaoman-${VERSION}.aab"
            fi
          fi
        fi
      fi
    fi
  fi

  # iOS / macOS（需完整 Xcode + CocoaPods）
  if [[ "$HOST_OS" == "darwin" ]]; then
    if ensure_xcode; then
      ensure_cocoapods || true
      # 确保平台工程完整
      if [[ ! -f ios/Runner.xcodeproj/project.pbxproj || ! -f macos/Runner.xcodeproj/project.pbxproj ]]; then
        run_optional flutter-create-apple \
          "$flutter_bin" create . --project-name xiaoman --platforms=ios,macos || true
      fi

      if [[ "$IOS_IPA" -eq 1 ]]; then
        # 先无签名构建（始终可产出可安装到模拟器/企业侧载前的 .app）
        if run_optional flutter-ios-app "$flutter_bin" build ios --release --no-codesign; then
          if [[ -d build/ios/iphoneos/Runner.app ]]; then
            ditto -c -k --sequesterRsrc --keepParent \
              build/ios/iphoneos/Runner.app \
              "$OUT/flutter/ios/xiaoman-${VERSION}-Runner.app.zip"
            ok "iOS Runner.app → flutter/ios/xiaoman-${VERSION}-Runner.app.zip"
            cat >"$OUT/flutter/ios/INSTALL.md" <<EOF
# iOS 安装

## 未签名 Runner.app（本包）
\`xiaoman-${VERSION}-Runner.app.zip\` 需用 Xcode 签名后装到设备，或用于模拟器。

## IPA（有开发者证书时）
本机执行：
\`\`\`bash
cd apps/flutter_app && flutter build ipa --release
\`\`\`
或配置 Apple 证书后重跑 \`./build_all.sh --only flutter\`。
EOF
          fi
        fi
        # 有证书时额外打 ipa
        if run_optional flutter-ios-ipa "$flutter_bin" build ipa --release --no-tree-shake-icons; then
          local ipa
          ipa="$(find build/ios/ipa -name '*.ipa' 2>/dev/null | head -1 || true)"
          if [[ -n "$ipa" ]]; then
            cp "$ipa" "$OUT/flutter/ios/xiaoman-${VERSION}.ipa"
            ok "iOS IPA → flutter/ios/xiaoman-${VERSION}.ipa"
          fi
        else
          warn "ipa 未生成（通常缺少签名证书）；已保留 Runner.app.zip"
        fi
      fi

      if run_optional flutter-macos "$flutter_bin" build macos --release; then
        local app_path="build/macos/Build/Products/Release/xiaoman.app"
        [[ -d "$app_path" ]] || app_path="build/macos/Build/Products/Release/Runner.app"
        if [[ ! -d "$app_path" ]]; then
          app_path="$(find build/macos/Build/Products/Release -maxdepth 1 -name '*.app' | head -1 || true)"
        fi
        if [[ -n "${app_path:-}" && -d "$app_path" ]]; then
          package_macos_artifacts "$app_path" "$OUT/flutter/macos"
        else
          warn "macOS .app 产物未找到"
        fi
      fi
    else
      warn "未安装完整 Xcode，跳过本机 iOS / macOS 打包"
      mkdir -p "$OUT/flutter/ios" "$OUT/flutter/macos"
      cat >"$OUT/flutter/ios/README.txt" <<'EOF'
本机缺少完整 Xcode（仅有 Command Line Tools），无法编译 iOS。

## 方案 A：安装 Xcode 后本机构建
  ./scripts/bootstrap_apple_toolchain.sh
  # 或带 Apple ID 自动下载：
  # XCODES_USERNAME=… XCODES_PASSWORD=… ./scripts/bootstrap_apple_toolchain.sh --auto
  ./build_all.sh --only flutter --bootstrap-xcode

产物：flutter/ios/*.ipa 或 *-Runner.app.zip

## 方案 B：GitHub Actions（推荐，无需本机 Xcode）
  1. 将仓库推送到 GitHub
  2. gh workflow run build-native-apps.yml
  3. ./scripts/fetch_ci_native_artifacts.sh
  或：./build_all.sh --only flutter --fetch-ci
EOF
      cat >"$OUT/flutter/macos/README.txt" <<'EOF'
本机缺少完整 Xcode，无法编译 macOS App。

## 方案 A：本机
  ./scripts/bootstrap_apple_toolchain.sh
  ./build_all.sh --only flutter

产物：flutter/macos/*-macos.app.zip 与 *.dmg

## 方案 B：CI
  gh workflow run build-native-apps.yml
  ./scripts/fetch_ci_native_artifacts.sh
EOF
    fi
  else
    warn "非 macOS 宿主，跳过 iOS / macOS 打包（请用 GitHub Actions macos runner）"
    mkdir -p "$OUT/flutter/ios" "$OUT/flutter/macos"
    cat >"$OUT/flutter/ios/README.txt" <<'EOF'
请在 macOS + Xcode 上构建，或使用 CI：
  gh workflow run build-native-apps.yml
  ./scripts/fetch_ci_native_artifacts.sh
EOF
    cp "$OUT/flutter/ios/README.txt" "$OUT/flutter/macos/README.txt"
  fi

  # Windows（不可在 macOS/Linux 交叉编译）
  if [[ "$HOST_OS" == mingw* || "$HOST_OS" == msys* || "$HOST_OS" == cygwin* || "$HOST_OS" == windows* ]]; then
    if [[ ! -f windows/CMakeLists.txt ]]; then
      run_optional flutter-create-windows \
        "$flutter_bin" create . --project-name xiaoman --platforms=windows || true
    fi
    if run_optional flutter-windows "$flutter_bin" build windows --release; then
      local win_dir="build/windows/x64/runner/Release"
      [[ -d "$win_dir" ]] || win_dir="build/windows/runner/Release"
      if [[ -d "$win_dir" ]]; then
        (cd "$win_dir" && zip -qr "$OUT/flutter/windows/xiaoman-${VERSION}-windows.zip" .)
        ok "Windows → flutter/windows/xiaoman-${VERSION}-windows.zip"
        cat >"$OUT/flutter/windows/INSTALL.md" <<EOF
# Windows 安装

1. 解压 \`xiaoman-${VERSION}-windows.zip\`
2. 运行 \`xiaoman.exe\`（或 \`Runner.exe\`）
EOF
      fi
    fi
  else
    warn "当前非 Windows 宿主：无法本机交叉编译 Windows（请用 CI windows-latest）"
    mkdir -p "$OUT/flutter/windows"
    cat >"$OUT/flutter/windows/README.txt" <<'EOF'
Flutter Windows 桌面必须在 Windows 上编译。

## 本机（Windows）
  ./build_all.sh --only flutter

## CI（推荐）
  gh workflow run build-native-apps.yml
  ./scripts/fetch_ci_native_artifacts.sh
  # 或
  ./build_all.sh --only flutter --fetch-ci

产物：flutter/windows/xiaoman-*-windows.zip（含 xiaoman.exe）
EOF
  fi

  # 可选：从 CI 拉取缺失的原生包
  if [[ "$FETCH_CI" -eq 1 ]]; then
    log "从 GitHub Actions 拉取 iOS/macOS/Windows 产物…"
    if [[ -x "$ROOT/scripts/fetch_ci_native_artifacts.sh" ]]; then
      if "$ROOT/scripts/fetch_ci_native_artifacts.sh" --out "$OUT/flutter" \
          >"$LOG_DIR/fetch-ci.log" 2>&1; then
        ok "CI 产物已合并到 flutter/{ios,macos,windows}"
      else
        warn "拉取 CI 产物失败（详见 $LOG_DIR/fetch-ci.log）。需先 push 并跑通 build-native-apps.yml"
      fi
    fi
  fi

  popd >/dev/null
  CONTINUE_ON_ERROR="$_prev_continue"

  if [[ -d "$OUT/flutter" ]]; then
    (cd "$OUT" && zip -qr "xiaoman-flutter-apps-${VERSION}.zip" flutter)
    ok "Flutter 汇总包 → xiaoman-flutter-apps-${VERSION}.zip"
  fi
}

if [[ "$SKIP_FLUTTER" -eq 0 ]] && should_build flutter; then
  build_flutter_apps || true
elif [[ "$SKIP_FLUTTER" -eq 1 ]]; then
  warn "已跳过 Flutter（--skip-flutter）"
fi

# ── 6. 安装说明 + 清单 ───────────────────────────────────
log "生成 INSTALL.md 与清单"
{
  echo "# 小满 ${VERSION} 安装 / 部署指南"
  echo
  echo "构建时间：$(date -Iseconds) · 宿主：${HOST_OS} $(uname -m)"
  echo
  echo "| 产物 | 文件 | 说明 |"
  echo "|---|---|---|"
  echo "| API | \`xiaoman-api-${VERSION}.zip\` | 解压后 \`./start.sh\`（Node ≥ 20） |"
  echo "| Web | \`xiaoman-web-${VERSION}.zip\` | 静态资源，部署到 Nginx/CDN |"
  echo "| 小程序 | \`xiaoman-miniprogram-${VERSION}.zip\` | 微信开发者工具导入 |"
  echo "| Android | \`flutter/android/xiaoman-${VERSION}.apk\` | \`adb install -r\` 或手机直接安装 |"
  echo "| iOS | \`flutter/ios/*.ipa\` 或 \`*-Runner.app.zip\` | 需 Xcode；无证书时为未签名包 |"
  echo "| macOS | \`flutter/macos/*-macos.app.zip\` / \`*.dmg\` | 解压或打开 DMG 拖入「应用程序」 |"
  echo "| Windows | \`flutter/windows/*-windows.zip\` | 解压运行 \`xiaoman.exe\`（需 Windows / CI） |"
  echo
  echo "## 本机缺 Xcode / Windows 时"
  echo
  echo '```bash'
  echo './scripts/bootstrap_apple_toolchain.sh   # 安装/引导 Xcode + CocoaPods'
  echo 'gh workflow run build-native-apps.yml    # CI 打 iOS/macOS/Windows'
  echo './scripts/fetch_ci_native_artifacts.sh   # 拉取 CI 产物到 dist/release/latest/flutter'
  echo './build_all.sh --only flutter --fetch-ci'
  echo '```'
  echo
  echo "详情见各子目录 README / INSTALL.md。"
} >"$OUT/INSTALL.md"

{
  echo "# Xiaoman release $VERSION ($STAMP)"
  echo
  echo "## Artifacts"
  (cd "$OUT" && find . -type f \( -name '*.zip' -o -name '*.apk' -o -name '*.aab' -o -name '*.ipa' \) | sort)
  echo
  echo "## Tree"
  (cd "$OUT" && find . -maxdepth 3 -type d | sort)
} >"$OUT/MANIFEST.md"

if command -v shasum >/dev/null 2>&1; then
  (cd "$OUT" && find . -type f \( -name '*.zip' -o -name '*.apk' -o -name '*.aab' -o -name '*.ipa' \) -print0 \
    | xargs -0 shasum -a 256 >SHA256SUMS.txt 2>/dev/null || true)
elif command -v sha256sum >/dev/null 2>&1; then
  (cd "$OUT" && find . -type f \( -name '*.zip' -o -name '*.apk' -o -name '*.aab' -o -name '*.ipa' \) -print0 \
    | xargs -0 sha256sum >SHA256SUMS.txt 2>/dev/null || true)
fi

ln -sfn "$OUT" "$OUT_ROOT/latest"

# 更新 BUILD_INFO 中的工具链实况
{
  echo "product: xiaoman (小满 · 日程分身)"
  echo "version: $VERSION"
  echo "built_at: $(date -Iseconds)"
  echo "host: $HOST_OS $(uname -m)"
  echo "node: $(node -v 2>/dev/null || echo n/a)"
  echo "pnpm: $(pnpm -v 2>/dev/null || echo n/a)"
  echo "flutter: $(resolve_flutter 2>/dev/null || echo 'not found')"
  echo "java: $(resolve_java_home 2>/dev/null || echo 'not found')"
  echo "android_sdk: $(find_android_home 2>/dev/null || echo 'not found')"
  echo "xcode: $(has_full_xcode && xcodebuild -version 2>/dev/null | head -1 || echo 'not found (CLT only)')"
  echo "cocoapods: $(command -v pod >/dev/null && pod --version 2>/dev/null | head -1 || echo 'not found')"
  echo "only: ${ONLY:-all}"
  echo "fetch_ci: $FETCH_CI"
} >"$OUT/BUILD_INFO.txt"

log "构建完成"
echo "----------------------------------------"
echo "输出: $OUT"
echo "快捷: $OUT_ROOT/latest"
echo "安装说明: $OUT/INSTALL.md"
echo "成功: ${#OKS[@]}"
echo "失败: ${#FAILS[@]}"
if [[ "${#FAILS[@]}" -gt 0 ]]; then
  printf '  - %s\n' "${FAILS[@]}"
  echo "日志: $LOG_DIR"
  exit 1
fi
exit 0
