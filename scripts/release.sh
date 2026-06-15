#!/usr/bin/env bash
# ============================================================
# EmbyTok 自动发布脚本
# 用法: ./scripts/release.sh [--dry-run] <patch|minor|major>
# 功能:
#   1. 更新版本号 (pubspec.yaml / build.gradle / version.dart / version.py)
#   2. 同步 Android versionCode (递增)
#   3. 提交变更并打 tag (vX.Y.Z)
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
log_dry()     { echo -e "${CYAN}[DRY-RUN]${NC} $*"; }

# ============================================================
# Task 3 修复: 命令存在性预检查
# 在版本更新流程开始前确保所有必需命令可用
# ============================================================
log_step "检查运行环境..."

# 必需命令（发布流程必须）
REQUIRED_CMDS=("git" "sed" "grep" "awk")
for cmd in "${REQUIRED_CMDS[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        log_success "$cmd 已安装"
    else
        log_error "必需命令 '$cmd' 未安装或不在 PATH 中"
        log_info "请安装后重试:  macOS: brew install $cmd  /  Linux: apt/yum install $cmd"
        exit 1
    fi
done

# 可选命令（仅在非 dry-run 正式发布时需要）
OPTIONAL_CMDS=("flutter")
for cmd in "${OPTIONAL_CMDS[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        log_success "$cmd 已安装（用于本地构建验证）"
    else
        log_warn "$cmd 未安装（仅在需要本地构建时需要，dry-run 模式可跳过）"
    fi
done

# ============================================================
# Task 1 修复: 跨平台 sed 兼容
# macOS 使用 BSD sed，Linux 使用 GNU sed，两者 -i 语法不同
# ============================================================

# sed_inplace: 跨平台的 sed -i 封装
#   用法: sed_inplace "s/old/new/" filename
#   - Linux (GNU sed): sed -i "expr" file
#   - macOS (BSD sed): sed -i "" "expr" file
sed_inplace() {
    local expr="$1"
    local file="$2"
    if [ "$(uname -s)" = "Darwin" ]; then
        # macOS / BSD sed: -i 需要空字符串参数
        sed -i "" "$expr" "$file"
    else
        # Linux / GNU sed: -i 直接使用
        sed -i "$expr" "$file"
    fi
}
log_info "sed 兼容模式: $(uname -s)"

# ============================================================
# 解析参数
# ============================================================
DRY_RUN=false
RELEASE_TYPE=""

for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=true
            ;;
        patch|minor|major)
            RELEASE_TYPE="$arg"
            ;;
        *)
            echo ""
            log_error "未知参数: $arg"
            echo ""
            echo "用法: ./scripts/release.sh [--dry-run] <patch|minor|major>"
            echo ""
            echo "示例:"
            echo "  ./scripts/release.sh patch          # 发布 patch 版本 (1.1.3 → 1.1.4)"
            echo "  ./scripts/release.sh minor          # 发布 minor 版本 (1.1.3 → 1.2.0)"
            echo "  ./scripts/release.sh major          # 发布 major 版本 (1.1.3 → 2.0.0)"
            echo "  ./scripts/release.sh --dry-run patch # 预览发布，不实际修改"
            exit 1
            ;;
    esac
done

if [ -z "$RELEASE_TYPE" ]; then
    echo ""
    log_error "请指定发布类型: patch | minor | major"
    echo ""
    echo "用法: ./scripts/release.sh [--dry-run] <patch|minor|major>"
    exit 1
fi

# ============================================================
# 初始化
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo ""
echo "========================================"
echo " EmbyTok 发布流程"
echo " 模式: $RELEASE_TYPE"
if [ "$DRY_RUN" = true ]; then
    echo " Dry-Run: ${CYAN}是${NC}（仅预览，不实际修改）"
fi
echo " 项目目录: $PROJECT_ROOT"
echo "========================================"

# ============================================================
# 1. 解析当前版本号
# ============================================================
log_step "解析当前版本号..."

