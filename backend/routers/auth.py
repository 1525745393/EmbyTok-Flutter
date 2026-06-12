from __future__ import annotations

from fastapi import APIRouter, Depends

from clients.emby_client import EmbyClient
from core.errors import BAD_REQUEST, APIError, SERVER_UNREACHABLE
from models.base_models import AuthRequest, AuthResponse
from routers.deps import get_emby_server_url

router = APIRouter(prefix="/api/auth", tags=["认证"])


@router.post("/login", response_model=AuthResponse, summary="用户登录认证")
async def login(body: AuthRequest) -> AuthResponse:
    """使用用户名和密码登录 Emby 服务器，返回访问令牌与用户信息"""
    if not body.emby_url:
        raise APIError(BAD_REQUEST, "emby_url 不能为空")
    try:
        async with EmbyClient(base_url=body.emby_url) as client:
            data = await client.authenticate(body.username, body.password)
            if not isinstance(data, dict):
                raise APIError(502, "服务器返回格式异常")

            access_token = data.get("AccessToken") or (
                (data.get("SessionInfo") or {}).get("AccessToken")
            )
            user_info = data.get("User") or {}
            user_id = user_info.get("Id")
            username = user_info.get("Name") or body.username
            server_id = data.get("ServerId")

            if not access_token or not user_id:
                raise APIError(401, "用户名或密码无效")

            return AuthResponse(
                access_token=str(access_token),
                user_id=str(user_id),
                username=str(username),
                server_id=str(server_id) if server_id else None,
            )
    except APIError as exc:
        if exc.status_code == 401:
            raise
        if exc.status_code == SERVER_UNREACHABLE or "无法连接" in str(exc.message):
            raise APIError(502, f"无法连接 Emby 服务器：{exc.message}")
        raise
