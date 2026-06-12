# EmbyTok Flutter - 原生打包验证清单

## 文件与目录结构检查
- [ ] Checkpoint 1: `frontend/android/settings.gradle` 存在且声明了 `google()`、`mavenCentral()` 仓库
- [ ] Checkpoint 2: `frontend/android/build.gradle` 存在且声明 AGP 与 Kotlin 插件 classpath
- [ ] Checkpoint 3: `frontend/android/gradle.properties` 存在 `org.gradle.jvmargs`、`android.useAndroidX`、`android.overridePathCheck=true`
- [ ] Checkpoint 4: `frontend/android/gradle/wrapper/gradle-wrapper.properties` 存在且 Gradle 版本 >= 8.0
- [ ] Checkpoint 5: `frontend/android/app/build.gradle` 存在，包含 `namespace 'com.embbytok.app'`、`minSdk 21`、`compileSdk 34`、`signingConfigs.release`
- [ ] Checkpoint 6: `frontend/android/app/src/main/AndroidManifest.xml` 存在，包含 `INTERNET` 权限与 `MainActivity` 声明，`android:exported="true"`
- [ ] Checkpoint 7: `frontend/android/app/src/main/res/values/strings.xml` 存在，定义 `app_name = EmbyTok`
- [ ] Checkpoint 8: `frontend/android/app/src/main/res/xml/network_security_config.xml` 存在
- [ ] Checkpoint 9: `frontend/android/app/src/main/kotlin/com/embbytok/app/MainActivity.kt` 存在
- [ ] Checkpoint 10: `frontend/android/app/proguard-rules.pro` 存在且被 `app/build.gradle` 引用
- [ ] Checkpoint 11: `frontend/android/key.properties.template` 存在
- [ ] Checkpoint 12: `frontend/android/.gitignore` 忽略 `key.properties`、`*.jks`、`*.keystore`、`local.properties`
- [ ] Checkpoint 13: `frontend/ios/Podfile` 存在，`platform :ios, '12.0'`，含 Flutter 标准 Pod 配置
- [ ] Checkpoint 14: `frontend/ios/Runner/Info.plist` 存在，含 `CFBundleDisplayName = EmbyTok`、`NSAppTransportSecurity`、`CFBundleShortVersionString = $(FLUTTER_BUILD_NAME)`
- [ ] Checkpoint 15: `frontend/ios/Runner/AppDelegate.swift` 存在（或 Objective-C 对应文件）
- [ ] Checkpoint 16: `frontend/ios/Flutter/Debug.xcconfig` 与 `Release.xcconfig` 存在
- [ ] Checkpoint 17: `frontend/ios/ExportOptions.plist` 存在（或有注释说明的模板）
- [ ] Checkpoint 18: `frontend/ios/.gitignore` 忽略 `Pods/`、`*.xcuserstate`、`Runner.xcworkspace/xcuserdata/`
- [ ] Checkpoint 19: `frontend/scripts/build_android.sh` 与 `frontend/scripts/build_ios.sh` 存在且可执行（`chmod +x` 已设置）
- [ ] Checkpoint 20: `frontend/README_PACKAGING.md` 存在，含完整 Android/iOS 构建与发布指南

## Android 编译与签名验证
- [ ] Checkpoint 21: `cd frontend && flutter build apk --debug` 成功执行，输出 `app-debug.apk` 存在
- [ ] Checkpoint 22: 填写 `android/key.properties` 后，`flutter build apk --release` 成功，输出 `app-release.apk` 存在
- [ ] Checkpoint 23: `aapt dump badging build/app/outputs/flutter-apk/app-release.apk` 显示 `package: name='com.embbytok.app' versionCode='1' versionName='0.1.0'`
- [ ] Checkpoint 24: `aapt dump permissions build/app/outputs/flutter-apk/app-release.apk` 包含 `android.permission.INTERNET`
- [ ] Checkpoint 25: `keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk` 输出非 debug 签名（Owner 非 `CN=Android Debug`）
- [ ] Checkpoint 26: 真机安装 release APK 后运行 30 秒无崩溃（登录、列表滚动、视频播放）
- [ ] Checkpoint 27: `adb logcat --buffer=crash` 中无 Fatal Exception 与混淆相关崩溃

## iOS 编译与签名验证
- [ ] Checkpoint 28: `cd frontend && flutter build ios --no-codesign` 成功执行（需 macOS）
- [ ] Checkpoint 29: `cd frontend/ios && pod install` 成功完成，生成 `Runner.xcworkspace`
- [ ] Checkpoint 30: Xcode 打开 `Runner.xcworkspace`，Signing & Capabilities 无红色错误（需开发者填写 Team）
- [ ] Checkpoint 31: `/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" ios/Runner/Info.plist` 输出 `EmbyTok`
- [ ] Checkpoint 32: `/usr/libexec/PlistBuddy -c "Print :NSAppTransportSecurity:NSAllowsArbitraryLoads" ios/Runner/Info.plist` 输出 `true`
- [ ] Checkpoint 33: Xcode "Product > Archive" 成功，Organizer 中出现新 Archive
- [ ] Checkpoint 34: `xcodebuild -exportArchive` 可基于 `ExportOptions.plist` 导出 IPA

## 构建脚本与文档验证
- [ ] Checkpoint 35: `sh frontend/scripts/build_android.sh debug` 成功结束（exit 0），打印 APK 路径与大小
- [ ] Checkpoint 36: 未填写 `key.properties` 时，`sh frontend/scripts/build_android.sh release` 以非 0 退出并打印"请先填写 android/key.properties"
- [ ] Checkpoint 37: `sh frontend/scripts/build_ios.sh release` 在 macOS 下可执行、输出友好中文日志
- [ ] Checkpoint 38: `frontend/README_PACKAGING.md` 中明确指出 `key.properties`、`*.keystore`、Apple Developer 证书等敏感信息不可提交到 Git
- [ ] Checkpoint 39: `git check-ignore android/key.properties android/*.jks android/*.keystore` 全部命中被忽略规则
- [ ] Checkpoint 40: 新开发者阅读 README_PACKAGING.md 后，可在 30 分钟内完成 Android/iOS 的首次构建
