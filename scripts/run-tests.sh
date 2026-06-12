#!/bin/bash
# ============================================================
# EmbyTok - 统一测试执行脚本
# 功能：依次运行 Flutter 和 Python 测试
# ============================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log_info()    { echo -e "${CYAN}[信息]${NC} $1"; }
log_success() { echo -e "${GREEN}[成功]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[警告]${NC} $1"; }
log_error()   { echo -e "${RED}[错误]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

FLUTTER_OK=0
PYTHON_OK=0

run_flutter_tests() {
    echo ""
    log_info "运行 Flutter 测试..."
    echo "----------------------------------------"

    cd "$PROJECT_ROOT/frontend"

    if flutter test; then
        log_success "Flutter 测试通过"
        FLUTTER_OK=1
    else
        log_error "Flutter 测试失败"
        FLUTTER_OK=0
    fi
}

run_python_tests() {
    echo ""
    log_info "运行 Python 后端测试..."
    echo "----------------------------------------"

    if [ ! -d "$PROJECT_ROOT/backend/tests" ]; then
        log_warn "未找到 backend/tests 目录，跳过 Python 测试"
        PYTHON_OK=1
        return 0
    fi

    cd "$PROJECT_ROOT/backend"

    if python3 -m pytest -v; then
        log_success "Python 测试通过"
        PYTHON_OK=1
    else
        log_error "Python 测试失败"
        PYTHON_OK=0
    fi
}

print_summary() {
    echo ""
    echo "========================================"
    echo -e "${BOLD}测试结果汇总${NC}"
    echo "========================================"
    echo ""

    if [ "$FLUTTER_OK" -eq 1 ] && [ "$PYTHON_OK" -eq 1 ]; then
        echo -e "${BOLD}${GREEN}所有测试通过！${NC}"
        echo ""
        exit 0
    else
        echo -e "${BOLD}${RED}有测试失败${NC}"
        echo -e "  Flutter: $([ "$FLUTTER_OK" -eq 1 ] && echo "通过" || echo "失败")"
        echo -e "  Python:  $([ "$PYTHON_OK" -eq 1 ] && echo "通过" || echo "失败")"
        echo ""
        exit 1
    fi
}

main() {
    echo ""
    echo -e "${BOLD}${CYAN}=======================================================${NC}"
    echo -e "${BOLD}${CYAN}           EmbyTok - 测试执行              ${NC}"
    echo -e "${BOLD}${CYAN}=======================================================${NC}"

    run_flutter_tests
    run_python_tests
    print_summary
}

main "$@"
