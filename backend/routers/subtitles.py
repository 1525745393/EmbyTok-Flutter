from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends

from clients.emby_client import EmbyClient
from core.response_utils import subtitle_track_from_emby
from models.base_models import SubtitleTrack
from routers.deps import get_emby_server_url, get_emby_token, get_user_id

router = APIRouter(prefix="/api/items/{item_id}/subtitles", tags=["字幕"])


@router.get("", response_model=List[SubtitleTrack], summary="获取字幕轨道列表")
async def list_subtitles(
    item_id: str,
    emby_server_url: str = Depends(get_emby_server_url),
    emby_token: str = Depends(get_emby_token),
    user_id: str = Depends(get_user_id),
) -> List[SubtitleTrack]:
    """返回指定媒体项的所有可用字幕轨道

    字幕流 URL 使用 emby_server_url 拼成绝对地址（B2：原实现遗漏导致 url 为相对路径）。
    """
    async with EmbyClient(base_url=emby_server_url, token=emby_token) as client:
        client.user_id = user_id
        raw_list = await client.get_subtitles(item_id)
        return [subtitle_track_from_emby(item, emby_server_url) for item in raw_list]
