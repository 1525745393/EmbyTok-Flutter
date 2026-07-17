from __future__ import annotations

from typing import Optional

from fastapi import Header

from core.config import DEFAULT_PAGE_LIMIT, MAX_PAGE_LIMIT
from core.errors import BAD_REQUEST, APIError


def get_emby_server_url(
    emby_server_url: str = Header(..., alias="X-Emby-Server-Url"),
) -> str:
    """从请求头 X-Emby-Server-Url 获取 Emby 服务器地址"""
    if not emby_server_url:
        raise APIError(BAD_REQUEST, "缺少 X-Emby-Server-Url 请求头")
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
