# EmbyTok Flutter - 完善工作流 Spec

## Overview
- **Summary**: 为 EmbyTok Flutter 项目建立完整的开发工作流体系，包括根级 `.gitignore`、统一的构建/运行脚本（Makefile、Shell 脚本）、CI/CD 配置（GitHub Actions）、代码质量工具（Dart Analyze、flutter_lints）、以及跨平台的统一部署流程。
- **Purpose**: 当前项目缺少统一的工作流入口。开发者不知道一键启动命令在哪里，不知道如何运行测试，没有 CI 自动验证，也没有代码质量检查。这导致新成员上手困难，代码质量无法保证，发布流程手动且容易出错。
- **Target Users**: Flutter/Dart 开发者、CI/CD 工程师、项目维护者

## Goals
1. **一键启动**：提供 `make` 或 `make help` 命令，清晰展示所有可用操作
2. **统一脚本**：将前端 (Flutter) 和后端 (FastAPI) 的构建、运行、测试命令统一管理
3. **CI 自动化**：配置 GitHub Actions，在每个 PR 和 push 时自动运行测试、lint 和构建验证
4. **代码质量**：集成 Dart Analyze、flutter_lints，确保提交代码符合项目规范
5. **部署简化**：提供 Docker 构建与推送的统一脚本
6. **版本管理**：配置 semantic versioning 或简化的版本管理流程

## Non-Goals (Out of Scope)
- 不创建真实的 Git 仓库或 GitHub 组织（仅提供配置文件）
- 不实现完整的 CD 部署流水线（仅提供构建和本地部署脚本，真实部署需配置 secret）
- 不引入额外的外部服务依赖（如 SonarQube、Sentry 等）
- 不创建 Windows PowerShell 脚本（仅提供 bash 脚本和 Makefile，Windows 用户可通过 WSL 使用）
- 不实现 iOS 自动签名和发布到 App Store 的完整流水线（仅提供基础 Archive 脚本）
- 不创建 VS Code/IntelliJ 工作区配置（非必需）

## Background & Context
- 项目结构：`/workspace` 根目录包含 `backend/`（FastAPI + Python）和 `frontend/`（Flutter）
- 当前已有部分脚本：`frontend/scripts/build_android.sh`、`frontend/scripts/build_ios.sh`、`frontend/test/run_all_tests.sh`
- 当前已有 Docker 配置：`backend/Dockerfile`、`docker-compose.yml`
- 缺少根级 `.gitignore`（目前仅有 `frontend/android/.gitignore` 和 `frontend/ios/.gitignore`）
- 缺少统一入口：开发者需要分别进入子目录执行不同命令
- 缺少 CI 配置：没有任何自动化验证机制
- 缺少 Makefile：没有统一的命令快捷方式
- 缺少 `.editorconfig`：编辑器代码风格一致性配置

## Functional Requirements
- **FR-1**: 根级 `.gitignore` 文件存在，正确忽略 Flutter/Dart 构建产物、IDE 文件、系统临时文件、Python `__pycache__`、`.venv`、Docker secrets
- **FR-2**: `Makefile` 存在于项目根目录，提供以下目标：
  - `make help`：显示所有可用命令及其描述
  - `make setup`：安装前端和后端依赖（flutter pub get + pip install -r）
  - `make run-backend`：启动后端服务（docker-compose up 或 uvicorn）
  - `make run-frontend`：启动 Flutter 应用（flutter run）
  - `make run-all`：同时启动前后端（前后端联动）
  - `make test-all`：运行所有测试（Dart 测试 + Python 测试）
  - `make test-frontend`：仅运行 Flutter 测试
  - `make test-backend`：仅运行 Python 后端测试
  - `make lint`：运行 `flutter analyze` 和 Python lint
  - `make build-apk`：构建 Android APK
  - `make build-ios`：构建 iOS（提示 macOS 限制）
  - `make build-docker`：构建 Docker 镜像
  - `make clean`：清理所有构建产物
