#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

SUMMARY_FILE="${GITHUB_STEP_SUMMARY:-/dev/null}"

# PR_BODY 由 CI 上下文注入（gh pr view --json body 或 GitHub Actions env）
# 为什么缺失时降级 exit 0：本地手动运行时无 PR 上下文，不应因此阻断
if [ -z "${PR_BODY:-}" ]; then
    echo "::warning::PR_BODY 环境变量未设置，跳过 PR 模板校验（降级模式）"
    exit 0
fi

# export 给 Python 子进程读取：os.environ 仅可见已 export 的变量
export PR_BODY

# 为什么用 Python 解析：PR body 含 HTML 注释、多级标题、waiver 块等结构，
# 纯 bash 正则难以可靠处理，Python 正则与字符串处理更稳健
# heredoc 终止符 PYEOF 必须顶格，是 bash 语法要求
set +e
missing=$(python3 - <<'PYEOF'
import os
import re
import sys

body = os.environ.get('PR_BODY', '')

# 必填栏位标题：与 PR 模板约定保持一致
required_sections = ['### 改了什么', '### 为什么', '### 如何验证']

# 提取指定 H3 栏位内容：从标题下一行到下一个同级或更高级标题
def extract_section(name):
    pattern = re.escape(name) + r'\s*\n(.*?)(?=\n#{2,3}\s|\Z)'
    match = re.search(pattern, body, re.DOTALL)
    if not match:
        return None
    return match.group(1)

# 去除 HTML 注释后再 strip：避免注释内容被误判为"已填写"
def strip_html_comments(text):
    return re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)

missing_sections = []
for section in required_sections:
    content = extract_section(section)
    if content is None:
        missing_sections.append(section + '（标题缺失）')
        continue
    cleaned = strip_html_comments(content).strip()
    if not cleaned:
        missing_sections.append(section + '（内容为空）')

# 校验 waiver 块：格式 <!-- waiver: signed-by=xxx issue=#xxx -->
# 仅当存在 waiver 块时校验字段完整性，缺失 signed-by 或 issue 视为格式错误
waiver_errors = []
for match in re.finditer(r'<!--\s*waiver:\s*(.*?)-->', body, re.DOTALL):
    waiver_body = match.group(1)
    if 'signed-by' not in waiver_body:
        waiver_errors.append('waiver 块缺少 signed-by 字段')
    if 'issue' not in waiver_body:
        waiver_errors.append('waiver 块缺少 issue 字段')

if missing_sections or waiver_errors:
    for item in missing_sections:
        print('缺失必填栏位：' + item)
    for item in waiver_errors:
        print('Waiver 校验失败：' + item)
    sys.exit(1)

sys.exit(0)
PYEOF
)
py_exit=$?
set -e

if [ "$py_exit" -ne 0 ]; then
    log_error "PR 模板校验未通过"
    {
        echo "## PR 模板校验"
        echo ""
        echo "以下问题需补充："
        echo ""
        echo '```'
        echo "$missing"
        echo '```'
    } >> "$SUMMARY_FILE"
    exit 1
fi

{
    echo "## PR 模板校验"
    echo ""
    echo "✅ 必填栏位完整，waiver 格式正确"
} >> "$SUMMARY_FILE"

log_success "PR 模板校验通过"
exit 0
