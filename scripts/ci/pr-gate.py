#!/usr/bin/env python3
"""代码审查工作流的人工评审流程强门禁主逻辑。

为什么独立于 pr_gate_lib.py：本脚本只承载「业务判定」（5 步校验 + 降级策略），
所有 GitHub API 访问交给 pr_gate_lib.GitHubAPI，便于单测时整体 mock。

执行约定（对齐 spec FR-1..FR-7 / NFR-1 / NFR-2）：
- exit 0：PASS（含降级 PASS）
- exit 1：FAIL（人工评审未通过）
"""

from __future__ import annotations

import fnmatch
import os
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone

from pr_gate_lib import GitHubAPI, RateLimitError


# ============================================================
# 常量
# ============================================================

# 核心模块 glob 映射。
# 为什么用 fnmatch 而非 pathlib.match：fnmatch 在各 Python 3 版本行为稳定，
# 且其 * 会匹配包括 / 在内的任意字符，故 */player* 可命中任意目录层级下的
# player 前缀文件（等价于 glob 的 **/player*）。
CORE_GLOBS: list[str] = [
    "frontend/lib/*/player*",                  # 播放器：核心播放体验
    "frontend/lib/*/auth*",                    # 鉴权：登录态 / Token 处理
    "backend/api/routes/*.py",                 # 后端路由：API 入口
    "scripts/release*.sh",                     # 发布流程：影响发版安全
    ".github/workflows/android-release.yml",   # CI/CD：发布流水线
]

SOLO_THRESHOLD = 2              # 维护者数量 ≤ 2 触发 Solo 降级
OVERDUE_HOURS = 48              # PR 未合并超时阈值（小时）
REVIEW_OVERDUE_LABEL = "review-overdue"
POST_REVIEW_LABEL = "post-review"

# 严重级别前缀正则。为什么用 MULTILINE：评论体可能多行，
# 任意一行以 [Blocker] 开头都应被识别为对应级别。
SEVERITY_RE = re.compile(r"^\s*\[(Blocker|Major|Minor|Nit)\]", re.MULTILINE)

# Waiver 证据块正则：MAJOR-N 编号 + 签名 + 关联 issue + 原因，缺一不可。
WAIVER_RE = re.compile(
    r"<!--\s*waiver:\s*(MAJOR-\d+)\s*\n"
    r"\s*signed-by:\s*@?(\S+)\s*\n"
    r"\s*issue:\s*#?(\d+)\s*\n"
    r"\s*reason:\s*(.+?)\s*\n"
    r"\s*-->",
    re.MULTILINE,
)

# 紧急绕过块正则：签名 + 原因 + ticket。
EMERGENCY_BYPASS_RE = re.compile(
    r"<!--\s*emergency-bypass\s*\n"
    r"\s*signed-by:\s*@?(\S+)\s*\n"
    r"\s*reason:\s*(.+?)\s*\n"
    r"\s*ticket:\s*#?(\d+)\s*\n"
    r"\s*-->",
    re.MULTILINE,
)


# ============================================================
# 数据结构
# ============================================================

@dataclass
class CommentSeverity:
    """单条评论的严重级别归类结果。"""
    level: str              # Blocker / Major / Minor / Nit / unprefixed
    body: str
    is_resolved: bool       # inline 评论是否已 resolved；PR 级评论恒为 False
    author: str = ""


@dataclass
class Waiver:
    """解析出的 waiver 证据块。"""
    major_id: str           # MAJOR-N
    signed_by: str          # 签名 login
    issue_number: int       # 关联 issue 编号
    reason: str             # 豁免原因


@dataclass
class EmergencyBypass:
    """解析出的紧急绕过块。"""
    signed_by: str
    reason: str
    ticket: int


