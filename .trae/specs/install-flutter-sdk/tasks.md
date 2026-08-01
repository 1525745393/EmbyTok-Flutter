# Flutter SDK 本地环境安装 - The Implementation Plan (Decomposed and Prioritized Task List)

## [x] Task 1: Flutter SDK PATH 注入与版本验证
- **Priority**: high
- **Depends On**: None
- **Description**:
  - 为当前用户（root）写入 `~/.zshrc` 和 `~/.profile`，以幂等方式导出 PATH（追加 `/opt/flutter/bin`，如已存在则不重复写入），并同步导出 `PUB_CACHE=$HOME/.pub-cache` 以及 `ANDROID_HOME=$HOME/Android/Sdk`、`ANDROID_SDK_ROOT=$HOME/Android/Sdk`。
  - 以 `zsh -lc` 模拟新开 login shell，验证 `which flutter` 指向 `/opt/flutter/bin/flutter`。
  - 清理 `/opt/flutter/bin/cache/lockfile` 并用 `pkill -9 -f flutter` 处理残留进程，获取 `flutter --version`。
  - 若 Flutter 版本 `< 3.10.0` 或 Dart 版本 `< 3.0.0 || >= 4.0.0`：执行 `flutter channel stable && flutter upgrade` 升级；失败则记录并中止后续 Android 步骤。
- **Acceptance Criteria Addressed**: [AC-1]
- **Test Requirements**:
  - `programmatic` TR-1.1: `zsh -lc "which flutter"` 输出包含 `/opt/flutter/bin/flutter` 且退出码为 0。
  - `programmatic` TR-1.2: `flutter --version` 的 Flutter 主/次版本号解析后 `>= 3.10.0`；Dart 版本 `>= 3.0.0 < 4.0.0`。
  - `programmatic` TR-1.3: 再次写入 PATH 导出语句不产生重复条目（或 PATH 中重复 `/opt/flutter/bin` 的次数为 1）。
- **Notes**: 不要执行 `git commit/push/stash`。只做环境编辑与脚本写入；不对 `/opt/flutter` 仓库提交变更。

## [x] Task 2: 系统依赖补齐与 Flutter 工件预缓存
- **Priority**: high
- **Depends On**: Task 1
- **Description**:
  - `apt-get install -y --no-install-recommends` 安装 Flutter/Linux 桌面构建依赖：`clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev curl unzip git xz-utils`。使用 `--no-install-recommends` 控制体积。
  - 在新 shell 中执行 `flutter config --no-analytics` 关闭遥测，再执行 `flutter precache --android --linux` 拉取 Android/Linux 平台工件。
  - 验证缓存目录 `/opt/flutter/bin/cache/artifacts/engine` 中存在 `android-arm64-release/linux-x64/` 等目录，或 `flutter precache` 退出码为 0。
- **Acceptance Criteria Addressed**: [AC-1, AC-3]
- **Test Requirements**:
  - `programmatic` TR-2.1: `apt list --installed 2>/dev/null | grep -E '^(clang|cmake|ninja-build|libgtk-3-dev|liblzma-dev|libstdc\+\+-12-dev)/'` 全部有命中。
  - `programmatic` TR-2.2: `flutter precache --android --linux` 退出码 0。
  - `programmatic` TR-2.3: `ls /opt/flutter/bin/cache/dart-sdk/bin/dart` 存在且可执行。
- **Notes**: 不要改动 /opt/flutter 下的权限归属。若 apt 源下载失败可重试 2 次，再退出报错。

## [x] Task 3: Android SDK（cmdline-tools、platform、build-tools、platform-tools）安装
- **Priority**: high
- **Depends On**: Task 2
- **Description**:
  - 检查 Java 版本。若 `java -version` 返回 `25+`，先通过 mise 安装兼容 Java 17：`mise use -g java@17`，并在后续所有 sdkmanager 调用中 `export JAVA_HOME=$(mise where java@17)`。
  - 创建目录 `$HOME/Android/Sdk/cmdline-tools/latest`。下载最新 commandlinetools-linux zip，解压到 latest 下的 bin/lib 目录（要求 `$HOME/Android/Sdk/cmdline-tools/latest/bin/sdkmanager` 存在）。
  - 使用 `yes | sdkmanager --sdk_root=$HOME/Android/Sdk --licenses` 接受已有许可证。
  - 使用 `sdkmanager --sdk_root=$HOME/Android/Sdk --install "platform-tools" "platforms;android-35" "build-tools;35.0.0" "cmdline-tools;latest"`。
  - 在 `~/.zshrc` / `~/.profile` 中追加 `$ANDROID_HOME/platform-tools` 与 `$ANDROID_HOME/cmdline-tools/latest/bin` 到 PATH（幂等）。
- **Acceptance Criteria Addressed**: [AC-5, AC-6]
- **Test Requirements**:
  - `programmatic` TR-3.1: `ls $HOME/Android/Sdk/platforms/android-35/android.jar` 存在。
  - `programmatic` TR-3.2: `ls $HOME/Android/Sdk/build-tools/35.*/aapt` 存在。
  - `programmatic` TR-3.3: `zsh -lc "sdkmanager --sdk_root=$HOME/Android/Sdk --list_installed"` 输出包含 `platforms;android-35` 与 `build-tools;35.0.0`。
