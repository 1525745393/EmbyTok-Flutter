#!/usr/bin/env bash
# ============================================================
# EmbyTok 发布回滚脚本
# 用法: ./scripts/rollback-release.sh [--dry-run]
# 功能:
#   1. 找到最新的 release 提交 (chore(release): bump version to ...)
#   2. 删除该提交及其 tag (vX.Y.Z)
#   3. 将版本号恢复到 release 之前的状态
# ============================================================

set -euo pipefail

# ---------- 颜色定义 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_error()   { echo -e "${RED}❌ $*${NC}"; }
log_warn()    { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_step()    { echo -e "\n${CYAN}▶ $*${NC}"; }
log_dry()     { echo -e "${CYAN}[DRY-RUN]${NC} $*"; }

# ---------- 解析参数 ----------
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        *)
            log_error "未知参数: $arg"
            echo "用法: ./scripts/rollback-release.sh [--dry-run]"
            exit 1
            ;;
    esac
done

# ---------- 初始化 ----------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo ""
echo "========================================"
echo " EmbyTok 发布回滚"
if [ "$DRY_RUN" = true ]; then
    echo " Dry-Run: 是（仅预览，不实际执行）"
fi
echo "========================================"

# ---------- 1. 检查 git 环境 ----------
log_step "检查 Git 环境..."

if ! command -v git >/dev/null 2>&1; then
    log_error "git 命令未安装或不在 PATH 中"
    exit 1
fi
log_success "git 命令可用"

# 检查是否在 Git 仓库中
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_error "当前目录不是 Git 仓库"
    exit 1
fi

# 检查工作树是否干净
if git status --porcelain | grep -q .; then
    log_warn "Git 工作树存在未提交的变更，回滚操作将保留这些变更"
    echo ""
    log_info "当前未提交变更:"
    git status --short | head -10 | while read -r line; do
        log_info "$line"
    done
else
    log_success "Git 工作树干净"
fi

# ---------- 2. 找到最新的 release 提交 ----------
log_step "查找最新 release 提交..."

# 使用 commit message 模式查找
RELEASE_COMMIT=$(git log --oneline --grep="chore(release): bump version" -1 2>/dev/null | awk '{print $1}')

if [ -z "$RELEASE_COMMIT" ]; then
    # 尝试更宽泛的匹配
    RELEASE_COMMIT=$(git log --oneline --grep="release" -1 2>/dev/null | awk '{print $1}')
fi

if [ -z "$RELEASE_COMMIT" ]; then
    log_error "未找到 release 提交，无法回滚"
    exit 1
fi

RELEASE_MESSAGE=$(git log --format="%s" -1 "$RELEASE_COMMIT")
RELEASE_TAG=$(git describe --tags --exact-match "$RELEASE_COMMIT" 2>/dev/null || echo "")

log_info "提交 SHA:   $RELEASE_COMMIT"
log_info "提交信息:   $RELEASE_MESSAGE"
log_info "关联标签:   ${RELEASE_TAG:-<无>}"

# 解析当前版本（从提交信息中提取）
CURRENT_VERSION=$(echo "$RELEASE_MESSAGE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [ -z "$CURRENT_VERSION" ]; then
    log_error "无法从提交信息中解析版本号"
    exit 1
fi
log_info "当前版本:   $CURRENT_VERSION"

# 找到前一个提交
PREVIOUS_COMMIT=$(git rev-parse "$RELEASE_COMMIT^")
PREVIOUS_VERSION=$(grep -E '^version:' frontend/pubspec.yaml | head -1 | sed 's/^version:[[:space:]]*//' | tr -d "'\"" | xargs)

log_info "上一版本:   $PREVIOUS_VERSION (基于当前 pubspec.yaml)"

# ---------- 3. 确认操作 ----------
echo ""
log_warn "即将执行以下操作:"
echo ""
echo "  1. 删除本地提交:  $RELEASE_COMMIT ($RELEASE_MESSAGE)"
echo "  2. 删除本地标签:  v$CURRENT_VERSION (如果存在)"
echo "  3. 删除远程标签:  origin/v$CURRENT_VERSION (如果存在)"
echo ""

if [ "$DRY_RUN" = false ]; then
    echo -n "请确认执行 (y/N): "
    read -r CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        log_info "用户取消操作"
        exit 0
    fi
fi

# ---------- 4. 执行回滚 ----------
log_step "执行回滚..."

CURRENT_TAG="v$CURRENT_VERSION"

# 4.1 删除远程 tag
if [ "$DRY_RUN" = true ]; then
    log_dry "git push origin --delete $CURRENT_TAG (预览: 不会执行)"
else
    log_info "检查远程标签 origin/$CURRENT_TAG..."
    if git ls-remote --tags origin 2>/dev/null | grep -q "refs/tags/$CURRENT_TAG"; then
        log_info "删除远程标签 origin/$CURRENT_TAG..."
        git push origin --delete "$CURRENT_TAG" 2>&1
        log_success "远程标签已删除"
    else
        # Task 5 修复: 语义清晰的错误消息
        # 旧版本: "远程 tag origin/$CURRENT_TAG 已存在或不存在，跳过"
        # 新版本: 明确表达"不存在"，不产生矛盾
        log_warn "远程标签 origin/$CURRENT_TAG 不存在，跳过"
    fi
fi

# 4.2 删除本地 tag
if [ "$DRY_RUN" = true ]; then
    log_dry "git tag -d $CURRENT_TAG (预览: 不会执行)"
else
    if git rev-parse "$CURRENT_TAG" >/dev/null 2>&1; then
        log_info "删除本地标签 $CURRENT_TAG..."
        git tag -d "$CURRENT_TAG"
        log_success "本地标签已删除"
    else
        log_warn "本地标签 $CURRENT_TAG 不存在，跳过"
    fi
fi

# 4.3 回滚 release 提交
if [ "$DRY_RUN" = true ]; then
    log_dry "git reset --hard $PREVIOUS_COMMIT (预览: 不会执行)"
else
    log_info "回滚到上一个提交: $PREVIOUS_COMMIT..."
    git reset --hard "$PREVIOUS_COMMIT"
    log_success "提交已回滚"
fi

# ---------- 5. 总结 ----------
echo ""
echo "========================================"
if [ "$DRY_RUN" = true ]; then
    log_dry "回滚预览完成！"
    echo ""
    log_info "要实际执行回滚，请移除 --dry-run 参数:"
    echo "  $ ./scripts/rollback-release.sh"
else
    log_success "回滚完成！"
    echo ""
    echo "回滚后状态:"
    echo "  当前版本: $PREVIOUS_VERSION (需手动验证文件内容)"
    echo "  HEAD 指向: $(git rev-parse --short HEAD)"
    echo ""
    echo "注意事项:"
    echo "  • 如果远程分支已推送了 release 提交，需要强制推送回滚:"
    echo "    $ git push -f origin main"
    echo "  • 强制推送会重写历史，确保团队成员了解此操作"
fi
echo "========================================"