@dataclass
class GateResult:
    """5 步校验的聚合结果，用于渲染 Summary 评论与决定 PASS/FAIL。"""
    is_core: bool = False
    required_approvals: int = 0
    actual_approvals: int = 0
    blockers_unresolved: int = 0
    majors_unresolved: int = 0
    majors_waived: int = 0
    minors_unresolved: int = 0
    nits_unresolved: int = 0
    unprefixed: int = 0
    solo_mode: bool = False
    emergency_bypass: bool = False
    emergency_bypass_by: str = ""
    waived_majors: list[str] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)

    @property
    def passed(self) -> bool:
        # 紧急绕过：强制 PASS（spec 降级策略）
        if self.emergency_bypass:
            return True
        # 审批人数不足：FAIL
        if self.actual_approvals < self.required_approvals:
            return False
        # 未解决 Blocker：FAIL
        if self.blockers_unresolved > 0:
            return False
        # Major 未解决且无 waiver 抵消：FAIL
        if self.majors_unresolved - self.majors_waived > 0:
            return False
        return True


# ============================================================
# Step 1: 核心模块变更识别
# ============================================================

def is_core_change(pr_files: list[str]) -> bool:
    """检查变更文件是否命中任一核心 glob。命中即视为核心变更。"""
    for path in pr_files:
        for pattern in CORE_GLOBS:
            if fnmatch.fnmatch(path, pattern):
                return True
    return False


# ============================================================
# Step 2: 审批人数统计
# ============================================================

def get_required_approvals(is_core: bool, maintainers: list[str]) -> int:
    """根据核心模块标志与团队规模返回所需审批数。

    Solo 降级（spec FR-3）：维护者 ≤ 2 时，强制要求 2 审批会导致 PR 长期阻塞，
    故统一降级为 1。非核心模块本就只需 1 审批。
    """
    if len(maintainers) <= SOLO_THRESHOLD:
        return 1
    return 2 if is_core else 1


def count_unique_approvals(reviews: list[dict], pr_author_login: str) -> int:
    """统计唯一 approval 数（排除作者自审，同一人多次 approval 只算一次）。"""
    approvers: set[str] = set()
    for review in reviews:
        if review.get("state") != "APPROVED":
            continue
        user = (review.get("user") or {}).get("login", "")
        # 排除空用户与作者自审（PR 作者不应审批自己的 PR）
        if not user or user == pr_author_login:
            continue
        approvers.add(user)
    return len(approvers)


# ============================================================
# Step 3: 评论严重级别解析
# ============================================================

def classify_comment(body: str, is_resolved: bool, author: str = "") -> list[CommentSeverity]:
    """单条评论可能含多个严重级别前缀（多行），全部解析出来。

    为什么返回 list：一条评论可能同时含 [Blocker] 与 [Minor] 两段，
    分别归类才能准确统计未解决项。
    """
    body = body or ""
    matches = SEVERITY_RE.findall(body)
    if not matches:
        # 无前缀：整条作为 unprefixed 计入，仅 warn 不阻断
        return [CommentSeverity(level="unprefixed", body=body, is_resolved=is_resolved, author=author)]
    return [
        CommentSeverity(level=level, body=body, is_resolved=is_resolved, author=author)
        for level in matches
    ]


def collect_severities(
    reviews: list[dict],
    review_threads: list[dict],
    issue_comments: list[dict],
) -> list[CommentSeverity]:
    """聚合所有评论来源（review / inline / PR 级评论）的严重级别归类。"""
    severities: list[CommentSeverity] = []
    # review body：PR 级 review 评论，无 resolved 概念
    for review in reviews:
        severities.extend(classify_comment(
            review.get("body", ""),
            is_resolved=False,
            author=(review.get("user") or {}).get("login", ""),
        ))
    # review_threads：inline 评论，携带 isResolved 状态
    for thread in review_threads:
        severities.extend(classify_comment(
            thread.get("body", ""),
            is_resolved=bool(thread.get("isResolved", False)),
            author=thread.get("author", ""),
        ))
    # issue_comments：PR 级评论，无 resolved
    for comment in issue_comments:
        severities.extend(classify_comment(
            comment.get("body", ""),
            is_resolved=False,
            author=(comment.get("user") or {}).get("login", ""),
        ))
    return severities


