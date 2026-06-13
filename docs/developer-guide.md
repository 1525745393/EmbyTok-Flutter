# EmbyTok - 开发者指南

> 本文件目标：为项目贡献者提供完整的本地开发环境搭建、代码规范、测试流程、CI/CD 工作流说明以及常用命令速查。
>
> 开始之前建议先阅读：[架构总览](architecture.md)（理解项目结构后开发效率更高）

---

## 一、前置依赖

| 依赖 | 最低版本 | 用途 | 验证命令 |
|------|---------|------|---------|
| **Flutter SDK** | 3.19.0 | 构建移动应用 | `flutter --version` |
| **Dart SDK** | 3.3.0 | Dart 语言（随 Flutter 安装） | `dart --version` |
| **Python** | 3.10+ | 后端 FastAPI 服务 | `python3 --version` |
| **Android Studio**（可选） | Giraffe | 构建 Android APK | `studio.sh --version` |
| **Git** | 2.0+ | 版本控制 | `git --version` |

### 1.1 安装 Flutter（macOS / Linux）

```bash
# 方法 A：使用官方包管理器
# macOS（Homebrew）
brew install --cask flutter

# Linux：下载官方包
cd ~/Downloads
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.0-stable.tar.xz
tar -xf flutter_linux_3.24.0-stable.tar.xz -C ~/
export PATH="$HOME/flutter/bin:$PATH"  # 添加到 ~/.bashrc 或 ~/.zshrc

# 运行 Flutter 诊断
flutter doctor

# 启用 Android 平台（如果要构建 APK）
flutter doctor --android-licenses
```

`flutter doctor` 预期输出：

```
[✓] Flutter (Channel stable, 3.24.0)
[✓] Android toolchain - develop for Android devices
[✓] Android Studio (version Giraffe)
[✓] Connected device (1 available)
```

### 1.2 安装 Python 3.10+

```bash
# macOS
brew install python@3.11

# Ubuntu/Debian
sudo apt install python3 python3-venv python3-pip
```

---

## 二、获取项目代码

```bash
# 克隆仓库
git clone https://github.com/1525745393/EmbyTok-Flutter.git
cd EmbyTok-Flutter

# 查看项目结构
ls -la
```

你应该看到以下目录结构：

```
EmbyTok-Flutter/
├── frontend/      # Flutter 客户端
├── backend/       # FastAPI 中间层
├── docs/          # 文档（本文件所在目录）
├── Makefile       # 统一的命令入口
├── docker-compose.yml
├── CODE_WIKI.md
├── README.md
└── ...
```

---

## 三、搭建 Flutter 前端开发环境

### 3.1 安装依赖

```bash
cd frontend

# 安装 Dart 依赖（第一次执行或 pubspec.yaml 变更后需要）
flutter pub get
```

### 3.2 运行开发版本

```bash
# 连接 Android 设备或启动模拟器后
flutter devices
# 输出:
# 1 connected device:
#   • Android SDK built for x86 • emulator-5554 • android-x86 • Android 11 (API 30) (emulator)

# 启动开发版本（带热重载 Hot Reload）
flutter run

# 启动到特定设备
flutter run -d <device-id>

# 使用 Profile 模式（接近生产性能，保留调试信息）
flutter run --profile

# 使用 Release 模式（完全优化，无调试信息）
flutter run --release
```

**热重载（Hot Reload）**：运行 `flutter run` 后，在终端按 `r` 键即可热重载（无需重启应用，状态保留）。按 `R` 全量重启。

### 3.3 构建 APK

```bash
# 构建 Release APK（包含所有 ABI，文件较大）
flutter build apk --release

# 按 ABI 拆分（推荐，生成多个 APK 供不同 CPU 架构）
flutter build apk --release --split-per-abi

# 产物位置
# build/app/outputs/flutter-apk/
#   app-arm64-v8a-release.apk   ← 现代手机（推荐）
#   app-armeabi-v7a-release.apk ← 较旧设备
#   app-x86_64-release.apk      ← 模拟器
```

### 3.4 构建 Web 版

```bash
flutter build web --release
# 产物: build/web/
# 可部署到任何静态文件服务器（Nginx / GitHub Pages 等）
```

