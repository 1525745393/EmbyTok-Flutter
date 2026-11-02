from __future__ import annotations

from typing import Optional
from urllib.parse import urlparse

from fastapi import Header

from core.config import DEFAULT_PAGE_LIMIT, MAX_PAGE_LIMIT
from core.errors import BAD_REQUEST, APIError

_ALLOWED_SCHEMES = ("http", "https")


def get_emby_server_url(
    emby_server_url: str = Header(..., alias="X-Emby-Server-Url"),
) -> str:
    """从请求头 X-Emby-Server-Url 获取 Emby 服务器地址。

    仅允许显式 http/https scheme（防代理被用作任意地址转发/SSRF 面扩大），
    缺 scheme、非白名单 scheme 或畸形 URL 一律拒绝。
    """
    if not emby_server_url:
        raise APIError(BAD_REQUEST, "缺少 X-Emby-Server-Url 请求头")
    parsed = urlparse(emby_server_url)
    if parsed.scheme not in _ALLOWED_SCHEMES or not parsed.netloc:
        raise APIError(BAD_REQUEST, "X-Emby-Server-Url 必须是 http:// 或 https:// 地址")
    return emby_server_url


def get_emby_token(
    emby_token: Optional[str] = Header(default=None, alias="X-Emby-Token"),
    authorization: Optional[str] = Header(default=None, alias="Authorization"),
) -> str:
    """从请求头 X-Emby-Token 或 Authorization: Bearer 获取 token"""
    if emby_token:
        return emby_token
    if authorization and authorization.lower().startswith("bearer "):
        return authorization.split(" ", 1)[1].strip()
    raise APIError(BAD_REQUEST, "缺少 X-Emby-Token 或 Authorization 请求头")


def get_user_id(
    emby_user_id: str = Header(..., alias="X-Emby-UserId"),
) -> str:
    """从请求头 X-Emby-UserId 获取用户 ID"""
    if not emby_user_id:
        raise APIError(BAD_REQUEST, "缺少 X-Emby-UserId 请求头")
    return emby_user_id


def clamp_limit(limit: int) -> int:
    """收敛分页 limit 到 [1, MAX_PAGE_LIMIT] 区间（B1：防止客户端传入超大 limit
    导致 Emby 拉取巨量数据造成内存/超时风险）

    可作为 FastAPI 依赖使用：`limit: int = Depends(clamp_limit)`
    """
    if limit < 1:
        return DEFAULT_PAGE_LIMIT
    return min(limit, MAX_PAGE_LIMIT)