def summarize_severities(severities: list[CommentSeverity]) -> dict[str, int]:
    """按级别统计未 resolved 数量；unprefixed 单独统计用于 warn。"""
    counts = {
        "blockers_unresolved": 0,
        "majors_unresolved": 0,
        "minors_unresolved": 0,
        "nits_unresolved": 0,
        "unprefixed": 0,
    }
    for severity in severities:
        if severity.level == "Blocker":
            if not severity.is_resolved:
                counts["blockers_unresolved"] += 1
        elif severity.level == "Major":
            if not severity.is_resolved:
                counts["majors_unresolved"] += 1
        elif severity.level == "Minor":
            if not severity.is_resolved:
                counts["minors_unresolved"] += 1
        elif severity.level == "Nit":
            if not severity.is_resolved:
                counts["nits_unresolved"] += 1
        else:
            counts["unprefixed"] += 1
    return counts


# ============================================================
# Step 4: Waiver 证据块校验
# ============================================================

def parse_waivers(pr_body: str) -> list[Waiver]:
    """从 PR body 解析所有 waiver 块。格式不符（缺字段）的块会被丢弃（TR-3.6）。"""
    waivers: list[Waiver] = []
    for match in WAIVER_RE.finditer(pr_body or ""):
        major_id, signed_by, issue_str, reason = match.groups()
        try:
            issue_number = int(issue_str)
        except (TypeError, ValueError):
            # issue 编号非整数：视为格式不符，跳过
            continue
        waivers.append(Waiver(
            major_id=major_id,
            signed_by=signed_by,
            issue_number=issue_number,
            reason=reason.strip(),
        ))
    return waivers


def parse_emergency_bypass(pr_body: str) -> EmergencyBypass | None:
    """从 PR body 解析紧急绕过块。格式不符返回 None。"""
    match = EMERGENCY_BYPASS_RE.search(pr_body or "")
    if not match:
        return None
    signed_by, reason, ticket_str = match.groups()
    try:
        ticket = int(ticket_str)
    except (TypeError, ValueError):
        return None
    return EmergencyBypass(signed_by=signed_by, reason=reason.strip(), ticket=ticket)


def validate_waivers(
    waivers: list[Waiver],
    maintainers: list[str],
    api: GitHubAPI,
) -> tuple[list[Waiver], list[str]]:
    """校验 waiver：签名者必须在 maintainers 列表，关联 issue 必须存在且 open。

    返回 (有效 waivers, 失败原因列表)。
    为什么单独传 api：issue 存在性需走网络请求，单测时可 mock 整个 GitHubAPI。
    """
    valid: list[Waiver] = []
    failures: list[str] = []
    maintainers_set = set(maintainers)
    for waiver in waivers:
        if waiver.signed_by not in maintainers_set:
            failures.append(
                f"{waiver.major_id}: signed-by @{waiver.signed_by} 不在 CODEOWNERS 维护者列表"
            )
            continue
        issue = api.get_issue(waiver.issue_number)
        if issue is None:
            failures.append(f"{waiver.major_id}: 关联 issue #{waiver.issue_number} 不存在")
            continue
        if issue.get("state") != "open":
            failures.append(
                f"{waiver.major_id}: 关联 issue #{waiver.issue_number} 状态为 {issue.get('state')}，需 open"
            )
            continue
        valid.append(waiver)
    return valid, failures


# ============================================================
# Step 5: 超时提醒
# ============================================================

def parse_pr_created_at(pr: dict) -> datetime:
    """解析 PR created_at（GitHub ISO 8601 含 Z 后缀）为 UTC datetime。"""
    created_str = pr.get("created_at", "")
    # Python 3.11 之前 fromisoformat 不支持 Z 后缀，统一替换为 +00:00
    if created_str.endswith("Z"):
        created_str = created_str[:-1] + "+00:00"
    try:
        return datetime.fromisoformat(created_str)
    except (ValueError, TypeError):
        # 解析失败：返回当前时间，视为不过期，避免误报超时
        return datetime.now(timezone.utc)


def is_pr_overdue(pr: dict) -> bool:
    """PR 是否超过 48h 未合并。"""
    created = parse_pr_created_at(pr)
    now = datetime.now(timezone.utc)
    elapsed_hours = (now - created).total_seconds() / 3600.0
    return elapsed_hours > OVERDUE_HOURS


def get_pr_labels(pr: dict) -> list[str]:
    """从 PR 详情提取 label 名称列表。"""
    return [label.get("name", "") for label in pr.get("labels", []) if label.get("name")]


