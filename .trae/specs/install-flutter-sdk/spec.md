# Flutter SDK 本地环境安装 - Product Requirement Document

## Overview
- **Summary**: 在当前 Ubuntu 24.04 本地开发容器中，将已存在于 `/opt/flutter` 的 Flutter SDK 注册为可用开发工具，完成 PATH 持久化、依赖预缓存、Android SDK 安装与 Android licenses 接受，最终满足 EmbyTok-Flutter 项目对 Flutter/Dart 的版本约束，并可执行 `flutter test` 单元测试、`flutter analyze` 静态检查与 `flutter build apk` 构建。
- **Purpose**: 解决"Flutter 命令找不到"与"不能在本地验证测试/构建"的问题，避免所有代码修改只能依赖 GitHub Actions 的 CI 反馈，大幅缩短验证周期。
- **Target Users**: EmbyTok-Flutter 项目开发者（AI 代理与本地开发人员）。

## Goals
- 任意新开 shell 会话中 `which flutter` 找到 Flutter，且 `flutter --version` 版本满足 `>= 3.10.0`。
- 在 `frontend/` 目录下 `flutter pub get` 成功，无版本解算失败。
- 在 `frontend/` 目录下 `flutter test` 可启动（测试通过与否由用例本身决定，但 CLI 不能报"命令找不到/SDK 未配置"）。
- 在 `frontend/` 目录下 `flutter analyze` 可启动（分析结果不阻断安装，但 CLI 本身必须正常）。
- Android toolchain 可用：Android SDK 安装完毕、compileSdk 35 相关平台/构建工具存在、licenses 已接受，`flutter build apk` 可进入构建阶段。
- `flutter doctor -v` 输出中 Flutter、Android toolchain 两项不标为严重问题（可接受 Connected device、Chrome、IDE、Network resources 项为 [!] 或缺失）。

## Non-Goals (Out of Scope)
- 不安装 Xcode/iOS 工具链（当前平台为 Linux，物理上不支持 iOS 构建）。
- 不配置物理 Android 设备连接（USB 驱动、WLAN 调试不在环境范围）。
- 不启动 Android Emulator（需 KVM 加速和图形栈，容器中不保证）。
- 不安装 Android Studio IDE（仅保留 commandline-tools + platform/build-tools）。
- 不修改 CI 工作流文件 `.github/workflows/*.yml`（CI 已有独立 Flutter 安装流程）。

