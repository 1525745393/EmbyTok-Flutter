# EmbyTok Flutter - 原生打包（Android/iOS）产品需求文档

## Overview
- **Summary**: 为 EmbyTok Flutter 客户端配置完整的 Android 与 iOS 原生打包方案，包含项目脚手架、签名配置、构建脚本与发布指南，使应用能够在真机上安装、运行并发布到应用商店。
- **Purpose**: 目前项目仅包含 Flutter 业务代码（lib/），android/ 与 ios/ 目录为空，无法生成原生 APK / IPA 安装包；同时缺失签名与混淆配置，无法满足应用商店发布要求。本 Spec 补齐这一缺口。
- **Target Users**:
  - Flutter 开发者（本地构建 debug/release 包）
  - CI/CD 工程师（自动化签名与打包）
  - 应用发布者（发布到 Google Play / App Store / TestFlight）

## Goals
1. 为 Android 建立完整 Gradle 工程结构，支持 `flutter build apk` 生成 debug + release APK
2. 为 Android 配置 release 签名机制，生成可上传的签名 release APK
3. 为 Android 配置 ProGuard/R8 混淆规则，确保第三方库（dio、video_player 等）在 release 下不报错
4. 为 iOS 建立完整 Xcode 工程结构（Runner），支持 `flutter build ios` 与 Archive
5. 为 iOS 配置 Info.plist 权限声明（网络、视频播放等）与签名相关说明
6. 提供构建脚本和一键命令，降低开发者心智负担
7. 提供签名与发布指南，包含 Google Play 与 App Store 基本流程

## Non-Goals (Out of Scope)
- 不涉及 Google Play / App Store 的具体审核素材（截图、文案、隐私政策页等）
- 不实现 iOS 端的 Apple Developer 账号具体证书/描述文件的管理工具（仅给出标准 xcodebuild 命令流）
- 不实现应用内购买、推送通知等需要额外原生插件的功能
- 不处理 Android TV / Android Auto / Wear OS 等额外平台
- 不处理 iOS 端的 Widget、App Clip 等扩展功能
- 不实现自动上传到商店的 CI/CD 流水线（仅提供本地构建脚本与说明）

## Background & Context
- EmbyTok Flutter 当前版本：`0.1.0`，包名：`embbytok_flutter`，SDK：`flutter: ">=3.10.0"`，Dart：`">=3.0.0 <4.0.0"`
- 依赖：`flutter_riverpod: ^2.5.0`、`go_router: ^13.0.0`、`dio: ^5.4.0`、`shared_preferences: ^2.2.0`、`cached_network_image: ^3.3.0`、`intl: ^0.19.0`、`connectivity_plus: ^5.0.0`、`video_player: ^2.8.0`
- Android 侧：`android/` 目录当前仅含 `.gitkeep`，需要从零创建 Flutter 3.x 标准工程
- iOS 侧：`ios/` 目录当前仅含 `.gitkeep`，需要从零创建 Flutter 3.x 标准工程
- 当前 minSdkVersion：计划 Android 21 (5.0 Lollipop)，compileSdkVersion：34（Android 14）
- iOS 目标：iOS 12.0 及以上

