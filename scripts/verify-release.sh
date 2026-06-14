#!/bin/bash
# ============================================================
# EmbyTok - 发布前验证脚本
# 功能：
#   1. 检查 pubspec.yaml / build.gradle / lib/utils/version.dart 三者版本号一致
#   2. 检查 CHANGELOG.md 中是否存在该版本条目
#   3. 检查 Git 工作树是否干净
#   4. 检查 versionCode 是否大于上次 tag
#   5. （可选）执行单元测试
# ============================================================
set -euo pipefail

# ---------- 颜色与日志 ----------
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

ERRORS=0

# ---------- 解析命令行参数 ----------
RUN_TESTS=0
for arg in "$@"; do
    case "$arg" in
        --with-tests) RUN_TESTS=1 ;;
        -h|--help)
            echo "用法: $0 [--with-tests]"
            echo ""
            echo "检查项："
            echo "  1. pubspec.yaml 版本"
            echo "  2. android/app/build.gradle 版本"
            echo "  3. lib/utils/version.dart 版本"
            echo "  4. CHANGELOG.md 中存在对应版本条目"
            echo "  5. Git 工作树是否干净"
            echo "  6. versionCode 单调递增"
            exit 0
            ;;
    esac
done

# ---------- 辅助函数 ----------

# 从文件中提取版本号
check_file_exists() {
    if [ ! -f "$1" ]; then
        log_error "文件不存在: $1"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
    return 0
}

# 从 pubspec.yaml 中读取 version
get_pubspec_version() {
    grep -E '^version:' "$PROJECT_ROOT/frontend/pubspec.yaml" | awk '{print $2}' | tr -d '[:space:]'
}

# 从 build.gradle 中读取 versionName
get_gradle_version_name() {
    grep -E "versionName" "$PROJECT_ROOT/frontend/android/app/build.gradle" | head -1 | sed -E "s/.*versionName[[:space:]]+\"([0-9.]+)\".*/\1/"
}

# 从 build.gradle 中读取 versionCode
get_gradle_version_code() {
    grep -E "versionCode" "$PROJECT_ROOT/frontend/android/app/build.gradle" | head -1 | awk '{print $2}' | tr -d '[:space:]'
}

# 从 version.dart 中读取 kAppVersion
get_dart_version() {
    grep -E "kAppVersion = " "$PROJECT_ROOT/frontend/lib/utils/version.dart" | head -1 | sed -E "s/.*'([0-9.]+)'.*/\1/"
}

# 从 version.dart 中读取 kAppVersionCode
get_dart_version_code() {
    grep -E "kAppVersionCode = " "$PROJECT_ROOT/frontend/lib/utils/version.dart" | head -1 | awk -F'= ' '{print $2}' | tr -d ';[:space:]'
}

# 从 backend/core/version.py 中读取 __version__
get_py_version() {
    grep -E '__version__.*=' "$PROJECT_ROOT/backend/core/version.py" | head -1 | sed -E "s/.*\"([0-9.]+)\".*/\1/"
}

# 检查 CHANGELOG.md 是否包含版本条目（支持 "## [X.Y.Z]"）
check_changelog_entry() {
    local version="$1"
    # 支持两种格式匹配：标题以 ## [X.Y.Z] 或 [X.Y.Z]
    if grep -qE "^\[${version}\]|^##\s*\[${version}\]" "$PROJECT_ROOT/CHANGELOG.md"; then
        return 0
    fi
    return 1
}

# ---------- 主逻辑 ----------
echo -e "${BOLD}=======================================${NC}"
echo -e "${BOLD}  EmbyTok 发布前验证${NC}"
echo -e "${BOLD}=======================================${NC}"
echo ""

# Step 1: 检查关键文件是否存在
log_info "1/6 检查关键文件是否存在..."
check_file_exists "$PROJECT_ROOT/frontend/pubspec.yaml"
check_file_exists "$PROJECT_ROOT/frontend/android/app/build.gradle"
check_file_exists "$PROJECT_ROOT/frontend/lib/utils/version.dart"
check_file_exists "$PROJECT_ROOT/backend/core/version.py"
check_file_exists "$PROJECT_ROOT/CHANGELOG.md"

# Step 2: 读取版本号
log_info "2/6 读取各文件版本号..."
PUBSPEC_VERSION="$(get_pubspec_version)"
GRADLE_VERSION="$(get_gradle_version_name)"
GRADLE_CODE="$(get_gradle_version_code)"
DART_VERSION="$(get_dart_version)"
DART_CODE="$(get_dart_version_code)"
PY_VERSION="$(get_py_version)"

echo "  pubspec.yaml     -> ${PUBSPEC_VERSION:-<未找到>}"
echo "  build.gradle     -> ${GRADLE_VERSION:-<未找到>} (code=${GRADLE_CODE:-<未找到>})"
echo "  version.dart     -> ${DART_VERSION:-<未找到>} (code=${DART_CODE:-<未找到>})"
echo "  backend/version.py -> ${PY_VERSION:-<未找到>}"

