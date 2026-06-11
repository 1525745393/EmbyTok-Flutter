# EmbyTok Flutter - 原生打包实施计划

## 总览
基于 [spec.md](./spec.md) ，将 Android 与 iOS 原生打包的具体实施工作分解为 10 个任务，按依赖顺序排列。

## [x] Task 1: 准备阶段 — 确定包名、版本号与关键参数
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 确定 Android `applicationId` = `com.embbytok.app`，iOS `Bundle Identifier` = `com.embbytok.app`
  - 确定 Android `compileSdk = 34`、`minSdk = 21`、`targetSdk = 34`
  - 确定 iOS `MinimumOSVersion = 12.0`
  - 确定 Kotlin 版本 `1.9.0`、AGP 版本 `7.4.2`、Gradle wrapper 版本 `8.3`
- **Acceptance Criteria Addressed**: AC-4, AC-6
- **Test Requirements**:
  - `programmatic` TR-1.1: 在后续文件（build.gradle、Info.plist）中可以找到上述数值
  - `programmatic` TR-1.2: `frontend/pubspec.yaml` 中的 `version: 0.1.0` 与 Info.plist / build.gradle 中的版本声明一致
- **Notes**: 后续 Task 所有版本号需与本任务统一

---

## [ ] Task 2: Android Gradle 根工程（settings.gradle、build.gradle、gradle-wrapper）
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 创建 `frontend/android/settings.gradle`：`pluginManagement` + `dependencyResolutionManagement`，声明 `google()`、`mavenCentral()`，以及可选的阿里云镜像（通过环境变量开关）
  - 创建 `frontend/android/build.gradle`（根工程）：声明 `com.android.application` 与 Kotlin 插件 classpath
  - 创建 `frontend/android/gradle.properties`：`org.gradle.jvmargs=-Xmx4G`、`android.useAndroidX=true`、`android.enableJetifier=true`、`android.overridePathCheck=true`
  - 创建 `frontend/android/gradle/wrapper/gradle-wrapper.properties`：`distributionUrl=https\://services.gradle.org/distributions/gradle-8.3-bin.zip`
  - 创建 `frontend/android/local.properties.template`：`sdk.dir` 与 `flutter.sdk` 占位（作为模板，不提交真实路径）
  - 更新 `.gitignore`：忽略 `local.properties`、`.gradle/`、`/build/` 等
- **Acceptance Criteria Addressed**: AC-1, AC-10, FR-10, FR-11
- **Test Requirements**:
  - `programmatic` TR-2.1: `flutter build apk --debug` 成功（签名采用 debug keystore 即可）
  - `programmatic` TR-2.2: `gradle-wrapper.properties` 的 Gradle 版本与 AGP 7.4.2 兼容（Gradle 8.x）
  - `human-judgement` TR-2.3: settings.gradle 中的仓库声明清晰，含"阿里云镜像"的注释开关

---

## [ ] Task 3: Android app 模块配置（app/build.gradle + AndroidManifest）
- **Priority**: P0
- **Depends On**: Task 2
- **Description**:
  - 创建 `frontend/android/app/build.gradle`：
    - `namespace 'com.embbytok.app'`
    - `compileSdk 34`
    - `defaultConfig`: `applicationId "com.embbytok.app"`、`minSdk 21`、`targetSdk 34`、`versionCode 1`、`versionName "0.1.0"`
    - `buildTypes.release`: `minifyEnabled true`、`shrinkResources true`、`signingConfig signingConfigs.release`（条件性 fallback 到 debug）
    - `splits.abi`: 启用 `arm64-v8a`、`armeabi-v7a`，并 `universalApk false`
    - `ndk.abiFilters`: 同上
  - 创建 `frontend/android/app/src/main/AndroidManifest.xml`：
    - `<manifest package="com.embbytok.app">`
    - `<uses-permission android:name="android.permission.INTERNET"/>`
    - `<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>`
    - `<application>` 含 `android:label="EmbyTok"`、`android:icon="@mipmap/ic_launcher"`、`android:networkSecurityConfig="@xml/network_security_config"`
    - `<activity android:name=".MainActivity" ...>` Flutter standard
  - 创建 `frontend/android/app/src/main/res/values/strings.xml`（app_name = EmbyTok）
  - 创建 `frontend/android/app/src/main/res/xml/network_security_config.xml`（允许明文 HTTP，内网 Emby Server 场景）
  - 创建 `frontend/android/app/src/main/kotlin/com/embbytok/app/MainActivity.kt`（空壳，继承 `FlutterActivity`）
