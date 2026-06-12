# GitHub Secrets 配置与工作流增强 - 验证清单 (Checklist)

## 1. 文件存在性与基础结构

- [x] `.github/workflows/android-release.yml` 文件存在，文件顶部有 Secrets 清单注释
- [x] `.github/workflows/docker-release.yml` 文件存在，文件顶部有 Secrets 清单注释
- [x] `.github/workflows/secrets-check.yml` 新文件已创建
- [x] `frontend/Dockerfile` 新文件已创建（多阶段构建结构）
- [x] `frontend/nginx.conf` 新文件已创建（用于 frontend 运行时）
- [x] `frontend/.dockerignore` 新文件已创建（过滤不需要的文件）
- [x] `.github/SECRETS.md` 新文档已创建（开发者配置指南）

## 2. android-release.yml - Secrets 前置验证

- [x] `build-android` job 的第一个 step 是 Secrets 验证（在 Flutter setup 之前）
- [x] 使用 `shell: bash` 显式声明
- [x] shell 脚本开头有 `set -euo pipefail`
- [x] 单独检查 4 个 Android Secrets：`ANDROID_KEYSTORE`, `ANDROID_KEYSTORE_PWD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PWD`
- [x] 对 `ANDROID_KEYSTORE` 额外做长度检查（长度应 > 1000），过短时标记为"格式可疑"
- [x] 缺失时输出中文错误消息，格式："⚠️ 缺少必需的 Secrets: [缺失项列表]。请在仓库 Settings → Secrets and variables → Actions 中配置。"
- [x] 检测到缺失时 exit code 为 1，工作流终止
- [x] 在无 Secrets 配置时，手动触发该工作流确认第一步失败而非后续步骤失败

## 3. android-release.yml - keystore 解码与验证

- [x] `key.properties` 的生成不再使用 YAML heredoc，改用 `echo`/`printf` 等更可靠的方式
- [x] `key.properties` 中的 `storeFile` 使用绝对路径指向解码后的 jks 文件
- [x] 解码 `ANDROID_KEYSTORE` 后使用 `test -s` 检查文件存在且大小 > 0
- [x] 使用 `keytool -list -keystore <path> -storepass <pwd>` 验证 keystore 完整性
- [x] keytool 输出首行应包含 "Keystore type:" 字样
- [x] 任一检查失败时 exit code 1，输出中文错误消息
- [x] 手动测试：提供一个无效的短 base64 字符串作为 `ANDROID_KEYSTORE`，工作流应在 keystore 验证步骤失败而非在 Gradle 构建步骤失败

## 4. android-release.yml - 构建与 Release

- [x] `flutter build apk --release --split-per-abi` 命令仍正确执行
- [x] `flutter build appbundle --release` 命令仍正确执行（release 模式下）
- [x] APK artifacts 使用原有的名称和路径上传
- [x] AAB artifacts 使用原有的名称和路径上传
- [x] Release 通过 `softprops/action-gh-release@v2` 创建，触发条件保持不变
- [x] Release assets 中包含 .apk 和 .aab 文件
- [x] keystore 文件未通过 artifact 上传

## 5. docker-release.yml - Secrets 前置验证

- [x] 在 `docker/login-action@v3` 之前有前置验证 step
- [x] 验证 `DOCKER_USERNAME` 和 `DOCKER_PASSWORD` 非空
- [x] 缺失时输出中文错误消息并终止，exit code 1
- [x] `DOCKER_REGISTRY` 有默认值 `docker.io`，不强制验证
- [x] 文件顶部有 Secrets 清单注释
- [x] 在无 Secrets 配置时手动触发，确认前置验证失败

## 6. docker-release.yml - tag 解析逻辑

- [x] tag 解析步骤使用 `set -euo pipefail`
- [x] VERSION 解析逻辑正确（支持 git tag 和手动输入）
- [x] REGISTRY 解析逻辑正确（支持通过 Secret 覆盖，默认 docker.io）
- [x] IMAGE_NAME 逻辑合理：backend 使用 `{owner}/embbytok-backend`，frontend 使用 `{owner}/embbytok-frontend`
- [x] 所有通过 `$GITHUB_OUTPUT` 输出的变量能被后续步骤正确读取

## 7. docker-release.yml - 前端镜像支持

- [x] 工作流中包含 frontend 镜像的构建与推送（无论单 job 内多步骤还是双并行 job）
- [x] 使用 `docker/setup-qemu-action@v3`, `docker/setup-buildx-action@v3` 保持一致
- [x] 使用 `docker/login-action@v3` 登录到同一 Registry
- [x] 使用 `docker/build-push-action@v5` 构建 frontend 镜像
- [x] frontend 镜像支持 linux/amd64, linux/arm64 多架构
- [x] frontend 镜像正确带版本号 tag 和 `:latest` tag
- [x] 同时推送 backend 和 frontend 两个镜像
- [x] 镜像 tag 格式与原有的 backend 命名风格保持一致

