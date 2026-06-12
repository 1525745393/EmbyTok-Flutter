# EmbyTok Flutter - 完善工作流 验证检查清单

## Task 1: 根级 .gitignore 和 .editorconfig

### .gitignore 完整性
- [x] 文件存在于项目根目录
- [x] 包含 Flutter 相关忽略：`.dart_tool/`、`.pub-cache/`、`build/`、`*.flutter-plugins`、`*.flutter-plugins-dependencies`、`.packages`
- [x] 包含 Android 相关忽略：`*.jks`、`*.keystore`、`key.properties`、`android/.gradle/`、`android/local.properties`
- [x] 包含 iOS 相关忽略：`**/ios/Pods/`、`**/ios/Runner.xcworkspace/`、`**/ios/Runner.xcodeproj/project.xcworkspace/`、`**/ios/Runner.xcodeproj/xcuserdata/`
- [x] 包含 Python 相关忽略：`__pycache__/`、`*.py[cod]`、`.venv/`、`venv/`、`*.egg-info/`、`.pytest_cache/`
- [x] 包含 IDE 相关忽略：`.idea/`、`.vscode/`、`*.iml`、`*.ipr`、`*.iws`
- [x] 包含系统文件：`.DS_Store`、`Thumbs.db`
- [x] 包含日志和环境：`*.log`、`.env`、`.env.*`、`secrets/`
- [x] 包含 Docker：`*.dockerignore` 本身不忽略，但需排除镜像/容器临时文件
- [x] 不包含 `!` 反向规则使重要源代码被忽略

### .editorconfig 完整性
- [x] 文件存在于项目根目录
- [x] 包含 `root = true` 声明
- [x] `[*]` 部分包含：`charset = utf-8`、`end_of_line = lf`、`indent_style = space`、`indent_size = 4`、`insert_final_newline = true`、`trim_trailing_whitespace = true`
- [x] `[*.{yml,yaml,json}]` 配置 `indent_size = 2`
- [x] `[Makefile]` 配置 `indent_style = tab`
- [x] `[*.md]` 配置合适的换行规则

---

## Task 2: Makefile

- [x] 文件存在于项目根目录
- [x] 声明 `.PHONY` 包含所有 target
- [x] 默认 target `help` 在顶部（或通过 `.DEFAULT_GOAL := help` 声明）
- [x] `help` 命令列出所有 target 及其中文描述
- [x] 包含 `setup`：安装 Flutter + Python 依赖
- [x] 包含 `run-backend`：启动后端服务
- [x] 包含 `run-frontend`：启动 Flutter 应用
- [x] 包含 `run-all`：同时启动前后端
- [x] 包含 `stop`：停止所有服务
- [x] 包含 `test-all` / `test-frontend` / `test-backend`：运行测试
- [x] 包含 `lint`：代码质量检查
- [x] 包含 `build-apk`：构建 Android APK
- [x] 包含 `build-ios`：构建 iOS（带平台检查）
- [x] 包含 `build-docker`：构建 Docker 镜像
- [x] 包含 `clean`：清理构建产物
- [x] `make help` 执行成功，输出清晰可读
- [x] `make -n` dry-run 无语法错误

---

## Task 3: 根级 scripts 目录

### 文件存在性与权限
- [x] `scripts/` 目录存在
- [x] `scripts/setup.sh` 存在且可执行（`chmod +x`）
- [x] `scripts/run-all.sh` 存在且可执行
- [x] `scripts/run-tests.sh` 存在且可执行
- [x] `scripts/build-all.sh` 存在且可执行
- [x] `scripts/docker-push.sh` 存在且可执行

### 脚本内容质量
- [x] 所有脚本以 `#!/bin/bash` 开头
- [x] 所有脚本包含 `set -euo pipefail` 或等效错误处理
- [x] 定义统一的日志函数（如 `log_info`、`log_success`、`log_error`）
- [x] 日志输出使用中文描述
- [x] 输出包含阶段分隔线
- [x] 每个脚本执行结束后打印完成提示
- [x] `bash -n <script>` 语法检查全部通过（无语法错误）

---

## Task 4: GitHub Actions CI Workflow

### ci.yml
- [x] 文件存在于 `.github/workflows/ci.yml`
- [x] YAML 语法正确（可通过 `python -c "import yaml; yaml.safe_load(...)"` 验证）
- [x] `name` 字段存在（如 "CI - Test, Lint & Build"）
- [x] `on` 字段包含 `push`（分支）和 `pull_request`
- [x] `jobs` 至少包含一个 job（如 `test-and-lint`）
- [x] job 使用 `runs-on: ubuntu-latest`
- [x] 使用 `actions/checkout@v4` 获取源码
- [x] 使用 `subosito/flutter-action@v2` 或等效 Flutter setup
- [x] 使用 `actions/setup-python@v5` 设置 Python
- [x] 执行 `flutter pub get` 安装依赖
- [x] 执行 `flutter analyze` 进行代码分析
- [x] 执行 `flutter test --coverage` 运行测试
- [x] 执行 Docker 镜像构建与基础健康检查（`docker build ... && docker run ...`）
- [x] Python 部分执行 `pip install -r backend/requirements.txt`
- [x] 执行 `pytest` 或其他 Python 测试命令
- [x] 使用 `concurrency` 避免同一 PR 重复运行
- [x] 步骤名称使用中文，便于阅读

