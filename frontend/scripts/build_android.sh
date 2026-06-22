#!/bin/bash
# ======================================================================
# EmbyTok Android 构建脚本
# 用法：
#   sh scripts/build_android.sh [debug|release] [输出目录]
# 示例：
#   sh scripts/build_android.sh debug
#   sh scripts/build_android.sh release build/app/outputs/flutter-apk
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
mode="${1:-debug}"
output_dir="${2:-build/app/outputs/flutter-apk}"

if [ "$mode" != "debug" ] && [ "$mode" != "release" ]; then
    log_err "无效的构建模式：$mode（仅支持 debug 或 release）"
    exit 1
fi

# ---------- 切换到项目根目录 ----------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.." || { log_err "无法切换到项目根目录"; exit 1; }
PROJECT_ROOT="$(pwd)"
log_ok "当前项目目录：$PROJECT_ROOT"
log_info "构建模式：$mode"
log_info "输出目录：$PROJECT_ROOT/$output_dir"

# ---------- 前置检查 ----------
section "执行前置检查"

# 检查 flutter 命令
if ! command -v flutter >/dev/null 2>&1; then
    log_err "未检测到 Flutter SDK，请先安装 Flutter 并配置环境变量"
    exit 1
fi
log_ok "Flutter SDK 已检测到"

# 检查 pubspec.yaml
if [ ! -f "pubspec.yaml" ]; then
    log_err "未检测到 pubspec.yaml，可能未在正确的项目目录运行脚本"
    exit 1
fi
log_ok "pubspec.yaml 已检测到"

# release 模式下检查签名密钥
if [ "$mode" = "release" ]; then
    # 若环境变量全部存在且 key.properties 不存在，则自动生成
    if [ -n "$ANDROID_KEYSTORE_PATH" ] && [ -n "$ANDROID_KEYSTORE_PASSWORD" ] && [ -n "$ANDROID_KEY_ALIAS" ] && [ -n "$ANDROID_KEY_PASSWORD" ]; then
        if [ ! -f "android/key.properties" ]; then
            log_info "检测到签名环境变量，自动生成 android/key.properties ..."
            cat > android/key.properties <<EOF
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyPassword=$ANDROID_KEY_PASSWORD
keyAlias=$ANDROID_KEY_ALIAS
storeFile=$ANDROID_KEYSTORE_PATH
EOF
            log_ok "已自动生成 android/key.properties"
        else
            log_info "android/key.properties 已存在，跳过自动生成"
        fi
    fi

    if [ ! -f "android/key.properties" ]; then
        log_err "release 构建需要签名密钥。请先："
        echo -e "${RED}${PREFIX}   1. 生成 keystore：keytool -genkey -v -keystore android/embbytok-keystore.jks -keyalg RSA -keysize 2048 -validity 36500 -alias embbytok${NC}"
        echo -e "${RED}${PREFIX}   2. 复制 android/key.properties.template 为 android/key.properties 并填写真实值${NC}"
        exit 1
    fi
    log_ok "android/key.properties 已检测到"
fi

# ---------- 构建执行 ----------
section "开始构建 Android APK"

# 清理之前的混淆输出目录以保证纯净
mkdir -p build/debug-info

FLUTTER_CMD="flutter build apk --$mode --split-per-abi"
if [ "$mode" = "release" ]; then
    FLUTTER_CMD="$FLUTTER_CMD --obfuscate --split-debug-info=./build/debug-info --no-tree-shake-icons"
fi

log_info "执行命令：$FLUTTER_CMD"
if ! eval "$FLUTTER_CMD"; then
    log_err "Android $mode 构建失败，请检查上方日志"
    exit 1
fi
log_ok "Android $mode 构建成功"

# ---------- 构建后输出 ----------
section "构建产物"

if [ ! -d "$output_dir" ]; then
    log_err "未找到输出目录：$PROJECT_ROOT/$output_dir"
    exit 1
fi

APK_LIST="$(find "$output_dir" -maxdepth 2 -name "*.apk" 2>/dev/null | sort)"
if [ -z "$APK_LIST" ]; then
    log_err "未在 $output_dir 下找到任何 .apk 文件"
    exit 1
fi

echo -e "${PREFIX} 以下 APK 已生成："
while IFS= read -r apk; do
    size_bytes=$(stat -c%s "$apk" 2>/dev/null || stat -f%z "$apk" 2>/dev/null)
    if [ -n "$size_bytes" ]; then
        size_mb=$(awk "BEGIN {printf \"%.2f\", $size_bytes/1048576}")
        echo -e "${GREEN}${PREFIX}   - $apk  (${size_mb} MB)${NC}"
    else
        echo -e "${GREEN}${PREFIX}   - $apk${NC}"
    fi
done <<< "$APK_LIST"

echo ""
log_info "你可以使用以下方式发布 APK："
echo -e "${YELLOW}${PREFIX}   adb install <apk_path>        # 安装到连接的设备/模拟器${NC}"
echo -e "${YELLOW}${PREFIX}   上传到 Google Play / 国内应用商店  # 发布正式版本${NC}"

section "构建完成"
log_ok "全部步骤执行完毕 🎉"
exit 0
