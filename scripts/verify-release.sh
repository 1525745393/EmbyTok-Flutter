#!/usr/bin/env bash
# ============================================================
# EmbyTok 发布前验证脚本
# 检查项目中所有版本号字段的一致性
# 用法: ./scripts/verify-release.sh
# ============================================================

set -euo pipefail

# ---------- 颜色定义 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_error()   { echo -e "${RED}❌ $*${NC}"; }
log_warn()    { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_info()    { echo -e "    $*"; }

# ---------- 初始化 ----------
ERRORS=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "========================================"
echo " EmbyTok 发布前验证"
echo " 项目目录: $PROJECT_ROOT"
echo "========================================"

# ---------- 1. 读取前端 pubspec 版本 ----------
echo ""
echo "--- 1/8 读取前端版本信息 ---"

PUBSPEC_VERSION=""
if [ -f "frontend/pubspec.yaml" ]; then
    PUBSPEC_VERSION=$(grep -E '^version:' frontend/pubspec.yaml | head -1 | sed 's/^version:[[:space:]]*//' | tr -d "'" | tr -d '"' | xargs)
fi

if [ -n "$PUBSPEC_VERSION" ]; then
    log_success "pubspec.yaml: $PUBSPEC_VERSION"
else
    log_error "无法从 pubspec.yaml 读取版本号"
    ERRORS=$((ERRORS + 1))
fi

# ---------- 2. 读取前端 build.gradle 版本 ----------
echo ""
echo "--- 2/8 读取 Android build.gradle 版本 ---"

GRADLE_VERSION=""
GRADLE_VERSION_CODE=""
if [ -f "frontend/android/app/build.gradle" ]; then
    GRADLE_VERSION=$(grep -E 'versionName' frontend/android/app/build.gradle | head -1 | sed 's/.*versionName[[:space:]]*//' | tr -d '"' | tr -d "'" | xargs)
    GRADLE_VERSION_CODE=$(grep -E 'versionCode' frontend/android/app/build.gradle | head -1 | sed 's/.*versionCode[[:space:]]*//' | xargs)
fi

if [ -n "$GRADLE_VERSION" ]; then
    log_success "build.gradle: versionName=$GRADLE_VERSION, versionCode=$GRADLE_VERSION_CODE"
else
    log_error "无法从 build.gradle 读取版本号"
    ERRORS=$((ERRORS + 1))
fi

# ---------- 3. 读取 Flutter version.dart ----------
echo ""
echo "--- 3/8 读取 Flutter version.dart ---"

DART_VERSION=""
if [ -f "frontend/lib/utils/version.dart" ]; then
    DART_VERSION=$(grep -E "embbytokVersion" frontend/lib/utils/version.dart | head -1 | sed "s/.*= *'//" | sed "s/'.*//" | xargs)
fi

if [ -n "$DART_VERSION" ]; then
    log_success "version.dart: $DART_VERSION"
else
    log_error "无法从 version.dart 读取版本号"
    ERRORS=$((ERRORS + 1))
fi

# ---------- 4. 读取后端 version.py ----------
echo ""
echo "--- 4/8 读取 Backend version.py ---"

PY_VERSION=""
if [ -f "backend/core/version.py" ]; then
    PY_VERSION=$(grep -E "^__version__" backend/core/version.py | head -1 | sed "s/.*= *'//" | sed "s/'.*//" | xargs)
fi

if [ -n "$PY_VERSION" ]; then
    log_success "version.py: $PY_VERSION"
else
    log_warn "无法从 version.py 读取版本号（如未使用后端则可忽略）"
fi

# ---------- 5. 前端版本一致性检查 ----------
echo ""
echo "--- 5/8 检查前端版本号一致性 ---"

if [ -n "$PUBSPEC_VERSION" ] && [ "$PUBSPEC_VERSION" = "$GRADLE_VERSION" ] && [ "$GRADLE_VERSION" = "$DART_VERSION" ]; then
    log_success "前端版本号一致: $PUBSPEC_VERSION"
else
    log_error "前端版本号不一致！"
    log_info "  pubspec.yaml: ${PUBSPEC_VERSION:-<缺失>}"
    log_info "  build.gradle: ${GRADLE_VERSION:-<缺失>}"
    log_info "  version.dart: ${DART_VERSION:-<缺失>}"
    ERRORS=$((ERRORS + 1))
fi

# ---------- 6. 前后端版本一致性检查 ----------
echo ""
echo "--- 6/8 检查前后端版本号一致性 ---"

if [ -n "$PY_VERSION" ]; then
    if [ "$PUBSPEC_VERSION" = "$PY_VERSION" ]; then
        log_success "前后端版本号一致: $PUBSPEC_VERSION"
    else
        log_error "前后端版本号不一致！"
        log_info "  前端: $PUBSPEC_VERSION"
        log_info "  后端: $PY_VERSION"
        ERRORS=$((ERRORS + 1))
    fi
else
    log_warn "跳过前后端版本一致性检查（后端版本未配置）"
fi

# ---------- 7. CHANGELOG 检查 ----------
echo ""
echo "--- 7/8 检查 CHANGELOG ---"

if [ -f "CHANGELOG.md" ]; then
    if grep -q "## \[$PUBSPEC_VERSION\]" CHANGELOG.md 2>/dev/null; then
        log_success "CHANGELOG.md 中存在版本 $PUBSPEC_VERSION 的条目"
    else
        log_warn "CHANGELOG.md 中未找到版本 $PUBSPEC_VERSION 的条目"
        log_info "  请确保在发布前更新 CHANGELOG.md"
    fi
else
    log_warn "CHANGELOG.md 文件不存在"
fi

# ---------- 8. Git 工作树状态检查 ----------
echo ""
echo "--- 8/8 检查 Git 工作树状态 ---"

if command -v git >/dev/null 2>&1; then
    if git status --porcelain | grep -q .; then
        log_warn "Git 工作树存在未提交的变更:"
        git status --short | head -10 | while read -r line; do
            log_info "$line"
        done
    else
        log_success "Git 工作树干净"
    fi
else
    log_warn "git 命令未找到，跳过工作树检查"
fi

# ---------- 总结 ----------
echo ""
echo "========================================"
if [ "$ERRORS" -eq 0 ]; then
    log_success "所有检查通过！可以执行发布操作。"
    echo ""
    log_info "发布命令: ./scripts/release.sh patch"
    log_info "预览命令: ./scripts/release.sh --dry-run patch"
    exit 0
else
    log_error "发现 $ERRORS 个问题，请在发布前修复。"
    echo ""
    exit 1
fi