---

## 四、搭建 FastAPI 后端开发环境

### 4.1 创建虚拟环境并安装依赖

```bash
cd backend

# 创建虚拟环境（首次需要）
python3 -m venv .venv
source .venv/bin/activate         # Windows: .venv\Scripts\activate

# 安装依赖
pip install --upgrade pip
pip install -r requirements.txt
```

### 4.2 启动开发服务器

```bash
# 开发模式（带自动重载，推荐）
uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# 生产模式
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
```

启动成功后：

```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Started reloader process [12345] using WatchFiles
INFO:     Started server process [12346]
INFO:     Application startup complete.
```

### 4.3 验证后端

```bash
# 健康检查
curl http://localhost:8000/health
# 预期: {"status":"ok","version":"1.0.0","service":"embbytok-backend"}

# Swagger UI（交互式 API 文档）
# 浏览器打开: http://localhost:8000/docs
```

### 4.4 运行后端测试

```bash
cd backend
source .venv/bin/activate
pip install pytest pytest-asyncio httpx

python -m pytest tests/ -v

# 生成覆盖率报告
python -m pytest tests/ --cov=. --cov-report=html
# 报告位置: htmlcov/index.html
```

---

## 五、使用 Makefile（命令速查）

项目根目录的 `Makefile` 为常用任务提供快捷命令。你不需要分别进入 `frontend/` 和 `backend/`。

```bash
cd EmbyTok-Flutter

# 显示帮助（查看所有可用命令）
make help

# 一键安装所有依赖（Flutter + Python）
make setup

# 启动前端（Flutter 应用）
make run-frontend

# 启动后端（FastAPI）
make run-backend

# 同时启动前后端（推荐开发使用）
make run-all

# 运行 Flutter 测试
make test-frontend

# 运行 Python 测试
make test-backend

# 运行全部测试
make test-all

# Flutter 静态分析（代码质量检查）
make lint

# 构建 Android APK
make build-apk

# 构建后端 Docker 镜像
make build-docker

# 清理构建产物
make clean

# 停止后端服务
make stop
```

---

## 六、代码规范与代码质量

### 6.1 Flutter / Dart 规范

**静态分析**：

```bash
cd frontend
flutter analyze
```

**代码格式化**：

```bash
flutter format lib/
```

**命名约定**：

| 元素 | 命名风格 | 示例 |
|------|---------|------|
| 类 / 枚举 / 类型参数 | UpperCamelCase | `AuthProvider`, `VideoControls` |
| 变量 / 函数 / 方法 | lowerCamelCase | `accessToken`, `loginWithPassword()` |
| 常量 | lowerCamelCase（或全大写，Flutter 推荐前者） | `kPrimaryColor`, `maxRetries` |
| 文件名 / 目录名 | snake_case | `auth_provider.dart`, `video_controls.dart` |

### 6.2 Python 规范

**代码风格检查**：

```bash
cd backend
source .venv/bin/activate
pip install ruff
ruff check .

# 自动修复可修复的问题
ruff check . --fix
```

**类型检查**：

```bash
pip install mypy
mypy .
```

**命名约定**（遵循 PEP 8）：

| 元素 | 命名风格 | 示例 |
|------|---------|------|
| 类 | UpperCamelCase | `EmbyClient`, `AuthRequest` |
| 函数 / 变量 / 方法 | snake_case | `access_token`, `get_libraries()` |
| 常量 | UPPER_SNAKE_CASE | `MAX_RETRIES`, `DEFAULT_TIMEOUT` |
| 模块 / 文件名 | snake_case | `emby_client.py`, `auth.py` |

### 6.3 代码文件头部约定

每个代码文件开头应简短描述文件用途。示例：

```dart
// lib/services/api_client.dart
// API 客户端：封装 Dio HTTP 请求，统一注入鉴权 Header，统一错误处理
```

```python
# backend/routers/auth.py
# 认证路由：提供 /api/auth/login 端点，转发用户凭证到 Emby 服务器
```

---

## 七、提交规范与 Git 工作流

### 7.1 提交信息格式

遵循 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

