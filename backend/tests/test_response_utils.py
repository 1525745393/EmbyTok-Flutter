# 响应工具函数测试
# 验证 Emby 响应到应用模型的转换逻辑

import pytest
from core.response_utils import media_item_from_emby
from models.base_models import MediaItem


class TestMediaItemFromEmby:
    """Emby 响应转换测试"""

    def test_basic_movie_conversion(self):
        """测试基础电影转换"""
        emby_data = {
            "Id": "item-123",
            "Name": "测试电影",
            "Type": "Movie",
            "Overview": "这是一部测试电影",
            "RunTimeTicks": 72000000000,  # 2小时
            "ProductionYear": 2024,
            "CommunityRating": 8.5,
            "Genres": ["动作", "科幻"],
        }

        result = media_item_from_emby(emby_data, "http://test.emby.com")

        assert result.id == "item-123"
        assert result.title == "测试电影"
        assert result.type == "Movie"
        assert result.overview == "这是一部测试电影"
        assert result.duration_seconds == 7200.0  # 2小时 = 7200秒
        assert result.year == 2024
        assert result.rating == 8.5
        assert result.genres == ["动作", "科幻"]

    def test_episode_conversion(self):
        """测试剧集转换"""
        emby_data = {
            "Id": "episode-456",
            "Name": "测试剧集 S01E02",
            "Type": "Episode",
            "SeriesName": "测试剧集",
            "SeasonName": "Season 1",
            "ParentIndexNumber": 1,  # 季号
            "IndexNumber": 2,  # 集号
            "RunTimeTicks": 18000000000,  # 30分钟
            "Overview": "这是第二集",
        }

        result = media_item_from_emby(emby_data, "http://test.emby.com")

        assert result.id == "episode-456"
        assert result.title == "测试剧集 S01E02"
        assert result.type == "Episode"
        assert result.series_name == "测试剧集"
        assert result.season_number == 1
        assert result.episode_number == 2
        assert result.duration_seconds == 1800.0

    def test_series_conversion(self):
        """测试系列转换"""
        emby_data = {
            "Id": "series-789",
            "Name": "测试系列",
            "Type": "Series",
            "Overview": "这是一个系列",
            "ProductionYear": 2023,
            "CommunityRating": 9.0,
        }

        result = media_item_from_emby(emby_data, "http://test.emby.com")

        assert result.id == "series-789"
        assert result.title == "测试系列"
        assert result.type == "Series"
        assert result.year == 2023
        assert result.rating == 9.0

    def test_with_image_tags(self):
        """测试带图片标签的转换"""
        emby_data = {
            "Id": "item-with-images",
            "Name": "带图片的媒体项",
            "Type": "Movie",
            "ImageTags": {
                "Primary": "primary-tag-123",
                "Backdrop": "backdrop-tag-456",
            },
        }

        result = media_item_from_emby(emby_data, "http://test.emby.com")

        # 验证图片 URL 构造
        assert result.primary_image_url is not None
        assert "primary-tag-123" in result.primary_image_url
        assert result.backdrop_image_url is not None
        assert "backdrop-tag-456" in result.backdrop_image_url

    def test_with_user_data(self):
        """测试带用户数据的转换"""
        emby_data = {
            "Id": "item-with-userdata",
            "Name": "带用户数据的媒体项",
            "Type": "Movie",
            "UserData": {
                "IsFavorite": True,
                "Played": False,
                "PlaybackPositionTicks": 36000000000,  # 1小时
            },
        }

        result = media_item_from_emby(emby_data, "http://test.emby.com")

        assert result.user_data is not None
        assert result.user_data.is_favorite == True
        assert result.user_data.played == False
        assert result.user_data.playback_position_ticks == 36000000000

    def test_with_people(self):
        """测试带演员信息的转换"""
        emby_data = {
            "Id": "item-with-people",
            "Name": "带演员的媒体项",
            "Type": "Movie",
            "People": [
                {"Name": "演员A", "Type": "Actor", "Role": "主角"},
                {"Name": "导演B", "Type": "Director"},
            ],
        }

        result = media_item_from_emby(emby_data, "http://test.emby.com")

        assert result.people is not None
        assert len(result.people) == 2
        assert result.people[0]["Name"] == "演员A"
        assert result.people[0]["Type"] == "Actor"
        assert result.people[1]["Name"] == "导演B"
        assert result.people[1]["Type"] == "Director"

    def test_with_media_sources(self):
        """测试带媒体源的转换"""
        emby_data = {
            "Id": "item-with-sources",
            "Name": "带媒体源的媒体项",
            "Type": "Movie",
            "MediaSources": [
                {
                    "Id": "source-1",
                    "Name": "高清源",
                    "Path": "/path/to/video.mp4",
                    "MediaStreams": [
                        {"Type": "Video", "Codec": "h264"},
                        {"Type": "Audio", "Codec": "aac", "Language": "中文"},
                        {"Type": "Subtitle", "Language": "中文"},
                    ],
                },
            ],
        }

        result = media_item_from_emby(emby_data, "http://test.emby.com")

        assert result.media_sources is not None
        assert len(result.media_sources) == 1
        assert result.media_sources[0]["Id"] == "source-1"
        assert len(result.media_sources[0]["MediaStreams"]) == 3

    def test_empty_fields(self):
        """测试空字段处理"""
        emby_data = {
            "Id": "minimal-item",
            "Name": "最小媒体项",
            "Type": "Movie",
        }

        result = media_item_from_emby(emby_data, "http://test.emby.com")

        assert result.id == "minimal-item"
        assert result.title == "最小媒体项"
        assert result.type == "Movie"
        assert result.overview is None
        assert result.year is None
        assert result.rating is None
        assert result.genres is None
        assert result.user_data is None

    def test_missing_required_fields(self):
        """测试缺少必填字段"""
        emby_data = {
            "Name": "缺少 ID 的媒体项",
            "Type": "Movie",
        }

        # 应该抛出异常或返回默认值
        with pytest.raises((KeyError, ValueError, AttributeError)):
            media_item_from_emby(emby_data, "http://test.emby.com")

    def test_invalid_run_time_ticks(self):
        """测试无效的 RunTimeTicks"""
        emby_data = {
            "Id": "invalid-duration",
            "Name": "无效时长",
            "Type": "Movie",
            "RunTimeTicks": -1000,  # 负数
        }

        result = media_item_from_emby(emby_data, "http://test.emby.com")

        # 应该处理负数情况
        assert result.duration_seconds is not None

    def test_special_characters_in_name(self):
        """测试名称中的特殊字符"""
        emby_data = {
            "Id": "special-chars",
            "Name": "测试<特殊>字符&符号",
            "Type": "Movie",
            "Overview": "包含<script>标签的描述",
        }

        result = media_item_from_emby(emby_data, "http://test.emby.com")

        # 应该正确处理特殊字符，不进行 HTML 解码
        assert result.title == "测试<特殊>字符&符号"
        assert result.overview == "包含<script>标签的描述"

    def test_unicode_characters(self):
        """测试 Unicode 字符"""
        emby_data = {
            "Id": "unicode-item",
            "Name": "测试中文标题 🎬",
            "Type": "Movie",
            "Overview": "包含 emoji 的描述 🎥",
        }

        result = media_item_from_emby(emby_data, "http://test.emby.com")

        assert result.title == "测试中文标题 🎬"
        assert result.overview == "包含 emoji 的描述 🎥"

    def test_large_rating_value(self):
        """测试大评分值"""
        emby_data = {
            "Id": "large-rating",
            "Name": "大评分",
            "Type": "Movie",
            "CommunityRating": 10.0,  # 最大评分
        }

        result = media_item_from_emby(emby_data, "http://test.emby.com")

        assert result.rating == 10.0

    def test_zero_rating_value(self):
        """测试零评分值"""
        emby_data = {
            "Id": "zero-rating",
            "Name": "零评分",
            "Type": "Movie",
            "CommunityRating": 0.0,
        }

        result = media_item_from_emby(emby_data, "http://test.emby.com")

        assert result.rating == 0.0

    def test_null_rating_value(self):
        """测试空评分值"""
        emby_data = {
            "Id": "null-rating",
            "Name": "空评分",
            "Type": "Movie",
            "CommunityRating": None,
        }

        result = media_item_from_emby(emby_data, "http://test.emby.com")

        assert result.rating is None

    def test_multiple_genres(self):
        """测试多个类型"""
        emby_data = {
            "Id": "multi-genres",
            "Name": "多类型",
            "Type": "Movie",
            "Genres": ["动作", "科幻", "冒险", "剧情"],
        }

        result = media_item_from_emby(emby_data, "http://test.emby.com")

        assert result.genres == ["动作", "科幻", "冒险", "剧情"]

    def test_empty_genres_list(self):
        """测试空类型列表"""
        emby_data = {
            "Id": "empty-genres",
            "Name": "空类型",
            "Type": "Movie",
            "Genres": [],
        }

        result = media_item_from_emby(emby_data, "http://test.emby.com")

        assert result.genres == []

    def test_image_url_with_server_url(self):
        """测试图片 URL 构造（带服务器地址）"""
        emby_data = {
            "Id": "image-url-test",
            "Name": "图片 URL 测试",
            "Type": "Movie",
            "ImageTags": {
                "Primary": "tag-123",
            },
        }

        server_url = "http://emby.example.com:8096"
        result = media_item_from_emby(emby_data, server_url)

        assert result.primary_image_url is not None
        assert server_url in result.primary_image_url
        assert "tag-123" in result.primary_image_url

    def test_image_url_without_server_url(self):
        """测试图片 URL 构造（无服务器地址）"""
        emby_data = {
            "Id": "no-server-url",
            "Name": "无服务器地址",
            "Type": "Movie",
            "ImageTags": {
                "Primary": "tag-456",
            },
        }

        result = media_item_from_emby(emby_data, "")

        # 应该处理空服务器地址情况
        assert result.primary_image_url is not None

    def test_nested_user_data_fields(self):
        """测试嵌套用户数据字段"""
        emby_data = {
            "Id": "nested-userdata",
            "Name": "嵌套用户数据",
            "Type": "Movie",
            "UserData": {
                "IsFavorite": True,
                "Played": True,
                "PlaybackPositionTicks": 36000000000,
                "LastPlayedDate": "2024-01-01T00:00:00Z",
                "Key": "item-key-123",
            },
        }

        result = media_item_from_emby(emby_data, "http://test.emby.com")

        assert result.user_data is not None
        assert result.user_data.is_favorite == True
        assert result.user_data.played == True
        assert result.user_data.playback_position_ticks == 36000000000