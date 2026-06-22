# GitHub Secrets 配置与工作流增强 - 实施计划 (Tasks)

## [ ] Task 1: 增强 android-release.yml - 添加 Secrets 前置验证
- **Priority**: P0
- **Depends On**: 无
- **Description**:
  - 在 `build-android` job 的 Flutter setup 步骤之前，新增第一个 step：验证 4 个 Android Secrets 全部非空
  - Shell 脚本中使用 `set -euo pipefail` 严格模式
  - 对每个 Secret 单独检查：若为空则加入缺失列表
  - 输出格式：中文错误消息，列出所有缺失项 + 配置路径指引
  - exit code 1 终止流程
  - 在文件顶部添加注释块，列出本工作流依赖的所有 Secrets 名称和用途
- **Acceptance Criteria Addressed**: AC-1, AC-10
- **Test Requirements**:
  - `programmatic` TR-1.1: 本地运行 `yamllint` 检查 YAML 语法正确性
  - `programmatic` TR-1.2: 通过 Act 或 GitHub CLI 触发 workflow，在不配置 Secrets 的情况下确认第一步失败并输出中文提示
  - `programmatic` TR-1.3: 验证 shell 脚本在 `set -euo pipefail` 下行为正确（变量未定义时报错）
- **Notes**: 注意 `ANDROID_KEYSTORE` 是 base64 字符串，长度应该 > 1000，可以在验证中做长度检查，过短时标记为"格式可疑"

## [ ] Task 2: 增强 android-release.yml - keystore 解码与验证
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 重构现有的 `恢复签名配置` step（现 50-63 行）
  - 将 `key.properties` 的生成从 YAML heredoc 改为更可靠的方式（使用 `printf` 或 `echo` 单行写入）
  - 在解码 `ANDROID_KEYSTORE` 后：
    1. 检查输出文件存在且大小 > 0（`test -s`）
    2. 用 `keytool -list -keystore <path> -storepass <pwd> 2>/dev/null | head -1` 验证 keystore 完整性，应包含 "Keystore type:" 字样
    3. 任一检查失败则 exit code 1 终止，输出中文错误消息
  - `key.properties` 中的 `storeFile` 路径应指向解码后 jks 文件的绝对路径（以避免 Gradle 工作目录变化导致的问题）
- **Acceptance Criteria Addressed**: AC-2, AC-3
- **Test Requirements**:
  - `programmatic` TR-2.1: 手动提供一个无效的短 base64 字符串作为 ANDROID_KEYSTORE，验证工作流在验证步骤失败而非在 Gradle 构建步骤失败
  - `programmatic` TR-2.2: 验证解码后 jks 文件写入到正确路径且 Gradle 能读到（通过实际 Android 构建验证）
- **Notes**: `keytool` 命令在 GitHub Actions ubuntu-latest runner 上已预装，无需额外安装

## [ ] Task 3: 增强 docker-release.yml - Secrets 前置验证与元数据解析
- **Priority**: P0
- **Depends On**: 无
- **Description**:
  - 在 `build-and-push` job 中，登录 Docker 步骤之前新增前置验证 step
  - 验证 `DOCKER_USERNAME` 和 `DOCKER_PASSWORD` 非空
  - 如有缺失，输出中文错误消息并终止
  - 重构现有的 tag 解析逻辑（现 41-61 行），将 shell 脚本简化为更易读的形式，同时保持功能一致
  - 在文件顶部添加 Secrets 清单注释
- **Acceptance Criteria Addressed**: AC-4
- **Test Requirements**:
  - `programmatic` TR-3.1: 不配置 Docker Secrets 触发 workflow，确认前置验证失败
  - `programmatic` TR-3.2: 配置错误密码，确认 `docker/login-action` 失败后工作流终止
- **Notes**: `DOCKER_REGISTRY` 是可选的（有默认值 `docker.io`），不必强制验证