- **Acceptance Criteria Addressed**: AC-1, AC-4
- **Test Requirements**:
  - `programmatic` TR-3.1: `aapt dump badging build/app/outputs/flutter-apk/app-debug.apk | grep "package: name='com.embbytok.app'"` 成功
  - `programmatic` TR-3.2: `aapt dump permissions build/app/outputs/flutter-apk/app-debug.apk` 中存在 `android.permission.INTERNET`
  - `human-judgement` TR-3.3: AndroidManifest.xml 中 `<activity>` 配置正确，`android:exported="true"` 符合 Android 12+ 要求

---

## [ ] Task 4: Android release 签名机制（key.properties + signingConfigs）
- **Priority**: P0
- **Depends On**: Task 3
- **Description**:
  - 在 `frontend/android/app/build.gradle` 的顶部增加读取 `key.properties` 的逻辑：
    - `def keystorePropertiesFile = rootProject.file("key.properties")`
    - `def keystoreProperties = new Properties()`
    - 文件存在时 `keystoreProperties.load(...)`，不存在时回退到 debug 签名
  - 在 `android { signingConfigs { release { ... } } }` 中引用 `keystoreProperties['storeFile']` / `keyPassword` / `keyAlias` / `storePassword`
  - 创建 `frontend/android/key.properties.template`（占位模板，含 4 个字段注释）
  - 创建 `frontend/android/app/keytool_gen.sh` 辅助脚本（提示用户生成 keystore 的 keytool 命令，但不强求）
  - 更新 `frontend/android/.gitignore`：忽略 `key.properties`、`*.jks`、`*.keystore`
- **Acceptance Criteria Addressed**: AC-2, AC-10
- **Test Requirements**:
  - `programmatic` TR-4.1: 在正确填写 `key.properties` 后，`flutter build apk --release` 成功
  - `programmatic` TR-4.2: `keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk` 的输出 owner 字段不是 `androiddebugkey`
  - `human-judgement` TR-4.3: `key.properties` 不在 `git status` 的 tracked 文件列表中

---

## [ ] Task 5: Android ProGuard/R8 混淆规则（proguard-rules.pro）
- **Priority**: P1
- **Depends On**: Task 4
- **Description**:
  - 创建 `frontend/android/app/proguard-rules.pro`：
    - `dio` 相关：保留 `okhttp3`、`retrofit`、Gson 反射字段（如 `keep class com.dio.** { *; }`、`keep class okhttp3.** { *; }`）
    - `flutter_riverpod` / `provider`：保留 Flutter 插件回调 `io.flutter.plugins.**`
    - `shared_preferences`：`keep class io.flutter.plugins.sharedpreferences.** { *; }`
    - `connectivity_plus`：`keep class com.example.connectivity_plus.** { *; }`
    - `video_player`（exoplayer）：`keep class com.google.android.exoplayer2.** { *; }`
    - 保留 Kotlin 协程相关 `keepnames class kotlinx.coroutines.internal.MainDispatcherFactory`
    - 通用：`-keepattributes *Annotation*, Signature, EnclosingMethod`
  - 在 `app/build.gradle` 中确保 `minifyEnabled true` + `shrinkResources true` 时使用 `proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'`
- **Acceptance Criteria Addressed**: AC-3
- **Test Requirements**:
  - `human-judgement` TR-5.1: 安装 release APK 后执行 30 秒冒烟测试，无崩溃
  - `human-judgement` TR-5.2: `adb logcat --buffer=crash` 在启动后 1 分钟内无 Fatal Exception
  - `programmatic` TR-5.3: `proguard-rules.pro` 文件存在且被 `app/build.gradle` 引用

---

## [ ] Task 6: Android 应用图标与资源（可选但推荐）
- **Priority**: P2
- **Depends On**: Task 3
- **Description**:
  - 使用 `flutter_launcher_icons` 或手动放置 `ic_launcher.png` / `ic_launcher_round.png` 到 `mipmap-hdpi`/`mdpi`/`xhdpi`/`xxhdpi`/`xxxhdpi`
  - 创建 `frontend/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`（自适应图标，至少有一个 background + foreground）
  - 若无真实图标素材，至少放一个 512x512 的占位 PNG（可在后续迭代中替换）
- **Acceptance Criteria Addressed**: 辅助性 AC，无正式 AC 映射
- **Test Requirements**:
  - `human-judgement` TR-6.1: 安装到真机后桌面图标可见，非默认 Flutter 蓝图标
  - `programmatic` TR-6.2: `res/mipmap-anydpi-v26/ic_launcher.xml` 存在

