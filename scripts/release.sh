#!/bin/bash
# ============================================================
# EmbyTok - 版本发布脚本
# 功能：
#   1. 自动更新版本号（MAJOR/MINOR/PATCH）
#   2. 自动生成 CHANGELOG 占位条目
#   3. 运行发布前验证（verify-release.sh）
#   4. 生成 Git 提交和 tag
#   5. 推送 tag 触发 CI/CD 自动构建
# 使用：
#   ./scripts/release.sh bump    # 交互式选择版本号升级
#   ./scripts/release.sh patch   # bump PATCH（1.2.3 → 1.2.4）
#   ./scripts/release.sh minor   # bump MINOR（1.2.3 → 1.3.0）
#   ./scripts/release.sh major   # bump MAJOR（1.2.3 → 2.0.0）
#   ./scripts/release.sh custom 1.2.5  # 自定义版本号
#   ./scripts/release.sh --dry-run patch  # 预览操作
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

cd "$PROJECT_ROOT"

# ---------- 参数解析 ----------
DRY_RUN=0
BUMP_TYPE=""
CUSTOM_VERSION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)    DRY_RUN=1; shift ;;
        patch|minor|major|bump)
            BUMP_TYPE="$1"; shift ;;
        custom)
            BUMP_TYPE="custom"; shift; CUSTOM_VERSION="$1"; shift ;;
        -h|--help)
            echo "用法: $0 [--dry-run] <patch|minor|major|bump|custom <version>>"
            echo ""
            echo "示例："
            echo "  $0 patch       # 自动 bump PATCH 版本号"
            echo "  $0 minor       # 自动 bump MINOR 版本号"
            echo "  $0 major       # 自动 bump MAJOR 版本号"
            echo "  $0 bump        # 交互式选择"
            echo "  $0 custom 1.2.5 # 指定版本号"
            echo "  $0 --dry-run patch  # 预览操作，不实际变更"
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            exit 1
            ;;
    esac
done

# ---------- 标题 ----------
echo -e "${BOLD}=======================================${NC}"
echo -e "${BOLD}  EmbyTok 版本发布${NC}"
echo -e "${BOLD}=======================================${NC}"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
    log_warn "⚠️  DRY RUN 模式 — 仅预览操作"
    echo ""
fi

# ---------- 检查 Git 状态 ----------
log_info "1/8 检查 Git 状态..."
if ! git diff --quiet || ! git diff --cached --quiet; then
    log_error "❌ Git 工作树存在未提交的变更"
    echo ""
    git status --short
    echo ""
    log_error "请先提交或放弃所有变更后再发布"
    exit 1
fi
log_success "  ✓ Git 工作树干净"

# ---------- 读取当前版本 ----------
echo ""
log_info "2/8 读取当前版本..."
CURRENT_VERSION="$(grep -E '^version:' frontend/pubspec.yaml | awk '{print $2}')"
CURRENT_CODE="$(grep -E 'versionCode' frontend/android/app/build.gradle | head -1 | awk '{print $2}')"

if [ -z "$CURRENT_VERSION" ]; then
    log_error "无法从 pubspec.yaml 读取当前版本号"
    exit 1
fi

log_success "  当前版本: $CURRENT_VERSION (versionCode=$CURRENT_CODE)"

# ---------- 解析新版本号 ----------
echo ""
log_info "3/8 计算新版本号..."

# 拆分版本号
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

case "$BUMP_TYPE" in
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
    custom)
        if [ -z "$CUSTOM_VERSION" ]; then
            log_error "custom 模式需要指定版本号"
            exit 1
        fi
        if ! echo "$CUSTOM_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
            log_error "版本号格式错误，应为 MAJOR.MINOR.PATCH"
            exit 1
        fi
        IFS='.' read -r MAJOR MINOR PATCH <<< "$CUSTOM_VERSION"
        ;;
    bump|*)
        # 交互式模式
        echo ""
        echo "  可选方案："
        echo "    1) patch → $MAJOR.$MINOR.$((PATCH + 1))  (用于 bug 修复)"
        echo "    2) minor → $MAJOR.$((MINOR + 1)).0  (用于新增功能)"
        echo "    3) major → $((MAJOR + 1)).0.0  (用于破坏性变更)"
        echo ""
        echo -n "请输入选择 (1/2/3, 默认 1): "
        read -r CHOICE
        case "$CHOICE" in
            2) MINOR=$((MINOR + 1)); PATCH=0 ;;
            3) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
            1|"") PATCH=$((PATCH + 1)) ;;
            *) log_error "无效选择"; exit 1 ;;
        esac
        ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
# versionCode 加 1（整数单调递增）
NEW_CODE=$((CURRENT_CODE + 1))

log_success "  新版本: $NEW_VERSION (versionCode=$NEW_CODE)"

# ---------- dry-run 检查 ----------
if [ "$DRY_RUN" -eq 1 ]; then
    echo ""
    log_info "DRY RUN — 预览："
    echo "  ✓ 生成版本号: $NEW_VERSION"
    echo "  ✓ 更新 pubspec.yaml (version: $NEW_VERSION)"
    echo "  ✓ 更新 build.gradle (versionName \"$NEW_VERSION\", versionCode $NEW_CODE)"
    echo "  ✓ 更新 version.dart (kAppVersion = '$NEW_VERSION', kAppVersionCode = $NEW_CODE)"
    echo "  ✓ 更新 backend/core/version.py (__version__ = \"$NEW_VERSION\")"
    echo "  ✓ 添加 CHANGELOG.md 条目"
    echo "  ✓ 运行 verify-release.sh"
    echo "  ✓ Git commit + tag v$NEW_VERSION + push"
    echo ""
    log_warn "⚠️  实际发布请去掉 --dry-run"
    exit 0
