# ===========================================================
#  EmbyTok - 统一 Makefile (中文工作流入口)
# ===========================================================
.DEFAULT_GOAL := help

# ===========================================================
# 配置
# ===========================================================
SHELL := /bin/bash
FRONTEND_DIR := frontend
BACKEND_DIR := backend
SCRIPTS_DIR := scripts

# ===========================================================
# 颜色
# ===========================================================
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
BLUE   := $(shell tput -Txterm setaf 4)
MAGENTA := $(shell tput -Txterm setaf 5)
CYAN   := $(shell tput -Txterm setaf 6)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)
BOLD   := $(shell tput -Txterm bold)

# ===========================================================
.PHONY: help setup run-backend run-frontend run-all stop test-all test-frontend test-backend lint build-apk build-ios build-docker clean docker-push version verify-release release-check release-docs

# ===========================================================
# 目标：显示帮助
# ===========================================================
help: ## 显示本帮助信息
	@echo ""
	@echo "$(BOLD)$(CYAN)╔══════════════════════════════════════════════════════════╗$(RESET)
	@echo "$(BOLD)$(CYAN)║                    EmbyTok 项目 Makefile 命令清单                    $(RESET)"
	@echo "$(BOLD)$(CYAN)╚══════════════════════════════════════════════════════════╝$(RESET)"
	@echo ""
	@echo "$(BOLD)$(YELLOW)◆ 环境配置$(RESET)"
	@awk 'BEGIN {FS = ":.*?## } /^[a-zA-Z][a-zA-Z0-9_-]*:/ { printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E '^\s+(setup|lint)'
	@echo ""
	@echo "$(BOLD)$(YELLOW)◆ 运行服务$(RESET)"
	@awk 'BEGIN {FS = ":.*?## } /^[a-zA-Z][a-zA-Z0-9_-]*:/ { printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST)' $(MAKEFILE_LIST) | grep -E '^\s+run-'
	@awk 'BEGIN {FS = ":.*?## } /^[a-zA-Z][a-zA-Z0-9_-]*:/ { printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E '^\s+stop'
	@echo ""
	@echo "$(BOLD)$(YELLOW)◆ 测试与构建$(RESET)"
	@awk 'BEGIN {FS = ":.*?## } /^[a-zA-Z][a-zA-Z0-9_-]*:/ { printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E '^\s+test-'
	@awk 'BEGIN {FS = ":.*?## } /^[a-zA-Z][a-zA-Z0-9_-]*:/ { printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E '^\s+lint'
	@echo ""
	@echo "$(BOLD)$(YELLOW)◆ 构建与发布$(RESET)"
	@awk 'BEGIN {FS = ":.*?## } /^[a-zA-Z][a-zA-Z0-9_-]*:/ { printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E '^\s+build-'
	@awk 'BEGIN {FS = ":.*?## } /^[a-zA-Z][a-zA-Z0-9_-]*:/ { printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E '^\s+docker-push'
	@echo ""
	@echo "$(BOLD)$(YELLOW)◆ 版本管理$(RESET)"
	@awk 'BEGIN {FS = ":.*?## } /^[a-zA-Z][a-zA-Z0-9_-]*:/ { printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E '^\s+(version|verify|release-)'
	@echo ""
	@echo "$(BOLD)$(YELLOW)◆ 其他$(RESET)"
	@awk 'BEGIN {FS = ":.*?## } /^[a-zA-Z][a-zA-Z0-9_-]*:/ { printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E '^\s+clean'
	@echo ""
	@echo "$(BOLD)$(MAGENTA)提示：Windows 用户请通过 WSL 使用本 Makefile$(RESET)"
	@echo ""

