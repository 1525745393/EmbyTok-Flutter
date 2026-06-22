from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends

from clients.emby_client import EmbyClient
from core.response_utils import paginate_from_items
from models.base_models import Library, MediaItem, PaginatedResponse
from routers.deps import get_emby_server_url, get_emby_token, get_user_id

router = APIRouter(prefix="/api/libraries", tags=["媒体库"])


@router.get("", response_model=List[Library], summary="获取媒体库列表")
async def list_libraries(
    emby_server_url: str = Depends(get_emby_server_url),
    emby_token: str = Depends(get_emby_token),
    _: str = Depends(get_user_id),
) -> List[Library]:
    """返回当前用户可见的所有虚拟媒体库"""
    from core.response_utils import library_from_emby

    async with EmbyClient(base_url=emby_server_url, token=emby_token) as client:
        raw_list = await client.get_libraries()
        return [library_from_emby(item, emby_server_url) for item in raw_list]


@router.get(
    "/{library_id}/items",
    response_model=PaginatedResponse[MediaItem],
    summary="获取媒体库内的视频列表",
)
async def list_library_items(
    library_id: str,
    limit: int = 20,
    offset: int = 0,
    sort: str = "SortName",
    emby_server_url: str = Depends(get_emby_server_url),
    emby_token: str = Depends(get_emby_token),
    user_id: str = Depends(get_user_id),
) -> PaginatedResponse[MediaItem]:
    """按分页返回指定媒体库下的媒体项"""
    from core.response_utils import media_item_from_emby

    async with EmbyClient(base_url=emby_server_url, token=emby_token) as client:
        client.user_id = user_id
        data = await client.get_items(
            parent_id=library_id,
            limit=limit,
            offset=offset,
            sort=sort,
        )
        items = data.get("Items", []) if isinstance(data, dict) else []
        total = data.get("TotalRecordCount", len(items)) if isinstance(data, dict) else len(items)
        converted = [media_item_from_emby(item, emby_server_url) for item in items]
        return paginate_from_items(converted, total=total, limit=limit, offset=offset)
