# EmbyTok 打包与发布指南

本指南描述如何将 EmbyTok Flutter 项目打包为 Android APK / AAB 与 iOS IPA 并发布到应用商店。

> 本文档对应项目根目录下的 `scripts/` 目录内封装好的构建脚本，推荐直接使用脚本而非手动键入 `flutter build` 命令。

---

## 1. 前置条件

| 工具 | 版本要求 | 说明 |
| --- | --- | --- |
| Flutter SDK | 3.10+ | `flutter --version` 验证 |
| Dart SDK | 3.0+ | 随 Flutter 提供 |
| Android Studio | Arctic Fox+ | 提供 Android SDK 与 JDK |
| JDK | 17 | 部分 Flutter / Gradle 插件要求 JDK 17 |
| Android SDK Platform | 34 | 在 Android Studio SDK Manager 中安装 |
| Android SDK Build-Tools | 34.0.0 | 同上 |
| macOS | 12+ | 构建 iOS / IPA 需要（Android 无此要求） |
| Xcode | 14+ | 包含 `xcodebuild` 与 iOS SDK |
| CocoaPods | 1.12+ | `pod --version` 验证 |

执行环境自检：

```bash
flutter doctor -v
```

---

## 2. 环境变量配置

在 `~/.bash_profile` / `~/.zshrc` 中添加以下内容（路径请根据本机实际情况修改）：

```bash
# Flutter
export PATH="$HOME/flutter/bin:$PATH"

# Android SDK
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$PATH"

# JDK（Android Studio Arctic Fox 自带 JDK 17，指向其 jbr 目录即可）
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
```

Windows 用户请在「系统 → 高级系统设置 → 环境变量」中进行等效配置。

配置完成后：

```bash
source ~/.zshrc
flutter doctor --android-licenses
```

---

## 3. Android 构建流程

### 3.1 Debug 构建（一行命令）

```bash
cd frontend
sh scripts/build_android.sh debug
```

脚本会自动完成 `flutter build apk --debug --split-per-abi`，并在 `build/app/outputs/flutter-apk/` 下打印出所有 `.apk` 的路径与大小。

### 3.2 Release 签名构建

正式发布必须走 release + 签名的流程。

#### 3.2.1 生成 keystore

```bash
keytool -genkey -v \
  -keystore android/embbytok-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 36500 \
  -alias embbytok
```

> 按提示填写国家、组织、名称等信息，注意两次输入的 keystore 密码与 key 密码。建议 alias 固定使用 `embbytok` 与模板一致。
> 生成后 **立即把 `android/embbytok-keystore.jks` 离线备份**，并确认 `.gitignore` 已忽略。

#### 3.2.2 配置 key.properties

将 `android/key.properties.template`（如项目中已提供）复制为 `android/key.properties`，并填入：

```properties
storePassword=你的keystore密码
keyPassword=你的key密码
keyAlias=embbytok
storeFile=embbytok-keystore.jks
```

> `storeFile` 建议写相对路径，让 Gradle 在 `android/` 目录下找到 jks；如写绝对路径请使用 `/Users/xxx/.../android/embbytok-keystore.jks`。

> **自动化提示**：若 CI/CD 设置了环境变量 `ANDROID_KEYSTORE_PATH`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`，脚本会自动生成 `android/key.properties`（仅当文件不存在时）。

#### 3.2.3 执行构建命令

```bash
cd frontend
sh scripts/build_android.sh release
```

脚本等价于执行：

```bash
flutter build apk --release --split-per-abi \
  --obfuscate --split-debug-info=./build/debug-info \
  --no-tree-shake-icons
```

产物位于：

```
build/app/outputs/flutter-apk/
  app-armeabi-v7a-release.apk
  app-arm64-v8a-release.apk
  app-x86_64-release.apk
```

同时脚本会为每一个 apk 打印体积大小，便于验证。

#### 3.2.4 验证签名 APK

构建完成后可以用以下命令二次确认签名有效：

```bash
# 验证 APK 签名（JDK 提供）
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# 使用 keytool 查看签名信息（APK 内 v1 签名）
unzip -p build/app/outputs/flutter-apk/app-arm64-v8a-release.apk 'META-INF/*.RSA' | keytool -printcert

