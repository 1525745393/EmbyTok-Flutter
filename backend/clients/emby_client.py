from __future__ import annotations

from typing import Any, Dict, List, Optional

import httpx

from core.config import (
    EMBY_CLIENT_MAX_CONNECTIONS,
    EMBY_CLIENT_MAX_KEEPALIVE,
    EMBY_CLIENT_TIMEOUT,
    get_emby_client_header,
)
from core.errors import SERVER_UNREACHABLE, APIError, handle_emby_error


# 应用级共享 httpx.AsyncClient（P1：复用连接池，避免每次请求新建客户端）
# 由 main.py 在 startup/shutdown 中管理生命周期，所有 EmbyClient 复用此实例
_shared_client: Optional[httpx.AsyncClient] = None


def get_shared_http_client() -> httpx.AsyncClient:
    """获取应用级共享的 httpx.AsyncClient。

    若尚未初始化，则按默认配置创建一个（用于测试或未走 lifespan 的场景）。
    生产环境应由 main.py 在 startup 中显式初始化，以应用连接池配置。
    """
    global _shared_client
    if _shared_client is None or _shared_client.is_closed:
        _shared_client = httpx.AsyncClient(
            timeout=httpx.Timeout(EMBY_CLIENT_TIMEOUT),
            limits=httpx.Limits(
                max_connections=EMBY_CLIENT_MAX_CONNECTIONS,
                max_keepalive_connections=EMBY_CLIENT_MAX_KEEPALIVE,
            ),
            headers=get_emby_client_header(),
        )
    return _shared_client


async def close_shared_http_client() -> None:
    """关闭应用级共享的 httpx.AsyncClient（应用退出时调用）"""
    global _shared_client
    if _shared_client is not None and not _shared_client.is_closed:
        try:
            await _shared_client.aclose()
        except Exception:
            pass
    _shared_client = None


