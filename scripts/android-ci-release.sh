#!/usr/bin/env bash
# ============================================================
# EmbyTok Android CI 发布脚本
# 简化版本，用于 GitHub Actions 自动化发布
# ============================================================

set -eo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}✓ $1${NC}"; }
log_info() { echo -e "${YELLOW}! $1${NC}"; }
log_err()  { echo -e "${RED}✗ $1${NC}" >&2; }
log_step() { echo -e "\n=== $1 ==="; }

log_step "检查环境变量"
if [ -z "${ANDROID_KEYSTORE:-}" ]; then
    log_err "缺少环境变量: ANDROID_KEYSTORE"
    exit 1
fi
if [ -z "${ANDROID_KEYSTORE_PWD:-}" ]; then
    log_err "缺少环境变量: ANDROID_KEYSTORE_PWD"
    exit 1
fi
if [ -z "${ANDROID_KEY_ALIAS:-}" ]; then
    log_err "缺少环境变量: ANDROID_KEY_ALIAS"
    exit 1
fi
if [ -z "${ANDROID_KEY_PWD:-}" ]; then
    log_err "缺少环境变量: ANDROID_KEY_PWD"
    exit 1
fi
log_ok "所有必需环境变量已配置"

log_step "配置签名密钥"
KEYSTORE_PATH="$PWD/frontend/android/app/embbytok-keystore.jks"
KEY_PROPERTIES_PATH="$PWD/frontend/android/key.properties"

log_info "创建 keystore 文件: $KEYSTORE_PATH"
echo "$ANDROID_KEYSTORE" | base64 -d > "$KEYSTORE_PATH"
if [ ! -f "$KEYSTORE_PATH" ]; then
    log_err "无法创建 keystore 文件"
    exit 1
fi
KEYSTORE_SIZE=$(stat -c%s "$KEYSTORE_PATH" 2>/dev/null || stat -f%z "$KEYSTORE_PATH" 2>/dev/null)
log_ok "Keystore 文件已创建 ($KEYSTORE_SIZE 字节)"

log_info "生成 key.properties: $KEY_PROPERTIES_PATH"
cat > "$KEY_PROPERTIES_PATH" <<EOF
storePassword=$ANDROID_KEYSTORE_PWD
keyPassword=$ANDROID_KEY_PWD
keyAlias=$ANDROID_KEY_ALIAS
storeFile=$KEYSTORE_PATH
EOF
if [ ! -f "$KEY_PROPERTIES_PATH" ]; then
    log_err "无法创建 key.properties"
    exit 1
fi
log_ok "key.properties 已生成"

log_step "进入 frontend 目录"
cd frontend || { log_err "无法进入 frontend 目录"; exit 1; }
log_ok "当前目录: $(pwd)"

mkdir -p build/app/outputs/flutter-apk

log_step "构建 Split APKs (ABI 分离)"
log_info "执行: flutter build apk --release --split-per-abi"
if flutter build apk --release --split-per-abi; then
    log_ok "Split APKs 构建成功"
else
    log_err "Split APKs 构建失败"
    exit 1
fi

log_step "构建 Universal APK"
log_info "执行: flutter build apk --release"
if flutter build apk --release; then
    log_ok "Universal APK 构建成功"
else
    log_err "Universal APK 构建失败"
    exit 1
fi

log_step "构建 App Bundle"
log_info "执行: flutter build appbundle --release"
if flutter build appbundle --release; then
    log_ok "App Bundle 构建成功"
else
    log_err "App Bundle 构建失败"
    exit 1
fi

log_step "验证构建产物"

REQUIRED_FILES=(
    "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
    "build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk"
    "build/app/outputs/flutter-apk/app-x86_64-release.apk"
    "build/app/outputs/flutter-apk/app-release.apk"
    "build/app/outputs/bundle/release/app-release.aab"
)

ALL_OK=true
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        SIZE=$(du -sh "$file" | cut -f1)
        log_ok "$file ($SIZE)"
    else
        log_err "$file 不存在"
        ALL_OK=false
    fi
done

log_info "列出构建目录内容:"
ls -la build/app/outputs/flutter-apk/ 2>/dev/null || log_err "flutter-apk 目录不存在"
ls -la build/app/outputs/bundle/release/ 2>/dev/null || log_err "bundle/release 目录不存在"

if [ "$ALL_OK" = false ]; then
    log_err "部分构建产物缺失"
    exit 1
fi

log_step "构建完成"
log_ok "所有构建产物已生成成功 🎉"