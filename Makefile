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
.PHONY: help setup run-backend run-frontend run-all stop test-all test-frontend test-backend lint build-apk build-ios build-docker clean docker-push

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
