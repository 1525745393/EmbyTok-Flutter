#!/bin/bash
# ============================================================
# EmbyTok - 发布回滚脚本
# 功能：
#   1. 回滚 Git tag 到指定的上一个稳定版本
#   2. 删除远程和本地 tag
#   3. 提供 dry-run 模式
# 使用：
#   ./scripts/rollback-release.sh           # 回滚到上一个 tag
#   ./scripts/rollback-release.sh v1.2.3  # 回滚到指定 tag
#   ./scripts/rollback-release.sh --dry-run  # 预览操作，不实际变更
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
TARGET_TAG=""
FORCE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --force)     FORCE=1; shift ;;
        -h|--help)
            echo "用法: $0 [选项] [目标tag]"
            echo ""
            echo "示例："
            echo "  $0                       # 回滚到上一个 tag"
            echo "  $0 v1.2.3               # 回滚到指定 tag 作为当前"
            echo "  $0 --dry-run             # 预览，不实际变更"
            exit 0
            ;;
        *)
            if [[ "$1" == v* ]]; then
                TARGET_TAG="$1"
                shift
            else
                log_error "未知参数: $1"
                exit 1
            fi
            ;;
    esac
done

# ---------- 开始回滚流程 ----------
echo -e "${BOLD}=======================================${NC}"
echo -e "${BOLD}  EmbyTok 发布回滚${NC}"
echo -e "${BOLD}=======================================${NC}"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
    log_warn "⚠️  DRY RUN 模式 — 只会显示要执行的操作，不会实际变更"
    echo ""
fi

# 1. 列出所有 tag，按时间排序
log_info "1/5 获取 Git tag 列表..."
ALL_TAGS="$(git tag --sort=-creatordate)"
if [ -z "$ALL_TAGS" ]; then
    log_error "未找到任何 tag，无法回滚"
    exit 1
fi
echo "$ALL_TAGS" | head -10 | sed 's/^/  /'

# 2. 确认要回滚的 tag 和回滚到的 tag
CURRENT_TAG="$(echo "$ALL_TAGS" | head -1)"
if [ -n "$TARGET_TAG" ]; then
    # 用户指定了目标 tag，回滚到该 tag
    ROLLBACK_TO_TAG="$TARGET_TAG"
    # 找到当前最新 tag
else
    # 找到上一个 tag（不包括最新的那个除外）
    ROLLBACK_TO_TAG="$(echo "$ALL_TAGS" | sed -n '2p')"
fi

# 3. 确认
echo ""
log_info "2/5 回滚方案："
echo "  当前最新 tag: $CURRENT_TAG"
echo "  回滚到 tag:   $ROLLBACK_TO_TAG"
echo ""
if [ -z "$ROLLBACK_TO_TAG" ]; then
    log_error "未找到可回滚的上一个 tag"
    exit 1
fi

# 4. 确认 tag 与远程分支
log_info "3/5 确认 tag 存在..."
if ! git rev-parse "$CURRENT_TAG" >/dev/null 2>&1; then
    log_error "本地不存在 tag: $CURRENT_TAG"
    exit 1
fi
log_success "  ✓ 本地 tag 存在"

# 5. 检查分支和 tag 完整性
echo ""
log_info "4/5 规划执行以下操作："
if [ "$DRY_RUN" -eq 1 ]; then
    echo "  - (预览) 删除远程 tag $CURRENT_TAG"
    echo "  - (预览) 删除本地 tag $CURRENT_TAG"
    echo "  - (预览) 切换到 tag $ROLLBACK_TO_TAG 对应的提交为 \"当前最新版本"
    echo ""
    log_warn "⚠️  回滚方案预览完成，请去掉 --dry-run 再执行"
    exit 0
fi

# 实际执行（非 dry-run
echo "  - 删除远程 tag origin/$CURRENT_TAG"
echo "  - 删除本地 tag $CURRENT_TAG"
echo ""

# 确认
if [ "$FORCE" -ne 1 ]; then
    echo -n "确认执行？ (y/N): "
    read -r CONFIRM
    if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
        log_warn "已取消回滚"
        exit 0
    fi
fi

# 6. 执行
echo ""
log_info "5/5 开始执行回滚..."

# 6.1 删除远程 tag
if git ls-remote --tags origin 2>/dev/null | grep -q "refs/tags/$CURRENT_TAG"; then
    echo -e "${GREEN}  - 删除远程 tag origin/$CURRENT_TAG${NC}"
    git push origin --delete "$CURRENT_TAG" 2>&1
else
    log_warn "  远程 tag origin/$CURRENT_TAG 已存在或不存在，跳过"
fi

# 6.2 删除本地 tag
echo "  - 删除本地 tag $CURRENT_TAG"
git tag -d "$CURRENT_TAG" 2>&1

# 6.3 同时确认远程 Release 需通过 GitHub Web 页面手动删除
echo ""
log_success "✅ 回滚完成!"
echo ""
echo "  后续操作建议："
echo "    1. GitHub Release 页面手动删除 $CURRENT_TAG 的发布"
echo "    2. 修改版本号为 $ROLLBACK_TO_TAG，运行 ./scripts/release.sh 重新发布"
echo "    3. 需要将 main 分支回退到 $ROLLBACK_TO_TAG。"