class EmbyClient:
    """Emby 服务器异步 HTTP 客户端，封装常用接口

    性能说明：默认复用应用级共享的 httpx.AsyncClient（连接池/keep-alive/TLS 会话），
    避免每次请求都新建客户端导致的 TCP+TLS 握手开销。可通过 shared_client=False
    强制使用独立客户端（仅用于测试或隔离场景）。
    """

    def __init__(
        self,
        base_url: str,
        token: Optional[str] = None,
        timeout: float = EMBY_CLIENT_TIMEOUT,
        shared_client: bool = True,
    ) -> None:
        self.base_url: str = base_url.rstrip("/")
        self.token: Optional[str] = token
        self.user_id: Optional[str] = None
        self.timeout: float = timeout

        if shared_client:
            # 复用应用级共享客户端（P1：连接池复用）
            self._client: httpx.AsyncClient = get_shared_http_client()
            self._owns_client: bool = False
        else:
            # 独立客户端（仅用于测试等隔离场景）
            self._client = httpx.AsyncClient(
                timeout=httpx.Timeout(timeout),
                headers=get_emby_client_header(),
            )
            self._owns_client = True

    # ------------------------------------------------------------------
    # 基础工具方法
    # ------------------------------------------------------------------
    def _build_url(self, path: str) -> str:
        """拼接请求地址"""
        return f"{self.base_url}{path}"

    def _default_params(self) -> Dict[str, Any]:
        """通用查询参数（包含鉴权 token）"""
        params: Dict[str, Any] = {}
        if self.token:
            params["ApiKey"] = self.token
        return params

    async def _request(
        self,
        method: str,
        path: str,
        params: Optional[Dict[str, Any]] = None,
        json: Optional[Dict[str, Any]] = None,
        data: Optional[Dict[str, Any]] = None,
    ) -> Any:
        """统一请求入口，处理错误并返回 JSON"""
        url = self._build_url(path)
        merged_params = {**self._default_params(), **(params or {})}

        try:
            resp = await self._client.request(
                method=method,
                url=url,
                params=merged_params if merged_params else None,
                json=json,
                data=data,
            )
        except httpx.HTTPError as exc:
            raise APIError(SERVER_UNREACHABLE, f"无法连接服务器：{exc}") from exc

        if resp.status_code >= 400:
            message = ""
            try:
                raw = resp.json()
                if isinstance(raw, dict):
                    message = raw.get("Message") or raw.get("message") or ""
            except ValueError:
                message = resp.text[:200]
            raise handle_emby_error(resp.status_code, message)

        if resp.headers.get("content-type", "").lower().startswith("application/json"):
            try:
                return resp.json()
            except ValueError:
                return resp.text
        return resp.text

    # ------------------------------------------------------------------
    # 鉴权
    # ------------------------------------------------------------------
    async def authenticate(self, username: str, password: str) -> dict:
        """登录接口 POST /Users/AuthenticateByName，返回原始 JSON"""
        payload = {
            "Username": username,
            "Pw": password,
        }
        params = {
            "format": "json",
        }
        data = await self._request(
            "POST",
            "/Users/AuthenticateByName",
            params=params,
            json=payload,
        )
        if isinstance(data, dict):
            access_token = data.get("AccessToken") or (
                data.get("SessionInfo", {}) or {}
            ).get("AccessToken")
            user_info = data.get("User") or {}
            uid = user_info.get("Id")
            if access_token:
                self.token = access_token
            if uid:
                self.user_id = str(uid)
        return data

    # ------------------------------------------------------------------
    # 媒体库
    # ------------------------------------------------------------------
    async def get_libraries(self) -> List[dict]:
        """获取虚拟文件夹列表 GET /Library/VirtualFolders"""
        params = {}
        data = await self._request("GET", "/Library/VirtualFolders", params=params)
        if isinstance(data, list):
            return data
        if isinstance(data, dict):
            return data.get("Items") or data.get("items") or []
        return []

    # ------------------------------------------------------------------
    # 媒体项
    # ------------------------------------------------------------------
    async def get_items(
        self,
        parent_id: Optional[str] = None,
        limit: int = 20,
        offset: int = 0,
        sort: str = "SortName",
    ) -> dict:
        """获取媒体项列表 GET /Items（与前端字段集保持一致：MediaSources,Path）"""
        params: Dict[str, Any] = {
            "Recursive": "true",
            "IncludeItemTypes": "Movie,Episode,Video",
            "Fields": (
                "Overview,Genres,People,CommunityRating,"
                "ProductionYear,ImageTags,UserData,RuntimeTicks,"
                "MediaSources,Path"
            ),
            "SortBy": sort,
            "StartIndex": offset,
            "Limit": limit,
        }
        if parent_id:
            params["ParentId"] = parent_id
        if self.user_id:
            params["UserId"] = self.user_id
        return await self._request("GET", "/Items", params=params)

    async def get_item(self, item_id: str) -> dict:
        """获取单个媒体项详情 GET /Items/{item_id}（与前端字段集保持一致）"""
        params: Dict[str, Any] = {
            "Fields": (
                "Overview,Genres,People,CommunityRating,"
                "ProductionYear,ImageTags,UserData,RuntimeTicks,"
                "MediaSources,Path,MediaStreams"
            ),
        }
        if self.user_id:
            params["UserId"] = self.user_id
        return await self._request("GET", f"/Items/{item_id}", params=params)

    async def get_playback_url(self, item_id: str) -> str:
        """构造直链播放地址（相对路径，不含 token）

        安全说明（B4）：原实现将 token 拼到 URL query (?api_key=...) 返回给客户端，
        会在访问日志/代理链路中泄露。现在返回不含 token 的相对路径，由前端
        通过自有认证头/已有 playback_url 字段附加鉴权（与 media_item_from_emby
        返回的 playback_url 行为一致）。
        """
        return f"/Items/{item_id}/Download"

    async def search(
        self,
        query: str,
        limit: int = 20,
        offset: int = 0,
        include_types: Optional[List[str]] = None,
    ) -> dict:
        """搜索媒体项（支持类型过滤）"""
        params: Dict[str, Any] = {
            "SearchTerm": query,
            "Recursive": "true",
            "Fields": (
                "Overview,Genres,People,CommunityRating,ProductionYear,"
                "RuntimeTicks,MediaSources,Path"
            ),
            "StartIndex": offset,
            "Limit": limit,
        }
        if include_types:
            params["IncludeItemTypes"] = ",".join(include_types)
        else:
            params["IncludeItemTypes"] = "Movie,Episode,Video"
        if self.user_id:
            params["UserId"] = self.user_id
        return await self._request("GET", "/Items", params=params)

    async def search_persons(
        self,
        query: str,
        limit: int = 20,
    ) -> dict:
        """搜索人物（演员/导演/编剧）"""
        params: Dict[str, Any] = {
            "SearchTerm": query,
            "Limit": limit,
            "Fields": (
                "Overview,ImageTags,Name"
            ),
        }
        if self.user_id:
            params["UserId"] = self.user_id
        return await self._request("GET", "/Persons", params=params)

    async def get_subtitles(self, item_id: str) -> List[dict]:
        """获取字幕轨道 GET /Items/{item_id}/PlaybackInfo"""
        params: Dict[str, Any] = {}
        if self.user_id:
            params["UserId"] = self.user_id
        data = await self._request(
            "GET",
            f"/Items/{item_id}/PlaybackInfo",
            params=params,
        )
        if not isinstance(data, dict):
            return []
        media_sources = data.get("MediaSources") or []
        tracks: List[dict] = []
        for source in media_sources:
            if not isinstance(source, dict):
                continue
            for stream in source.get("MediaStreams", []) or []:
                if not isinstance(stream, dict):
                    continue
                if stream.get("Type") == "Subtitle":
                    tracks.append(stream)
        return tracks

    # ------------------------------------------------------------------
    # 收藏
    # ------------------------------------------------------------------
    async def get_favorites(self) -> dict:
        """获取收藏列表（与前端字段集保持一致）"""
        params: Dict[str, Any] = {
            "Recursive": "true",
            "Filters": "IsFavorite",
            "IncludeItemTypes": "Movie,Episode,Video",
            "Fields": (
                "Overview,Genres,People,CommunityRating,ProductionYear,"
                "RuntimeTicks,MediaSources,Path,ImageTags,UserData"
            ),
        }
        if self.user_id:
            params["UserId"] = self.user_id
        return await self._request("GET", "/Items", params=params)

    async def toggle_favorite(self, item_id: str, is_favorite: bool) -> dict:
        """切换收藏状态（与前端对齐：使用带 userId 的 /Users/{uid}/FavoriteItems/{id}）"""
        if not self.user_id:
            raise APIError(400, "需要先完成登录后才能操作收藏")
        path = f"/Users/{self.user_id}/FavoriteItems/{item_id}"
        method = "POST" if is_favorite else "DELETE"
        return await self._request(method, path)

    # ------------------------------------------------------------------
    # 播放进度
    # ------------------------------------------------------------------
    async def save_playback_progress(
        self,
        item_id: str,
        position_ticks: int,
        is_paused: bool = False,
    ) -> None:
        """上报播放进度 POST /Sessions/Playing/Progress

        Args:
            item_id: 媒体项 ID。
            position_ticks: 播放位置（ticks，1 秒 = 10_000_000 ticks）。
            is_paused: 是否处于暂停状态。原实现写死 False 导致暂停时
                Emby 仍记录为"在播"，续播位置失真。
        """
        if not self.user_id:
            raise APIError(400, "需要先完成登录后才能上报播放进度")
        payload = {
            "ItemId": item_id,
            "PositionTicks": int(position_ticks),
            "IsPaused": bool(is_paused),
            "EventName": "pause" if is_paused else "timeupdate",
        }
        params: Dict[str, Any] = {"UserId": self.user_id}
        await self._request(
            "POST",
            "/Sessions/Playing/Progress",
            params=params,
            json=payload,
        )

    async def get_playback_progress(self, item_id: str) -> Optional[int]:
        """获取上次播放进度（秒）"""
        if not self.user_id:
            return None
        try:
            data = await self._request(
                "GET",
                f"/Users/{self.user_id}/Items/{item_id}/UserData",
            )
            if isinstance(data, dict):
                ticks = data.get("PlaybackPositionTicks")
                if ticks is not None:
                    return int(ticks) // 10_000_000
        except APIError:
            return None
        return None

    # ------------------------------------------------------------------
    # 生命周期
    # ------------------------------------------------------------------
    async def close(self) -> None:
        """关闭底层 httpx 客户端

        仅关闭自身拥有的客户端（独立模式）。共享模式下不关闭应用级客户端，
        其生命周期由 main.py 统一管理。
        """
        if not self._owns_client:
            return
        try:
            await self._client.aclose()
        except Exception:
            pass

    async def __aenter__(self) -> "EmbyClient":
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        await self.close()
