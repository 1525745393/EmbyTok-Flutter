#!/bin/bash
# ============================================================
# EmbyTok - Docker 镜像构建并推送脚本
# 支持 Docker Hub 或私有仓库
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

REGISTRY="${REGISTRY:-docker.io}"
IMAGE_NAME="${IMAGE_NAME:-embbytok-backend}"
TAG="${TAG:-latest}"

build_and_push() {
    echo ""
    log_info "构建 Docker 镜像..."
    echo "----------------------------------------"

    IMAGE_TAG="${REGISTRY}/${IMAGE_NAME}:${TAG}"
    IMAGE_LATEST="${REGISTRY}/${IMAGE_NAME}:latest"

    log_info "镜像标签: $IMAGE_TAG"
    echo ""

    cd "$PROJECT_ROOT"

    log_info "开始构建..."
    if docker build -t "$IMAGE_TAG" backend/; then
        log_success "构建完成"
    else
        log_error "构建失败"
        exit 1
    fi

    if [ "$TAG" != "latest" ]; then
        log_info "打 latest 标签..."
        docker tag "$IMAGE_TAG" "$IMAGE_LATEST"
        log_success "标签完成"
    fi

    echo ""
    log_info "登录到 $REGISTRY..."

    if [ -n "${DOCKER_USERNAME:-}" ] && [ -n "${DOCKER_PASSWORD:-}" ]; then
        if echo "$DOCKER_PASSWORD" | docker login "$REGISTRY" -u "$DOCKER_USERNAME" --password-stdin; then
            log_success "登录成功"
        else
            log_error "登录失败"
            exit 1
        fi
    else
        log_warn "未设置 DOCKER_USERNAME 和 DOCKER_PASSWORD 环境变量"
        log_info "请设置环境变量:"
        echo "  export DOCKER_USERNAME=your-username"
        echo "  export DOCKER_PASSWORD=your-password"
        exit 1
    fi

    echo ""
    log_info "推送镜像到 $REGISTRY..."
    echo "----------------------------------------"

    if docker push "$IMAGE_TAG"; then
        log_success "$IMAGE_TAG 推送成功"
    else
        log_error "$IMAGE_TAG 推送失败"
        exit 1
    fi

    if [ "$TAG" != "latest" ]; then
        if docker push "$IMAGE_LATEST"; then
            log_success "$IMAGE_LATEST 推送成功"
        else
            log_warn "$IMAGE_LATEST 推送失败"
        fi
    fi

    echo ""
    log_info "退出登录..."
    docker logout "$REGISTRY" >/dev/null 2>&1 || true
    log_success "完成"
}

main() {
    echo ""
    echo -e "${BOLD}${CYAN}=======================================================${NC}"
    echo -e "${BOLD}${CYAN}             EmbyTok - Docker 镜像构建与推送              ${NC}"
    echo -e "${BOLD}${CYAN}=======================================================${NC}"
    echo ""
    log_info "配置信息:"
    echo "  仓库:    $REGISTRY"
    echo "  镜像名:  $IMAGE_NAME"
    echo "  标签:    $TAG"
    echo ""

    build_and_push

    echo ""
    echo -e "${BOLD}${GREEN}========================================${NC}"
    echo -e "${BOLD}${GREEN}镜像构建与推送完成！${NC}"
    echo -e "${BOLD}${GREEN}========================================${NC}"
}

main "$@"