## Functional Requirements
- **FR-1**: Android 目录存在完整 Gradle 工程（settings.gradle / build.gradle / app/build.gradle / gradle-wrapper.properties），运行 `flutter build apk --debug` 在空签名下可编译通过
- **FR-2**: Android release 签名：项目包含 `key.properties` 模板 + `app/build.gradle` 中 `signingConfigs` 配置，可读取 keystore 信息并完成签名
- **FR-3**: AndroidManifest.xml 声明 `INTERNET` 权限与应用入口 Activity，并配置正确的 `applicationId`（`com.embbytok.app`）
- **FR-4**: Android ProGuard/R8 规则：`android/app/proguard-rules.pro` 中包含 `dio`、`video_player`、`shared_preferences`、`connectivity_plus` 的必要保留规则，release 构建不出现 `ClassNotFoundException`
- **FR-5**: iOS 目录存在完整 Runner 工程骨架（`Runner.xcworkspace`、`Info.plist`、`Podfile`），运行 `flutter build ios --config-only` / 手动 pod install 后可在 Xcode 打开
- **FR-6**: iOS Info.plist 声明 `NSAppTransportSecurity`（允许 HTTP 请求，因部分 Emby Server 可能部署在内网 HTTP 下）与 `CFBundleShortVersionString` / `CFBundleVersion` 动态版本号占位
- **FR-7**: iOS `Bundle Identifier` 配置为 `com.embbytok.app`，`MinimumOSVersion` 设置为 `12.0`
- **FR-8**: 提供 `build_android.sh` / `build_ios.sh` 构建脚本，包含环境检查、签名参数注入与输出路径打印
- **FR-9**: 提供 `README_PACKAGING.md` 文档，描述 Android/iOS 的完整构建、签名与发布流程（含 keystore 生成、iOS 证书、App Store Connect 基本步骤）
- **FR-10**: Android 在非 ASCII 路径下构建时（Windows 场景），`gradle.properties` 中包含 `android.overridePathCheck=true`，避免 AGP 路径检查失败
- **FR-11**: Android 仓库采用"阿里云镜像 + google() + mavenCentral() 兜底"策略，避免国内开发者遇到依赖解析失败；同时保留 `google()` + `mavenCentral()` 作为国际开发者的默认路径
- **FR-12**: 国际化支持：Android strings.xml 定义 app_name（`EmbyTok`），iOS Info.plist 中 `CFBundleDisplayName` 对应 `EmbyTok`

## Non-Functional Requirements
- **NFR-1 (性能)**: release APK 大小应尽量 < 40MB（ARM64 + armeabi-v7a 拆分）；IPA 大小 < 50MB
- **NFR-2 (可靠性)**: release 构建应与 debug 构建行为一致，不出现"release 下崩溃但 debug 下正常"的问题
- **NFR-3 (可维护性)**: 所有签名敏感信息（keystore 密码、iOS 证书 ID）不得硬编码在版本控制中，统一通过环境变量或本地未提交文件读取
- **NFR-4 (兼容性)**: Android 最低 API 21，最高 API 34；iOS 最低 12.0
- **NFR-5 (安全性)**: Android release 开启 R8 混淆与 zipAlign；iOS 开启 `Dead Code Stripping` 与 `Strip Debug Symbols`
- **NFR-6 (可测试性)**: 构建脚本有基本的前置条件检查（如 Flutter 版本、keystore 文件是否存在），失败时输出明确中文错误信息

## Constraints
- **Technical**: Flutter 3.10+ / Dart 3.0+ / AGP 7.4+ / Xcode 14+；Android 使用 Kotlin DSL 或 Groovy（本项目采用 Groovy 以与大多数 Flutter 模板对齐）；iOS 使用 CocoaPods
- **Business**: 不提供真实签名证书，仅提供模板与流程；开发者需自备 keystore / Apple Developer 账号
- **Dependencies**: 依赖 `com.android.tools.build:gradle`、`org.jetbrains.kotlin:kotlin-gradle-plugin`、CocoaPods 的 `Firebase/CoreOnly`（若不需要可移除，默认不引入）

## Assumptions
- 开发者已安装 Flutter SDK 3.10+、Android Studio（带 Android SDK）、JDK 17（AGP 8.x 推荐）
- iOS 侧开发者使用 macOS + Xcode 14+
- Emby Server 的 `playbackUrl` 可能是 HTTP 或 HTTPS，因此 iOS 需要放宽 ATS（`NSAppTransportSecurity` 至少允许任意加载，或在 Info.plist 中声明 `NSAllowsArbitraryLoads=true`）
- 本项目视频内容为用户自有媒体，不涉及第三方版权，无需 App Store 额外版权证明

## Acceptance Criteria

### AC-1: Android Gradle 工程完整
- **Given**: 开发者在 `frontend/` 目录执行 `flutter build apk --debug`
- **When**: Flutter 环境正常（无 Android Studio 许可证问题）
- **Then**: 编译成功，在 `frontend/build/app/outputs/flutter-apk/` 生成 `app-debug.apk`
- **Verification**: `programmatic`（检查文件是否存在 + `adb install` 成功）
- **Notes**: 本 AC 仅要求 debug 签名通过，不验证 release 签名

