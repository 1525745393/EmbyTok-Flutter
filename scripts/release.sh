#!/usr/bin/env bash
# ============================================================
# EmbyTok 发布前预检脚本
# 用法: ./scripts/release.sh [--dry-run] <patch|minor|major>
# 功能:
#   1. 发布前预检：验证代码质量 + 预览版本号
#   2. 更新版本号 (pubspec.yaml / build.gradle / version.dart / version.py)
#   3. 同步 Android versionCode (递增)
# 注意: 实际发布由 CI (semantic-release) 自动完成，本脚本不执行 git commit/tag
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
# 0. 工作环境预检
# ============================================================
log_step "检查工作环境..."

# 检查当前分支：发布预检建议在 main 分支执行
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ "$CURRENT_BRANCH" != "main" ]; then
    log_warn "当前分支 '$CURRENT_BRANCH' 不是 main，CI 发布仅在 main 分支触发"
    log_info "建议切换到 main 分支后再执行预检"
fi

# 检查工作树状态
if ! git diff --quiet HEAD 2>/dev/null; then
    log_warn "Git 工作树存在未提交的变更，建议先提交"
else
    log_success "Git 工作树干净"
fi

# ============================================================
# 1. 解析当前版本号
# ============================================================
log_step "解析当前版本号..."

PUBSPEC_VERSION=$(grep -E '^version:' frontend/pubspec.yaml | head -1 | sed 's/^version:[[:space:]]*//' | tr -d "'\"" | xargs)

if [ -z "$PUBSPEC_VERSION" ]; then
    log_error "无法从 pubspec.yaml 读取版本号"
    exit 1
fi

# 裁剪 +BUILD 后缀（如 2.30.3+2303 → 2.30.3），仅保留语义版本号用于计算
# pubspec.yaml 中 version 字段可能携带 build 号，但版本号计算只关心语义版本部分
PUBSPEC_VERSION="${PUBSPEC_VERSION%%+*}"

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

# 预检：检查目标 tag 是否已存在
# 若已存在，CI semantic-release 可能跳过该版本，提前提示开发者注意
if git rev-parse "v$NEW_VERSION" >/dev/null 2>&1; then
    log_warn "tag v$NEW_VERSION 已存在，CI 可能不会重新发布该版本"
fi

# 计算新的 versionCode（读取 build.gradle 当前值 +1）
CURRENT_VERSION_CODE=$(grep -E 'versionCode' frontend/android/app/build.gradle | head -1 | sed 's/.*versionCode[[:space:]]*//' | xargs)
NEW_VERSION_CODE=$((CURRENT_VERSION_CODE + 1))
log_info "新 versionCode: $CURRENT_VERSION_CODE → $NEW_VERSION_CODE"

# ============================================================
# 3. 前置验证：Flutter 静态分析和构建验证
# ============================================================
log_step "前置验证：Flutter 代码质量检查..."

# 检查 flutter 是否可用
if command -v flutter >/dev/null 2>&1; then
    log_info "Flutter 已安装，执行静态分析..."

    # 进入 frontend 目录执行检查
    cd "$PROJECT_ROOT/frontend"

    # 运行 flutter analyze（不允许 error，warning 可以）
    if ! flutter analyze --no-pub 2>&1; then
        log_error "Flutter 静态分析失败，存在编译错误！"
        log_info "请修复上述错误后重新运行发布脚本"
        log_info "提示：可先本地运行 'flutter analyze' 检查问题"
        cd "$PROJECT_ROOT"
        exit 1
    fi
    log_success "Flutter 静态分析通过"

    # 运行 flutter build --debug 验证构建
    log_info "执行 Debug 构建验证..."
    # 分离构建执行和日志输出，避免 pipefail 下 tee 失败误判构建结果
    # 直接使用管道时，pipefail 会让整条管道在任一命令失败时返回失败，
    # 但 tee 几乎不会失败，导致无法区分是 flutter 构建失败还是管道问题
    set +e
    flutter build apk --debug > /tmp/flutter-build-debug.log 2>&1
    BUILD_EXIT_CODE=$?
    set -e
    cat /tmp/flutter-build-debug.log
    if [ $BUILD_EXIT_CODE -ne 0 ]; then
        log_error "Flutter Debug 构建失败！"
        log_info "查看构建日志: /tmp/flutter-build-debug.log"
        cd "$PROJECT_ROOT"
        exit 1
    fi
    log_success "Flutter Debug 构建验证通过"

    cd "$PROJECT_ROOT"
else
    log_warn "Flutter 未安装，跳过本地构建验证"
    log_info "提示：Flutter 静态分析已在 CI 中执行，建议本地安装 Flutter"
fi

# ============================================================
# 4. 预览将修改的文件
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
    echo "# 以上为本地预检预览，实际版本号和文件修改由 CI semantic-release 自动完成"
    echo "# CI 流程: push main → semantic-release 分析提交 → 决定版本号 → 更新四文件 → 构建 APK → 创建 Release"
    echo ""
    log_dry "实际发布由 CI 自动完成，请 push 代码到 main 分支"
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
# 5. 发布预检总结
# ============================================================
log_step "发布预检总结..."
echo ""
echo "========================================"
log_success "发布预检完成！"
echo ""
echo "预览版本: v$NEW_VERSION (versionCode: $NEW_VERSION_CODE)"
echo ""
echo "后续步骤:"
echo "  1. 将代码 push 到 main 分支:"
echo "     $ git push origin main"
echo ""
echo "  2. CI 将自动分析提交并决定版本号、构建签名 APK、创建 Release"
echo ""
echo "  3. 在 GitHub Release 页面查看发布结果"
echo ""
echo "========================================"
