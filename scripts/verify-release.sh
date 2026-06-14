#!/bin/bash
# ============================================================
# EmbyTok - 发布前验证脚本（增强版）
# 功能：
#   1. 检查 pubspec.yaml / build.gradle / lib/utils/version.dart 版本号一致
#   2. 检查 CHANGELOG.md 中是否存在该版本条目
#   3. 检查 Git 工作树是否干净
#   4. 检查 versionCode 是否大于上次 tag
#   5. 验证 minSdk/targetSdk 兼容性
#   6. 验证后端 version.py 与前端同步
#   7. （可选）执行单元测试
#   8. （可选）检查 flutter analyze 是否有严重错误
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
WARNINGS=0

# ---------- 参数解析 ----------
RUN_TESTS=0
RUN_ANALYZE=0
for arg in "$@"; do
    case "$arg" in
        --with-tests)     RUN_TESTS=1 ;;
        --with-analyze)   RUN_ANALYZE=1 ;;
        --strict)         RUN_TESTS=1; RUN_ANALYZE=1 ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项："
            echo "  --with-tests     运行 Flutter 测试"
            echo "  --with-analyze   运行 flutter analyze 代码检查"
            echo "  --strict         = --with-tests --with-analyze"
            echo "  -h, --help       显示此帮助"
            exit 0
            ;;
    esac
done

# ---------- 辅助函数 ----------
check_file_exists() {
    if [ ! -f "$1" ]; then
        log_error "文件不存在: $1"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
    return 0
}

get_pubspec_version() {
    grep -E '^version:' "$PROJECT_ROOT/frontend/pubspec.yaml" | awk '{print $2}' | tr -d '[:space:]'
}
get_gradle_version_name() {
    grep -E "versionName" "$PROJECT_ROOT/frontend/android/app/build.gradle" | head -1 | sed -E "s/.*versionName[[:space:]]+\"([0-9.]+)\".*/\1/"
}
get_gradle_version_code() {
    grep -E "versionCode" "$PROJECT_ROOT/frontend/android/app/build.gradle" | head -1 | awk '{print $2}' | tr -d '[:space:]'
}
get_dart_version() {
    grep -E "kAppVersion = " "$PROJECT_ROOT/frontend/lib/utils/version.dart" | head -1 | sed -E "s/.*'([0-9.]+)'.*/\1/"
}
get_dart_version_code() {
    grep -E "kAppVersionCode = " "$PROJECT_ROOT/frontend/lib/utils/version.dart" | head -1 | awk -F'= ' '{print $2}' | tr -d ';[:space:]'
}
get_py_version() {
    grep -E '__version__.*=' "$PROJECT_ROOT/backend/core/version.py" | head -1 | sed -E "s/.*\"([0-9.]+)\".*/\1/"
}

# 检查 CHANGELOG 条目的函数
check_changelog_entry() {
    local version="$1"
    if grep -qE "^\[${version}\]|^##\s*\[${version}\]" "$PROJECT_ROOT/CHANGELOG.md"; then
        return 0
    fi
    return 1
}

# ---------- 1. 检查关键文件 ----------
echo -e "${BOLD}=======================================${NC}"
echo -e "${BOLD}  EmbyTok 发布前验证${NC}"
echo -e "${BOLD}=======================================${NC}"
echo ""

log_info "1/8 检查关键文件存在..."
check_file_exists "$PROJECT_ROOT/frontend/pubspec.yaml"
check_file_exists "$PROJECT_ROOT/frontend/android/app/build.gradle"
check_file_exists "$PROJECT_ROOT/frontend/lib/utils/version.dart"
check_file_exists "$PROJECT_ROOT/backend/core/version.py"
check_file_exists "$PROJECT_ROOT/CHANGELOG.md"

# ---------- 2. 读取版本号 ----------
echo ""
log_info "2/8 读取各文件版本号..."
PUBSPEC_VERSION="$(get_pubspec_version)"
GRADLE_VERSION="$(get_gradle_version_name)"
GRADLE_CODE="$(get_gradle_version_code)"
DART_VERSION="$(get_dart_version)"
DART_CODE="$(get_dart_version_code)"
PY_VERSION="$(get_py_version)"

