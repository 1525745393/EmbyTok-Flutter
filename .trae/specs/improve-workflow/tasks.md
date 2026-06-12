# EmbyTok Flutter - 完善工作流 任务分解

## [ ] Task 1: 根级 .gitignore 和 .editorconfig
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 创建根目录 `.gitignore`，合并 Flutter、Android、iOS、Python、IDE、系统文件的忽略规则
  - 创建 `.editorconfig`：`root = true`、`indent_style = space`、`indent_size = 4`、`end_of_line = lf`、`charset = utf-8`、`trim_trailing_whitespace = true`、`insert_final_newline = true`
  - 为 Dart/YAML/JSON/Python/Swift/Kotlin 分别配置合理规则
- **Acceptance Criteria Addressed**: AC-1, AC-10
- **Test Requirements**:
  - `programmatic` TR-1.1: `.gitignore` 文件存在，包含以下条目：`build/`、`.dart_tool/`、`.idea/`、`.vscode/`、`*.jks`、`*.keystore`、`key.properties`、`.env`、`__pycache__/`、`.venv/`、`*.log`、`.DS_Store`、`Pods/`
  - `programmatic` TR-1.2: `.editorconfig` 文件存在，内容格式正确（可通过 `editorconfig-checker` 或手动检查）
- **Notes**: 注意 Flutter 官方推荐的 gitignore 条目（参考 flutter create 生成的默认 .gitignore）

## [ ] Task 2: Makefile（统一命令入口）
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 在项目根目录创建 `Makefile`
  - `.PHONY` 声明所有 target
  - 默认 target `help`（不是具体的构建命令）
  - 实现以下目标（至少 10 个）：
    - `help`：格式化显示所有命令（使用 `@echo` + 彩色输出或简单对齐）
    - `setup`：检查 Flutter → `flutter pub get`（frontend/）；检查 Python → `pip install -r backend/requirements.txt`
    - `run-backend`：`cd backend && docker-compose up -d`（或 `uvicorn main:app --reload`）
    - `run-frontend`：`cd frontend && flutter run`（带提示选择设备）
    - `run-all`：同时启动前后端（后台模式，提示 Ctrl+C 退出后 `make stop`）
    - `stop`：停止 docker-compose 服务
    - `test-all`：`make test-frontend && make test-backend`
    - `test-frontend`：`cd frontend && flutter test`
    - `test-backend`：`cd backend && python -m pytest` 或提示没有 Python 测试
    - `lint`：`cd frontend && flutter analyze` + Python lint（如有）
    - `build-apk`：`cd frontend && flutter build apk --release`
    - `build-ios`：输出 macOS 限制提示（在非 macOS 上 exit 0 但提示）
    - `build-docker`：`docker build -t embbytok-backend backend/` 或 `docker-compose build`
    - `clean`：清理 Flutter build 目录、`__pycache__`、`*.pyc`
- **Acceptance Criteria Addressed**: AC-2, AC-3, AC-11
- **Test Requirements**:
  - `programmatic` TR-2.1: `make help` 成功执行，显示命令列表
  - `programmatic` TR-2.2: `make -n setup`（dry-run）不报错
  - `human-judgement` TR-2.3: 命令描述为中文且清晰易理解

## [ ] Task 3: 根级 scripts 目录（Shell 脚本集）
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 创建 `scripts/` 目录，放置以下脚本：
    - `setup.sh`：环境检查 + 依赖安装（Flutter version 检查、Python version 检查、flutter pub get、pip install）
    - `run-all.sh`：同时启动后端（uvicorn 或 docker）和前端（flutter run），前台方式带进程管理
    - `run-tests.sh`：依次运行 Flutter 测试和 Python 测试，汇总测试结果（通过/失败计数）
    - `build-all.sh`：依次构建 Android APK 和 Docker 镜像，输出产物路径和大小
    - `docker-push.sh`：从环境变量读取 `REGISTRY`、`IMAGE_NAME`、`TAG`，执行 `docker build` + `docker login` + `docker push`
  - 所有脚本：
    - 以 `#!/bin/bash` 开头
    - 顶部设置 `set -euo pipefail`
    - 使用统一的日志函数（如 `log_info "..."`、`log_success "..."`、`log_error "..."`），输出彩色中文
    - 包含 `==========` 或 `----------` 分隔线
    - 出错时 `exit 1`，成功时输出完成提示
