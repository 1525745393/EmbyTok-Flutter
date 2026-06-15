#!/usr/bin/env bash
# ============================================================
# EmbyTok Flutter 本地检查脚本
# 功能: 执行 flutter analyze 和 flutter build 验证
# 用法: ./scripts/flutter-check.sh [--fast]
#   --fast: 仅运行 flutter analyze，跳过构建验证
# ============================================================

set -euo pipefail

# ============================================================
# 颜色输出函数
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_error()   { echo -e "${RED}❌ $*${NC}"; }
log_warn()    { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_step()    { echo -e "\n${MAGENTA}▶ $*${NC}"; }

# ============================================================
# 解析参数
# ============================================================
FAST_MODE=false
for arg in "$@"; do
    case "$arg" in
        --fast)
            FAST_MODE=true
            ;;
        --help|-h)
            echo "用法: ./scripts/flutter-check.sh [--fast]"
            echo ""
            echo "选项:"
            echo "  --fast    仅运行 flutter analyze，跳过构建验证"
            echo "  --help    显示此帮助信息"
            exit 0
            ;;
    esac
done

# ============================================================
# 环境检查
# ============================================================
log_step "检查运行环境..."

if ! command -v flutter >/dev/null 2>&1; then
    log_error "Flutter SDK 未安装或不在 PATH 中"
    log_info "请安装 Flutter: https://flutter.dev/docs/get-started/install"
    exit 1
fi

FLUTTER_VERSION=$(flutter --version 2>&1 | head -1)
log_success "Flutter 已安装: $FLUTTER_VERSION"

# ============================================================
# 获取项目根目录
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FRONTEND_DIR="$PROJECT_ROOT/frontend"

if [ ! -d "$FRONTEND_DIR" ]; then
    log_error "找不到 frontend 目录: $FRONTEND_DIR"
    exit 1
fi

cd "$FRONTEND_DIR"

echo ""
echo "========================================"
echo " EmbyTok Flutter 本地检查"
echo " 项目目录: $PROJECT_ROOT"
echo " 前端目录: $FRONTEND_DIR"
echo "========================================"

# ============================================================
# 1. 安装依赖
# ============================================================
log_step "安装依赖..."
if ! flutter pub get 2>&1; then
    log_error "flutter pub get 失败"
    exit 1
fi
log_success "依赖安装完成"

# ============================================================
# 2. Flutter 静态分析
# ============================================================
log_step "执行 Flutter 静态分析..."
echo ""

if ! flutter analyze --no-pub 2>&1; then
    log_error "Flutter 静态分析失败！"
    log_info "请修复上述错误后重新运行此脚本"
    log_info "提示：查看 https://dart.dev/tools/linter-rules 了解各规则的含义"
    exit 1
fi

log_success "Flutter 静态分析通过 ✓"

# ============================================================
# 3. Flutter Debug 构建验证（可选）
# ============================================================
if [ "$FAST_MODE" = true ]; then
    echo ""
    log_info "快速模式：跳过构建验证"
    log_info "如需完整验证，请运行: ./scripts/flutter-check.sh"
else
    log_step "执行 Flutter Debug 构建验证..."
    echo ""

    BUILD_LOG="/tmp/flutter-build-$(date +%Y%m%d-%H%M%S).log"

    if ! flutter build apk --debug 2>&1 | tee "$BUILD_LOG"; then
        log_error "Flutter Debug 构建失败！"
        log_info "查看构建日志: $BUILD_LOG"
        exit 1
    fi

    log_success "Flutter Debug 构建验证通过 ✓"

    # 显示构建产物
    APK_COUNT=$(find build -name "*.apk" 2>/dev/null | wc -l)
    if [ "$APK_COUNT" -gt 0 ]; then
        log_info "构建产物 APK:"
        find build -name "*.apk" -exec ls -lh {} \; 2>/dev/null | while read -r line; do
            log_info "  $line"
        done
    fi
fi

# ============================================================
# 完成
# ============================================================
echo ""
echo "========================================"
log_success "所有检查通过！代码可以提交。"
echo "========================================"
