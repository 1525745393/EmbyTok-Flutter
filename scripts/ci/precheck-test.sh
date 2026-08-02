#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

# 切换到 frontend 目录：flutter test 需在 pubspec.yaml 所在目录执行
FRONTEND_DIR="$(cd "$(dirname "$0")/../.." && pwd)/frontend"
cd "$FRONTEND_DIR"

SUMMARY_FILE="${GITHUB_STEP_SUMMARY:-/dev/null}"

log_info "执行 flutter test --coverage"

# 退出码非0即视为测试失败：测试失败必须阻断流水线
if ! flutter test --coverage; then
    log_error "flutter test 失败"
    exit 1
fi

# coverage 标准产物路径：flutter test --coverage 默认生成 coverage/lcov.info
COVERAGE_FILE="$FRONTEND_DIR/coverage/lcov.info"
{
    echo "## Flutter 测试覆盖率产物"
    echo ""
    echo "- 覆盖率报告路径：\`$COVERAGE_FILE\`"
    if [ -f "$COVERAGE_FILE" ]; then
        echo "- 文件已生成 ✓"
    else
        echo "- ⚠️ 未找到 lcov.info，请确认 test 是否产生覆盖率数据"
    fi
} >> "$SUMMARY_FILE"

log_success "flutter test 通过"
exit 0
