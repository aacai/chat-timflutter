#!/usr/bin/env bash
# 在 Linux (x86_64) 上构建「可达」桌面包：deb / AppImage
#
# 前置依赖（Ubuntu 22.04+）：
#   sudo apt update && sudo apt install -y \
#     build-essential curl wget file pkg-config libssl-dev libfuse2 \
#     libwebkit2gtk-4.1-dev libgtk-3-dev libayatana-appindicator3-dev \
#     librsvg2-dev patchelf
#   curl https://sh.rustup.rs -sSf | sh -s -- -y
#
# Tauri CLI 走 npm 的预编译二进制；cargo install tauri-cli 会重编译整个 Rust 依赖树，
# 在本机要十几分钟。交付用的包由 .github/workflows/build.yml 的 linux job 构建，
# 本脚本只用于本地复现，产物不入库。
#
# 用法：在项目根目录执行  bash scripts/build-linux.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FLUTTER="flutter"
if command -v fvm >/dev/null 2>&1; then FLUTTER="fvm flutter"; fi
TAURI="$ROOT/node_modules/.bin/tauri"

echo "==> [1/4] 构建 Flutter Web 产物（base href 必须为 / 以适配 tauri://localhost）"
$FLUTTER build web --release --base-href /

echo "==> [2/4] 校验产物资源"
grep -q '<base href="/" />' build/web/index.html || {
  echo "错误：base href 不是 /，Tauri 下资源会 404" >&2
  exit 1
}
for f in main.dart.js flutter_bootstrap.js trtc-wrapper.js \
         node_modules/@tencentcloud/chat/index.js; do
  [ -f "build/web/$f" ] || { echo "缺少 $f" >&2; exit 1; }
done

echo "==> [3/4] 安装预编译 Tauri CLI"
npm install --no-save --no-audit --no-fund '@tauri-apps/cli@^2'
"$TAURI" --version

echo "==> [4/4] Tauri 打包（deb / AppImage）"
"$TAURI" build --bundles deb,appimage

echo "==> 完成，产物在 src-tauri/target/release/bundle/"