# Step 3: 检查前端版本号一致性
log_info "3/6 检查前端版本号一致性..."
if [ -n "$PUBSPEC_VERSION" ] && [ "$PUBSPEC_VERSION" = "$GRADLE_VERSION" ] && [ "$GRADLE_VERSION" = "$DART_VERSION" ]; then
    log_success "  前端版本号一致: $PUBSPEC_VERSION"
else
    log_error "  前端版本号不一致！"
    log_error "    pubspec.yaml  -> $PUBSPEC_VERSION"
    log_error "    build.gradle  -> $GRADLE_VERSION"
    log_error "    version.dart  -> $DART_VERSION"
    ERRORS=$((ERRORS + 1))
fi

# Step 4: 检查 versionCode 一致性 + 递增性
log_info "4/6 检查 versionCode 一致性与递增性..."
if [ -n "$GRADLE_CODE" ] && [ "$GRADLE_CODE" = "$DART_CODE" ]; then
    log_success "  versionCode 一致: $GRADLE_CODE"
else
    log_error "  versionCode 不一致！"
    log_error "    build.gradle  -> $GRADLE_CODE"
    log_error "    version.dart  -> $DART_CODE"
    ERRORS=$((ERRORS + 1))
fi

# 检查是否大于上次 tag 中的 versionCode（如果能从 git 解析）
LAST_TAG_CODE=0
if command -v git >/dev/null 2>&1; then
    LAST_TAG="$(git -C "$PROJECT_ROOT" describe --tags --abbrev=0 2>/dev/null || echo "")"
    if [ -n "$LAST_TAG" ]; then
        # 从最新 tag 尝试解析 versionCode：读取当时 build.gradle 内容
        LAST_TAG_CODE="$(git -C "$PROJECT_ROOT" show "$LAST_TAG:frontend/android/app/build.gradle" 2>/dev/null | grep -E "versionCode" | head -1 | awk '{print $2}' | tr -d '[:space:]' || echo "0")"
        if [ -n "$LAST_TAG_CODE" ] && [ "$LAST_TAG_CODE" -gt 0 ] 2>/dev/null; then
            if [ "$GRADLE_CODE" -gt "$LAST_TAG_CODE" ] 2>/dev/null; then
                log_success "  versionCode ($GRADLE_CODE) > 上次 tag ($LAST_TAG -> $LAST_TAG_CODE) ✓"
            else
                log_error "  versionCode 未递增！当前=$GRADLE_CODE，上次 tag=$LAST_TAG_CODE"
                ERRORS=$((ERRORS + 1))
            fi
        fi
    fi
fi

# Step 5: 检查 CHANGELOG
log_info "5/6 检查 CHANGELOG.md 版本条目..."
if [ -n "$PUBSPEC_VERSION" ] && check_changelog_entry "$PUBSPEC_VERSION"; then
    log_success "  CHANGELOG.md 中找到 [$PUBSPEC_VERSION] 条目"
else
    log_error "  CHANGELOG.md 中未找到 [$PUBSPEC_VERSION] 版本条目"
    log_warn "  请在 CHANGELOG.md 中添加: ## [$PUBSPEC_VERSION] — YYYY-MM-DD"
    ERRORS=$((ERRORS + 1))
fi

# Step 6: 检查 Git 工作树
log_info "6/6 检查 Git 工作树..."
if command -v git >/dev/null 2>&1; then
    if git -C "$PROJECT_ROOT" diff --quiet && git -C "$PROJECT_ROOT" diff --cached --quiet; then
        log_success "  Git 工作树干净"
    else
        log_warn "  Git 工作树存在未提交变更，建议提交后再发布"
        git -C "$PROJECT_ROOT" status --short
    fi
else
    log_warn "  未检测到 git 命令，跳过 Git 检查"
fi

# （可选）单元测试
if [ "$RUN_TESTS" -eq 1 ]; then
    echo ""
    log_info "可选：运行前端测试..."
    if [ -f "$PROJECT_ROOT/frontend/pubspec.yaml" ] && command -v flutter >/dev/null 2>&1; then
        if flutter test --no-pub >/dev/null 2>&1; then
            log_success "  Flutter 测试通过"
        else
            log_error "  Flutter 测试失败，请查看 flutter test 输出"
            ERRORS=$((ERRORS + 1))
        fi
    else
        log_warn "  未检测到 Flutter，跳过测试"
    fi
fi

# ---------- 汇总 ----------
echo ""
echo -e "${BOLD}=======================================${NC}"
if [ "$ERRORS" -eq 0 ]; then
    log_success "✅ 所有检查通过，可以发布！"
    echo ""
    echo "  发布建议命令："
    echo "    git tag v${PUBSPEC_VERSION} -m \"Release v${PUBSPEC_VERSION}\""
    echo "    git push origin main --tags"
    exit 0
else
    log_error "❌ 发现 $ERRORS 个问题，请修复后再发布"
    exit 1
fi
