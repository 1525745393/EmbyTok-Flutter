#!/bin/bash
# ============================================================
# EmbyTok - 一键启动前后端服务
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log_info()    { echo -e "${CYAN}[信息]${NC} $1"; }
log_success() { echo -e "${GREEN}[成功]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[警告]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

main() {
    echo ""
    echo -e "${BOLD}${CYAN}=======================================================${NC}"
    echo -e "${BOLD}${CYAN}              EmbyTok - 启动所有服务                   ${NC}"
    echo -e "${BOLD}${CYAN}=======================================================${NC}"

    echo ""
    log_info "启动后端服务..."
    cd "$PROJECT_ROOT"

    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose up -d
        log_success "后端服务已启动"
        log_info "后端地址: http://localhost:8000/docs"
    else
        log_warn "未检测到 docker-compose，使用 uvicorn 启动后端..."
        cd "$PROJECT_ROOT/backend"
        python3 -m uvicorn main:app --reload --host 0.0.0.0 --port 8000 &
        log_success "后端服务已启动 (PID: $!)"
    fi

    echo ""
    log_info "启动 Flutter 应用..."
    log_warn "提示：按 Ctrl+C 退出 Flutter 后运行 make stop 停止后端服务"
    echo ""

    cd "$PROJECT_ROOT/frontend"
    flutter run

    log_success "应用已退出"
}

main "$@"