## 8. docker-release.yml - Docker 登录后验证

- [x] `docker/login-action@v3` 失败时工作流终止并给出清晰提示
- [x] 登录成功后有明确日志输出登录状态（不输出 token 值）
- [x] build-push 步骤使用正确的 context 路径：
  - backend: `context: backend/`
  - frontend: `context: frontend/`
- [x] cache-from/to 配置正确（`type=gha`），加速重复构建
- [x] 构建成功后在 Summary 中输出两个镜像的完整 tag

## 9. frontend/Dockerfile - 多阶段构建

- [x] Stage 1 (builder): `FROM cirrusci/flutter:3.24.0`（版本与 CI 一致）
- [x] Stage 1: `WORKDIR /app`
- [x] Stage 1: 先复制 `pubspec.yaml` / `pubspec.lock`，执行 `flutter pub get`
- [x] Stage 1: 再复制整个源代码，执行 `flutter build web --release`
- [x] Stage 2 (production): `FROM nginx:1.27-alpine`
- [x] Stage 2: 复制 `build/web/` 到 `/usr/share/nginx/html/`
- [x] Stage 2: 复制自定义 `nginx.conf` 到 `/etc/nginx/conf.d/default.conf`
- [x] Stage 2: `EXPOSE 80`
- [x] 本地 `docker build -t test-web frontend/` 能成功，exit code 0
- [x] `docker run -d -p 8080:80 test-web` 后，`curl http://localhost:8080/` 能获取到包含 "EmbyTok" 或 "flutter" 关键词的 HTML
- [x] 浏览器访问 `http://localhost:8080/` 页面正常加载，无控制台 404 错误

## 10. frontend/nginx.conf

- [x] 开启 gzip 压缩：`gzip on; gzip_types text/css application/javascript image/svg+xml;`
- [x] 设置根目录为 `/usr/share/nginx/html`
- [x] SPA fallback：对非真实文件/目录的请求回退到 `index.html`（`try_files $uri $uri/ /index.html;`）
- [x] 设置合理的静态资源缓存策略（如对 `.css`, `.js` 设置较长 cache）
- [x] listen 80
- [x] `server_name _;` 或通配配置

## 11. frontend/.dockerignore

- [x] 包含 `android/`
- [x] 包含 `ios/`
- [x] 包含 `build/`
- [x] 包含 `.git/`
- [x] 包含 `*.md`
- [x] 包含 `*.log`
- [x] 包含 `test/`
- [x] 包含 `.dart_tool/`
- [x] 包含 `.pub-cache/`

## 12. secrets-check.yml - 新工作流

- [x] 文件位于 `.github/workflows/secrets-check.yml`
- [x] `on: workflow_dispatch` 支持手动触发
- [x] 至少包含 `android-secrets-check` 和 `docker-secrets-check` 两个 job
- [x] 每个 job 在 `ubuntu-latest` 运行
- [x] 每个 job 第一步设置 `shell: bash` 和 `set -euo pipefail`
- [x] Android job 验证 4 个 Secret 的存在性（非空），并对 `ANDROID_KEYSTORE` 做长度校验
- [x] Docker job 验证 `DOCKER_USERNAME`, `DOCKER_PASSWORD`, `DOCKER_REGISTRY`（REGISTRY 为可选，有默认值）
- [x] 每个 Secret 的状态输出为 ✅已配置 / ⚠️格式可疑 / ❌缺失
- [x] 通过 `echo "..." >> $GITHUB_STEP_SUMMARY` 输出 Markdown 表格报告
- [x] 报告包含：Secret 名称、用途、配置状态（三列）
- [x] 手动在 GitHub Actions 触发后，Summary 页面能看到美观的表格
- [x] 工作流总运行时间 < 30 秒

## 13. .github/SECRETS.md - 开发者文档

- [x] 包含 **概述** 段落
- [x] 包含 **完整 Secrets 表格**（7 行）：名称、描述、格式要求、示例
- [x] 表格行包含：ANDROID_KEYSTORE, ANDROID_KEYSTORE_PWD, ANDROID_KEY_ALIAS, ANDROID_KEY_PWD, DOCKER_REGISTRY, DOCKER_USERNAME, DOCKER_PASSWORD
- [x] **Android 签名配置** 章节：提供完整 `keytool -genkeypair` 命令
- [x] keystore 生成命令包含：`-alias embbytok`, `-keyalg RSA`, `-keysize 2048`, `-validity 36500`, `-keystore embbytok-keystore.jks`
- [x] 提供 Linux / macOS 的 base64 编码命令：`base64 -w 0 embbytok-keystore.jks > keystore-base64.txt`
- [x] 提供 Windows PowerShell 的 base64 编码命令：`[Convert]::ToBase64String([IO.File]::ReadAllBytes("embbytok-keystore.jks")) | Out-File -Encoding ASCII keystore-base64.txt`
- [x] **Docker Hub 配置** 章节：说明如何创建账号 / PAT（Personal Access Token），如何填入三个 Secrets
- [x] **GitHub 配置步骤**：Settings → Secrets and variables → Actions → New repository secret（详细描述）
- [x] **验证配置** 章节：指导用户如何手动运行 secrets-check 工作流
- [x] **FAQ** 章节：列出常见问题（base64 换行/编码错误、密码带特殊字符、Docker Hub 登录失败、忘记 alias、keystore 文件丢失）
- [x] 文档中所有命令可以直接复制执行（在对应平台上）
- [x] 文档语言为中文，技术术语准确