```
<type>(<scope>): <subject>
<空行>
<body>（可选）
```

**type 可选值**：

| type | 说明 | 示例 |
|------|------|------|
| `feat` | 新功能 | `feat(video): 支持倍速播放 1.5x` |
| `fix` | 修复 bug | `fix(auth): 修复登录后 Token 丢失的问题` |
| `docs` | 文档变更 | `docs: 完善开发者指南` |
| `refactor` | 重构代码（非功能变更） | `refactor(api): 统一响应格式` |
| `perf` | 性能优化 | `perf(backend): 使用 httpx 连接池` |
| `test` | 新增/修改测试 | `test(auth): 登录流程测试` |
| `chore` | 构建/工具链/依赖更新 | `chore(deps): 升级 flutter 到 3.24.0` |
| `style` | 代码格式调整（不影响逻辑） | `style: 统一缩进为 2 空格` |

### 7.2 分支命名

```
# 新功能
feat/video-playback

# 修复 Bug
fix/login-token-loss

# 文档
docs/developer-guide

# 重构
refactor/api-response-format
```

### 7.3 推荐工作流

```bash
# 1. 切换到主分支并更新
git checkout main
git pull origin main

# 2. 创建新分支
git checkout -b feat/your-feature-name

# 3. 开发（小步提交，保持代码随时可工作）
git add .
git commit -m "feat(scope): 说明这次提交做了什么"

# 4. 推送分支
git push origin feat/your-feature-name

# 5. 在 GitHub 上提交 Pull Request
#    → 关联一个 Issue（如有）
#    → 请求 code review
#    → 通过后合并
```

### 7.4 提交前的自检清单

提交前建议逐一检查：

- [ ] `flutter analyze` 无错误
- [ ] `flutter test` 全部通过
- [ ] `ruff check backend/` 无警告
- [ ] `python -m pytest backend/tests/` 全部通过
- [ ] 手动在真机或模拟器上运行一次关键流程（登录→浏览→播放）
- [ ] 提交信息符合 Conventional Commits 规范

---

## 八、测试指南

### 8.1 Flutter 测试

```bash
cd frontend

# 运行全部单元测试
flutter test

# 运行单个测试文件
flutter test test/models/user_test.dart

# 运行带覆盖率
flutter test --coverage
# 报告位置: coverage/lcov.info
# 可视化: lcov --list coverage/lcov.info
```

**测试文件位置**：`frontend/test/`

**测试类型**：

| 类型 | 说明 | 位置 |
|------|------|------|
| 单元测试 | 测试单个函数 / 类 | `test/models/`, `test/utils/` |
| Widget 测试 | 测试单个 UI 组件 | `test/widgets/` |
| 集成测试 | 端到端测试 | `test/integration_test/` |

### 8.2 Python 后端测试

```bash
cd backend
source .venv/bin/activate

# 运行所有测试
python -m pytest tests/ -v

# 运行单个测试
python -m pytest tests/test_health.py -v

# 生成覆盖率报告
python -m pytest tests/ --cov=. --cov-report=html
# 浏览器打开: htmlcov/index.html
```

**测试文件位置**：`backend/tests/`

---

## 九、CI/CD 工作流

### 9.1 工作流文件

项目使用 GitHub Actions，配置文件位于 `.github/workflows/`：

| 工作流 | 文件 | 触发条件 | 功能 |
|--------|------|---------|------|
| **Android Release** | `android-release.yml` | Push tag `v*` | 构建 Android APK 并上传到 GitHub Release |
| **Docker Release** | `docker-release.yml` | Push tag `v*` | 构建并推送 Docker 镜像 |
| **CI** | `ci.yml` | Push / PR 到 main 分支 | 运行 lint、测试、构建检查 |
| **Secrets Check** | `secrets-check.yml` | Push / PR | 扫描提交的敏感信息（密钥、Token 等） |

### 9.2 触发发布流程

发布新版本时，推送一个符合 SemVer 规范的 tag：

```bash
git checkout main
git pull origin main

# 创建 tag（使用语义化版本号）
git tag -a v1.0.7 -m "Release v1.0.7: 修复登录 bug + 添加收藏功能"

# 推送到 GitHub（自动触发 Release 工作流）
git push origin v1.0.7
```

