from __future__ import annotations

from typing import List, Optional, TypeVar, Generic

from pydantic import BaseModel, Field


T = TypeVar("T")


class AuthRequest(BaseModel):
    """认证请求模型"""

    emby_url: str = Field(..., description="Emby 服务器地址")
    username: str = Field(..., description="用户名")
    password: str = Field(..., description="密码")


class AuthResponse(BaseModel):
    """认证响应模型"""

    access_token: str = Field(..., description="访问令牌")
    user_id: str = Field(..., description="用户 ID")
    username: str = Field(..., description="用户名")
    server_id: Optional[str] = Field(default=None, description="服务器 ID")


class Library(BaseModel):
    """媒体库模型"""

    id: str = Field(..., description="媒体库 ID")
    name: str = Field(..., description="媒体库名称")
    type: str = Field(..., description="媒体库类型（电影、电视节目等）")
    item_count: Optional[int] = Field(default=None, description="媒体项数量")
    cover_image_url: Optional[str] = Field(default=None, description="封面图片 URL")


class MediaItem(BaseModel):
    """媒体项模型"""

    id: str = Field(..., description="媒体项 ID")
    title: str = Field(..., description="标题")
    type: str = Field(..., description="类型（Movie/Episode/Video 等）")
    duration_seconds: Optional[float] = Field(default=None, description="时长（秒）")
    thumbnail_url: Optional[str] = Field(default=None, description="缩略图 URL")
    overview: Optional[str] = Field(default=None, description="简介")
    year: Optional[int] = Field(default=None, description="年份")
    rating: Optional[float] = Field(default=None, description="评分")
    genres: Optional[List[str]] = Field(default=None, description="类型标签")
    playback_url: Optional[str] = Field(default=None, description="播放 URL")


class PlaybackInfo(BaseModel):
    """播放信息模型"""

    item_id: str = Field(..., description="媒体项 ID")
    playback_url: str = Field(..., description="播放地址")
    format: str = Field(default="direct", description="播放格式（direct/transcode 等）")
    protocol: str = Field(default="http", description="传输协议（http/hls 等）")


class SubtitleTrack(BaseModel):
    """字幕轨道模型"""

    id: str = Field(..., description="字幕轨道 ID")
    name: str = Field(..., description="字幕名称")
    language: str = Field(..., description="语言")
    format: str = Field(..., description="格式（srt/vtt/ass 等）")
    url: Optional[str] = Field(default=None, description="字幕下载地址")


class PaginatedResponse(BaseModel, Generic[T]):
    """分页响应模型（泛型）"""

    items: List[T] = Field(..., description="当前页数据项列表")
    total: int = Field(..., description="总条数")
    offset: int = Field(..., description="起始偏移")
    limit: int = Field(..., description="每页条数")