---

## [ ] Task 7: iOS Xcode 工程骨架（Runner 目录 + Podfile + Info.plist）
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 创建 `frontend/ios/Podfile`：
    - 标准 Flutter Podfile：`platform :ios, '12.0'`
    - `use_frameworks!`、`use_modular_headers!`
    - `flutter_additional_ios_build_settings(target)` 调用
  - 创建 `frontend/ios/Runner/Info.plist`：
    - `CFBundleDevelopmentRegion = en`
    - `CFBundleDisplayName = EmbyTok`
    - `CFBundleExecutable = $(EXECUTABLE_NAME)`
    - `CFBundleIdentifier = $(PRODUCT_BUNDLE_IDENTIFIER)`
    - `CFBundleName = $(PRODUCT_NAME)`
    - `CFBundlePackageType = APPL`
    - `CFBundleShortVersionString = $(FLUTTER_BUILD_NAME)`
    - `CFBundleVersion = $(FLUTTER_BUILD_NUMBER)`
    - `LSRequiresIPhoneOS = true`
    - `NSAppTransportSecurity` → `NSAllowsArbitraryLoads = true`、`NSAllowsArbitraryLoadsInWebContent = true`
    - `UILaunchStoryboardName = LaunchScreen`
    - `UISupportedInterfaceOrientations`（竖屏为主）：`UIInterfaceOrientationPortrait`、可选上下颠倒
    - `UIViewControllerBasedStatusBarAppearance = false`
    - `io.flutter.embedded_views_preview = true`（video_player 要求）
  - 创建 `frontend/ios/Runner/Runner-Bridging-Header.h`（空，但 Flutter 某些插件需要）
  - 创建 `frontend/ios/Runner/AppDelegate.swift`（空壳，继承 `FlutterAppDelegate`）
  - 创建 `frontend/ios/Runner/Base.lproj/LaunchScreen.storyboard`（基本启动画面，含 Logo 占位）
  - 创建 `frontend/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` + `LaunchImage.imageset` 占位
  - 创建 `frontend/ios/Flutter/` 下的 `AppFrameworkInfo.plist`（标准 Flutter 模板）
  - 注意：`project.pbxproj` 是 Xcode 生成的工程元文件，此处不手写；采用 "由 Xcode 首次打开时生成" 方案，配套提供 `Runner.xcodeproj` 的最简结构 + README 指引用户 `open ios/Runner.xcworkspace`（或 `flutter create .` 重新生成 iOS 工程）
- **Acceptance Criteria Addressed**: AC-5, AC-6, AC-7
- **Test Requirements**:
  - `programmatic` TR-7.1: `/usr/libexec/PlistBuddy -c "Print :NSAppTransportSecurity" ios/Runner/Info.plist` 成功输出
  - `human-judgement` TR-7.2: Xcode 打开工程无红色错误项，Signing 页面可编辑 Team
  - `human-judgement` TR-7.3: `flutter build ios --no-codesign` 可成功（说明 Podfile & 工程结构正确）

---

## [ ] Task 8: iOS 签名与发布配置（Debug.xcconfig / Release.xcconfig / ExportOptions）
- **Priority**: P1
- **Depends On**: Task 7
- **Description**:
  - 创建 `frontend/ios/Flutter/Debug.xcconfig`：
    - `#include "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"`
    - `GCC_PREPROCESSOR_DEFINITIONS = $(inherited) COCOAPODS=1`
    - `DEVELOPMENT_TEAM = $(DEVELOPMENT_TEAM)`（通过环境变量注入，留空由开发者填写）
  - 创建 `frontend/ios/Flutter/Release.xcconfig`：
    - `#include "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"`
    - `FLUTTER_BUILD_NAME = 0.1.0`
    - `FLUTTER_BUILD_NUMBER = 1`
    - `DEVELOPMENT_TEAM = $(DEVELOPMENT_TEAM)`
    - `PRODUCT_BUNDLE_IDENTIFIER = com.embbytok.app`
  - 创建 `frontend/ios/ExportOptions.plist`（标准 `method = app-store` / `ad-hoc` / `development` 三份模板中的 `app-store` 一份作为默认；另两份作为注释示例）
  - 创建 `frontend/ios/export_options_development.plist`（开发测试签名用）
  - 更新 `frontend/ios/.gitignore`：忽略 `Pods/`、`Runner.xcworkspace/xcuserdata/`、`*.xcuserstate`
