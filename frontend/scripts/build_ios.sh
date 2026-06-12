#!/bin/bash
# ======================================================================
# EmbyTok iOS 构建脚本
# 用法：
#   sh scripts/build_ios.sh [debug|release] [export_method]
# export_method：app-store | ad-hoc | development
# 示例：
#   sh scripts/build_ios.sh
#   sh scripts/build_ios.sh release app-store
# ======================================================================

# ---------- 颜色定义 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PREFIX="[EmbyTok 构建]"
SEPARATOR="=========================="

log_ok()  { echo -e "${GREEN}${PREFIX} ✓ $1${NC}"; }
log_info(){ echo -e "${YELLOW}${PREFIX} ! $1${NC}"; }
log_err() { echo -e "${RED}${PREFIX} ✗ $1${NC}" >&2; }
section() { echo -e "\n${PREFIX} ${SEPARATOR}"; echo -e "${PREFIX} $1"; echo -e "${PREFIX} ${SEPARATOR}"; }

# ---------- 参数处理 ----------
mode="${1:-release}"
export_method="${2:-development}"

if [ "$mode" != "debug" ] && [ "$mode" != "release" ]; then
    log_err "无效的构建模式：$mode（仅支持 debug 或 release）"
    exit 1
fi

case "$export_method" in
    app-store|ad-hoc|development) ;;
    *)
        log_err "无效的导出方式：$export_method（仅支持 app-store / ad-hoc / development）"
        exit 1
        ;;
esac

# ---------- 切换到项目根目录 ----------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.." || { log_err "无法切换到项目根目录"; exit 1; }
PROJECT_ROOT="$(pwd)"
log_ok "当前项目目录：$PROJECT_ROOT"
log_info "构建模式：$mode"
log_info "导出方式：$export_method"

# ---------- 前置检查 ----------
section "执行前置检查"

# 检查是否是 macOS
if [ "$(uname -s)" != "Darwin" ]; then
    log_err "iOS 构建只能在 macOS 上运行（当前系统：$(uname -s)）"
    exit 1
fi
log_ok "系统检测：macOS"

# 检查 flutter 命令
if ! command -v flutter >/dev/null 2>&1; then
    log_err "未检测到 Flutter SDK，请先安装 Flutter 并配置环境变量"
    exit 1
fi
log_ok "Flutter SDK 已检测到"

# 检查 xcodebuild
if ! command -v xcodebuild >/dev/null 2>&1; then
    log_err "未检测到 xcodebuild，请先安装 Xcode（App Store 中搜索安装）"
    exit 1
fi
log_ok "xcodebuild 已检测到"

# 检查 pubspec.yaml
if [ ! -f "pubspec.yaml" ]; then
    log_err "未检测到 pubspec.yaml，可能未在正确的项目目录运行脚本"
    exit 1
fi
log_ok "pubspec.yaml 已检测到"

# 检查 iOS 目录
if [ ! -f "ios/Podfile" ]; then
    log_err "未检测到 ios/Podfile，请先运行 flutter create . 或确认 iOS 工程已初始化"
    exit 1
fi
log_ok "ios/Podfile 已检测到"

# ---------- 依赖安装 ----------
section "安装依赖"

log_info "执行 flutter pub get ..."
if ! flutter pub get; then
    log_err "flutter pub get 失败"
    exit 1
fi
log_ok "flutter pub get 成功"

log_info "执行 pod install --repo-update ..."
if ! command -v pod >/dev/null 2>&1; then
    log_err "未检测到 pod 命令，请先安装 CocoaPods：sudo gem install cocoapods"
    exit 1
fi

cd ios || { log_err "无法进入 ios 目录"; exit 1; }
if ! pod install --repo-update; then
    cd "$PROJECT_ROOT"
    log_err "pod install 失败，请检查 CocoaPods 配置或尝试：pod repo update"
    exit 1
fi
cd "$PROJECT_ROOT"
log_ok "pod install 成功"

# ---------- 构建执行 ----------
section "开始构建 iOS IPA"

mkdir -p build/debug-info

FLUTTER_CMD="flutter build ipa --$mode --export-method $export_method"
if [ "$mode" = "release" ]; then
    FLUTTER_CMD="$FLUTTER_CMD --obfuscate --split-debug-info=./build/debug-info"
fi

log_info "执行命令：$FLUTTER_CMD"
if ! eval "$FLUTTER_CMD"; then
    log_err "iOS $mode 构建失败，请检查上方日志"
    exit 1
fi
log_ok "iOS $mode 构建成功"

# ---------- 构建后输出 ----------
section "构建产物"

IPA_PATH="build/ios/ipa/EmbyTok.ipa"
if [ -f "$IPA_PATH" ]; then
    size_bytes=$(stat -f%z "$IPA_PATH" 2>/dev/null || stat -c%s "$IPA_PATH" 2>/dev/null)
    if [ -n "$size_bytes" ]; then
        size_mb=$(awk "BEGIN {printf \"%.2f\", $size_bytes/1048576}")
        echo -e "${GREEN}${PREFIX} ✓ IPA 已生成：$PROJECT_ROOT/$IPA_PATH  (${size_mb} MB)${NC}"
    else
        echo -e "${GREEN}${PREFIX} ✓ IPA 已生成：$PROJECT_ROOT/$IPA_PATH${NC}"
    fi
else
    log_info "未找到 $IPA_PATH，构建结果可能位于 build/ios/ipa/ 下的其他文件名"
fi

echo ""
log_info "你可以使用以下方式发布 IPA："
echo -e "${YELLOW}${PREFIX}   使用 Xcode Organizer 上传到 App Store Connect${NC}"
echo -e "${YELLOW}${PREFIX}   xcrun altool --upload-app -f $IPA_PATH -t ios -u <your_apple_id> -p <app_specific_password>${NC}"

section "构建完成"
log_ok "全部步骤执行完毕 🎉"
exit 0
