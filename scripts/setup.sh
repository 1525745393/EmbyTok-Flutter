#!/bin/bash
# ============================================================
# EmbyTok - 环境检查与依赖安装脚本
# 功能：检查开发环境，安装 Flutter + Python 依赖
# ============================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

log_info()    { echo -e "${CYAN}[信息]${NC} $1"; }
log_success() { echo -e "${GREEN}[成功]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[警告]${NC} $1"; }
log_error()   { echo -e "${RED}[错误]${NC} $1"; }
print_sep()   { echo -e "${MAGENTA}----------------------------------------${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

check_env() {
    echo ""
    log_info "检查开发环境..."
    print_sep

    if command -v flutter >/dev/null 2>&1; then
        flutter_version=$(flutter --version 2>/dev/null | head -n 1)
        log_success "Flutter 已安装: $flutter_version"
    else
        log_error "未检测到 Flutter SDK"
        log_info "请访问 https://docs.flutter.dev/get-started/install 安装 Flutter 3.10+"
        exit 1
    fi

    if command -v python3 >/dev/null 2>&1; then
        py_version=$(python3 --version 2>&1 | awk '{print $2}')
        log_success "Python 已安装: Python $py_version"
    else
        log_error "未检测到 Python3"
        exit 1
    fi

    if command -v docker >/dev/null 2>&1; then
        log_success "$(docker --version 2>&1)"
    else
        log_warn "未检测到 Docker（可选，构建 Docker 镜像需要）"
    fi

    print_sep
}

install_dependencies() {
    echo ""
    log_info "安装依赖..."
    print_sep

    echo ""
    log_info "安装 Flutter 依赖..."
    cd "$PROJECT_ROOT/frontend"
    if flutter pub get; then
        log_success "Flutter 依赖安装完成"
    else
        log_error "Flutter 依赖安装失败"
        exit 1
    fi

    echo ""
    log_info "安装 Python 依赖..."
    python3 -m pip install --upgrade pip >/dev/null 2>&1 || true
    cd "$PROJECT_ROOT/backend"
    if python3 -m pip install -r requirements.txt; then
        log_success "Python 依赖安装完成"
    else
        log_error "Python 依赖安装失败"
        exit 1
    fi

    print_sep
}

print_completion_info() {
    echo ""
    echo -e "${BOLD}${GREEN}========================================${NC}"
    echo -e "${BOLD}${GREEN}环境配置完成！${NC}"
    echo -e "${BOLD}${GREEN}========================================${NC}"
    echo ""
    log_info "下一步操作:"
    echo -e "  ${YELLOW}make run-all${NC}    - 启动所有服务"
    echo -e "  ${YELLOW}make test-all${NC}   - 运行所有测试"
    echo -e "  ${YELLOW}make lint${NC}       - 代码质量检查"
    echo ""
}

main() {
    echo ""
    echo -e "${BOLD}${BLUE}=======================================================${NC}"
    echo -e "${BOLD}${BLUE}            EmbyTok - 环境配置与依赖安装             ${NC}"
    echo -e "${BOLD}${BLUE}=======================================================${NC}"

    check_env
    install_dependencies
    print_completion_info
}

main "$@"
