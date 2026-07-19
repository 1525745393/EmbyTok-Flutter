from __future__ import annotations

from typing import Dict, List

from fastapi import APIRouter, Depends, Query

from clients.emby_client import EmbyClient
from core.response_utils import media_item_from_emby
from models.base_models import MediaItem
from routers.deps import get_emby_server_url, get_emby_token, get_user_id

router = APIRouter(prefix="/api/favorites", tags=["收藏"])


@router.get("", response_model=List[MediaItem], summary="获取收藏列表")
async def list_favorites(
    limit: int = Query(default=50, ge=1, le=500, description="每页条目数"),
    offset: int = Query(default=0, ge=0, description="分页起始偏移"),
    emby_server_url: str = Depends(get_emby_server_url),
    emby_token: str = Depends(get_emby_token),
    user_id: str = Depends(get_user_id),
) -> List[MediaItem]:
    """返回当前用户的收藏媒体项（支持分页，避免大量收藏时静默截断）"""
    async with EmbyClient(base_url=emby_server_url, token=emby_token) as client:
        client.user_id = user_id
        data = await client.get_favorites(limit=limit, offset=offset)
        items = data.get("Items", []) if isinstance(data, dict) else []
        return [media_item_from_emby(item, emby_server_url) for item in items]


@router.post("/{item_id}", summary="添加到收藏")
async def add_favorite(
    item_id: str,
    emby_server_url: str = Depends(get_emby_server_url),
    emby_token: str = Depends(get_emby_token),
    user_id: str = Depends(get_user_id),
) -> Dict[str, bool]:
    """将指定媒体项加入当前用户的收藏列表"""
    async with EmbyClient(base_url=emby_server_url, token=emby_token) as client:
        client.user_id = user_id
        await client.toggle_favorite(item_id, is_favorite=True)
        return {"ok": True}


@router.delete("/{item_id}", summary="取消收藏")
async def remove_favorite(
    item_id: str,
    emby_server_url: str = Depends(get_emby_server_url),
    emby_token: str = Depends(get_emby_token),
    user_id: str = Depends(get_user_id),
) -> Dict[str, bool]:
    """将指定媒体项从当前用户的收藏列表中移除"""
    async with EmbyClient(base_url=emby_server_url, token=emby_token) as client:
        client.user_id = user_id
        await client.toggle_favorite(item_id, is_favorite=False)
        return {"ok": True}
