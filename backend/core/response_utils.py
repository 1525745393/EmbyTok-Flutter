from __future__ import annotations

from typing import Any, Dict, List, Optional

from models.base_models import Library, MediaItem, PaginatedResponse, SubtitleTrack


def paginate_from_items(
    items: List[Any],
    total: int,
    limit: int,
    offset: int,
) -> PaginatedResponse[Any]:
    """根据数据列表与统计信息构造统一的分页响应"""
    return PaginatedResponse(
        items=list(items),
        total=int(total),
        offset=int(offset),
        limit=int(limit),
    )


def _safe(d: Any, key: str, default: Any = None) -> Any:
    if isinstance(d, dict):
        return d.get(key, default)
    return default


def _image_tag_url(
    emby_base_url: str,
    item_id: Optional[str],
    image_tag: Optional[str],
    image_type: str = "Primary",
) -> Optional[str]:
    """构造 Emby 图片地址"""
    if not item_id or not image_tag:
        return None
    base = emby_base_url.rstrip("/")
    return (
        f"{base}/Items/{item_id}/Images/{image_type}?Tag={image_tag}"
    )


def library_from_emby(raw: dict, emby_base_url: str) -> Library:
    """将 Emby 虚拟文件夹字典转换为统一的 Library 对象"""
    folder = _safe(raw, "Item") or raw
    item_id = str(_safe(folder, "Id", "") or "")
    name = str(_safe(folder, "Name", "") or "")
    collection_type = str(_safe(folder, "CollectionType", "") or "")
    refresh_state = _safe(raw, "RefreshProgress") if isinstance(raw, dict) else None

    item_count = None
    if isinstance(raw, dict):
        for key in ("ItemCount", "ItemCountInternal"):
            if raw.get(key) is not None:
                try:
                    item_count = int(raw[key])
                    break
                except (TypeError, ValueError):
                    continue

    image_tags = _safe(folder, "ImageTags") or {}
    primary_tag = _safe(image_tags, "Primary")
    cover_url = _image_tag_url(emby_base_url, item_id, primary_tag, "Primary")

    return Library(
        id=item_id,
        name=name or "未命名媒体库",
        type=collection_type or "Folder",
        item_count=item_count,
        cover_image_url=cover_url,
    )


def media_item_from_emby(raw: dict, emby_base_url: str) -> MediaItem:
    """将 Emby Item 字典转换为统一的 MediaItem 对象"""
    item_id = str(_safe(raw, "Id", "") or "")
    title = str(_safe(raw, "Name", "") or "")
    item_type = str(_safe(raw, "Type", "") or "Video")

    runtime_ticks = _safe(raw, "RunTimeTicks")
    duration_seconds: Optional[float] = None
    if runtime_ticks is not None:
        try:
            duration_seconds = float(int(runtime_ticks) / 10_000_000)
        except (TypeError, ValueError):
            duration_seconds = None

    image_tags = _safe(raw, "ImageTags") or {}
    primary_tag = _safe(image_tags, "Primary")
    thumbnail_url = _image_tag_url(emby_base_url, item_id, primary_tag, "Primary")

    overview = _safe(raw, "Overview")
    overview = str(overview) if overview is not None else None

    year = _safe(raw, "ProductionYear")
    if year is not None:
        try:
            year = int(year)
        except (TypeError, ValueError):
            year = None

    rating = _safe(raw, "CommunityRating")
    if rating is not None:
        try:
            rating = float(rating)
        except (TypeError, ValueError):
            rating = None

    genres_raw = _safe(raw, "Genres") or []
    genres: Optional[List[str]] = None
    if isinstance(genres_raw, list) and genres_raw:
        genres = [str(g) for g in genres_raw if g is not None]

    playback_url = f"{emby_base_url.rstrip('/')}/Items/{item_id}/Download"

    return MediaItem(
        id=item_id,
        title=title or "未命名",
        type=item_type,
        duration_seconds=duration_seconds,
        thumbnail_url=thumbnail_url,
        overview=overview,
        year=year,
        rating=rating,
        genres=genres,
        playback_url=playback_url,
    )


def subtitle_track_from_emby(raw: dict) -> SubtitleTrack:
    """将 Emby 字幕流字典转换为统一的 SubtitleTrack 对象"""
    index = _safe(raw, "Index")
    track_id = str(index) if index is not None else str(_safe(raw, "Id") or "0")
    name = str(_safe(raw, "DisplayTitle") or _safe(raw, "Title") or "字幕")
    language = str(_safe(raw, "Language") or "und")
    codec = str(_safe(raw, "Codec") or "srt")

    url: Optional[str] = None
    item_id = _safe(raw, "ItemId")
    if item_id is not None:
        base = ""
        if index is not None:
            url = f"{base}/Videos/{item_id}/{index}/Subtitles/0/Stream.{codec}"

    return SubtitleTrack(
        id=track_id,
        name=name,
        language=language,
        format=codec,
        url=url,
    )