- **Notes**: Java 17 兼容优先；sdkmanager 若报非法反射告警但安装成功，仅记录不阻塞。不要向仓库提交任何内容。

## [x] Task 4: Flutter Android licenses 接受、flutter doctor 校验
- **Priority**: high
- **Depends On**: Task 3
- **Description**:
  - 在新 shell 中执行 `yes | flutter doctor --android-licenses`，确保无"未接受许可证"提示。
  - 执行 `flutter config --android-sdk $HOME/Android/Sdk` 将 SDK 路径写入 Flutter 配置（如已存在可跳过）。
  - 执行 `flutter doctor -v`，确认 [✓] Flutter 与 [✓] Android toolchain 存在；其它项目可接受为 [!]（但输出不得包含 `Some Android licenses not accepted`）。
- **Acceptance Criteria Addressed**: [AC-5]
- **Test Requirements**:
  - `programmatic` TR-4.1: `flutter doctor -v` 输出同时命中 `[✓] Flutter` 和 `[✓] Android toolchain` 两行。
  - `programmatic` TR-4.2: `flutter doctor -v` 输出不包含 `Some Android licenses not accepted`。
- **Notes**: 若 Android toolchain 报 `cmdline-tools component is missing`，回到 Task 3 检查目录层级是否为 `cmdline-tools/latest/bin/sdkmanager`。

## [x] Task 5: 项目级验证（pub get、analyze、test、build smoke）
- **Priority**: high
- **Depends On**: Task 4
- **Description**:
  - `cd /workspace/frontend && flutter pub get`（优先使用 `--enforce-lockfile`，失败则降级为普通 `flutter pub get` 并记录 lockfile 漂移）。
  - `cd /workspace/frontend && flutter analyze --no-pub`：收集分析结果，不要求退出码 0，但不能报 SDK 未配置。
  - `cd /workspace/frontend && flutter test --no-pub --concurrency=1`：启动测试执行；不强制所有用例通过，但不能报环境级错误。
  - `cd /workspace/frontend && flutter build apk --debug --no-pub`：仅进入构建阶段，允许代码编译阶段失败，但不允许 Android SDK / licenses 缺失类报错。
- **Acceptance Criteria Addressed**: [AC-2, AC-3, AC-4, AC-6]
- **Test Requirements**:
  - `programmatic` TR-5.1: `pubspec.lock` 在运行后仍然存在，`flutter pub get` 退出码 0。
  - `programmatic` TR-5.2: `flutter analyze --no-pub` 的输出中，若退出码非 0，stderr/stdout 中至少一行匹配 `•.*\.dart:[0-9]+:[0-9]+`。
  - `programmatic` TR-5.3: `flutter test --no-pub --concurrency=1` 的 stdout 存在 `All tests passed!` 或 `Some tests failed.` 或 `Test failed` 或 `+X -Y: Some tests failed` 中任意一种明确结果标识（而非 "No devices connect"）。
  - `programmatic` TR-5.4: `flutter build apk --debug --no-pub` 的 stderr/stdout 不包含 `Android SDK file not found`、`Some Android licenses not accepted`、`Could not find an option named "android-sdk"` 类环境缺失报错。
- **Notes**: 运行该步骤时注意容器内存限制，可降低 concurrency=1，必要时 `flutter test` 单文件运行。不要提交变更到 git。

## [x] Task 6: 幂等性重跑校验与文档留痕
- **Priority**: medium
- **Depends On**: Task 5
- **Description**:
  - 完整重跑 Task 1~Task 4 的安装步骤（或脚本入口，如果已合并为单脚本），验证幂等：
    - PATH 追加不重复。
    - sdkmanager `--install` 不下载，提示 "All SDK package licenses accepted" 或 "Skipping 'XXX'; it is already installed."。
    - `flutter precache` 运行时间显著少于首次或直接返回。
  - 生成一次性环境快照输出文件到 `/tmp/flutter-env-snapshot.md`，内容包含：flutter --version、dart --version、flutter doctor 摘要、sdkmanager --list_installed 列表、flutter analyze 摘要、flutter test 摘要（只输出到 /tmp 不入库）。
- **Acceptance Criteria Addressed**: [AC-7]
- **Test Requirements**:
  - `programmatic` TR-6.1: 重跑安装脚本后，`zsh -lc 'echo $PATH | tr ":" "\n" | grep -c "/opt/flutter/bin"'` 计数为 1。
  - `programmatic` TR-6.2: 重跑 sdkmanager 安装命令，stdout 不出现新下载 "Downloading XXX" 字样。
  - `human-judgement` TR-6.3: 审阅 `/tmp/flutter-env-snapshot.md` 结构完整、含 6 项关键小节，字段不空。

# Task Dependencies
- [Task 2] depends on [Task 1]
- [Task 3] depends on [Task 2]
- [Task 4] depends on [Task 3]
- [Task 5] depends on [Task 4]
- [Task 6] depends on [Task 5]