## Background & Context
- 当前环境：Ubuntu 24.04.3 LTS，PATH 中已存在 Node、Java 25、Gradle 8.14、Python、Ruby 等，但缺少 `/opt/flutter/bin`。
- Flutter SDK 已物理存在于 `/opt/flutter`（仓库文件、DEPS、CHANGELOG.md 均齐备），但未被激活。
- 项目 [pubspec.yaml](file:///workspace/frontend/pubspec.yaml#L7-L9) 约束：`sdk: ">=3.0.0 <4.0.0"`，`flutter: ">=3.10.0"`。
- [build.gradle](file:///workspace/frontend/android/app/build.gradle#L47-L49) `compileSdk` 已升级为 35，要求 Android SDK Platform 35 和 Build-Tools。
- 之前多次代码修复（如类型安全解析、测试断言、缓存逻辑、刘海屏适配）均因容器内无 Flutter CLI，无法在提交前执行本地 `flutter test` 验证，只能靠静态代码审查。

## Functional Requirements
- **FR-1**: 安装任务将 `/opt/flutter/bin` 持久化加入 shell 的 PATH（`~/.zshrc` 或 `~/.profile` 中明确写入导出，对当前用户所有未来 shell 会话生效）。
- **FR-2**: 对 Flutter SDK 执行一次 `flutter precache`，拉取 Dart SDK、Android/ Linux 平台工件，避免首次命令调用出现启动锁 / 下载超时问题。
- **FR-3**: 安装 Android SDK Command-line Tools、Platform Tools、Build-Tools（对应 `compileSdk 35`）、Android 35 Platform，放置在 `$HOME/Android/Sdk`，设置 `ANDROID_HOME` 与 `ANDROID_SDK_ROOT` 环境变量持久化。
- **FR-4**: 使用 `flutter doctor --android-licenses` 或以 sdkmanager 等价方式接受 Android SDK licenses，无未接受许可证阻碍 APK 构建。
- **FR-5**: 验证脚本可一次性输出环境健康快照：Flutter 版本、Dart 版本、`flutter doctor` 摘要、`flutter analyze --no-pub --congratulate` 是否能正常启动、`flutter test --no-pub` 是否能进入执行阶段（不要求用例全绿）。

## Non-Functional Requirements
- **NFR-1 (Performance)**: 整个安装流程从 0 到可运行不得超过 10 分钟（假定网络正常，不含 Flutter SDK 本身已存在的时间）。可接受下载依赖部分为网络 IO 主导。
- **NFR-2 (Idempotency)**: 安装脚本必须幂等：重跑时已存在的 Flutter/Android 工件不重复下载，许可证接受不重复交互；已写入 PATH 的导出语句重复执行也不产生冲突。
- **NFR-3 (Non-Interactive)**: 所有安装步骤不得要求人工输入，`yes |` 或 `--licenses` 的非交互参数必须齐全，容器内无人值守下可完成。
- **NFR-4 (Reversibility)**: 不对 `/opt/flutter` 做写入或破坏性操作（仅读，可选改用户级 pub cache），Android SDK 全部写入用户目录 `$HOME/Android/Sdk`，不污染系统分区。
- **NFR-5 (Clarity)**: 安装失败时返回的退出码和日志必须可定位（哪一步失败、什么命令失败、原始 stdout/stderr 至少最后 40 行可见）。

## Constraints
- **Technical**:
  - 操作系统：Ubuntu 24.04.3 LTS (x86_64)，无 root 以外用户；使用 zsh 作为主 shell。
  - Flutter SDK 已存在于 `/opt/flutter`（**不得重新下载**，直接复用）。
  - Java 已通过 mise 安装（Java 25，sdkmanager 需要 Java 运行，这里可接受降级 17 或保持 25，视 sdkmanager 兼容性而定）。
  - 网络可访问 `storage.googleapis.com`、`dl.google.com`、`pub.dev`。
- **Business**:
  - 不得修改 CI 工作流、不得触发不必要的远程流水线构建。
  - 不得向仓库中提交任何本地机器私有配置（`local.properties`、`~/.gitconfig` 个人密钥、PAT 等）。
- **Dependencies**:
  - Flutter SDK 依赖：`curl`、`unzip`、`git`、`xz-utils`、`libglu1-mesa`、`lib32stdc++6`、`pkg-config`、`libgtk-3-0`、`clang`、`cmake`、`ninja-build`、`pkg-config`、`liblzma-dev`、`libstdc++-12-dev`（`flutter doctor` 会提示缺失，但项目以 Android 为主，缺失其中几项不强求安装；至少 `clang/cmake/ninja/libstdc++-12-dev` 保证 Linux 桌面构建不报错）。

## Assumptions
- Flutter SDK 位于 `/opt/flutter` 的版本满足 `>= 3.10.0`。若实际版本不满足，需在安装过程中 `git checkout stable` 或通过 `flutter channel stable && flutter upgrade` 升级，但升级操作需单独在 FR 下附加（此处先按"满足"假设，不足时作为回滚/偏差处理）。
- `sdkmanager` 版本兼容 Java 25。若不兼容，需改为 mise 安装 Java 17（通过 JAVA_HOME 覆盖）后再执行 sdkmanager。
- Android SDK `platforms;android-35` 和 `build-tools;35.x.x` 已在 Google 仓库发布可用。

## Acceptance Criteria

### AC-1: Flutter CLI 全局可用与版本合规
- **Given**: 开启一个新的 shell 会话（非交互式 login shell，例如 `zsh -lc "which flutter"` 模拟）。
- **When**: 执行 `which flutter` 与 `flutter --version`。
- **Then**: 1. `which flutter` 返回以 `/opt/flutter/bin/flutter`（或等价路径）结尾的绝对路径；2. `flutter --version` 的 Flutter 版本号字符串中主/次版本号满足 `>= 3.10.0`；3. Dart SDK 版本位于 `>= 3.0.0 <4.0.0`。
- **Verification**: `programmatic`
- **Notes**: 可直接用 grep 截取版本号后对比。

### AC-2: flutter pub get 在 frontend 目录成功
- **Given**: 已满足 AC-1。
- **When**: 在 `/workspace/frontend` 下执行 `flutter pub get --enforce-lockfile`（若 lockfile 冲突则退化为 `flutter pub get`）。
- **Then**: 进程退出码为 0，`pubspec.lock` 存在且包含所有依赖解析条目。
- **Verification**: `programmatic`

### AC-3: flutter test 可启动并产出结果
- **Given**: 已满足 AC-2。
- **When**: 在 `/workspace/frontend` 下执行 `flutter test --no-pub`（可选加 `--concurrency=1` 防止并发容器内存爆）。
- **Then**: 1. `flutter test` 命令本身不报 SDK/工具链配置错误；2. 命令输出包含 `All tests passed!` 或具体用例失败统计（两种结果均可，但不能是环境级报错）。
- **Verification**: `programmatic`

### AC-4: flutter analyze 可启动并产出结果
- **Given**: 已满足 AC-2。
- **When**: 在 `/workspace/frontend` 下执行 `flutter analyze --no-pub`。
- **Then**: 退出码 0（无分析错误）或非 0 但输出包含 `• issue` 格式的具体诊断行。不能输出"未配置 Dart/Flutter SDK"。
- **Verification**: `programmatic`

### AC-5: Android toolchain 可用与 licenses 全部接受
- **Given**: 已满足 AC-1。
- **When**: 执行 `flutter doctor -v`。
- **Then**: 1. `[✓] Flutter` 存在；2. `[✓] Android toolchain` 存在且文字中包含 `Android SDK at $HOME/Android/Sdk` 或 `Platform android-35, build-tools 35`；3. 输出不包含 `Some Android licenses not accepted`。
- **Verification**: `programmatic`

### AC-6: flutter build apk 可进入编译阶段
- **Given**: 已满足 AC-5。
- **When**: 在 `/workspace/frontend` 下执行 `flutter build apk --debug --no-pub`（debug 版本可避免 release 签名问题）。
- **Then**: 1. 不出现 Android SDK / licenses / SDK 版本相关报错；2. 若构建本身有代码错误，退出码非 0 也可接受，但错误必须来自 Dart/Java 编译本身而非环境缺失。
- **Verification**: `programmatic`
- **Notes**: 不强制要求最终 APK 成功生成。

### AC-7: 安装幂等性
- **Given**: 已通过 AC-1、AC-5。
- **When**: 再次完整执行安装脚本。
- **Then**: 1. 不重复下载 Android SDK；2. PATH 中不重复追加 `/opt/flutter/bin`（或虽追加但路径不重复）；3. 最终环境状态与首次安装后一致。
- **Verification**: `programmatic`

## Open Questions
- [ ] 当前 `/opt/flutter` 的实际版本号未知（仍卡启动锁中，spec 编写时尚未获取）。实施时若发现 `< 3.10.0`，是否允许在此任务中直接升级到 stable？是：在 FR 追加子项；否：降级为"回报告诉用户再手工升级"。
- [ ] Java 25 与 sdkmanager 的兼容性未知。若在实施中报 Java 版本不兼容，是否允许通过 mise 安装 Java 17 并在 sdkmanager 调用前切换 `JAVA_HOME`？是（推荐）：默认如此执行；否：退回无 Android 构建能力但保留 Flutter/Dart 测试能力。
