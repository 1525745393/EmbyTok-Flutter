#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

# require_tool 在 shellcheck 缺失时会 exit 0 + warning，本行之后的代码不会执行
require_tool shellcheck

# 切换到项目根目录：shellcheck 的 glob 需相对项目根解析
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

log_info "执行 shellcheck scripts/*.sh"

# 为什么用 -S error：docs/code-review.md §4 规定 warning 级 = Minor（建议修复，不阻断），
# 仅 error 级（语法错误、未定义变量等）才阻断合并
if ! shellcheck -S error scripts/*.sh; then
    log_error "shellcheck 发现 error 级问题"
    exit 1
fi

log_success "shellcheck 通过"
exit 0
