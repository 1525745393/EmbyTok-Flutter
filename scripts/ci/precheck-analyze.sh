#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

# 切换到 frontend 目录：flutter 命令必须在 pubspec.yaml 所在目录执行
FRONTEND_DIR="$(cd "$(dirname "$0")/../.." && pwd)/frontend"
cd "$FRONTEND_DIR"

# GitHub Step Summary 路径：本地运行时无此环境变量，降级写入 /dev/null
SUMMARY_FILE="${GITHUB_STEP_SUMMARY:-/dev/null}"

log_info "执行 flutter analyze --no-pub lib"

# 为什么用 set +e 包裹：flutter analyze 在仅有 warning/info 时也可能返回非0，
# 但本检查按任务约定以 stdout 是否含 "error •" 判定，需先捕获完整输出再判定
set +e
analyze_output=$(flutter analyze --no-pub lib 2>&1)
analyze_exit=$?
set -e

echo "$analyze_output"

# 写入 GitHub Step Summary，便于 PR 检查页面直接查看分析结果
{
    echo "## Flutter Analyze 结果"
    echo ""
    echo '```'
    echo "$analyze_output"
    echo '```'
} >> "$SUMMARY_FILE"

# 按任务约定：仅当 stdout 含 "error •" 才判定失败
# 为什么不直接用退出码：避免 warning/info 噪声误阻断流水线，统一以 error 级别为准
if echo "$analyze_output" | grep -q 'error •'; then
    log_error "检测到 error 级别静态分析问题"
    exit 1
fi

log_success "未检测到 error 级别问题"
exit 0
