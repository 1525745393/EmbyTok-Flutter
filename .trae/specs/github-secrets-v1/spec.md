# GitHub Secrets 配置与工作流增强 - Product Requirement Document

## Overview
- **Summary**: 为 EmbyTok-Flutter 项目建立标准化的 GitHub Secrets 配置流程，增强现有 Android 签名与 Docker 镜像发布的 CI/CD 工作流，添加前端 Flutter Web Docker 镜像构建能力，并为开发者提供清晰完整的配置指南。
- **Purpose**: 解决当前工作流中存在的 Secrets 依赖不明确、缺少前置验证、前端缺少 Docker 部署支持、以及开发者配置文档分散的问题。让首次部署的开发者能够在 30 分钟内完成所有 Secrets 配置并成功触发自动化构建与发布。
- **Target Users**: 项目维护者、CI/CD 配置人员、需要部署发布版本的开发者

## Goals

1. **Secrets 验证增强**: 在 `android-release.yml` 和 `docker-release.yml` 工作流最前端添加显式的 Secrets 验证步骤，当必需 Secrets 缺失时给出明确的中文错误提示，并以非零退出码终止，避免进入后续无效步骤。
2. **前端 Docker 镜像支持**: 创建前端 Flutter Web 的 Dockerfile 和配套 Nginx 配置，使得 EmbyTok 的 Web 版本可以通过容器化方式部署，并在 `docker-release.yml` 中添加前端镜像的构建与推送步骤。
3. **开发者文档完善**: 在根级 README 和 `.github/` 目录下添加清晰的 Secrets 配置指南，包括每个 Secret 的含义、生成方式、格式要求、以及在 GitHub 仓库设置页面的具体添加步骤。
4. **工作流语法健壮性**: 修复现有工作流 YAML 中可能存在的 heredoc 语法、变量引用等问题，保证在 GitHub Actions runner 环境中正确执行。
5. **Secrets 检查工作流**: 创建一个可手动触发的 `secrets-check.yml` 工作流，用于验证所有必需的 Secrets 是否已正确配置在仓库设置中，并输出完整的检查报告。

## Non-Goals (Out of Scope)

- 不在本 PRD 范围内添加 iOS 签名发布流程（iOS 需要 Apple Developer 账号和 macOS runner，将在后续版本单独规划）
- 不实现 Docker Hub 之外的私有镜像仓库的专用集成（当前设计已通过 `DOCKER_REGISTRY` 变量支持任意兼容 Docker Registry V2 API 的服务）
- 不涉及 Kubernetes Helm Chart 或其他编排系统的部署配置
- 不修改应用业务逻辑（视频播放、搜索、收藏等功能不在本 PRD 范围）
- 不创建新的密钥或 keystore 文件（该操作由开发者在本地执行，不在 CI 流程内生成）

## Background & Context

### 项目当前状态

EmbyTok-Flutter 项目的 CI/CD 基础设施已初步建立，存在以下工作流文件：