到 GitHub 仓库的 **Actions** 页面查看构建进度，成功后 Releases 页面会出现新版本并附带 APK 产物。

---

## 十、调试技巧

### 10.1 Flutter 调试

```bash
# 启动调试模式（连接设备后）
flutter run --debug

# 查看应用日志
flutter logs

# 查看 Dart 分析结果（代码质量）
flutter analyze

# 查看 Widget rebuild 性能
flutter run --debug --profile-widgets
```

### 10.2 后端调试

```bash
# 启动时开启自动重载（代码变更无需手动重启）
uvicorn main:app --reload

# 查看详细日志（调试模式）
uvicorn main:app --log-level debug

# 在浏览器中调试 API
# http://localhost:8000/docs  ← Swagger UI（可直接"Try it out"）
# http://localhost:8000/redoc ← ReDoc 文档
```

### 10.3 调试登录流程

1. 在 `frontend/lib/providers/auth_provider.dart` 的 `login()` 方法设置断点
2. 在 `backend/routers/auth.py` 的 `/api/auth/login` 端点设置断点（或 `print` 调试）
3. 用 Postman / curl 单独测试后端：

```bash
curl -X POST http://192.168.1.6:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"emby_url":"http://192.168.1.6:8010","username":"FK","password":"your-password"}'
```

---

## 十一、常见开发问题

### ❓ Flutter: `flutter pub get` 失败

**症状**：`Because embbytok requires SDK version >=3.19.0 <4.0.0, version solving failed.`

**解决**：升级 Flutter SDK

```bash
flutter upgrade
flutter --version   # 确认 >= 3.19.0
```

### ❓ Flutter: 找不到设备

**症状**：`flutter run` 输出 "No supported devices connected"

**解决**：

```bash
# 查看可用设备
flutter devices

# 启动 Android 模拟器
flutter emulators --launch <emulator-id>

# 或者通过 USB 连接手机（需开启开发者模式+USB 调试）
```

### ❓ 后端: `Address already in use`

**症状**：`OSError: [Errno 48] Address already in use`

**解决**：端口被占用，杀掉占用 8000 端口的进程

```bash
lsof -ti:8000 | xargs kill -9   # macOS / Linux
# Windows: netstat -ano | findstr :8000 → 用任务管理器杀进程
```

---

## 十二、资源与参考

| 资源 | 链接 |
|------|------|
| **Flutter 官方文档** | https://docs.flutter.dev/ |
| **Riverpod 文档** | https://riverpod.dev/ |
| **FastAPI 官方文档** | https://fastapi.tiangolo.com/ |
| **Emby API 文档** | https://swagger.emby.media/ |
| **Conventional Commits** | https://www.conventionalcommits.org/ |
| **Dart 代码规范** | https://dart.dev/guides/language/effective-dart |
| **PEP 8 - Python 代码风格** | https://peps.python.org/pep-0008/ |
| **项目架构说明** | [架构总览](architecture.md) |
| **API 参考** | [API 参考](api-reference.md) |
| **部署指南** | [部署指南](deployment.md) |
| **用户使用指南** | [用户指南](user-guide.md) |
| **故障排查** | [故障排查](troubleshooting.md) |

---

## 十三、第一次贡献的路径推荐

如果你是第一次接触这个项目，建议按以下路径上手：

```
1. 阅读 README.md → 了解项目是什么
2. 阅读 docs/architecture.md → 理解三层架构和核心模块
3. 按本文件第三节和第四节 → 搭建本地环境
4. make run-all → 同时启动前后端，在手机上安装应用
5. 浏览一个简单路由文件（如 backend/routers/libraries.py）
6. 浏览一个简单 Provider（如 frontend/lib/providers/library_provider.dart）
7. 尝试做一个小改动：例如修改首页的标题文字
8. flutter analyze + flutter test → 确保一切正常
9. 提交 PR: feat(your-name): 小改动说明
```

---

*文档版本：v1.0 | 最后更新：2026-06-12 | 对应项目版本：EmbyTok-Flutter v1.0.x*
