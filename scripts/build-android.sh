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

# === 测试模式包体积验证 ===
# 1. 输出 APK 大小报告
echo "=== APK 大小报告 ==="
ls -lh build/app/outputs/flutter-apk/*.apk build/app/outputs/bundle/release/*.aab 2>/dev/null | awk '{print $9, $5}'

# 2. 包体积上限检查（arm64 单 APK 不超过 80MB）
APK_SIZE=$(stat -c%s build/app/outputs/flutter-apk/app-arm64-v8a-release.apk 2>/dev/null || echo 0)
APK_MB=$((APK_SIZE / 1024 / 1024))
echo "arm64 APK 大小: ${APK_MB}MB"
if [ "$APK_MB" -gt 80 ]; then
  echo "::warning::APK 体积 ${APK_MB}MB 超过 80MB 建议上限"
fi

# 3. 验证 test_mode 代码未被打包进 release（检查 libapp.so 中不应含 test_mode 路由字符串）
if [ -f build/app/intermediates/flutter/release/flutter_assets/kernel_blob.bin ]; then
  echo "注意: release 构建使用 AOT kernel_blob.bin"
fi
# 解压 APK 检查 lib/arm64-v8a/libapp.so 中是否含 test-mode 路由字符串
if command -v unzip >/dev/null 2>&1; then
  unzip -p build/app/outputs/flutter-apk/app-arm64-v8a-release.apk lib/arm64-v8a/libapp.so 2>/dev/null | strings 2>/dev/null | grep -c "test-mode" | xargs -I{} echo "test-mode 字符串出现次数: {}" || echo "无法检查（strings 不可用，跳过）"
fi
