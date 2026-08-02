#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

# 切换到 backend 目录：pytest 需在 backend 根目录执行以正确发现 conftest.py
BACKEND_DIR="$(cd "$(dirname "$0")/../.." && pwd)/backend"
cd "$BACKEND_DIR"

# 为什么显式检测 tests 目录：避免 tests 目录被误删时 pytest 静默跳过导致"假通过"
if [ ! -d "tests" ]; then
    log_error "未找到 backend/tests 目录"
    exit 1
fi

log_info "执行 python3 -m pytest -v"

# 退出码非0即视为测试失败：后端测试失败必须阻断流水线
if ! python3 -m pytest -v; then
    log_error "后端测试失败"
    exit 1
fi

log_success "后端测试通过"
exit 0