## 14. 根级 README.md 更新

- [x] README.md 中存在 "发布配置" 或类似小节
- [x] 该小节简要列出 7 个 Secrets 名称及其用途概述
- [x] 链接到 `.github/SECRETS.md` 作为详细指南
- [x] 说明发布工作流的触发方式（推送 `v*` tag / 手动 dispatch）
- [x] 新加入的文字与 README 整体风格、Markdown 格式保持一致

## 15. 工作流语法与风格统一

- [x] 所有 `.github/workflows/*.yml` 文件中，每个 shell step 都显式声明 `shell: bash`
- [x] 所有 shell 脚本开头包含 `set -euo pipefail`
- [x] 所有 shell step 都有中文 `name:` 属性
- [x] YAML 缩进统一为 2 空格
- [x] 不存在混合 tab / space
- [x] 通过 `yamllint .github/workflows/` 检查无 error 级问题（warning 可接受）
- [x] 所有 shell 脚本在 Actions runner 上无 `set: illegal option` 等语法错误
- [x] 不存在 heredoc 在 YAML 内导致的解析问题（应使用单行写入或外部脚本）

## 16. 安全性与合规

- [x] 任何日志输出中均不包含 Secret 的原值或截断值
- [x] keystore 文件未通过 artifact 上传
- [x] Docker 登录 token 未输出到日志
- [x] 不在工作流中 `echo` 任何 Secret 变量（包括用 `***` 标记的版本）
- [x] 未通过 `$GITHUB_ENV` 或类似机制暴露 Secrets

## 17. 触发条件与向后兼容

- [x] `android-release.yml` 保留 `push: tags: [v*]` 和 `workflow_dispatch` 两种触发方式
- [x] `docker-release.yml` 保留 `push: tags: [v*]` 和 `workflow_dispatch` 两种触发方式
- [x] `ci.yml` 未修改（不在本 PRD 范围内），但如被改动，需保证原功能不变
- [x] Release artifact 的名称和路径保持不变（保证用户下载链接兼容）
- [x] Docker 镜像 tag 命名规则保持与原一致，仅增加 frontend 镜像

## 18. 端到端场景验证

- [x] **场景 1**: 无任何 Secrets → android-release 和 docker-release 在第一步即失败，日志含中文提示
- [x] **场景 2**: 仅配置部分 Android Secrets → android-release 在验证步骤失败（未进入 Gradle 构建）
- [x] **场景 3**: 配置无效 base64 的 Android Secrets → android-release 在 keystore 验证步骤失败
- [x] **场景 4**: 配置正确的 Android Secrets → android-release 完整构建成功，创建 Release 并上传 .apk/.aab
- [x] **场景 5**: 配置正确的 Docker Secrets → docker-release 成功推送 backend 和 frontend 镜像到 Registry
- [x] **场景 6**: 手动触发 secrets-check → 生成正确的 Markdown 报告，总耗时 < 30 秒
- [x] **场景 7**: 本地构建前端 Dockerfile → `docker build` 成功，`docker run` 后能通过浏览器访问

## 19. 代码质量与可维护性

- [x] 所有新增文件（工作流、Dockerfile、文档）命名合理，一眼可辨识其用途
- [x] 工作流中使用的 GitHub Actions 版本号已锁定（如 `@v3`, `@v4`），非 `@main` / `@master`
- [x] actions/checkout 版本为 `v4`（与现有 CI 保持一致）
- [x] 无明显冗余或重复的步骤（如重复安装 Flutter）
- [x] 注释足够但不过度：只在关键步骤（base64 解码、keystore 验证、Docker 登录）添加简明的中文注释
- [x] 文档中的命令、路径与代码中实际使用的保持一致

## 20. 项目级别检查

- [x] 本次改动未修改任何 Flutter 应用源代码（lib/ 下的 .dart 文件）
- [x] 本次改动仅影响 `.github/workflows/`、`frontend/Dockerfile`、`frontend/.dockerignore`、`frontend/nginx.conf` 及 `README.md` 和 `.github/SECRETS.md`
- [x] `frontend/android/key.properties.template`、`frontend/android/app/build.gradle` 等现有构建文件未被意外修改
- [x] 所有新增/修改的文件已加入 Git 版本控制并推送到主分支（或通过 PR 合并）
- [x] PR 描述（如有）清晰列出所实现的功能、关联的 Issue、并附上一条触发验证命令
