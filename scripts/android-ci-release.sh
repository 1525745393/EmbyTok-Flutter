#!/usr/bin/env bash
# ============================================================
# EmbyTok Android CI 发布脚本
# 简化版本，用于 GitHub Actions 自动化发布
# ============================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}✓ $1${NC}"; }
log_info() { echo -e "${YELLOW}! $1${NC}"; }
log_err()  { echo -e "${RED}✗ $1${NC}" >&2; }
log_step() { echo -e "\n=== $1 ==="; }

# 检查必需的环境变量
REQUIRED_ENVS=(
    "ANDROID_KEYSTORE"
    "ANDROID_KEYSTORE_PWD"
    "ANDROID_KEY_ALIAS"
    "ANDROID_KEY_PWD"
)

log_step "检查环境变量"
for env_var in "${REQUIRED_ENVS[@]}"; do
    if [ -z "${!env_var:-}" ]; then
        log_err "缺少必需的环境变量: $env_var"
        exit 1
    fi
done
log_ok "所有必需环境变量已配置"

# 创建 keystore 文件
log_step "配置签名密钥"
KEYSTORE_PATH="$PWD/frontend/android/app/embbytok-keystore.jks"
KEY_PROPERTIES_PATH="$PWD/frontend/android/key.properties"

echo "$ANDROID_KEYSTORE" | base64 -d > "$KEYSTORE_PATH"
if [ ! -f "$KEYSTORE_PATH" ]; then
    log_err "无法创建 keystore 文件"
    exit 1
fi
log_ok "Keystore 文件已创建: $KEYSTORE_PATH"

# 生成 key.properties
cat > "$KEY_PROPERTIES_PATH" <<EOF
storePassword=$ANDROID_KEYSTORE_PWD
keyPassword=$ANDROID_KEY_PWD
keyAlias=$ANDROID_KEY_ALIAS
storeFile=$KEYSTORE_PATH
EOF
log_ok "key.properties 已生成: $KEY_PROPERTIES_PATH"

# 进入 frontend 目录
cd frontend || { log_err "无法进入 frontend 目录"; exit 1; }

# 创建构建输出目录
mkdir -p build/app/outputs/flutter-apk

# Build 1: 构建 split-per-abi APKs（arm64-v8a, armeabi-v7a, x86_64）
log_step "构建 Split APKs (ABI 分离)"
flutter build apk --release --split-per-abi
log_ok "Split APKs 构建成功"

# Build 2: 构建 universal APK
log_step "构建 Universal APK"
flutter build apk --release
log_ok "Universal APK 构建成功"

# Build 3: 构建 App Bundle
log_step "构建 App Bundle"
flutter build appbundle --release
log_ok "App Bundle 构建成功"

# 验证构建产物
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

if [ "$ALL_OK" = false ]; then
    log_err "部分构建产物缺失"
    exit 1
fi

log_step "构建完成"
log_ok "所有构建产物已生成成功 🎉"