echo "  pubspec.yaml       → ${PUBSPEC_VERSION:-<未找到>}"
echo "  build.gradle       → ${GRADLE_VERSION:-<未找到>} (code=${GRADLE_CODE:-<未找到>})"
echo "  version.dart       → ${DART_VERSION:-<未找到>} (code=${DART_CODE:-<未找到>})"
echo "  backend/version.py → ${PY_VERSION:-<未找到>}"

# ---------- 3. 前端版本一致性检查 ----------
echo ""
log_info "3/8 检查前端版本号一致性 (pubspec ↔ gradle ↔ dart)..."
if [ -n "$PUBSPEC_VERSION" ] && [ "$PUBSPEC_VERSION" = "$GRADLE_VERSION" ] && [ "$GRADLE_VERSION" = "$DART_VERSION" ]; then
    log_success "  前端版本号一致: $PUBSPEC_VERSION"
else
    log_error "  前端版本号不一致！"
    [ -n "$PUBSPEC_VERSION" ] || log_error "    pubspec.yaml: <缺失>"
    [ -n "$GRADLE_VERSION" ]  || log_error "    build.gradle: <缺失>"
    [ -n "$DART_VERSION" ]    || log_error "    version.dart: <缺失>"
    ERRORS=$((ERRORS + 1))
fi

# ---------- 4. 检查 versionCode 一致性 + 递增性 ----------
echo ""
log_info "4/8 检查 versionCode 一致性与递增性..."
if [ -n "$GRADLE_CODE" ] && [ "$GRADLE_CODE" = "$DART_CODE" ]; then
    log_success "  versionCode 一致: $GRADLE_CODE"
else
    log_error "  versionCode 不一致！"
    ERRORS=$((ERRORS + 1))
fi

# 检查是否比上次 tag 大
LAST_TAG_CODE=0
if command -v git >/dev/null 2>&1; then
    LAST_TAG="$(git -C "$PROJECT_ROOT" describe --tags --abbrev=0 2>/dev/null || echo "")"
    if [ -n "$LAST_TAG" ]; then
        LAST_TAG_CODE="$(git -C "$PROJECT_ROOT" show "$LAST_TAG:frontend/android/app/build.gradle" 2>/dev/null | grep -E "versionCode" | head -1 | awk '{print $2}' | tr -d '[:space:]' || echo "0")"
        if [ -n "$LAST_TAG_CODE" ] && [ "$LAST_TAG_CODE" -gt 0 ] 2>/dev/null; then
            if [ "$GRADLE_CODE" -gt "$LAST_TAG_CODE" ] 2>/dev/null; then
                log_success "  versionCode ($GRADLE_CODE) > 上次 tag ($LAST_TAG → $LAST_TAG_CODE) ✓"
            else
                log_warn "  ⚠️  versionCode 未比上次 tag 大：当前=$GRADLE_CODE，上次=$LAST_TAG_CODE"
                log_warn "     （非阻塞警告，但若为首次发布或同版本重试可忽略）"
                WARNINGS=$((WARNINGS + 1))
            fi
        fi
    fi
fi

# ---------- 5. 检查前后端版本同步性 ----------
echo ""
log_info "5/8 检查前后端版本同步性..."
if [ -n "$PY_VERSION" ] && [ "$PY_VERSION" = "$PUBSPEC_VERSION" ]; then
    log_success "  前后端版本同步: $PY_VERSION"
else
    log_warn "  ⚠️  前端版本 ($PUBSPEC_VERSION) 与后端版本 ($PY_VERSION) 不同步"
    log_warn "     （若非大版本拆分发布可忽略）"
    WARNINGS=$((WARNINGS + 1))
fi

# ---------- 6. 检查 CHANGELOG.md ----------
echo ""
log_info "6/8 检查 CHANGELOG.md 版本条目..."
if [ -n "$PUBSPEC_VERSION" ] && check_changelog_entry "$PUBSPEC_VERSION"; then
    log_success "  CHANGELOG.md 中找到 [$PUBSPEC_VERSION] 条目"
else
    log_error "  CHANGELOG.md 中未找到 [$PUBSPEC_VERSION] 条目"
    log_error "  请在 CHANGELOG.md 中添加: ## [$PUBSPEC_VERSION] — YYYY-MM-DD"
    ERRORS=$((ERRORS + 1))
fi