PUBSPEC_VERSION=$(grep -E '^version:' frontend/pubspec.yaml | head -1 | sed 's/^version:[[:space:]]*//' | tr -d "'\"" | xargs)

if [ -z "$PUBSPEC_VERSION" ]; then
    log_error "无法从 pubspec.yaml 读取版本号"
    exit 1
fi

# 解析 MAJOR.MINOR.PATCH
IFS='.' read -r MAJOR MINOR PATCH <<< "$PUBSPEC_VERSION"
log_info "当前版本: $MAJOR.$MINOR.$PATCH"

# ============================================================
# 2. 计算新版本号
# ============================================================
log_step "计算新版本号..."

case "$RELEASE_TYPE" in
    patch)
        PATCH=$((PATCH + 1))
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
log_success "新版本: $NEW_VERSION"

# 计算新的 versionCode（读取 build.gradle 当前值 +1）
CURRENT_VERSION_CODE=$(grep -E 'versionCode' frontend/android/app/build.gradle | head -1 | sed 's/.*versionCode[[:space:]]*//' | xargs)
NEW_VERSION_CODE=$((CURRENT_VERSION_CODE + 1))
log_info "新 versionCode: $CURRENT_VERSION_CODE → $NEW_VERSION_CODE"

# ============================================================
# 3. 预览将修改的文件
# ============================================================
log_step "预览修改内容..."

log_info "将修改以下文件:"
log_info "  1. frontend/pubspec.yaml           (version: $PUBSPEC_VERSION → $NEW_VERSION)"
log_info "  2. frontend/android/app/build.gradle (versionName: $PUBSPEC_VERSION → $NEW_VERSION, versionCode: $CURRENT_VERSION_CODE → $NEW_VERSION_CODE)"
log_info "  3. frontend/lib/utils/version.dart  (embbytokVersion: $PUBSPEC_VERSION → $NEW_VERSION, embbytokBuildNumber: $CURRENT_VERSION_CODE → $NEW_VERSION_CODE)"
log_info "  4. backend/core/version.py          (__version__: $PUBSPEC_VERSION → $NEW_VERSION, __build_number__: $CURRENT_VERSION_CODE → $NEW_VERSION_CODE)"

# ============================================================
# 4. 执行文件修改
# ============================================================
if [ "$DRY_RUN" = true ]; then
    echo ""
    log_dry "Dry-Run 模式：以下是将要执行的操作预览"
    echo ""
    echo "$ sed_inplace \"s/^version: .*/version: $NEW_VERSION/\" frontend/pubspec.yaml"
    echo "$ sed_inplace \"s/versionName .*/versionName \\\"$NEW_VERSION\\\"/\" frontend/android/app/build.gradle"
    echo "$ sed_inplace \"s/versionCode .*/versionCode $NEW_VERSION_CODE/\" frontend/android/app/build.gradle"
    echo "$ sed_inplace \"s/embbytokVersion = .*/embbytokVersion = '$NEW_VERSION'/\" frontend/lib/utils/version.dart"
    echo "$ sed_inplace \"s/embbytokBuildNumber = .*/embbytokBuildNumber = $NEW_VERSION_CODE/\" frontend/lib/utils/version.dart"
    echo "$ sed_inplace \"s/__version__ = .*/__version__ = '$NEW_VERSION'/\" backend/core/version.py"
    echo "$ sed_inplace \"s/__build_number__ = .*/__build_number__ = $NEW_VERSION_CODE/\" backend/core/version.py"
    echo ""
    echo "$ git add frontend/pubspec.yaml frontend/android/app/build.gradle frontend/lib/utils/version.dart backend/core/version.py CHANGELOG.md"
    echo "$ git commit -m \"chore(release): bump version to $NEW_VERSION\""
    echo "$ git tag -a v$NEW_VERSION -m \"Release v$NEW_VERSION\""
    echo ""
    log_dry "实际发布请移除 --dry-run 参数"
    exit 0
fi

