#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

# 切换到项目根目录：bandit 与 grep 均以 backend/ 相对路径扫描
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

SUMMARY_FILE="${GITHUB_STEP_SUMMARY:-/dev/null}"

# 为什么不直接调用 require_tool bandit：require_tool 命中缺失会 exit 0
# 跳过后续 CORS 检查，但任务要求 bandit 缺失时 CORS grep 仍执行。
# 故改为内联检测 + 标志位，使 CORS 检查不受 bandit 缺失影响
bandit_skipped=0
if ! command -v bandit >/dev/null 2>&1; then
    echo "::warning::工具 'bandit' 未安装，跳过 bandit 扫描（降级模式）"
    bandit_skipped=1
else
    log_info "执行 bandit 安全扫描"

    # 为什么用 set +e 包裹：bandit 发现高危问题会返回非0，set -e 会立即终止
    # 脚本，无法继续执行 CORS 检查。先捕获退出码再判定
    set +e
    bandit -r backend/ -c .bandit -f sarif -o /tmp/bandit.sarif 2>&1
    bandit_exit=$?
    set -e

    if [ "$bandit_exit" -ne 0 ]; then
        log_error "bandit 发现安全问题或执行失败（退出码 $bandit_exit）"
        {
            echo "## Bandit 安全扫描"
            echo ""
            echo "❌ bandit 退出码非0（$bandit_exit），请查看日志或 /tmp/bandit.sarif"
        } >> "$SUMMARY_FILE"
        exit 1
    fi

    {
        echo "## Bandit 安全扫描"
        echo ""
        echo "✅ 通过，SARIF 产物：/tmp/bandit.sarif"
    } >> "$SUMMARY_FILE"
fi

if [ "$bandit_skipped" -eq 1 ]; then
    {
        echo "## Bandit 安全扫描"
        echo ""
        echo "⚠️ bandit 未安装，已跳过"
    } >> "$SUMMARY_FILE"
fi

log_info "执行 CORS 配置检查"

# 检查危险的 CORS 通配配置：allow_origins=["*"] 允许任意站点携带凭证访问后端 API，
# 属于高风险配置，命中即阻断。grep 在 if 条件中不受 set -e 影响
if grep -rE 'allow_origins=\["\*"\]' backend/; then
    log_error "检测到 CORS allow_origins=[\"*\"] 通配配置，存在安全风险"
    {
        echo "## CORS 配置检查"
        echo ""
        echo "❌ 检测到 allow_origins=[\"*\"]"
    } >> "$SUMMARY_FILE"
    exit 1
fi

{
    echo "## CORS 配置检查"
    echo ""
    echo "✅ 未检测到通配 CORS 配置"
} >> "$SUMMARY_FILE"

log_success "安全检查通过"
exit 0