- **FR-3**: `.editorconfig` 文件存在，统一 4 空格缩进、UTF-8 编码、换行符
- **FR-4**: `scripts/` 目录存在于项目根目录，包含跨平台 shell 脚本：
  - `setup.sh`：环境检查与依赖安装（检查 Flutter、Python、Docker）
  - `run-all.sh`：一键启动前后端
  - `run-tests.sh`：统一测试入口
  - `build-all.sh`：全量构建脚本（Android APK + Docker 镜像）
  - `docker-push.sh`：Docker 镜像推送脚本（支持自定义 registry）
- **FR-5**: `.github/workflows/` 存在，包含至少 3 个 workflow：
  - `ci.yml`：CI 主流程（测试 + lint + 构建验证，在 push/PR 时触发）
  - `android-release.yml`：Android 发布构建（在 tag 或手动触发）
  - `docker-release.yml`：Docker 镜像发布（在 tag 或手动触发）
- **FR-6**: CI workflow 至少覆盖：
  - Flutter 环境搭建（使用 flutter-action）
  - Python 环境搭建
  - 运行 Flutter 测试（`flutter test`）
  - 运行 `flutter analyze` 代码分析
  - 验证 pub get 无警告
  - Python lint（pylint 或 flake8）
  - Python 测试（pytest）
  - 构建验证（Android debug APK 至少在 Linux runner 上）
  - Docker 镜像构建验证
  - 在 CI 日志中清晰显示各阶段状态
- **FR-7**: 所有 Shell 脚本具有可执行权限（`chmod +x`）
- **FR-8**: 脚本在出错时以非 0 退出码退出（`set -e` 或等效机制）
- **FR-9**: 所有脚本输出使用中文日志，包含阶段分隔线，便于排查问题
- **FR-10**: `README.md` 在「快速开始」章节更新，引导用户使用 `make` 命令

## Non-Functional Requirements
- **NFR-1 (可靠性)**: 所有脚本在缺少依赖时输出清晰的中文错误信息，而不是神秘崩溃
- **NFR-2 (可维护性)**: Makefile 和脚本结构清晰，注释充分，便于后续扩展
- **NFR-3 (跨平台)**: Makefile 在 Linux 和 macOS 上正常工作；Windows 用户提示使用 WSL
- **NFR-4 (性能)**: CI workflow 总耗时应在 15 分钟以内（不含缓存的首次运行可放宽到 30 分钟）
- **NFR-5 (安全性)**: `.gitignore` 正确忽略密钥文件、`.env`、`key.properties`、`*.jks`、secrets 目录等
- **NFR-6 (一致性)**: 所有脚本的日志输出风格统一（前缀、分隔线、emoji）

## Constraints
- **Technical**:
  - Shell 脚本使用 Bash（`#!/bin/bash`）
  - Makefile 使用标准 GNU Make 语法
  - GitHub Actions 使用 `ubuntu-latest` runner
  - Flutter SDK 使用 stable channel，版本 >= 3.10.0
  - Python 版本 >= 3.11
- **Business**:
  - 不引入付费 CI/CD 服务（仅使用 GitHub Actions free tier）
  - 不修改核心业务逻辑代码（Dart/Python 源码不动）
- **Dependencies**:
  - 依赖已存在的 `frontend/pubspec.yaml`、`backend/requirements.txt`、`docker-compose.yml`

## Assumptions
- 开发者使用类 Unix 系统（Linux、macOS、或 Windows WSL）
- 开发者已安装基础工具：`make`、`git`、`bash`
- Flutter、Python、Docker 可能需要开发者首次安装
- 项目最终会部署到 GitHub 或支持 YAML workflow 的平台
- 真实的发布密钥（Android keystore、Apple Developer、Docker Hub token）由运维/发布团队在 CI secret 中管理

## Acceptance Criteria

### AC-1: 根级 .gitignore 完整
- **Given**: 项目根目录存在 `.gitignore`
- **When**: 开发者运行 `git status`
- **Then**: 以下文件/目录不会显示为 untracked：`build/`、`.dart_tool/`、`.idea/`、`.vscode/`、`*.jks`、`key.properties`、`.env`、`__pycache__/`、`.venv/`、`*.log`、`.DS_Store`
- **Verification**: `programmatic`（检查文件存在并包含关键条目）
- **Notes**: 需要覆盖 Flutter、Android、iOS、Python、IDE、系统文件

