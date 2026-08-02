#!/usr/bin/env bash
# Android 发布构建脚本
# 为什么用独立脚本而非内联命令：@semantic-release/exec 默认用 /bin/sh（dash），
# dash 不支持 set -o pipefail，会导致管道中 flutter 失败但 tee 成功时退出码误判
set -euo pipefail

# 解码 keystore
mkdir -p frontend/android/app
echo "$ANDROID_KEYSTORE" | base64 -d > frontend/android/app/embbytok-keystore.jks
chmod 600 frontend/android/app/embbytok-keystore.jks

# 生成 key.properties
# 为什么用 printf 而非 echo：printf 对 \n 的处理更可移植
printf 'storePassword=%s\nkeyPassword=%s\nkeyAlias=%s\nstoreFile=%s\n' \
    "$ANDROID_KEYSTORE_PWD" "$ANDROID_KEY_PWD" "$ANDROID_KEY_ALIAS" \
    "$(pwd)/frontend/android/app/embbytok-keystore.jks" \
    > frontend/android/key.properties

cd frontend

# 构建 APK（分 ABI）+ AAB
# pipefail 确保 flutter 失败时管道退出码非零（tee 不会吞掉错误）
flutter build apk --release --split-per-abi 2>&1 | tee /tmp/flutter-build-debug.log
flutter build appbundle --release 2>&1 | tee -a /tmp/flutter-build-debug.log