---

## Task 5: Android Release Workflow

### android-release.yml
- [x] 文件存在于 `.github/workflows/android-release.yml`
- [x] YAML 语法正确
- [x] `on` 字段包含 `workflow_dispatch` 和/或 `push: tags: v*`
- [x] Job 使用 `ubuntu-latest` runner
- [x] 步骤包含：checkout → flutter setup → **keystore 解码写入**（从 `secrets.ANDROID_KEYSTORE` base64）
- [x] 步骤包含：写入 `key.properties`（使用 secrets: `storePassword`/`keyPassword`/`keyAlias`）
- [x] 步骤包含：`flutter build apk --release --split-per-abi`
- [x] 步骤包含：可选的 `flutter build appbundle --release`
- [x] 步骤包含：`actions/upload-artifact@v4` 上传 APK/AAB
- [x] 文件内有中文注释说明需要配置的 secrets 列表
- [x] YAML 中不包含真实的密钥/密码值（全部通过 secrets 引用）

---

## Task 6: Docker Release Workflow

### docker-release.yml
- [x] 文件存在于 `.github/workflows/docker-release.yml`
- [x] YAML 语法正确
- [x] `on` 字段包含 `workflow_dispatch` 和/或 `push: tags: v*`
- [x] 使用 `docker/setup-qemu-action@v3` 启用多架构
- [x] 使用 `docker/setup-buildx-action@v3` 启用 buildx
- [x] 使用 `docker/login-action@v3` 登录容器 registry（通过 secret）
- [x] 使用 `docker/build-push-action@v5` 构建并推送
- [x] `platforms` 包含 `linux/amd64,linux/arm64`
- [x] `tags` 至少包含 `:latest` 和 `:${{ github.ref_name }}`
- [x] `context: backend/` 指向正确的构建上下文
- [x] 文件内有中文注释说明如何配置 Docker Hub / GHCR 相关 secrets

---

## Task 7: README 更新

- [x] `README.md` 包含「前置条件」章节：列出 Flutter 3.10+、Python 3.11+、Docker（可选）
- [x] `README.md` 包含「快速开始」章节：`make setup && make run-all` 一行命令示例
- [x] `README.md` 包含「常用命令速查表」：表格形式列出所有 make 命令
- [x] `README.md` 包含「手动启动」：无 make 环境的替代命令
- [x] `README.md` 包含 CI/CD badge 占位（如 `[![CI](...)]`）
- [ ] `README_PACKAGING.md` 中包含对 `make build-apk` / `make build-docker` 的引用（文件不存在，跳过）
- [x] Markdown 格式正确，无语法错误

---

## Task 8: Python 后端测试骨架

- [x] `backend/tests/__init__.py` 存在
- [x] `backend/tests/conftest.py` 存在（可留空或含基本 fixture）
- [x] `backend/tests/test_health.py` 存在，包含至少一个 pytest 测试用例
- [x] `backend/requirements.txt` 包含 `pytest>=7.4`（或已有更高版本）
- [x] `backend/requirements.txt` 包含 `httpx>=0.25`（或已有更高版本）
- [x] 在有正确 Python 环境时 `pytest backend/` 可执行且不报错

---

## 最终验收（跨任务综合检查）

- [x] 根目录文件列表包含：`.gitignore`、`.editorconfig`、`Makefile`、`scripts/`、`.github/workflows/`
- [x] `scripts/` 目录包含至少 4 个 shell 脚本，全部可执行
- [x] `.github/workflows/` 目录包含至少 3 个 workflow YAML 文件
- [x] 所有 YAML 文件语法正确（通过 `python -c "import yaml; yaml.safe_load(...)"` 验证）
- [x] 所有 Shell 脚本语法正确（通过 `bash -n <file>` 验证）
- [x] Makefile 无语法错误（通过 `make -n help` 或 `make -n setup` dry-run 验证）
- [x] `.gitignore` 内容合理，不会意外忽略源代码
- [x] `.editorconfig` 内容合理，与项目实际代码风格一致
- [x] README 中的「快速开始」可操作，无需翻看其他文档即可跑通

---

## 手动操作验证（在真实环境中）

以下检查点需要在具备 Flutter / Python / Docker 环境的开发者机器上执行：

- [x] `cd /workspace && make help` → 显示完整命令列表（exit 0）
- [ ] `cd /workspace && make setup` → Flutter pub get + pip install 成功（exit 0）（需要 Flutter 环境）
- [ ] `cd /workspace && make test-frontend` → flutter test 通过（需要 Flutter 环境）
- [ ] `cd /workspace && make lint` → flutter analyze 无严重错误（需要 Flutter 环境）
- [ ] `cd /workspace && make build-apk` → 输出 APK 文件（需要 Flutter 环境）
- [ ] `cd /workspace && make build-docker` → Docker 镜像成功构建（需要 Docker 环境）
- [x] `cd /workspace && bash scripts/run-tests.sh` → 测试脚本执行结束，输出汇总结果
- [ ] `cd /workspace && bash scripts/build-all.sh` → 构建脚本执行成功（需要 Flutter + Docker 环境）
- [ ] `.github/workflows/ci.yml` 在 GitHub 实际 CI 环境下运行通过（push 触发）（需要真实 GitHub 环境）
