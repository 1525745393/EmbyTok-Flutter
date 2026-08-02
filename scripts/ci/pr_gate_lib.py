"""GitHub API 封装库，供 pr-gate.py 调用。

设计目标：
- 仅依赖 requests，不引入 PyGithub，减少 CI 安装时间与攻击面
- 统一处理认证、分页、限流降级（对齐 spec NFR-1 / NFR-2 / FR-6）
- 类型注解齐全，函数单一职责，便于 pr-gate.py 单元测试

为什么放在独立模块：主逻辑 pr-gate.py 与 API 访问解耦后，
单测时可 mock 整个 GitHubAPI 类，无需真实网络调用。
"""
from __future__ import annotations

import time
from typing import Any

import requests


class RateLimitError(Exception):
    """GitHub API 限流且无法在阈值内恢复时抛出。

    为什么单独定义异常：调用方（pr-gate.py 顶层 try/except）需要区分
    "限流降级" 与 "其他故障"，前者按 NFR-2 转 PASS + 标注不可靠，
    后者转 exit 0 + 标注工具故障。
    """


class GitHubAPI:
    """GitHub API 封装，处理认证、分页、限流。"""

    BASE_URL = "https://api.github.com"
    # 为什么 300s：spec FR-6 要求 <5min sleep 重试，>5min 降级。300s 即 5 分钟
    RATE_LIMIT_MAX_WAIT_SECONDS = 300
    # Summary 评论的隐藏标记，用于查找已存在评论以更新而非新建
    GATE_COMMENT_MARKER = "<!-- pr-gate-summary -->"

    def __init__(self, token: str, repo: str):
        # repo 格式: "owner/repo"
        if "/" not in repo:
            raise ValueError(f"repo 参数需为 'owner/repo' 格式，实际收到: {repo}")
        owner, name = repo.split("/", 1)
        self.token = token
        self.repo = repo
        self.owner = owner
        self.name = name
        # 为什么统一 session：复用 TCP 连接，减少 TLS 握手开销
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "EmbyTok-pr-gate/1.0",
        })

    # ============================================================
    # 内部请求方法
    # ============================================================

    def _request(self, method: str, path: str, **kwargs) -> requests.Response:
        """
        统一 REST 请求方法。

        限流处理策略（对齐 spec FR-6 / NFR-2）：
        1. 捕获 403 + X-RateLimit-Remaining: 0
        2. 从 X-RateLimit-Reset header 计算剩余等待秒数
        3. 若 < 300 秒（5分钟），sleep 等待后重试 1 次
        4. 若 > 300 秒或重试仍失败，抛出 RateLimitError 异常
        """
        url = path if path.startswith("http") else f"{self.BASE_URL}{path}"
        response = self.session.request(method, url, **kwargs)

        if response.status_code == 403 and response.headers.get("X-RateLimit-Remaining") == "0":
            wait_seconds = self._calculate_wait_seconds(response.headers.get("X-RateLimit-Reset"))
            if wait_seconds <= self.RATE_LIMIT_MAX_WAIT_SECONDS:
                # 加 2s 缓冲，避免醒来时 GitHub 服务端尚未完成重置
                time.sleep(wait_seconds + 2)
                response = self.session.request(method, url, **kwargs)
                if response.status_code != 403 or response.headers.get("X-RateLimit-Remaining") != "0":
                    return response
            # 等待时间过长或重试仍被限流，交给上层降级
            raise RateLimitError(
                f"GitHub API 限流，剩余等待 {wait_seconds}s 超过 {self.RATE_LIMIT_MAX_WAIT_SECONDS}s 阈值"
            )

        return response

    @staticmethod
    def _calculate_wait_seconds(reset_ts: str | None) -> int:
        """从 X-RateLimit-Reset 计算 sleep 秒数。无法解析时返回大数以触发降级"""
        if not reset_ts:
            return 10**9
        try:
            return max(0, int(reset_ts) - int(time.time()))
        except (ValueError, TypeError):
            return 10**9

    def _get_paginated(self, path: str, params: dict | None = None) -> list[dict]:
        """
        处理 REST Link header 分页。
        为什么手动解析 Link：requests 不内置分页，且 GitHub per_page 上限 100，
        大 PR 变更文件数可能超过（极少见但需防御）。
        """
        items: list[dict] = []
        params = dict(params or {})
        params.setdefault("per_page", 100)
        url = path if path.startswith("http") else f"{self.BASE_URL}{path}"
        while url:
            response = self._request("GET", url, params=params)
            response.raise_for_status()
            items.extend(response.json())
            url = self._next_link(response.headers.get("Link"))
            # 翻页 URL 已包含所有查询参数，下一轮不再传 params
            params = None
        return items

    @staticmethod
    def _next_link(link_header: str | None) -> str | None:
        """从 Link header 解析 rel="next" URL"""
        if not link_header:
            return None
        for part in link_header.split(","):
            if 'rel="next"' in part:
                # 形如 <https://api.github.com/...&page=2>; rel="next"
                return part.strip().split(">")[0].strip("<")
        return None

    def _graphql(self, query: str, variables: dict) -> dict:
        """GraphQL 查询，调用方自行处理 cursor 分页。

        为什么不复用 _request：GraphQL 走 POST /graphql 单一端点，
        限流检测逻辑与 REST 相同但请求构造不同，单独实现更清晰。
        """
        url = f"{self.BASE_URL}/graphql"
        payload = {"query": query, "variables": variables}
        response = self.session.post(url, json=payload)

        if response.status_code == 403 and response.headers.get("X-RateLimit-Remaining") == "0":
            wait_seconds = self._calculate_wait_seconds(response.headers.get("X-RateLimit-Reset"))
            if wait_seconds <= self.RATE_LIMIT_MAX_WAIT_SECONDS:
                time.sleep(wait_seconds + 2)
                response = self.session.post(url, json=payload)
                if not (response.status_code == 403 and response.headers.get("X-RateLimit-Remaining") == "0"):
                    pass
                else:
                    raise RateLimitError("GraphQL API 限流，重试后仍未恢复")
            else:
                raise RateLimitError(
                    f"GraphQL API 限流，剩余等待 {wait_seconds}s 超过阈值"
                )

        response.raise_for_status()
        body = response.json()
        if body.get("errors"):
            raise RuntimeError(f"GraphQL 查询错误: {body['errors']}")
        return body["data"]

    # ============================================================
    # 公开 API
    # ============================================================

    def get_pr_files(self, pr_number: int) -> list[str]:
        """GET /repos/{repo}/pulls/{pr}/files — 返回变更文件路径列表"""
        items = self._get_paginated(f"/repos/{self.repo}/pulls/{pr_number}/files")
        return [item["filename"] for item in items if "filename" in item]

    def get_pr(self, pr_number: int) -> dict:
        """GET /repos/{repo}/pulls/{pr} — 返回 PR 详情（含 body, user, created_at, head.sha）"""
        response = self._request("GET", f"/repos/{self.repo}/pulls/{pr_number}")
        response.raise_for_status()
        return response.json()

    def get_reviews(self, pr_number: int) -> list[dict]:
        """GET /repos/{repo}/pulls/{pr}/reviews — 返回所有 review（含 state=APPROVED, user, body）"""
        return self._get_paginated(f"/repos/{self.repo}/pulls/{pr_number}/reviews")

    def get_issue_comments(self, pr_number: int) -> list[dict]:
        """GET /repos/{repo}/issues/{pr}/comments — 返回 PR 级评论"""
        return self._get_paginated(f"/repos/{self.repo}/issues/{pr_number}/comments")

    def get_review_threads(self, pr_number: int) -> list[dict]:
        """
        GraphQL 查询 reviewThreads — 返回 inline comments + isResolved 状态。

        为什么用 GraphQL 而非 REST：REST 不直接提供 isResolved 字段，
        而 pr-gate Step 3 必须区分「已解决」与「未解决」的评论。
        分页通过 cursor 处理，单页 100 条足以覆盖常规 PR。
        """
        query = """
        query($owner: String!, $name: String!, $number: Int!, $after: String) {
          repository(owner: $owner, name: $name) {
            pullRequest(number: $number) {
              reviewThreads(first: 100, after: $after) {
                pageInfo { hasNextPage endCursor }
                nodes {
                  isResolved
                  comments(first: 1) {
                    nodes { body author { login } }
                  }
                }
              }
            }
          }
        }
        """
        threads: list[dict] = []
        cursor: str | None = None
        while True:
            data = self._graphql(query, {
                "owner": self.owner,
                "name": self.name,
                "number": pr_number,
                "after": cursor,
            })
            pr_node = (data.get("repository") or {}).get("pullRequest")
            if not pr_node:
                break
            connection = pr_node["reviewThreads"]
            for node in connection["nodes"]:
                comments = (node.get("comments") or {}).get("nodes", [])
                first = comments[0] if comments else {}
                threads.append({
                    "isResolved": bool(node.get("isResolved", False)),
                    "body": first.get("body", ""),
                    "author": (first.get("author") or {}).get("login", ""),
                })
            page_info = connection.get("pageInfo", {})
            if not page_info.get("hasNextPage"):
                break
            cursor = page_info.get("endCursor")
        return threads

    def get_issue(self, issue_number: int) -> dict | None:
        """GET /repos/{repo}/issues/{issue} — 验证 issue 存在（waiver 关联）"""
        response = self._request("GET", f"/repos/{self.repo}/issues/{issue_number}")
        if response.status_code == 404:
            return None
        response.raise_for_status()
        return response.json()

    def get_codeowners(self) -> list[str]:
        """
        读取 .github/CODEOWNERS 文件，解析出维护者 login 列表。

        为什么需要这个：判断「团队规模」用于 Solo 降级 + Waiver 签名权限校验。
        文件缺失时返回空列表，pr-gate.py 会按 solo 模式降级处理。
        """
        response = self._request(
            "GET",
            f"/repos/{self.repo}/contents/.github/CODEOWNERS",
            headers={"Accept": "application/vnd.github.raw+json"},
        )
        if response.status_code == 404:
            return []
        response.raise_for_status()
        maintainers: list[str] = []
        seen: set[str] = set()
        for raw_line in response.text.splitlines():
            line = raw_line.strip()
            # 为什么跳过注释和空行：CODEOWNERS 允许 # 注释与空行分隔
            if not line or line.startswith("#"):
                continue
            # CODEOWNERS 格式: <path> @user1 @user2 @org/team
            for token in line.split()[1:]:
                if token.startswith("@"):
                    # 取 @ 后的 login，剥离可能的 /team 后缀
                    login = token.lstrip("@").split("/")[0]
                    if login and login not in seen:
                        seen.add(login)
                        maintainers.append(login)
        return maintainers

    def post_comment(self, pr_number: int, body: str) -> None:
        """POST /repos/{repo}/issues/{pr}/comments — 发布评论"""
        response = self._request(
            "POST",
            f"/repos/{self.repo}/issues/{pr_number}/comments",
            json={"body": body},
        )
        response.raise_for_status()

    def update_comment(self, comment_id: int, body: str) -> None:
        """PATCH /repos/{repo}/issues/comments/{comment_id} — 更新已有评论"""
        response = self._request(
            "PATCH",
            f"/repos/{self.repo}/issues/comments/{comment_id}",
            json={"body": body},
        )
        response.raise_for_status()

    def find_gate_comment(self, pr_number: int) -> int | None:
        """查找已有的 Gate Check Summary 评论 ID（通过评论开头标记识别），用于更新而非新建"""
        for comment in self.get_issue_comments(pr_number):
            body = comment.get("body", "")
            if body.lstrip().startswith(self.GATE_COMMENT_MARKER):
                return comment.get("id")
        return None

    def upsert_gate_comment(self, pr_number: int, body: str) -> None:
        """发布或更新 Summary 评论，避免 PR 下堆积多条 Gate Check 评论"""
        existing_id = self.find_gate_comment(pr_number)
        # 为什么在 body 顶部放 marker：find_gate_comment 依赖此标记识别已存在评论
        full_body = f"{self.GATE_COMMENT_MARKER}\n{body}"
        if existing_id:
            self.update_comment(existing_id, full_body)
        else:
            self.post_comment(pr_number, full_body)

    def set_status(
        self,
        sha: str,
        state: str,
        description: str,
        context: str = "pr-gate / gate-check",
    ) -> None:
        """POST /repos/{repo}/statuses/{sha} — 设置 Status Check
        state: "success" 或 "failure"
        """
        response = self._request(
            "POST",
            f"/repos/{self.repo}/statuses/{sha}",
            json={
                "state": state,
                # GitHub 限制 description ≤ 140 字符，超出会被截断报错
                "description": description[:140],
                "context": context,
            },
        )
        response.raise_for_status()

    def add_labels(self, pr_number: int, labels: list[str]) -> None:
        """POST /repos/{repo}/issues/{pr}/labels — 添加 label"""
        response = self._request(
            "POST",
            f"/repos/{self.repo}/issues/{pr_number}/labels",
            json={"labels": labels},
        )
        response.raise_for_status()

    def remove_label(self, pr_number: int, label: str) -> None:
        """DELETE /repos/{repo}/issues/{pr}/labels/{label} — 移除 label"""
        response = self._request(
            "DELETE",
            f"/repos/{self.repo}/issues/{pr_number}/labels/{label}",
        )
        # 404 表示 label 不存在，视为已删除成功（幂等），避免重复删除报错
        if response.status_code not in (200, 204, 404):
            response.raise_for_status()
