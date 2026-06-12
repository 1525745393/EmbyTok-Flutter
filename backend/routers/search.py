from __future__ import annotations

from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field

from clients.emby_client import EmbyClient
from core.errors import BAD_REQUEST, APIError
from core.response_utils import media_item_from_emby, paginate_from_items
from models.base_models import MediaItem, PaginatedResponse
from routers.deps import get_emby_server_url, get_emby_token, get_user_id

router = APIRouter(prefix="/api/search", tags=["搜索"])


class _SearchBody(BaseModel):
    query: str = Field(..., description="搜索关键字")
    limit: int = Field(default=20, description="每页条数")
    offset: int = Field(default=0, description="起始偏移")
    types: Optional[List[str]] = Field(default=None, description="媒体类型过滤")


@router.post("", response_model=PaginatedResponse[MediaItem], summary="搜索媒体项（POST）")
async def search_post(
    body: _SearchBody,
    emby_server_url: str = Depends(get_emby_server_url),
    emby_token: str = Depends(get_emby_token),
    user_id: str = Depends(get_user_id),
) -> PaginatedResponse[MediaItem]:
    """按关键字搜索媒体项（支持分页与类型过滤）"""
    if not body.query:
        raise APIError(BAD_REQUEST, "query 不能为空")
    async with EmbyClient(base_url=emby_server_url, token=emby_token) as client:
        client.user_id = user_id
        data = await client.search(
            query=body.query,
            limit=body.limit,
            offset=body.offset,
        )
        items = data.get("Items", []) if isinstance(data, dict) else []
        total = data.get("TotalRecordCount", len(items)) if isinstance(data, dict) else len(items)
        converted = [media_item_from_emby(item, emby_server_url) for item in items]
        return paginate_from_items(converted, total=total, limit=body.limit, offset=body.offset)


@router.get("", response_model=PaginatedResponse[MediaItem], summary="搜索媒体项（GET）")
async def search_get(
    q: str = Query(..., description="搜索关键字"),
    limit: int = Query(default=20, description="每页条数"),
    offset: int = Query(default=0, description="起始偏移"),
    emby_server_url: str = Depends(get_emby_server_url),
    emby_token: str = Depends(get_emby_token),
    user_id: str = Depends(get_user_id),
) -> PaginatedResponse[MediaItem]:
    """通过查询字符串简单搜索媒体项"""
    if not q:
        raise APIError(BAD_REQUEST, "q 参数不能为空")
    async with EmbyClient(base_url=emby_server_url, token=emby_token) as client:
        client.user_id = user_id
        data = await client.search(query=q, limit=limit, offset=offset)
        items = data.get("Items", []) if isinstance(data, dict) else []
        total = data.get("TotalRecordCount", len(items)) if isinstance(data, dict) else len(items)
        converted = [media_item_from_emby(item, emby_server_url) for item in items]
        return paginate_from_items(converted, total=total, limit=limit, offset=offset)