# ============================================================
# 4.1 修改 pubspec.yaml
# ============================================================
log_step "更新 pubspec.yaml..."
sed_inplace "s/^version: .*/version: $NEW_VERSION/" frontend/pubspec.yaml
log_success "已更新 pubspec.yaml"

# ============================================================
# 4.2 修改 build.gradle
# ============================================================
log_step "更新 build.gradle..."
sed_inplace "s/versionName .*/versionName \"$NEW_VERSION\"/" frontend/android/app/build.gradle
sed_inplace "s/versionCode .*/versionCode $NEW_VERSION_CODE/" frontend/android/app/build.gradle
log_success "已更新 build.gradle"

# ============================================================
# 4.3 修改 version.dart
# ============================================================
log_step "更新 version.dart..."
sed_inplace "s/embbytokVersion = .*/embbytokVersion = '$NEW_VERSION';/" frontend/lib/utils/version.dart
sed_inplace "s/embbytokBuildNumber = .*/embbytokBuildNumber = $NEW_VERSION_CODE;/" frontend/lib/utils/version.dart
log_success "已更新 version.dart"

# ============================================================
# 4.4 修改 version.py
# ============================================================
log_step "更新 version.py..."
sed_inplace "s/__version__ = .*/__version__ = '$NEW_VERSION'/" backend/core/version.py
sed_inplace "s/__build_number__ = .*/__build_number__ = $NEW_VERSION_CODE/" backend/core/version.py
log_success "已更新 version.py"

# ============================================================
# 5. Git 提交和打标签
# ============================================================
log_step "Git 提交..."

# Task 2 修复: 使用精确文件列表，而非 git add -A
# 这样可以防止意外提交未跟踪的敏感文件（如密钥、临时文件等）
RELEASE_FILES=(
    "frontend/pubspec.yaml"
    "frontend/android/app/build.gradle"
    "frontend/lib/utils/version.dart"
    "backend/core/version.py"
    "CHANGELOG.md"
)

log_info "将添加以下文件:"
for f in "${RELEASE_FILES[@]}"; do
    if [ -f "$f" ]; then
        log_info "  ✓ $f"
    else
        log_warn "  ✗ $f (不存在，将跳过)"
    fi
done

# 只添加实际存在的文件
EXISTING_FILES=()
for f in "${RELEASE_FILES[@]}"; do
    [ -f "$f" ] && EXISTING_FILES+=("$f")
done

if [ ${#EXISTING_FILES[@]} -gt 0 ]; then
    git add "${EXISTING_FILES[@]}"
    log_success "已添加 ${#EXISTING_FILES[@]} 个文件到暂存区"
else
    log_error "没有可提交的文件！"
    exit 1
fi

# 确认当前工作树状态
STAGED_FILES=$(git diff --cached --name-only)
log_info "暂存区中的文件:"
echo "$STAGED_FILES" | while read -r line; do
    log_info "  • $line"
done

# 提交
COMMIT_MSG="chore(release): bump version to $NEW_VERSION"
git commit -m "$COMMIT_MSG"
log_success "已提交: $COMMIT_MSG"

# 打 tag
TAG_NAME="v$NEW_VERSION"
git tag -a "$TAG_NAME" -m "Release v$NEW_VERSION"
log_success "已打标签: $TAG_NAME"

# ============================================================
# 6. 输出总结
# ============================================================
echo ""
echo "========================================"
log_success "发布准备完成！"
echo ""
echo "新版本: v$NEW_VERSION (versionCode: $NEW_VERSION_CODE)"
echo ""
echo "后续步骤:"
echo "  1. 推送变更和标签到远程:"
echo "     $ git push origin main"
echo "     $ git push origin $TAG_NAME"
echo ""
echo "  2. 推送后将自动触发 GitHub Actions 工作流:"
echo "     - Android Release: 构建签名 APK/AAB"
echo ""
echo "  3. 在 GitHub Release 页面补充发布说明"
echo ""
echo "========================================"