def maybe_remind_overdue(api: GitHubAPI, pr_number: int, pr: dict) -> None:
    """Step 5: PR 超 48h 未合并时提醒 @Maintainer，已有 overdue label 则跳过避免重复。

    为什么吞掉所有异常：提醒是辅助功能，发生在 gate 结果已定之后，
    失败不应影响已计算的 gate 结果与 Summary 发布。
    """
    try:
        if not is_pr_overdue(pr):
            return
        if REVIEW_OVERDUE_LABEL in get_pr_labels(pr):
            return
        maintainers = api.get_codeowners()
        mention = " ".join(f"@{m}" for m in maintainers) if maintainers else "@maintainers"
        body = (
            f"⏰ PR #{pr_number} 已超过 {OVERDUE_HOURS}h 未合并，请维护者及时 review。\n\n"
            f"cc {mention}"
        )
        api.post_comment(pr_number, body)
        api.add_labels(pr_number, [REVIEW_OVERDUE_LABEL])
    except Exception as exc:  # noqa: BLE001 — 辅助功能，吞掉避免影响主流程
        print(f"⚠️ 超时提醒发送失败：{exc}", file=sys.stderr)


# ============================================================
# 主流程
# ============================================================

def run_gate(api: GitHubAPI, pr: dict, pr_number: int) -> GateResult:
    """对单个 PR 执行 Step 1~4 校验，返回 GateResult。

    pr 由调用方预先获取（process_single_pr 复用于 Status Check 的 sha），
    避免重复请求。
    """
    result = GateResult()

    # 一次性预取所有数据，减少多次网络往返
    pr_files = api.get_pr_files(pr_number)
    reviews = api.get_reviews(pr_number)
    review_threads = api.get_review_threads(pr_number)
    issue_comments = api.get_issue_comments(pr_number)
    maintainers = api.get_codeowners()

    # Step 1: 核心模块变更识别
    result.is_core = is_core_change(pr_files)

    # Step 2: 审批人数
    pr_author = (pr.get("user") or {}).get("login", "")
    result.solo_mode = len(maintainers) <= SOLO_THRESHOLD
    result.required_approvals = get_required_approvals(result.is_core, maintainers)
    result.actual_approvals = count_unique_approvals(reviews, pr_author)

    # Step 3: 评论严重级别
    severities = collect_severities(reviews, review_threads, issue_comments)
    counts = summarize_severities(severities)
    result.blockers_unresolved = counts["blockers_unresolved"]
    result.majors_unresolved = counts["majors_unresolved"]
    result.minors_unresolved = counts["minors_unresolved"]
    result.nits_unresolved = counts["nits_unresolved"]
    result.unprefixed = counts["unprefixed"]

    # Step 4: Waiver 校验
    waivers = parse_waivers(pr.get("body", ""))
    valid_waivers, waiver_failures = validate_waivers(waivers, maintainers, api)
    result.majors_waived = len(valid_waivers)
    result.waived_majors = [w.major_id for w in valid_waivers]
    for failure in waiver_failures:
        result.notes.append(f"⚠️ Waiver 校验失败：{failure}")

    # 紧急绕过：签名者必须在 maintainers 列表
    bypass = parse_emergency_bypass(pr.get("body", ""))
    if bypass is not None:
        if bypass.signed_by in set(maintainers):
            result.emergency_bypass = True
            result.emergency_bypass_by = bypass.signed_by
            result.notes.append(
                f"🚨 紧急绕过：由 @{bypass.signed_by} 签发，ticket #{bypass.ticket}"
            )
        else:
            result.notes.append(
                f"⚠️ 紧急绕过签名无效：@{bypass.signed_by} 不在维护者列表"
            )

    return result