# ---------- 7. 检查 Android SDK 配置 ----------
echo ""
log_info "7/8 检查 Android SDK 配置..."
MIN_SDK="$(grep -E 'minSdk' "$PROJECT_ROOT/frontend/android/app/build.gradle" | head -1 | awk '{print $2}')"
TARGET_SDK="$(grep -E 'targetSdk' "$PROJECT_ROOT/frontend/android/app/build.gradle" | head -1 | awk '{print $2}')"
COMPILE_SDK="$(grep -E 'compileSdk' "$PROJECT_ROOT/frontend/android/app/build.gradle" | head -1 | awk '{print $2}')"

if [ -n "$MIN_SDK" ] && [ -n "$TARGET_SDK" ] && [ -n "$COMPILE_SDK" ]; then
    log_success "  SDK 配置: minSdk=$MIN_SDK, targetSdk=$TARGET_SDK, compileSdk=$COMPILE_SDK"
    if [ "$MIN_SDK" -ge 21 ] && [ "$TARGET_SDK" -ge 33 ]; then
        log_success "  ✓ SDK 版本符合现代 Android 发布要求"
    else
        log_warn "  ⚠️ 建议 minSdk ≥ 21, targetSdk ≥ 33（Google Play 要求）"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    log_error "  无法读取 build.gradle 中的 SDK 配置"
    ERRORS=$((ERRORS + 1))
fi

# ---------- 8. 检查 Git 状态 ----------
echo ""
log_info "8/8 检查 Git 工作树状态..."
if command -v git >/dev/null 2>&1; then
    if git -C "$PROJECT_ROOT" diff --quiet && git -C "$PROJECT_ROOT" diff --cached --quiet; then
        log_success "  Git 工作树干净 ✓"
    else
        log_warn "  ⚠️  存在未提交变更，建议提交后再发布"
        git -C "$PROJECT_ROOT" status --short | sed 's/^/     /'
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# ---------- 可选：运行测试 ----------
if [ "$RUN_TESTS" -eq 1 ]; then
    echo ""
    log_info "可选：运行 Flutter 测试..."
    if command -v flutter >/dev/null 2>&1; then
        if flutter test 2>&1 | tail -5; then
            log_success "  Flutter 测试通过 ✓"
        else
            log_error "  Flutter 测试失败"
            ERRORS=$((ERRORS + 1))
        fi
    else
        log_warn "  未检测到 Flutter，跳过测试"
    fi
fi

# ---------- 可选：运行 analyze ----------
if [ "$RUN_ANALYZE" -eq 1 ]; then
    echo ""
    log_info "可选：运行 flutter analyze..."
    if command -v flutter >/dev/null 2>&1; then
        ANALYZE_OUTPUT="$(cd "$PROJECT_ROOT/frontend" && flutter analyze 2>&1 || true)"
        if echo "$ANALYZE_OUTPUT" | grep -qE "No issues found|0 issues"; then
            log_success "  flutter analyze 无问题 ✓"
        else
            ISSUE_COUNT="$(echo "$ANALYZE_OUTPUT" | grep -E "error|warning" | wc -l)"
            log_warn "  flutter analyze 发现 $ISSUE_COUNT 个问题（非阻塞，建议修复）"
        fi
    else
        log_warn "  未检测到 Flutter，跳过 analyze"
    fi
fi

# ---------- 汇总输出 ----------
echo ""
echo -e "${BOLD}=======================================${NC}"
echo -e "${BOLD}  验证结果汇总${NC}"
echo -e "${BOLD}=======================================${NC}"
echo ""

if [ "$ERRORS" -eq 0 ]; then
    log_success "✅ 所有关键检查通过，可以发布！"
    [ "$WARNINGS" -gt 0 ] && echo "   注意：存在 $WARNINGS 个警告项，请酌情处理"
    echo ""
    echo "  版本信息："
    echo "    版本号: $PUBSPEC_VERSION"
    echo "    versionCode: $GRADLE_CODE"
    echo "    minSdk: $MIN_SDK, targetSdk: $TARGET_SDK"
    echo ""
    echo "  下一步："
    echo "    git tag v${PUBSPEC_VERSION}"
    echo "    git push origin main --tags"
    exit 0
else
    log_error "❌ 发现 $ERRORS 个错误（警告 $WARNINGS 个），请修复后再发布"
    exit 1
fi