### AC-2: Android release 签名 APK 生成
- **Given**: 开发者已生成 keystore、填写 `android/key.properties`（含 `storePassword`、`keyPassword`、`keyAlias`、`storeFile`）
- **When**: 执行 `flutter build apk --release`
- **Then**: `build/app/outputs/flutter-apk/app-release.apk` 存在，且 `keytool -printcert -jarfile app-release.apk` 显示非 `CERT` debug 指纹
- **Verification**: `programmatic`（shell 命令检查）

### AC-3: Android ProGuard 安全
- **Given**: release APK 已生成
- **When**: 启动应用并进入任意页面后执行 10 秒基础操作（登录、刷新、播放视频）
- **Then**: 无 `ClassNotFoundException`、`NoSuchMethodError`、`MissingPluginException` 等混淆相关崩溃
- **Verification**: `human-judgment`（Logcat 检查）

### AC-4: Android 权限与包名正确
- **Given**: 使用 `aapt dump badging app-release.apk`
- **When**: 读取包名和 uses-permission 列表
- **Then**: package name 为 `com.embbytok.app`，且包含 `android.permission.INTERNET`
- **Verification**: `programmatic`（shell 命令检查）

### AC-5: iOS Runner 工程可打开
- **Given**: macOS + Xcode 14+ + CocoaPods 已安装
- **When**: 在 `frontend/` 执行 `flutter build ios --config-only`，然后 `cd ios && pod install`，最后 `open Runner.xcworkspace`
- **Then**: Xcode 正常打开工程，Target > Runner > Signing & Capabilities 可见 Bundle Identifier `com.embbytok.app` 且无红色错误（需开发者填入自己的签名 Team）
- **Verification**: `human-judgment`（手动在 Xcode 中验证）

### AC-6: iOS Info.plist 权限与版本号声明
- **Given**: 使用 `/usr/libexec/PlistBuddy` 或 Xcode 查看 `ios/Runner/Info.plist`
- **When**: 检查关键字段
- **Then**: 存在 `CFBundleShortVersionString`、`CFBundleVersion`、`NSAppTransportSecurity`（含 `NSAllowsArbitraryLoads = true`）、`UIApplicationSceneManifest`（Flutter 标准）
- **Verification**: `programmatic`（PlistBuddy shell 检查）

### AC-7: iOS Archive 成功
- **Given**: Xcode 已配置签名证书（开发者证书 + 描述文件）
- **When**: 在 Xcode 中选择 "Product > Archive"
- **Then**: Archive 成功出现在 Organizer，可导出为 IPA 或上传到 App Store Connect
- **Verification**: `human-judgment`（Xcode 手动验证）

### AC-8: 构建脚本可运行
- **Given**: 开发者按照 README 填好相关签名参数
- **When**: 执行 `sh scripts/build_android.sh release` 或 `sh scripts/build_ios.sh release`
- **Then**: 脚本输出友好中文日志，构建成功时打印 APK/IPA 最终路径；构建失败时提前退出并打印具体原因
- **Verification**: `human-judgment`（脚本执行 + 输出检查）

### AC-9: README 流程可复现
- **Given**: 新开发者拿到代码仓库
- **When**: 按 `README_PACKAGING.md` 的"Android 构建流程"和"iOS 构建流程"顺序执行
- **Then**: 可在 30 分钟内成功生成 APK 和 IPA（不包括 Flutter SDK 安装时间）
- **Verification**: `human-judgment`（新成员可复现性评估）

### AC-10: 敏感信息不在版本控制中
- **Given**: `git status`
- **When**: 检查仓库文件列表
- **Then**: `key.properties`、`*.keystore`、`ios/Runner/GoogleService-Info.plist`（若有）被 `.gitignore` 忽略
- **Verification**: `programmatic`（检查 `.gitignore` 与 `git check-ignore`）

## Open Questions
- [ ] 是否需要支持 Android App Bundle (AAB)？当前规划仅 APK，后续可按需补充 AAB 发布流程
- [ ] iOS 是否需要支持 "通过 Flutter 2.x 旧工程迁移"？当前按新建工程处理
- [ ] 是否需要引入 fastlane 自动化上传到商店？当前规划仅提供本地构建脚本
- [ ] Android 是否需要支持 armeabi-v7a 之外的 ABIs 拆分？当前规划默认 arm64-v8a + armeabi-v7a