### AC-2: Makefile 提供完整命令集
- **Given**: 项目根目录存在 `Makefile`
- **When**: 开发者运行 `make help`
- **Then**: 列出至少 10 个可用目标，每个目标有中文描述
- **Verification**: `human-judgment`（检查输出信息的完备性）

### AC-3: Make 命令可执行
- **Given**: 开发者在项目根目录
- **When**: 运行 `make setup`（需 Flutter 和 Python 环境）
- **Then**: 成功执行 `flutter pub get` 和 `pip install -r backend/requirements.txt`，无错误
- **Verification**: `programmatic`（检查退出码为 0）

### AC-4: 统一脚本目录存在
- **Given**: `scripts/` 目录存在于项目根目录
- **When**: 列出目录内容
- **Then**: 至少包含 `setup.sh`、`run-all.sh`、`run-tests.sh`、`build-all.sh`，每个文件有可执行权限
- **Verification**: `programmatic`（`ls -la scripts/` 检查）

### AC-5: 脚本错误处理
- **Given**: 运行脚本时缺少某个依赖（如未安装 Flutter）
- **When**: 脚本执行到环境检查阶段
- **Then**: 输出红色中文错误信息（如 "❌ 未检测到 Flutter SDK，请先安装"），以非 0 退出码退出，不继续执行
- **Verification**: `programmatic`（在缺少 Flutter 的环境中运行 `scripts/setup.sh` 检查错误输出）

### AC-6: CI workflow 存在且结构正确
- **Given**: `.github/workflows/ci.yml` 存在
- **When**: 检查 YAML 语法
- **Then**: 文件语法正确，包含 name、on (push/pull_request)、jobs 字段
- **Verification**: `programmatic`（可用 `yamllint` 或 Python `yaml.safe_load` 验证）

### AC-7: CI workflow 覆盖核心检查
- **Given**: CI workflow 已配置
- **When**: 触发 CI 运行
- **Then**: 至少运行以下步骤：Flutter 测试、flutter analyze、Python 测试、Docker 构建验证
- **Verification**: `human-judgment`（检查 workflow 步骤定义）

### AC-8: Android 发布 workflow 可配置
- **Given**: `.github/workflows/android-release.yml` 存在
- **When**: 检查配置内容
- **Then**: 包含 keystore 从 secret 获取、签名构建、上传 APK 作为 artifact 的步骤定义
- **Verification**: `human-judgment`（检查 YAML 步骤完备性）

### AC-9: Docker 发布 workflow 可配置
- **Given**: `.github/workflows/docker-release.yml` 存在
- **When**: 检查配置内容
- **Then**: 包含登录 Docker registry、构建镜像、推送镜像的步骤，支持通过 secret 配置 registry 和 tag
- **Verification**: `human-judgment`（检查 YAML 步骤完备性）

### AC-10: EditorConfig 统一编辑器风格
- **Given**: `.editorconfig` 存在于项目根目录
- **When**: 支持 EditorConfig 插件的编辑器打开项目
- **Then**: 自动应用以下规则：4 空格缩进、UTF-8 编码、LF 换行、文件末尾新行
- **Verification**: `programmatic`（检查文件内容包含关键规则）

### AC-11: README 更新与可操作性
- **Given**: `README.md` 已更新「快速开始」章节
- **When**: 新开发者阅读 README
- **Then**: 能通过 3~5 个 `make` 命令完成：安装依赖 → 运行测试 → 启动应用
- **Verification**: `human-judgment`（检查 README 步骤的清晰性和完整性）

## Open Questions
- [ ] 是否需要为 Python 后端添加具体的 pytest 测试框架配置（目前 backend 似乎没有测试目录）？
- [ ] 是否需要 pre-commit hook 配置（如 `.pre-commit-config.yaml`）？
- [ ] Docker 镜像默认 tag 规则是什么？（如 `embbytok:latest` / `embbytok:{version}` / `ghcr.io/{owner}/embbytok:{tag}`）
- [ ] CI 是否需要覆盖 Web 平台构建（`flutter build web`）？
- [ ] 是否需要代码覆盖率 badge（在 README 显示覆盖率）？
