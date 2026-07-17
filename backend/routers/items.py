from __future__ import annotations

from typing import Dict

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from clients.emby_client import EmbyClient
from core.errors import BAD_REQUEST, APIError
from core.response_utils import media_item_from_emby
from models.base_models import MediaItem, PlaybackInfo
from routers.deps import get_emby_server_url, get_emby_token, get_user_id

router = APIRouter(prefix="/api/items", tags=["媒体项"])


class _ProgressBody(BaseModel):
    position_seconds: float = Field(..., description="当前播放时间（秒）")
    is_paused: bool = Field(default=False, description="是否处于暂停状态（用于 Emby 续播位置准确性）")


@router.get("/{item_id}", response_model=MediaItem, summary="获取媒体项详情")
async def get_item(
    item_id: str,
    emby_server_url: str = Depends(get_emby_server_url),
    emby_token: str = Depends(get_emby_token),
    user_id: str = Depends(get_user_id),
) -> MediaItem:
    """根据媒体项 ID 返回完整的媒体信息"""
    async with EmbyClient(base_url=emby_server_url, token=emby_token) as client:
        client.user_id = user_id
        raw = await client.get_item(item_id)
        if not isinstance(raw, dict):
            raise APIError(404, "未找到指定的媒体项")
        return media_item_from_emby(raw, emby_server_url)


@router.get("/{item_id}/playback", response_model=PlaybackInfo, summary="获取播放信息")
async def get_playback(
    item_id: str,
    emby_server_url: str = Depends(get_emby_server_url),
    emby_token: str = Depends(get_emby_token),
    _: str = Depends(get_user_id),
) -> PlaybackInfo:
    """构造媒体项的直链播放地址"""
    async with EmbyClient(base_url=emby_server_url, token=emby_token) as client:
        url = await client.get_playback_url(item_id)
        return PlaybackInfo(
            item_id=item_id,
            playback_url=url,
            format="direct",
            protocol="http",
        )


@router.post("/{item_id}/progress", summary="上报播放进度")
async def save_progress(
    item_id: str,
    body: _ProgressBody,
    emby_server_url: str = Depends(get_emby_server_url),
    emby_token: str = Depends(get_emby_token),
    user_id: str = Depends(get_user_id),
) -> Dict[str, bool]:
    """保存当前媒体项的播放进度（秒）

    支持上报暂停状态（is_paused），原实现写死 IsPaused=False 导致暂停时
    Emby 仍记录为"在播"，续播位置失真。
    """
    if body.position_seconds < 0:
        raise APIError(BAD_REQUEST, "position_seconds 不能为负数")
    async with EmbyClient(base_url=emby_server_url, token=emby_token) as client:
        client.user_id = user_id
        await client.save_playback_progress(
            item_id=item_id,
            position_ticks=int(body.position_seconds * 10_000_000),
            is_paused=body.is_paused,
        )
        return {"ok": True}


@router.get("/{item_id}/progress", summary="获取播放进度")
async def get_progress(
    item_id: str,
    emby_server_url: str = Depends(get_emby_server_url),
    emby_token: str = Depends(get_emby_token),
    user_id: str = Depends(get_user_id),
) -> Dict[str, float]:
    """返回上次记录的播放进度（秒），未登录或不存在时返回 0"""
    async with EmbyClient(base_url=emby_server_url, token=emby_token) as client:
        client.user_id = user_id
        seconds = await client.get_playback_progress(item_id)
        return {"position_seconds": float(seconds or 0.0)}