- **Acceptance Criteria Addressed**: AC-4, AC-5, AC-9
- **Test Requirements**:
  - `programmatic` TR-3.1: 所有脚本存在，`ls -la scripts/` 显示 `rwxr-xr-x` 权限
  - `programmatic` TR-3.2: `bash -n scripts/setup.sh`（语法检查）无错误
  - `programmatic` TR-3.3: 每个脚本中包含 `set -e` 或等效错误处理

## [ ] Task 4: GitHub Actions CI workflow（主流程）
- **Priority**: P0
- **Depends On**: Task 3
- **Description**:
  - 创建 `.github/workflows/ci.yml`
  - 触发条件：`push`（所有分支）+ `pull_request`（所有分支）
  - name：`"CI - Test, Lint & Build"`
  - Jobs（可并行）：
    - `test-and-lint`:
      - `runs-on: ubuntu-latest`
      - 步骤：
        1. `actions/checkout@v4`
        2. `subosito/flutter-action@v2`（channel: stable，flutter-version: ">=3.10.0"）
        3. `actions/setup-python@v5`（python-version: "3.11"）
        4. `flutter pub get`（frontend）
        5. `flutter analyze --no-pub --no-fatal-infos`（frontend，失败不 fatal）
        6. `flutter test --coverage`（frontend）
        7. 上传 coverage 报告 artifact（可选）
        8. `pip install -r backend/requirements.txt`
        9. `pytest backend/`（如果没有测试则显示提示，不失败）
        10. `flutter build apk --debug`（验证 Android 至少能构建 debug）
    - `docker-build`:
      - `runs-on: ubuntu-latest`
      - 步骤：
        1. `actions/checkout@v4`
        2. `docker build -t embbytok-backend:ci-test backend/`
        3. 验证容器启动（运行容器后 curl 健康检查 `/health`）
        4. 清理镜像
  - 使用 `concurrency.group`，避免同一 PR 重复运行
- **Acceptance Criteria Addressed**: AC-6, AC-7
- **Test Requirements**:
  - `programmatic` TR-4.1: 文件存在，且通过 `python -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` 无语法错误
  - `human-judgement` TR-4.2: workflow 包含至少 5 个 job 步骤（checkout → flutter setup → pub get → test → analyze → build → docker）
  - `human-judgement` TR-4.3: 步骤名称使用中文描述，便于查看 CI 日志

## [ ] Task 5: GitHub Actions Android 发布 workflow
- **Priority**: P1
- **Depends On**: Task 4
- **Description**:
  - 创建 `.github/workflows/android-release.yml`
  - 触发：`workflow_dispatch`（手动触发）+ `push` 到 `tags/v*`
  - Job `build-release`:
    - `runs-on: ubuntu-latest`
    - 步骤：
      1. `actions/checkout@v4`
      2. Flutter setup（stable channel）
      3. **从 GitHub Secrets 恢复 keystore**：将 `${{ secrets.ANDROID_KEYSTORE }}`（base64 内容）解码写入 `frontend/android/app/embbytok-keystore.jks`
      4. 写入 `frontend/android/key.properties`（从 secrets: `storePassword`, `keyAlias`, `keyPassword`）
      5. `flutter pub get`
      6. `flutter build apk --release --split-per-abi`
      7. `flutter build appbundle --release`（可选，AAB 用于 Google Play）
      8. 使用 `actions/upload-artifact@v4` 上传 APK 和 AAB
      9. （可选）如果是 tag 触发，创建 GitHub Release 并附加 APK
  - YAML 中使用 `${{ secrets.XXX }}`，但不包含真实值
- **Acceptance Criteria Addressed**: AC-8
- **Test Requirements**:
  - `programmatic` TR-5.1: YAML 语法正确
  - `human-judgement` TR-5.2: 包含 keystore 解码、签名构建、artifact 上传三个关键步骤
  - `human-judgement` TR-5.3: 有中文注释说明如何配置 secret