- **Acceptance Criteria Addressed**: AC-7
- **Test Requirements**:
  - `human-judgement` TR-8.1: 正确配置签名 Team 后，Xcode Archive 成功
  - `human-judgement` TR-8.2: `xcodebuild -workspace Runner.xcworkspace -scheme Runner -archivePath ./build/ios/Runner.xcarchive archive` 成功输出 xcarchive
  - `human-judgement` TR-8.3: `xcodebuild -exportArchive -archivePath ./build/ios/Runner.xcarchive -exportOptionsPlist export_options_development.plist -exportPath ./build/ios/ipa` 成功生成 IPA

---

## [ ] Task 9: 构建脚本（build_android.sh + build_ios.sh）
- **Priority**: P1
- **Depends On**: Task 4, Task 8
- **Description**:
  - `frontend/scripts/build_android.sh`：
    - 参数 `debug` / `release`，默认 `debug`
    - 前置检查：`flutter --version`、`android/key.properties` 是否存在（release 时）
    - 环境变量：`ANDROID_KEYSTORE_PATH`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`（可选，若提供则自动写入 key.properties）
    - 执行：`flutter build apk --$mode --split-per-abi`
    - 输出：列出 APK 路径、文件大小
  - `frontend/scripts/build_ios.sh`：
    - 参数 `debug` / `release`，默认 `release`
    - 前置检查：`uname -s` 为 `Darwin`、`flutter --version`、`Xcodebuild -version`
    - 环境变量：`DEVELOPMENT_TEAM`、`EXPORT_METHOD`（app-store / ad-hoc / development）
    - 执行：`flutter build ipa --release --export-method ad-hoc`（或对应方法）
    - 输出：IPA 输出目录与文件大小
  - 两个脚本都使用中文日志，错误时以非 0 码退出
- **Acceptance Criteria Addressed**: AC-8
- **Test Requirements**:
  - `programmatic` TR-9.1: `sh scripts/build_android.sh debug` 成功结束（exit 0），输出 APK 路径
  - `programmatic` TR-9.2: 缺少 key.properties 时执行 `sh scripts/build_android.sh release` 以非 0 退出并打印"请先填写 android/key.properties"
  - `human-judgement` TR-9.3: 脚本输出清晰，中文可读，便于 CI 日志排查

---

## [ ] Task 10: README 打包与发布指南（README_PACKAGING.md）
- **Priority**: P1
- **Depends On**: Task 9
- **Description**:
  - 章节：
    1. 前置条件（Flutter SDK、Android Studio、JDK 17、Xcode、CocoaPods 版本要求）
    2. Android 构建流程（Debug → Release 签名 → keystore 生成 → key.properties 填写 → 构建 → 验证）
    3. iOS 构建流程（`pod install` → 签名配置 → Archive → 导出 IPA → 上传到 App Store Connect）
    4. 常见问题排查（依赖解析失败、非 ASCII 路径、签名错误、CocoaPods CDN 失败）
    5. 阿里云镜像与 Google/Maven 仓库开关说明
    6. `key.properties`、`*.keystore`、`ExportOptions.plist` 中真实 team ID 的安全提示（不要提交到 Git）
  - 附带：常见命令速查表（`flutter build apk`、`flutter build appbundle`、`flutter build ios`、`flutter build ipa`、`keytool` 生成命令）
- **Acceptance Criteria Addressed**: AC-9, AC-10
- **Test Requirements**:
  - `human-judgement` TR-10.1: 新开发者阅读文档后可以在 30 分钟内完成 Android/iOS 构建
  - `human-judgement` TR-10.2: 文档包含清晰的安全提示，强调签名密钥不在版本控制中
  - `programmatic` TR-10.3: README_PACKAGING.md 文件存在且路径正确（`frontend/README_PACKAGING.md`）

---

## 可并行执行的任务组
- **Task 2~6（Android 整体）** 与 **Task 7~8（iOS 整体）** 可完全并行执行，互不依赖
- Task 9 依赖 Task 4（Android 签名机制）与 Task 8（iOS 签名配置），需在它们之后
- Task 10 可与 Task 9 并行，或在 Task 9 之后

## 里程碑
- **Milestone A (Android MVP)**: Task 2~4 完成 → 可生成签名 release APK
- **Milestone B (iOS MVP)**: Task 7~8 完成 → 可在 Xcode Archive 生成 IPA
- **Milestone C (开发者友好)**: Task 9~10 完成 → 一键脚本与 README 就绪