# 用 aapt 查看包名与版本（aapt 在 Android SDK build-tools 中）
aapt dump badging build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | head -20
```

输出中如果能看到 `CN=...` 且末尾提示 `jar verified`，即代表签名有效。

### 3.3 App Bundle (AAB)（可选）

Google Play 推荐使用 AAB 发布，可自动根据设备分发优化体积：

```bash
flutter build appbundle --release --obfuscate --split-debug-info=./build/debug-info
```

产物位于：

```
build/app/outputs/bundle/release/app-release.aab
```

### 3.4 常见问题

| 问题 | 可能原因 | 解决方法 |
| --- | --- | --- |
| 依赖解析失败 | Gradle 镜像不通、代理错误 | 见「7. 阿里云镜像配置」 |
| 路径含中文（`mergeDebugResources` 报错） | Windows 用户名含中文、项目路径含中文 | 在 `android/gradle.properties` 中添加 `android.overridePathCheck=true`；或把项目移动到英文路径 |
| keystore 丢失 | 硬盘损坏、误删 | 使用离线备份重新放置；否则应用商店无法以相同签名更新 |
| 签名失败 | `key.properties` 中密码/别名错误、jks 路径找不到 | 使用 `keytool -list -v -keystore android/embbytok-keystore.jks` 手动验证 jks |
| ProGuard 混淆崩溃 | 插件 native 代码被误删 | 在 `android/app/proguard-rules.pro` 添加插件文档提供的 `-keep` 规则 |

---

## 4. iOS 构建流程

> iOS 构建必须在 **macOS + Xcode** 环境下执行。

### 4.1 首次构建准备

```bash
cd frontend
flutter pub get
cd ios
pod install --repo-update
open Runner.xcworkspace    # 在 Xcode 中打开
```

### 4.2 签名配置

1. Xcode → 打开项目 → 左侧 `Runner` → 顶部 `Signing & Capabilities`
2. 勾选 **Automatically manage signing**
3. 选择你的 **Team**（Apple Developer 账号）
4. 修改 **Bundle Identifier**（例如 `com.embbytok.app`），必须与 App Store Connect 中已登记的 ID 一致
5. 选中 Deployment Target ≥ 12.0，确保覆盖绝大多数设备

### 4.3 Archive 流程

1. Xcode 顶部菜单 `Product → Archive`（先选择真机 `Any iOS Device (arm64)` 作为目标，不要选模拟器）
2. Archive 成功后弹出 Organizer 窗口
3. 点击 **Distribute App** → 选择 **App Store Connect** → **Upload** 或 **Export**
4. 按照向导勾选「Rebuild from bitcode」「Strip Swift symbols」，完成上传

> 若要在多机一致地导出，可把导出选项保存为 `ios/ExportOptions.plist`，交给 `xcodebuild -exportArchive` 或 CI 工具使用。

### 4.4 使用脚本一键构建

```bash
cd frontend
sh scripts/build_ios.sh release development      # 内部测试 / 真机调试
sh scripts/build_ios.sh release ad-hoc           # 企业内部分发
sh scripts/build_ios.sh release app-store        # 上架 App Store
```

脚本内部会执行：

```bash
flutter pub get
cd ios && pod install --repo-update && cd ..
flutter build ipa --release --export-method <method> \
  --obfuscate --split-debug-info=./build/debug-info
```

产物位于：

```
build/ios/ipa/EmbyTok.ipa
```

### 4.5 上传到 App Store Connect

**方式一：Xcode Organizer**

上一节 Archive 成功后直接点 Distribute App → Upload。

**方式二：命令行 `altool`**

```bash
xcrun altool --upload-app \
  -f build/ios/ipa/EmbyTok.ipa \
  -t ios \
  -u your_apple_id@example.com \
  -p "你的App专用密码"
