#!/usr/bin/env bash
# fetch_ci_native_artifacts.sh — 从 GitHub Actions 拉取 iOS / macOS / Windows 安装包
#
# 前置：仓库已推送到 GitHub，且已跑过 workflow「Build native apps」
#
# 用法：
#   ./scripts/fetch_ci_native_artifacts.sh
#   ./scripts/fetch_ci_native_artifacts.sh --run <run-id>
#   ./scripts/fetch_ci_native_artifacts.sh --out dist/release/latest/flutter

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${OUT:-$ROOT/dist/release/latest/flutter}"
RUN_ID=""
WORKFLOW="build-native-apps.yml"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --run) RUN_ID="$2"; shift 2 ;;
    --workflow) WORKFLOW="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

log() { printf '\033[1;36m==>\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

command -v gh >/dev/null 2>&1 || fail "需要 GitHub CLI: brew install gh && gh auth login"
gh auth status >/dev/null 2>&1 || fail "gh 未登录，请执行: gh auth login"

mkdir -p "$OUT/ios" "$OUT/macos" "$OUT/windows" "$OUT/_ci_download"
TMP="$OUT/_ci_download"
rm -rf "$TMP"
mkdir -p "$TMP"

if [[ -z "$RUN_ID" ]]; then
  log "查找最近成功的 workflow: $WORKFLOW"
  RUN_ID="$(gh run list --workflow "$WORKFLOW" --status success --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)"
  [[ -n "$RUN_ID" ]] || fail "未找到成功的 CI 运行。请先 push 并触发: gh workflow run $WORKFLOW"
fi

log "下载 artifacts（run=$RUN_ID）→ $TMP"
gh run download "$RUN_ID" --dir "$TMP"

# 兼容 artifact 目录名（upload-artifact 会按 name 建子目录）
find "$TMP" -type f \( -name '*.ipa' -o -name '*Runner.app.zip' \) -exec cp -f {} "$OUT/ios/" \; 2>/dev/null || true
find "$TMP" -type f \( -name '*macos*.zip' -o -name '*macos*.dmg' -o -name '*.dmg' \) -exec cp -f {} "$OUT/macos/" \; 2>/dev/null || true
find "$TMP" -type f -name '*windows*.zip' -exec cp -f {} "$OUT/windows/" \; 2>/dev/null || true

# 扁平化常见 artifact 根目录
for dir in "$TMP"/*; do
  [[ -d "$dir" ]] || continue
  base="$(basename "$dir")"
  case "$base" in
    *ios*|*ipa*) cp -R "$dir"/. "$OUT/ios/" 2>/dev/null || true ;;
    *macos*|*mac*) cp -R "$dir"/. "$OUT/macos/" 2>/dev/null || true ;;
    *windows*|*win*) cp -R "$dir"/. "$OUT/windows/" 2>/dev/null || true ;;
  esac
done

log "已合并到 $OUT/{ios,macos,windows}"
find "$OUT/ios" "$OUT/macos" "$OUT/windows" -type f 2>/dev/null | head -40
ok_count="$(find "$OUT/ios" "$OUT/macos" "$OUT/windows" -type f \( -name '*.ipa' -o -name '*.zip' -o -name '*.dmg' -o -name '*.exe' \) 2>/dev/null | wc -l | tr -d ' ')"
[[ "${ok_count:-0}" -gt 0 ]] || fail "下载完成但未识别到安装包，请检查 artifact 内容: $TMP"
echo "完成：识别到 ${ok_count} 个安装包文件"