## [ ] Task 6: GitHub Actions Docker 发布 workflow
- **Priority**: P1
- **Depends On**: Task 4
- **Description**:
  - 创建 `.github/workflows/docker-release.yml`
  - 触发：`workflow_dispatch` + `push` 到 `tags/v*`
  - Job `build-and-push`:
    - `runs-on: ubuntu-latest`
    - 步骤：
      1. `actions/checkout@v4`
      2. `docker/setup-qemu-action@v3`
      3. `docker/setup-buildx-action@v3`
      4. `docker/login-action@v3`（从 secret 读取 registry/username/password，默认为 Docker Hub，可配置 GHCR）
      5. 提取版本号（从 git tag 或 `package.json`/`pubspec.yaml`）
      6. `docker/build-push-action@v5`：`context: backend/`，tags 为 `{image}:latest` 和 `{image}:{version}`，平台 `linux/amd64,linux/arm64`
      7. 输出镜像摘要
- **Acceptance Criteria Addressed**: AC-9
- **Test Requirements**:
  - `programmatic` TR-6.1: YAML 语法正确
  - `human-judgement` TR-6.2: 使用标准 docker/actions 官方 action（setup-buildx, login, build-push）
  - `human-judgement` TR-6.3: 包含多架构构建（amd64 + arm64）和 version/latest 双 tag

## [ ] Task 7: README 更新（快速开始章节）
- **Priority**: P1
- **Depends On**: Task 2, Task 3
- **Description**:
  - 更新根目录 `README.md` 的「快速开始」章节（在已存在的 README 内容中插入或重构）
  - 新结构包含：
    - 「前置条件」：列出需要的版本（Flutter 3.10+、Python 3.11+、Docker 可选）
    - 「一行命令启动」：`make setup && make run-all`
    - 「常用命令速查表」：表格形式列出所有 `make` 命令及其用途
    - 「手动启动」：无 make 环境的命令替代方案
    - 「CI/CD 状态」：预留 badge 位置（如 `[![CI](https://github.com/{user}/{repo}/actions/workflows/ci.yml/badge.svg)]`）
  - 更新 `README_PACKAGING.md`，添加 `make build-apk` / `make build-docker` 引用
- **Acceptance Criteria Addressed**: AC-11
- **Test Requirements**:
  - `human-judgement` TR-7.1: README 中的命令说明完整可操作
  - `human-judgement` TR-7.2: 包含完整的「快速开始」流程（setup → run → test）
  - `programmatic` TR-7.3: README.md 文件存在且语法正确（可通过 markdown 检查工具）

## [ ] Task 8: Python 后端测试脚手架（可选但推荐）
- **Priority**: P2
- **Depends On**: Task 3
- **Description**:
  - 由于当前 backend/ 没有 pytest 测试文件，创建最小测试骨架：
    - `backend/tests/__init__.py`
    - `backend/tests/conftest.py`：pytest fixture（空占位，后续可扩展）
    - `backend/tests/test_health.py`：一个基础测试，验证 FastAPI 可导入（`from main import app` 成功）
  - 在 `backend/requirements.txt` 中添加 `pytest>=7.4`、`httpx>=0.25`（如已有则跳过）
- **Acceptance Criteria Addressed**: AC-7（后端测试覆盖率起步）
- **Test Requirements**:
  - `programmatic` TR-8.1: `backend/tests/test_health.py` 存在
  - `programmatic` TR-8.2: `pytest backend/` 可成功执行（环境正确时）

---

# Task Dependencies

```
Task 1 (.gitignore + .editorconfig)
  ├── Task 2 (Makefile)
  │     └── Task 7 (README 更新)
  ├── Task 3 (scripts/)
  │     ├── Task 4 (CI workflow)
  │     │     ├── Task 5 (Android release)
  │     │     └── Task 6 (Docker release)
  │     └── Task 8 (Python 测试骨架)
```

**可并行执行的任务组**：
- Task 5 和 Task 6（两个 release workflow 互不依赖 Task 4 之后可同时开发）
- Task 7 可与 Task 4/5/6 并行（只依赖 Task 2 和 Task 3）

---

# 里程碑

| 里程碑 | 完成标志 | 对应 AC |
|--------|---------|---------|
| **M1: 基础工作流** | Task 1-3 完成 | AC-1~5, AC-10 |
| **M2: CI 自动化** | Task 4 完成 | AC-6~7 |
| **M3: 发布流水线** | Task 5-6 完成 | AC-8~9 |
| **M4: 文档就绪** | Task 7-8 完成 | AC-11 |