## [ ] Task 4: 创建前端 Flutter Web Dockerfile
- **Priority**: P0
- **Depends On**: 无
- **Description**:
  - 创建 `frontend/Dockerfile`（多阶段构建）
    - Stage 1 (`builder`): `FROM cirrusci/flutter:3.24.0`，复制 pubspec.yaml，执行 `flutter pub get`，复制源代码，执行 `flutter build web --release --source-maps`
    - Stage 2 (`production`): `FROM nginx:1.27-alpine`，复制 `build/web/` 到 `/usr/share/nginx/html/`，添加自定义 `nginx.conf`（见下）
  - 创建 `frontend/nginx.conf`：轻量配置，开启 gzip，将非静态文件请求回退到 `index.html`（Flutter SPA 路由需要）
  - 创建 `frontend/.dockerignore`：排除 `android/`, `ios/`, `build/`, `.git/`, `*.md`, `*.log`, `test/` 等
- **Acceptance Criteria Addressed**: AC-6
- **Test Requirements**:
  - `programmatic` TR-4.1: `cd frontend && docker build -t embbytok-frontend:test .` 构建成功，退出码 0
  - `programmatic` TR-4.2: `docker run -d -p 8080:80 embbytok-frontend:test` 成功启动，`curl -s http://localhost:8080/ | grep -i "embbytok\|flutter"` 能找到关键词
  - `human-judgment` TR-4.3: 浏览器访问 `http://localhost:8080/`，页面正常加载无报错（控制台无 404）
- **Notes**: `cirrusci/flutter` 镜像较大（~3GB），首次构建较慢。建议在 buildx 中使用 cache-from/to 加速

## [ ] Task 5: 增强 docker-release.yml - 支持 frontend 镜像
- **Priority**: P0
- **Depends On**: Task 3, Task 4
- **Description**:
  - 在 `docker-release.yml` 中将单 job (`build-and-push`) 改造为支持前后端两个镜像
  - 方案：
    - 保留一个 job，但在内部增加前端构建步骤
    - 或者更优：将 job 拆分为 `build-and-push-backend` 与 `build-and-push-frontend` 两个并行 job（共享 setup 步骤）
  - 前后端镜像 tag 命名规则保持一致：`{REGISTRY}/{OWNER|user}/embbytok-{backend|frontend}:{VERSION}` + `:latest`
  - 在 Release Notes / Summary 中输出两个镜像的完整 tag
- **Acceptance Criteria Addressed**: AC-5, AC-7
- **Test Requirements**:
  - `programmatic` TR-5.1: 创建测试 tag，触发 docker-release 工作流后验证 registry 上存在 `embbytok-backend:{version}` 和 `embbytok-frontend:{version}`（以及 `:latest`）
  - `programmatic` TR-5.2: `docker pull` 拉取两个镜像并运行健康检查
- **Notes**: 需要确认 `DOCKER_IMAGE_NAME` Secret 是否仍有存在价值，或直接使用固定命名 `{owner}/embbytok-{backend|frontend}`

## [ ] Task 6: 创建 secrets-check.yml - Secrets 配置检查工作流
- **Priority**: P1
- **Depends On**: 无
- **Description**:
  - 创建新文件 `.github/workflows/secrets-check.yml`
  - 支持 `workflow_dispatch` 手动触发
  - 包含两个 job:
    1. `android-secrets-check`: 验证 4 个 Android Secrets
    2. `docker-secrets-check`: 验证 3 个 Docker Secrets
  - 每个检查输出状态，最终通过 `echo "..." >> $GITHUB_STEP_SUMMARY` 生成 Markdown 表格报告
  - 表格列：Secret 名称、用途、配置状态（✅已配置/⚠️格式可疑/❌缺失）
- **Acceptance Criteria Addressed**: AC-8
- **Test Requirements**:
  - `human-judgment` TR-6.1: 在 GitHub Actions 页面手动触发该工作流，确认 Summary 输出美观的表格报告
  - `programmatic` TR-6.2: 工作流总耗时 < 30 秒
- **Notes**: 无法在工作流中直接读取 Secret 的值进行验证（GitHub Actions 会将其屏蔽）。我们只能检查变量是否被定义（非空字符串），以及对 `ANDROID_KEYSTORE` 做长度校验