fi

# ---------- 更新版本号文件 ----------
echo ""
log_info "4/8 更新各文件中的版本号..."

# 4.1 pubspec.yaml
sed -i "s/^version: .*/version: $NEW_VERSION/" frontend/pubspec.yaml
log_success "  ✓ pubspec.yaml  → version: $NEW_VERSION"

# 4.2 build.gradle
sed -i "s/versionName \"[^\"]*\"/versionName \"$NEW_VERSION\"/" frontend/android/app/build.gradle
sed -i "s/versionCode [0-9]*/versionCode $NEW_CODE/" frontend/android/app/build.gradle
log_success "  ✓ build.gradle → versionName \"$NEW_VERSION\", versionCode $NEW_CODE"

# 4.3 version.dart (Dart)
sed -i "s/kAppVersion = '[^']*'/kAppVersion = '$NEW_VERSION'/" frontend/lib/utils/version.dart
sed -i "s/kAppVersionCode = [0-9]*/kAppVersionCode = $NEW_CODE/" frontend/lib/utils/version.dart
log_success "  ✓ version.dart → kAppVersion = '$NEW_VERSION'"

# 4.4 backend/core/version.py (Python)
sed -i "s/__version__.*= *\"[^\"]*\"/__version__: str = \"$NEW_VERSION\"/" backend/core/version.py
log_success "  ✓ backend/core/version.py → __version__ = \"$NEW_VERSION\""

# ---------- 添加 CHANGELOG 条目 ----------
echo ""
log_info "5/8 在 CHANGELOG.md 添加 [$NEW_VERSION] 条目..."
TODAY="$(date +%Y-%m-%d)"

# 在 CHANGELOG.md 顶部第一个 "## [" 行之前插入新版本条
# 查找第一个 "## [X.Y.Z]" 或 "## [" 开头的行位置
if grep -q "^## " CHANGELOG.md; then
    # 找到第一个 ## 开头的行，在其前面插入
    awk -v version="$NEW_VERSION" -v date="$TODAY" '
        !found && /^## / {
            print "## [" version "] — " date
            print ""
            print "### Added"
            print ""
            print "- （请在此补充本次新增功能，然后提交）"
            print ""
            print "### Fixed"
            print ""
            print "- （请在此补充本次修复的 Bug）"
            print ""
            found=1
        }
        { print }
    ' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
    log_success "  ✓ CHANGELOG.md 已添加 [$NEW_VERSION] — $TODAY 条目（请编辑具体变更内容）"
else
    # 追加到文件末尾
    {
        echo ""
        echo "## [$NEW_VERSION] — $TODAY"
        echo ""
        echo "### Added"
        echo ""
        echo "- （请补充新增功能）"
        echo ""
    } >> CHANGELOG.md
    log_success "  ✓ CHANGELOG.md 已添加新版本条目"
fi

# ---------- 验证 ----------
echo ""
log_info "6/8 运行发布前验证..."
./scripts/verify-release.sh || {
    log_error "❌ 验证失败，请修复后重新运行"
    echo ""
    echo "  提示：可以手动编辑以下文件："
    echo "    - frontend/pubspec.yaml"
    echo "    - frontend/android/app/build.gradle"
    echo "    - frontend/lib/utils/version.dart"
    echo "    - backend/core/version.py"
    echo "    - CHANGELOG.md"
    exit 1
}

# ---------- 提交 ----------
echo ""
log_info "7/8 Git 提交变更..."
git add -A
git commit -m "chore: 发布 v$NEW_VERSION

- 版本号从 $CURRENT_VERSION 升级到 $NEW_VERSION
- versionCode: $CURRENT_CODE → $NEW_CODE" || {
    log_error "Git 提交失败"
    exit 1
}
log_success "  ✓ 已提交 (commit $(git rev-parse --short HEAD))"

# ---------- 创建 tag 并推送 ----------
echo ""
log_info "8/8 创建 tag v$NEW_VERSION 并推送到远程..."
git tag "v$NEW_VERSION" -m "Release v$NEW_VERSION"
git push origin main
git push origin "v$NEW_VERSION"

# ---------- 完成 ----------
echo ""
echo -e "${BOLD}=======================================${NC}"
log_success "✅ 发布成功! v$NEW_VERSION"
echo -e "${BOLD}=======================================${NC}"
echo ""
echo "  📦 版本号: v$CURRENT_VERSION → v$NEW_VERSION"
echo "  📊 versionCode: $CURRENT_CODE → $NEW_CODE"
echo "  🚀 CI/CD 已自动触发构建"
echo ""
echo "  后续操作："
echo "    1. 编辑 CHANGELOG.md 添加本次变更的具体说明并提交"
echo "    2. 在 GitHub Release 页面完善发布信息"
echo "    3. 查看 GitHub Actions 构建状态"
echo ""