```

> App 专用密码在 [Apple ID 账号管理页](https://appleid.apple.com/) → 「安全」→ 「App 专用密码」生成。

---

## 5. 版本号管理

Flutter 项目的版本号统一在 `pubspec.yaml` 中定义：

```yaml
name: embbytok_flutter
description: "EmbyTok Flutter"
publish_to: 'none'
version: 0.1.0+1        # ← 这里控制版本号
```

- `0.1.0` → `versionName`（Android）/ `CFBundleShortVersionString`（iOS），用户可见
- `+1` → `versionCode`（Android）/ `CFBundleVersion`（iOS），商店内部版本号，**必须单调递增**

每次发布前请至少把 `+N` 自增 1，否则应用商店会拒绝上传。

若需要在构建时覆盖：

```bash
flutter build apk --release --build-name=0.2.0 --build-number=5
```

---

## 6. 安全提示 ⚠️

> 以下内容极为重要，发布流程请务必逐条确认。

```
┌──────────────────────────────────────────────────────────┐
│  安全提示                                               │
├──────────────────────────────────────────────────────────┤
│  • 绝不将 android/key.properties、*.jks、*.keystore       │
│    提交到 Git 仓库（.gitignore 已忽略，但请再次确认）        │
│  • iOS 证书（.cer / .p12）与 Provisioning Profile         │
│    (.mobileprovision) 也不要提交到 Git                    │
│  • 所有签名密钥必须离线备份（离线硬盘/密码管理器），           │
│    一旦丢失，将无法在同一签名下更新已上架的应用               │
│  • 若手动编辑 ios/ExportOptions.plist 填写了 Team ID，      │
│    此文件也应加入 .gitignore（或只保留模板文件）             │
│  • CI/CD 中使用环境变量注入敏感信息，不要把密码写进配置文件    │
└──────────────────────────────────────────────────────────┘
```

---

## 7. 阿里云镜像配置（国内开发者可选）

### 7.1 Android Gradle 镜像

在 `android/settings.gradle` 中注释默认 `google()` / `mavenCentral()`，替换为阿里云镜像：

```groovy
pluginManagement {
    repositories {
        // google()
        // mavenCentral()
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/public' }
        maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        // google()
        // mavenCentral()
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/public' }
    }
}
```

也可以在 `~/.gradle/init.gradle` 中配置全局镜像：

```groovy
allprojects {
    repositories {
        all { ArtifactRepository repo ->
            if (repo instanceof MavenArtifactRepository) {
                def url = repo.url.toString()
                if (url.startsWith('https://repo.maven.apache.org/maven2')
                    || url.startsWith('https://jcenter.bintray.com')
                    || url.startsWith('https://repo1.maven.org/maven2')) {
                    project.logger.lifecycle "Repository ${repo.url} replaced by Aliyun mirror."
                    remove repo
                }
            }
        }
        maven { url 'https://maven.aliyun.com/repository/public' }
        maven { url 'https://maven.aliyun.com/repository/google' }
    }
}
```

### 7.2 iOS CocoaPods 镜像

`pod install` 在国内访问默认仓库可能较慢，可以切换到清华 TUNA 镜像：

```bash
cd ios
pod repo remove master
pod repo add master https://mirrors.tuna.tsinghua.edu.cn/git/cocoapods/specs.git
pod install --repo-update
```

或者在 `ios/Podfile` 顶部声明 `source`：

```ruby
source 'https://mirrors.tuna.tsinghua.edu.cn/git/cocoapods/specs.git'
```

---

## 8. 常见问题速查表

| 错误 / 现象 | 解决方法 |
| --- | --- |
| Gradle 依赖下载超时（`Could not resolve ...`） | 切换到阿里云镜像 / 检查科学上网代理；或在 `android/gradle.properties` 设置 `systemProp.http(s).proxyHost` |
| `Execution failed for task ':app:mergeDebugResources'.` | 项目路径/用户路径含中文 → `android/gradle.properties` 中添加 `android.overridePathCheck=true` |
| iOS `pod install` 卡死 | 执行 `pod repo update`；或按「7.2」切换到国内镜像仓库 |
| Xcode signing fails（`Code Signing Error`） | 检查 Signing & Capabilities 中的 Team 与 Bundle Identifier；确认 Provisioning Profile 与所选证书匹配 |
| `No Provisioning Profile found` | 在 Xcode 中勾选「Automatically manage signing」，让 Xcode 自动生成；或在 Apple Developer 网站手动生成 |
| `archive 时找不到 scheme` | 打开 `Runner.xcworkspace`（不是 `Runner.xcodeproj`），执行一次 `Product → Build` 即可刷新 scheme |
| Flutter `--obfuscate` 导致崩溃 | 确保同时使用 `--split-debug-info` 生成符号文件，便于后续符号化崩溃日志；某些反射插件需要在 ProGuard / 混淆规则中排除 |

---

## 9. 命令速查表

| 操作 | 命令 |
| --- | --- |
| 环境自检 | `flutter doctor -v` |
| 安装依赖 | `flutter pub get` |
| Android Debug 构建 | `sh scripts/build_android.sh debug` |
| Android Release 构建 | `sh scripts/build_android.sh release` |
| Android App Bundle | `flutter build appbundle --release --obfuscate --split-debug-info=./build/debug-info` |
| 安装到设备 | `adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |
| 查看已连接设备 | `adb devices` |
| iOS Pod 安装 | `cd ios && pod install --repo-update` |
| iOS Debug 构建（脚本） | `sh scripts/build_ios.sh debug development` |
| iOS Release 构建（脚本） | `sh scripts/build_ios.sh release app-store` |
| iOS 手动 Archive | `open ios/Runner.xcworkspace` → `Product → Archive` |
| 上传 IPA 到 App Store Connect | `xcrun altool --upload-app -f build/ios/ipa/EmbyTok.ipa -t ios -u <邮箱> -p <App专用密码>` |
| 查看版本号 | `grep '^version:' pubspec.yaml` |
| 覆盖版本号构建 | `flutter build apk --release --build-name=0.2.0 --build-number=5` |
| 验证 APK 签名 | `jarsigner -verify -verbose -certs <apk_path>` |

---

## 10. 脚本使用概览

```
/workspace/frontend/
├── scripts/
│   ├── build_android.sh     # Android APK 构建脚本（debug / release）
│   └── build_ios.sh         # iOS IPA 构建脚本（macOS 专用）
├── android/
│   └── key.properties       # release 签名配置（手动创建，不要提交 Git）
├── ios/
│   ├── Podfile              # iOS 依赖管理
│   └── Runner.xcworkspace   # Xcode 打开入口
├── pubspec.yaml             # 版本号 & 依赖
└── README_PACKAGING.md      # 本文件
```

祝发布顺利 🚀