## [ ] Task 7: 创建开发者文档 - SECRETS.md
- **Priority**: P1
- **Depends On**: 无
- **Description**:
  - 创建 `.github/SECRETS.md`，内容包括：
    1. **概述**：一句话说明为何需要这些 Secrets
    2. **完整 Secrets 表格**（7 行）：名称、描述、格式要求、示例
    3. **Android 签名配置步骤**：生成 keystore 的完整 `keytool` 命令，设置 DN，base64 编码（Linux/macOS `base64 -w 0`，Windows PowerShell `[Convert]::ToBase64String([IO.File]::ReadAllBytes(...))`），如何在 GitHub 页面添加
    4. **Docker Hub 配置步骤**：注册账号 / 创建 Access Token（Personal Access Token），如何填入 `DOCKER_USERNAME` / `DOCKER_PASSWORD` / `DOCKER_REGISTRY`
    5. **GitHub 配置操作指引**：截图/文字描述：Settings → Secrets and variables → Actions → New repository secret
    6. **验证配置**：如何手动运行 secrets-check 工作流验证
    7. **常见问题（FAQ）**：base64 编码错误、keystore 密码含特殊字符、Docker Hub 登录失败、忘记 alias 等
- **Acceptance Criteria Addressed**: AC-9
- **Test Requirements**:
  - `human-judgment` TR-7.1: 新开发者走查文档，确认可以在 30 分钟内独立完成所有配置
  - `human-judgment` TR-7.2: 文档结构清晰，无歧义，命令可直接复制执行

## [ ] Task 8: 更新根级 README.md - CI/CD 章节
- **Priority**: P1
- **Depends On**: Task 7
- **Description**:
  - 在现有 README 的 CI/CD 或部署相关章节中，添加 "发布配置" 小节
  - 简要列出 7 个 Secrets 名称及用途概述
  - 链接到 `.github/SECRETS.md` 作为详细指南
  - 说明触发条件（推送 `v*` tag 自动触发 release，或手动 workflow_dispatch）
- **Acceptance Criteria Addressed**: AC-9
- **Test Requirements**:
  - `human-judgment` TR-8.1: 阅读 README 的新小节，能快速理解需要配置哪些 Secrets 并找到后续链接

## [ ] Task 9: 工作流语法统一与 lint 检查
- **Priority**: P2
- **Depends On**: Task 1-6
- **Description**:
  - 对所有 `.github/workflows/*.yml` 文件进行统一风格检查
  - 所有 shell 步骤使用 `shell: bash` 显式声明
  - 所有 shell 脚本开头添加 `set -euo pipefail`
  - 为所有 shell 步骤添加中文 `name:`
  - 通过 yamllint 确认无语法错误（indent 2，不强制行宽）
- **Acceptance Criteria Addressed**: AC-10
- **Test Requirements**:
  - `programmatic` TR-9.1: `yamllint .github/workflows/` 无 error 级别的问题
  - `programmatic` TR-9.2: 所有 shell step 在 Actions runner 上无 `set: illegal option` 或类似语法错误

## [ ] Task 10: 端到端验证与修复迭代
- **Priority**: P0
- **Depends On**: Task 1-9
- **Description**:
  - 在一个 fork 或测试仓库中，按以下场景完整测试：
    1. 无任何 Secrets → 两个 release 工作流在第一步失败（AC-1, AC-4）
    2. 仅配置部分 Android Secrets → android-release 失败在验证步骤（AC-1）
    3. 配置无效 base64 的 Android Secrets → 失败在 keystore 验证步骤（AC-2）
    4. 配置正确的 Android Secrets → 完整构建成功并生成 Release（AC-3）
    5. 配置正确的 Docker Secrets → 前后端镜像推送成功（AC-5, AC-7）
    6. 手动触发 secrets-check → 输出正确报告（AC-8）
  - 根据实际测试结果修复问题并迭代
- **Acceptance Criteria Addressed**: AC-1 through AC-10
- **Test Requirements**:
  - `programmatic` TR-10.1: 以上 6 个场景全部按预期行为通过
  - `programmatic` TR-10.2: 前端镜像可以在本地成功 `docker run` 并访问（AC-6）
- **Notes**: 此步骤需要真实的 GitHub Actions 环境执行（本地 Act 工具可能部分替代，但建议在实际 GitHub 仓库测试）