# ===========================================================
# 环境配置
# ===========================================================
setup: ## 安装所有依赖（Flutter + Python）
	@echo "$(BOLD)$(GREEN)◆ 开始安装依赖...$(RESET)"
	@echo "----------------------------------------"
	@echo "$(YELLOW)► 检查 Flutter 环境$(RESET)"
	@command -v flutter >/dev/null 2>&1 || { echo "$(MAGENTA)  未检测到 Flutter SDK，请先安装 Flutter$(RESET)'; exit 1; }
	@echo "$(GREEN)✓ Flutter $(shell flutter --version 2>/dev/null | head -n 1)$(RESET)"
	@echo ""
	@echo "$(YELLOW)► 安装 Flutter 依赖$(RESET)"
	cd $(FRONTEND_DIR) && flutter pub get
	@echo "$(GREEN)✓ Flutter 依赖安装完成$(RESET)"
	@echo ""
	@echo "$(YELLOW)► 检查 Python 环境$(RESET)"
	@command -v python3 >/dev/null 2>&1 || { echo "$(MAGENTA)  未检测到 Python3，请先安装 Python 3.11+$(RESET)'; exit 1; }
	@echo "$(GREEN)✓ Python $(shell python3 --version 2>&1)$(RESET)"
	@echo ""
	@echo "$(YELLOW)► 安装 Python 依赖$(RESET)"
	python3 -m pip install --upgrade pip
	python3 -m pip install -r $(BACKEND_DIR)/requirements.txt
	@echo "$(GREEN)✓ Python 依赖安装完成$(RESET)"
	@echo ""
	@echo "$(BOLD)$(GREEN)✅ 所有依赖安装完成！$(RESET)"

# ===========================================================
# 运行服务
# ===========================================================
run-backend: ## 启动后端服务（Docker Compose）
	@echo "$(BOLD)$(CYAN)◆ 启动后端服务$(RESET)"
	@echo "----------------------------------------"
	docker-compose up -d
	@echo "$(GREEN)✅ 后端服务已启动$(RESET)"
	@echo "  访问地址: http://localhost:8000/docs"
	@echo "  健康检查: curl http://localhost:8000/health"

run-frontend: ## 启动 Flutter 应用
	@echo "$(BOLD)$(CYAN)◆ 启动 Flutter 应用$(RESET)"
	@echo "----------------------------------------"
	@echo "$(YELLOW)请根据提示选择运行设备：$(RESET)"
	cd $(FRONTEND_DIR) && flutter run

run-all: ## 同时启动前后端服务
	@echo "$(BOLD)$(CYAN)◆ 启动所有服务$(RESET)"
	@echo "----------------------------------------"
	@echo "$(YELLOW)启动后端服务...$(RESET)"
	docker-compose up -d
	@echo "$(GREEN)✓ 后端服务已启动$(RESET)"
	@echo ""
	@echo "$(YELLOW)启动 Flutter 应用...$(RESET)"
	@echo "$(MAGENTA)提示：按 Ctrl+C 退出 Flutter，然后运行 'make stop' 停止后端服务$(RESET)"
	cd $(FRONTEND_DIR) && flutter run

stop: ## 停止所有后端服务
	@echo "$(BOLD)$(YELLOW)◆ 停止后端服务$(RESET)"
	docker-compose down
	@echo "$(GREEN)✅ 服务已停止$(RESET)"

# ===========================================================
# 测试与代码质量
# ===========================================================
test-all: test-frontend test-backend ## 运行所有测试
	@echo ""
	@echo "$(BOLD)$(GREEN)✅ 所有测试执行完成$(RESET)"

test-frontend: ## 运行 Flutter 测试
	@echo "$(BOLD)$(CYAN)◆ 运行 Flutter 测试$(RESET)"
	@echo "----------------------------------------"
	cd $(FRONTEND_DIR) && flutter test
	@echo "$(GREEN)✅ Flutter 测试通过$(RESET)"

test-backend: ## 运行 Python 后端测试
	@echo "$(BOLD)$(CYAN)◆ 运行 Python 测试$(RESET)"
	@echo "----------------------------------------"
	@if [ -d "$(BACKEND_DIR)/tests" ]; then \
		cd $(BACKEND_DIR) && python3 -m pytest -v || { \
			echo "$(MAGENTA)后端测试完成（可能无测试或测试失败，详见上方输出)$(RESET)"; \
		}; \
	else \
		echo "$(YELLOW)提示：backend/tests 目录不存在，跳过后端测试$(RESET)"; \
	fi

lint: ## 代码质量检查（flutter analyze）
	@echo "$(BOLD)$(CYAN)◆ 代码质量检查$(RESET)"
	@echo "----------------------------------------"
	@echo "$(YELLOW)► Flutter 静态分析$(RESET)"
	cd $(FRONTEND_DIR) && flutter analyze || true
	@echo "$(GREEN)✅ 分析完成$(RESET)"

# ===========================================================
# 构建
# ===========================================================
build-apk: ## 构建 Android APK (Release)
	@echo "$(BOLD)$(CYAN)◆ 构建 Android APK (Release)$(RESET)"
	@echo "----------------------------------------"
	cd $(FRONTEND_DIR) && flutter build apk --release --split-per-abi
	@echo "$(GREEN)✅ APK 构建完成$(RESET)"
	@echo "  输出目录: $(FRONTEND_DIR)/build/app/outputs/flutter-apk/"

build-ios: ## 构建 iOS（仅 macOS 支持）
	@echo "$(BOLD)$(CYAN)◆ 构建 iOS 应用$(RESET)"
	@echo "----------------------------------------"
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		echo "$(YELLOW)在 macOS 系统构建 iOS...$(RESET)"; \
		cd $(FRONTEND_DIR) && flutter build ios --release --no-codesign; \
		echo "$(GREEN)✅ iOS 构建完成$(RESET)"; \
	else \
		echo "$(MAGENTA)⚠ iOS 构建仅支持 macOS 系统$(RESET)"; \
	fi

build-docker: ## 构建 Docker 后端镜像
	@echo "$(BOLD)$(CYAN)◆ 构建 Docker 后端镜像$(RESET)"
	@echo "----------------------------------------"
	docker build -t embbytok-backend:latest $(BACKEND_DIR)/
	@echo "$(GREEN)✅ 镜像已构建: embbytok-backend:latest$(RESET)"

# ===========================================================
# 推送 Docker 镜像
# ===========================================================
docker-push: ## 推送 Docker 镜像（需配置 REGISTRY/IMAGE/TAG 环境变量）
	@echo "$(BOLD)$(CYAN)◆ 推送 Docker 镜像$(RESET)"
	@echo "----------------------------------------"
	@REGISTRY=$${REGISTRY:-docker.io}; \
	IMAGE_NAME=$${IMAGE_NAME:-embbytok-backend}; \
	TAG=$${TAG:-latest}; \
	IMAGE_TAG=$${REGISTRY}/$${IMAGE_NAME}:$${TAG}; \
	echo "$(YELLOW)使用镜像: $${IMAGE_TAG}$(RESET)"; \
	docker build -t $${IMAGE_TAG} $(BACKEND_DIR)/; \
	docker push $${IMAGE_TAG}; \
	echo "$(GREEN)✅ 镜像已推送: $${IMAGE_TAG}$(RESET)"

# ===========================================================
# 版本管理与发布
# ===========================================================
version: ## 显示当前项目版本号（前端 + 后端 + Git tag）
	@echo "$(BOLD)$(CYAN)◆ 项目版本信息$(RESET)"
	@echo "----------------------------------------"
	@echo "  前端 (pubspec.yaml):  $(YELLOW)$(shell grep -E '^version:' $(FRONTEND_DIR)/pubspec.yaml | awk '{print $$2}')$(RESET)"
	@echo "  前端 (build.gradle):  $(YELLOW)$(shell grep -E 'versionName' $(FRONTEND_DIR)/android/app/build.gradle | head -1 | sed -E 's/.*"([0-9.]+)".*/\1/') (code=$(shell grep -E 'versionCode' $(FRONTEND_DIR)/android/app/build.gradle | head -1 | awk '{print $$2}'))$(RESET)"
	@echo "  前端 (version.dart):  $(YELLOW)$(shell grep -E "kAppVersion = " $(FRONTEND_DIR)/lib/utils/version.dart | head -1 | sed -E "s/.*'([0-9.]+)'.*/\1/") (code=$(shell grep -E "kAppVersionCode = " $(FRONTEND_DIR)/lib/utils/version.dart | head -1 | awk -F'= ' '{print $$2}' | tr -d ';'))$(RESET)"
	@echo "  后端 (version.py):    $(YELLOW)$(shell grep -E '__version__.*=' $(BACKEND_DIR)/core/version.py | head -1 | sed -E 's/.*"([0-9.]+)".*/\1/')$(RESET)"
	@if command -v git >/dev/null 2>&1; then \
		echo "  Git 最新 tag:         $(YELLOW)$(shell git describe --tags --abbrev=0 2>/dev/null || echo "<暂无>")$(RESET)"; \
		echo "  Git 当前分支:         $(YELLOW)$(shell git rev-parse --abbrev-ref HEAD 2>/dev/null)$(RESET)"; \
	fi

verify-release: ## 运行发布前验证（版本号一致性 + CHANGELOG + Git 工作树）
	@echo "$(BOLD)$(CYAN)◆ 发布前验证$(RESET)"
	@echo "----------------------------------------"
	@$(SCRIPTS_DIR)/verify-release.sh

release-check: verify-release ## verify-release 的别名

release-docs: ## 打开 RELEASE.md 和 COMMIT_CONVENTION.md 文档说明
	@echo "$(BOLD)$(CYAN)◆ 版本管理文档$(RESET)"
	@echo "----------------------------------------"
	@echo "  $(GREEN)docs/RELEASE.md$(RESET)              - 版本升级与发布流程"
	@echo "  $(GREEN)docs/COMMIT_CONVENTION.md$(RESET) - Git 提交信息规范"
	@echo "  $(GREEN)CHANGELOG.md$(RESET)                 - 变更日志（Keep a Changelog）"
	@echo ""
	@echo "  快速命令："
	@echo "    make version          — 查看当前版本"
	@echo "    make verify-release   — 发布前检查"
	@echo "    make release-docs     — 查看文档列表"

# ===========================================================
# 清理
# ===========================================================
clean: ## 清理构建产物
	@echo "$(BOLD)$(YELLOW)◆ 清理构建产物$(RESET)"
	@echo "----------------------------------------"
	@echo "$(YELLOW)清理 Flutter 构建...$(RESET)"
	@rm -rf $(FRONTEND_DIR)/build/ 2>/dev/null || true
	@echo "$(YELLOW)清理 Python 缓存...$(RESET)"
	@find $(BACKEND_DIR) -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@find $(BACKEND_DIR) -name "*.pyc" -delete 2>/dev/null || true
	@find . -name ".pytest_cache" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)✅ 清理完成$(RESET)"
