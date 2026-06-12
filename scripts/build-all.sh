#!/bin/bash
# ============================================================
# EmbyTok - 全量构建脚本
# 功能：构建 Android APK + Docker 后端镜像
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

build_android() {
    echo ""
    log_info "构建 Android APK (Release)..."
    echo "----------------------------------------"

    cd "$PROJECT_ROOT/frontend"

    if flutter build apk --release --split-per-abi; then
        log_success "APK 构建完成"
        OUTPUT_DIR="$PROJECT_ROOT/frontend/build/app/outputs/flutter-apk"
        echo ""
        log_info "构建产物:"
        for apk in "$OUTPUT_DIR"/*.apk; do
            if [ -f "$apk" ]; then
                if command -v stat >/dev/null 2>&1; then
                    size_bytes=$(stat -c%s "$apk" 2>/dev/null || stat -f%z "$apk" 2>/dev/null || echo "0")
                    size_mb=$(awk "BEGIN {printf \"%.2f\", $size_bytes / 1048576}")
                    echo "  $(basename "$apk") - ${size_mb} MB"
                else
                    echo "  $(basename "$apk")"
                fi
            fi
        done
    else
        log_error "Android APK 构建失败"
        exit 1
    fi
}

build_docker() {
    local version="$1"
    echo ""
    log_info "构建 Docker 后端镜像..."
    echo "----------------------------------------"

    cd "$PROJECT_ROOT"

    IMAGE_NAME="embbytok-backend:${version}"

    if docker build -t "$IMAGE_NAME" backend/; then
        log_success "Docker 镜像构建完成: $IMAGE_NAME"
        image_info=$(docker images "$IMAGE_NAME" --format "{{.Size}}")
        log_info "镜像大小: $image_info"
    else
        log_error "Docker 镜像构建失败"
        exit 1
    fi
}

main() {
    echo ""
    echo -e "${BOLD}${CYAN}=======================================================${NC}"
    echo -e "${BOLD}${CYAN}        EmbyTok - 全量构建           ${NC}"
    echo -e "${BOLD}${CYAN}=======================================================${NC}"

    VERSION="${1:-latest}"
    log_info "版本号: $VERSION"

    build_android
    build_docker "$VERSION"

    echo ""
    echo -e "${BOLD}${GREEN}========================================${NC}"
    echo -e "${BOLD}${GREEN}全量构建完成！${NC}"
    echo -e "${BOLD}${GREEN}========================================${NC}"
    echo ""
    log_info "下一步:"
    echo -e "  测试 APK:    ${YELLOW}flutter install${NC}"
    echo -e "  启动服务:  ${YELLOW}docker run -p 8000:8000 embbytok-backend:${VERSION}${NC}"
    echo ""
}

main "$@"
