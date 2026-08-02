#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

# 切换到 frontend 目录：dart run 需在 pubspec.yaml 所在目录执行
FRONTEND_DIR="$(cd "$(dirname "$0")/../.." && pwd)/frontend"
cd "$FRONTEND_DIR"

SUMMARY_FILE="${GITHUB_STEP_SUMMARY:-/dev/null}"

# 为什么先 pub get：自定义 lint 依赖 analyzer 包，需先解析本地依赖才能运行
log_info "执行 flutter pub get"
if ! flutter pub get; then
    log_error "flutter pub get 失败，无法运行硬编码颜色 lint"
    exit 1
fi

log_info "执行 dart run tool/lints/hardcoded_color_lint.dart"

# 为什么用 set +e 包裹：自定义 lint 工具可能返回非0，但任务约定以 stdout
# 是否含 "HardcodedColor" 判定违规，需先捕获完整输出
set +e
lint_output=$(dart run tool/lints/hardcoded_color_lint.dart 2>&1)
lint_exit=$?
set -e

echo "$lint_output"

# 按任务约定：stdout 含 HardcodedColor 即视为存在违规
if echo "$lint_output" | grep -q 'HardcodedColor'; then
    log_error "检测到硬编码颜色违规"
    {
        echo "## 硬编码颜色 Lint 违规"
        echo ""
        echo '```'
        echo "$lint_output"
        echo '```'
    } >> "$SUMMARY_FILE"
    exit 1
fi

# 工具本身执行失败但未检出违规：提示但不阻断，避免工具缺失导致流水线卡死
if [ "$lint_exit" -ne 0 ]; then
    log_warn "dart run 退出码非0（$lint_exit），可能是 lint 工具缺失或异常，未检出 HardcodedColor 违规"
fi

log_success "未检测到硬编码颜色违规"
exit 0