- [ci.yml](file:///workspace/.github/workflows/ci.yml) - Flutter 测试、Python 后端测试、Docker 构建验证
- [android-release.yml](file:///workspace/.github/workflows/android-release.yml) - Android 签名 APK/AAB 构建，已引用 `ANDROID_KEYSTORE`, `ANDROID_KEYSTORE_PWD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PWD`
- [docker-release.yml](file:///workspace/.github/workflows/docker-release.yml) - 后端 Docker 镜像构建与推送，已引用 `DOCKER_REGISTRY`, `DOCKER_USERNAME`, `DOCKER_PASSWORD`

前端目录结构完整，包含 `web/` 目录（Flutter Web 支持），但**缺少前端 Dockerfile**。

### 已发现的问题

1. **android-release.yml** (第 53-57 行): 使用 YAML heredoc 语法生成 `key.properties`，在某些 runner 环境中可能出现变量展开时机问题。且未在步骤前验证 4 个 Secrets 是否均非空。
2. **docker-release.yml** (第 48-55 行): `DOCKER_IMAGE_NAME` 的默认值 fallback 逻辑较复杂，缺少对 `DOCKER_USERNAME` / `DOCKER_PASSWORD` 为空时的提前检查。
3. **前端部署缺失**: 项目 README 中提到了前端 Web 构建，但没有实际的 `frontend/Dockerfile` 来支持容器化部署。
4. **文档不集中**: Android 签名配置指南仅存在于 `frontend/android/README_ANDROID_SIGN.md`，未在根级 README 的 CI/CD 章节中汇总。
5. **安全风险**: 工作流未验证 base64 解码是否成功，可能在无效 keystore 数据时静默失败。

### 技术约束

| 约束 | 详情 |
|------|------|
| CI Runner | GitHub Actions ubuntu-latest（Linux x64 环境） |
| Flutter 版本 | 3.24.0（由 subosito/flutter-action 锁定） |
| Docker Buildx | 支持多架构（amd64 + arm64） |
| Secrets 存储 | GitHub Repository Secrets（不可从 fork PR 中读取） |
| Android 签名 | JKS 格式 keystore，通过 base64 编码后存入 Secrets |

## Functional Requirements

### FR-1: Android Secrets 前置验证
在 `android-release.yml` 的 `build-android` job 中，第一个 step 必须验证以下 Secrets 全部非空：
- `ANDROID_KEYSTORE`（base64 字符串，长度应 > 1000）
- `ANDROID_KEYSTORE_PWD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PWD`

如有缺失，输出中文错误消息列出缺失项，并以 exit code 1 终止。

### FR-2: Android keystore 解码验证
将 `ANDROID_KEYSTORE` 解码写入 `frontend/android/app/embbytok-keystore.jks` 后，增加一步验证：
- 确认文件存在且大小 > 0
- 使用 `keytool -list -keystore ... -storepass ... 2>/dev/null | head -1` 验证 keystore 完整性

如验证失败，终止并报错。

### FR-3: Docker Secrets 前置验证
在 `docker-release.yml` 的构建步骤前，验证：
- `DOCKER_USERNAME` 非空
- `DOCKER_PASSWORD` 非空

同时在 `docker/login-action@v3` 后检查退出码，登录失败给出清晰提示。

### FR-4: 前端 Flutter Web Dockerfile
创建 `frontend/Dockerfile`（多阶段构建）：
- Stage 1: 使用 `cirrusci/flutter` 镜像，执行 `flutter build web --release`
- Stage 2: 使用 `nginx:alpine` 作为运行时，复制 Stage 1 产物，添加自定义 `nginx.conf`

创建 `frontend/.dockerignore`，排除不必要的文件（如 `build/`, `android/`, `ios/`, `.git/` 等）。

### FR-5: docker-release.yml 前端镜像支持
在 `docker-release.yml` 中增加 frontend 镜像的 build & push 步骤，与 backend 镜像并列执行：
- backend 镜像 tag: `{REGISTRY}/{OWNER}/embbytok-backend:{VERSION}`
- frontend 镜像 tag: `{REGISTRY}/{OWNER}/embbytok-frontend:{VERSION}`

两者均支持 `:latest` tag。

### FR-6: Secrets 检查工作流
创建新的 `.github/workflows/secrets-check.yml`，支持 `workflow_dispatch` 手动触发：
- 逐项验证所有 7 个 Secrets 的存在性与格式
- 输出美观的 Markdown 表格报告（通过 `$GITHUB_STEP_SUMMARY`）
- 将每个 Secret 的状态标记为：✅ 已配置 / ⚠️ 格式可疑 / ❌ 缺失

### FR-7: 工作流语法修复与统一
修复现有的 YAML heredoc 语法问题，改用更可靠的多行字符串或外部脚本。为 Android 和 Docker 工作流使用一致的错误处理风格（`set -euo pipefail`）。

### FR-8: 开发者文档
在以下位置添加/更新文档：
- **根级 README.md** 的 CI/CD 章节：新增 "发布配置" 小节，列出所有必需 Secrets 并链接到详细指南
- **创建 `.github/SECRETS.md`**：详细指南文档，包含：
  - 7 个 Secrets 的完整定义表（名称、用途、格式、示例）
  - Android keystore 生成命令（`keytool` 完整命令）
  - base64 编码方法（Linux / macOS / Windows PowerShell）
  - Docker Hub 账号与 Access Token 创建步骤
  - 图文并茂的 GitHub 仓库设置页面操作指引
  - 验证配置成功的方法（运行 secrets-check 工作流）

## Non-Functional Requirements

### NFR-1: 执行速度
- Android 工作流：前置验证步骤必须在 10 秒内完成（不影响构建主流程）
- Docker 工作流：前置验证步骤必须在 5 秒内完成
- Secrets Check 工作流：完整检查必须在 30 秒内完成

### NFR-2: 可维护性
- 所有工作流文件中的 Secrets 名称必须集中定义或至少在文件顶部以注释形式列出完整清单
- YAML 文件必须通过 yamllint 语法检查（indent: 2, line-length: 不强制）
- Shell 脚本必须使用 `set -euo pipefail` 开启严格模式

### NFR-3: 安全性
- **绝不**在任何日志中输出 Secrets 的值（即使是截断或部分内容也不允许）
- 验证步骤中，仅输出 "已配置" / "缺失" / "格式可疑" 三种状态之一
- keystore 文件在 CI job 结束后随 runner 自动销毁，不通过 artifact 上传

### NFR-4: 向后兼容
- 修改后的工作流必须保持原有的触发条件（`push: tags: [v*]` 和 `workflow_dispatch`）
- 必须保持已有的 artifact 名称和 Release 行为不变
- Docker 镜像 tag 命名规则保持与现有一致，仅增加 frontend 镜像

### NFR-5: 可读性
- 所有工作流步骤必须包含中文 `name:`，描述该步骤的明确目的
- 关键命令（如 base64 解码、docker login 等）必须附有简明的中文注释

## Constraints

- **技术**: 必须使用 GitHub Actions 生态（不迁移到 GitLab CI、Jenkins 等其他平台）
- **工具**: Docker 构建必须使用 `docker/setup-buildx-action` + `docker/build-push-action`（与现有方式一致）
- **Android**: 必须使用 JKS 格式 keystore（与现有的 Gradle 配置兼容）
- **Docker Registry**: 默认使用 Docker Hub（`docker.io`），但必须支持通过 `DOCKER_REGISTRY` 切换
- **Dart/Flutter**: 不得因本 PRD 的实施修改任何 Flutter 应用的源代码（仅添加构建配置文件）

## Assumptions

1. 假设开发者在配置 Secrets 之前已经安装并配置了 Flutter SDK 和 JDK（用于本地手动生成 keystore）
2. 假设使用 Docker Hub 作为默认镜像仓库（支持通过 Secret 切换到其他 Registry）
3. 假设 GitHub Actions runner 具有访问外部网络的权限（用于拉取基础镜像、登录 Docker Hub）
4. 假设仓库 owner 对仓库具有 `Settings → Secrets and variables → Actions` 的写权限
5. 假设 Flutter Web 构建在 Linux x64 runner 上可以成功（与 `cirrusci/flutter` 镜像兼容）

## Acceptance Criteria

### AC-1: Android 工作流 Secrets 验证
- **Given** 仓库未配置 `ANDROID_KEYSTORE` 或其他 Android Secrets
- **When** 手动触发 android-release 工作流（workflow_dispatch）
- **Then** 工作流在第一个步骤即失败，日志中包含明确的中文提示列出所有缺失的 Secrets
- **Verification**: programmatic（可通过 GitHub CLI 触发 workflow 并检查 conclusion）
- **Notes**: 错误消息格式为 "⚠️ 缺少必需的 Secrets: [缺失项列表]。请在仓库 Settings → Secrets and variables → Actions 中配置。"

### AC-2: Android keystore 格式验证
- **Given** `ANDROID_KEYSTORE` 中存储了无效的 base64 字符串（如普通文本）
- **When** 工作流执行到 keystore 验证步骤
- **Then** `base64 --decode` 返回非零退出码，工作流终止并提示 "keystore 文件解码失败，请确认 base64 格式正确"
- **Verification**: programmatic

### AC-3: Android 签名构建成功
- **Given** 所有 Android Secrets 正确配置
- **When** 工作流执行到构建步骤
- **Then** 成功生成 `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk` 和 `app-release.aab`，并上传到 Release Assets
- **Verification**: programmatic（检查 Release 是否包含 .apk/.aab 文件）

### AC-4: Docker 工作流 Secrets 验证
- **Given** 仓库未配置 `DOCKER_USERNAME` 或 `DOCKER_PASSWORD`
- **When** 手动触发 docker-release 工作流
- **Then** 工作流在登录步骤前失败，提示缺少 Docker 认证信息
- **Verification**: programmatic

### AC-5: Docker 后端镜像构建与推送
- **Given** Docker Secrets 正确配置，且后端代码无变更
- **When** 推送一个以 `v` 开头的 Git tag
- **Then** 成功构建并推送 `embbytok-backend:{tag}` 和 `embbytok-backend:latest` 多架构镜像
- **Verification**: programmatic（通过 `docker manifest inspect` 验证）

### AC-6: 前端 Dockerfile 存在且可构建
- **Given** `frontend/Dockerfile` 和相关文件已创建
- **When** 在 `frontend/` 目录执行 `docker build -t test-web .`
- **Then** 构建成功，生成的镜像可以通过 `docker run -p 8080:80 test-web` 启动，并在浏览器访问首页
- **Verification**: programmatic + human-judgment（自动化构建验证 + 人工访问确认）

### AC-7: 前端 Docker 镜像纳入发布工作流
- **Given** Docker Secrets 已配置
- **When** 推送一个以 `v` 开头的 Git tag
- **Then** 工作流同时构建并推送 backend 和 frontend 两个镜像，各自带版本号和 latest tag
- **Verification**: programmatic

### AC-8: Secrets Check 工作流可手动触发
- **Given** 仓库中存在 `.github/workflows/secrets-check.yml`
- **When** 在 Actions 页面手动触发该工作流
- **Then** 工作流在 30 秒内完成，输出一个 Markdown 表格报告，显示 7 个 Secrets 的配置状态
- **Verification**: human-judgment（通过 GitHub UI 查看 Summary）

### AC-9: 开发者文档可读性
- **Given** `.github/SECRETS.md` 已创建
- **When** 新开发者按顺序阅读该文档
- **Then** 可以在不查阅其他资源的情况下，在 30 分钟内完成所有 7 个 Secrets 的配置并成功触发一次完整发布流程
- **Verification**: human-judgment（实际走查测试）

### AC-10: YAML 语法与风格一致性
- **Given** 所有工作流文件已更新
- **When** 运行 yamllint 和 shellcheck 对 `.github/workflows/` 目录进行检查
- **Then** 无严重级别错误（warning 可接受）
- **Verification**: programmatic

## Open Questions

- [ ] 是否需要在 Docker Hub 上创建官方组织账号（如 `embbytok`），还是使用个人账号即可？
- [ ] Docker 镜像的 tag 是否需要包含 Git commit hash（例如 `v1.0.0-abc123`），以方便定位？
- [ ] 是否需要为 Docker Release 工作流添加构建缓存过期清理策略（当前 build-push-action 使用 GHA cache，但未设过期）？
- [ ] frontend Dockerfile 是否需要支持通过环境变量动态设置后端 API 地址，还是保持静态编译时固定？