def render_summary(result: GateResult, pr_number: int) -> str:
    """渲染 Markdown 格式的 Summary 评论（含检查项结果表格）。"""
    status_icon = "✅ PASS" if result.passed else "❌ FAIL"
    lines: list[str] = [
        f"## 🔒 PR Gate Check — {status_icon}",
        "",
        f"PR #{pr_number}",
        "",
        "| 检查项 | 结果 | 详情 |",
        "| --- | --- | --- |",
    ]

    # 核心模块变更
    core_icon = "🔥" if result.is_core else "—"
    lines.append(f"| 核心模块变更 | {core_icon} | {'是' if result.is_core else '否'} |")

    # 审批人数
    approval_ok = result.actual_approvals >= result.required_approvals
    approval_icon = "✅" if approval_ok else "❌"
    approval_detail = f"{result.actual_approvals}/{result.required_approvals}"
    if result.solo_mode:
        approval_detail += "（Solo 模式）"
    lines.append(f"| 审批人数 | {approval_icon} | {approval_detail} |")

    # Blocker
    blocker_icon = "✅" if result.blockers_unresolved == 0 else "❌"
    lines.append(f"| Blocker 未解决 | {blocker_icon} | {result.blockers_unresolved} |")

    # Major（含 waiver 抵消）
    major_remaining = result.majors_unresolved - result.majors_waived
    major_icon = "✅" if major_remaining <= 0 else "❌"
    major_detail = f"{result.majors_unresolved} 未解决"
    if result.majors_waived > 0:
        major_detail += f"，{result.majors_waived} 已 waiver"
    lines.append(f"| Major 未解决（含 waiver） | {major_icon} | {major_detail} |")

    # Minor / Nit / 无前缀（仅提示，不阻断）
    lines.append(f"| Minor 未解决 | ⚠️ | {result.minors_unresolved} |")
    lines.append(f"| Nit 未解决 | ℹ️ | {result.nits_unresolved} |")
    lines.append(f"| 无前缀评论（仅 warn） | ℹ️ | {result.unprefixed} |")

    if result.emergency_bypass:
        lines.append("")
        lines.append(
            f"🚨 **紧急绕过**：由 @{result.emergency_bypass_by} 签发，Gate 降级为 PASS"
        )

    if result.solo_mode:
        lines.append("")
        lines.append("⚠️ **Solo 模式**：维护者 ≤ 2，审批要求已降级为 1")

    if result.waived_majors:
        lines.append("")
        lines.append(f"**已 waiver 的 Major**：{', '.join(result.waived_majors)}")

    if result.notes:
        lines.append("")
        lines.append("**备注**：")
        for note in result.notes:
            lines.append(f"- {note}")

    return "\n".join(lines)


def create_post_review_issue(api: GitHubAPI, pr_number: int, result: GateResult) -> None:
    """紧急绕过生效后创建 post-review issue，追踪事后复核。

    为什么吞掉异常：issue 创建失败不应影响已 PASS 的 gate 结果，仅记日志由后续人工补建。
    为什么直接用 session：pr_gate_lib 未暴露 create_issue 方法，且这是低频操作，
    避免为此修改库；限流概率极低。
    """
    try:
        title = f"[post-review] PR #{pr_number} 紧急绕过追踪"
        body = (
            f"PR #{pr_number} 启用了紧急绕过，由 @{result.emergency_bypass_by} 签发。\n\n"
            f"需在合并后补齐正式 review 流程。\n\n"
            f"**未解决项**：\n"
            f"- Blocker: {result.blockers_unresolved}\n"
            f"- Major: {result.majors_unresolved - result.majors_waived}\n"
        )
        response = api.session.post(
            f"{api.BASE_URL}/repos/{api.repo}/issues",
            json={"title": title, "body": body, "labels": [POST_REVIEW_LABEL]},
        )
        response.raise_for_status()
    except Exception as exc:  # noqa: BLE001 — 辅助功能，吞掉避免影响主流程
        print(f"⚠️ post-review issue 创建失败：{exc}", file=sys.stderr)


def process_single_pr(api: GitHubAPI, pr_number: int) -> int:
    """处理单个 PR：执行校验 → 超时提醒 → 发布 Summary → 设置 Status Check。"""
    pr = api.get_pr(pr_number)
    result = run_gate(api, pr, pr_number)

    # Step 5: 超时提醒（辅助功能，内部吞异常）
    maybe_remind_overdue(api, pr_number, pr)

    # 发布 / 更新 Summary 评论
    summary = render_summary(result, pr_number)
    api.upsert_gate_comment(pr_number, summary)

    # 设置 Status Check
    sha = (pr.get("head") or {}).get("sha", "")
    if sha:
        if result.passed:
            api.set_status(sha, "success", "Gate Check 通过")
        else:
            api.set_status(sha, "failure", "Gate Check 未通过，请处理 Blocker/Major/审批")

    # 紧急绕过：创建 post-review issue 追踪事后复核
    if result.emergency_bypass:
        create_post_review_issue(api, pr_number, result)

    return 0 if result.passed else 1


def list_open_pr_numbers(api: GitHubAPI) -> list[int]:
    """列出所有 open PR 编号（schedule 触发时遍历用）。

    为什么访问 _get_paginated：pr_gate_lib 未暴露 list_prs 公开方法，
    但 _get_paginated 已封装分页与限流重试，复用可保持降级行为一致，
    避免在此重复实现分页逻辑。
    """
    items = api._get_paginated(f"/repos/{api.repo}/pulls", params={"state": "open"})
    return [item["number"] for item in items if item.get("number")]


def emit_degradation_status(api: GitHubAPI, pr_number_str: str, message: str) -> None:
    """降级路径下尝试为当前 PR 发布 success Status Check（不阻断合并）。

    为什么吞掉异常：降级路径本身已是容错，再失败仅记日志，不再传播。
    """
    if not pr_number_str:
        return
    try:
        pr_number = int(pr_number_str)
        pr = api.get_pr(pr_number)
        sha = (pr.get("head") or {}).get("sha", "")
        if sha:
            api.set_status(sha, "success", message)
    except Exception as exc:  # noqa: BLE001 — 降级路径，吞掉避免二次故障
        print(f"⚠️ 降级 Status 发布失败：{exc}", file=sys.stderr)


def main() -> int:
    """主入口：解析环境变量 → 执行 5 步校验 → 发布 Summary + Status Check。

    降级策略（spec NFR-2）：
    - RateLimitError：Gate 降级 PASS + 标注"⚠️ API 限流，结果不可靠"
    - 其他 Exception：Gate 降级 PASS + 标注"⚠️ Gate Check 工具故障，请人工确认"
    两种情况都 exit 0，不阻断合并。
    """
    token = os.environ.get("GITHUB_TOKEN", "")
    repo = os.environ.get("REPO", "")
    event_name = os.environ.get("GITHUB_EVENT_NAME", "")
    pr_number_str = os.environ.get("PR_NUMBER", "")

    if not token or not repo:
        # 配置缺失：降级 PASS，不阻断合并
        print("ERROR: GITHUB_TOKEN 和 REPO 环境变量必须设置", file=sys.stderr)
        return 0

    api = GitHubAPI(token, repo)
    is_schedule = event_name == "schedule"

    try:
        if is_schedule:
            # schedule 触发：遍历所有 open PR，逐个处理
            # 每个 PR 独立设置 Status，整体 exit 0（定时任务不阻断）
            for number in list_open_pr_numbers(api):
                try:
                    process_single_pr(api, number)
                except Exception as exc:  # noqa: BLE001 — 单个 PR 失败不影响其他 PR
                    print(f"⚠️ PR #{number} 处理失败：{exc}", file=sys.stderr)
            return 0

        if not pr_number_str:
            print("ERROR: PR_NUMBER 环境变量未设置（非 schedule 触发时必需）", file=sys.stderr)
            return 0

        return process_single_pr(api, int(pr_number_str))

    except RateLimitError as exc:
        # 限流降级：PASS + 标注不可靠
        print(f"⚠️ API 限流，结果不可靠：{exc}", file=sys.stderr)
        emit_degradation_status(api, pr_number_str, "⚠️ API 限流，结果不可靠")
        return 0
    except Exception as exc:  # noqa: BLE001 — 兜底降级
        # 工具故障降级：PASS + 标注需人工确认
        print(f"⚠️ Gate Check 工具故障，请人工确认：{exc}", file=sys.stderr)
        emit_degradation_status(api, pr_number_str, "⚠️ Gate Check 工具故障，请人工确认")
        return 0


if __name__ == "__main__":
    sys.exit(main())
