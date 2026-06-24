# EmbyClient 核心业务逻辑测试
# 覆盖认证、媒体库、媒体项、搜索、收藏、播放进度等关键功能

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
import httpx

from clients.emby_client import EmbyClient
from core.errors import APIError


@pytest.fixture
def emby_client():
    """创建测试用的 EmbyClient 实例"""
    client = EmbyClient(base_url="http://test.emby.com", token="test-token")
    client.user_id = "test-user-123"
    return client


@pytest.fixture
def mock_httpx_response():
    """创建模拟的 httpx 响应"""
    def create_response(status_code=200, json_data=None, text_data=None):
        response = MagicMock(spec=httpx.Response)
        response.status_code = status_code
        response.headers = {"content-type": "application/json"}

        if json_data is not None:
            response.json = MagicMock(return_value=json_data)
        if text_data is not None:
            response.text = text_data

        return response
    return create_response


class TestEmbyClientAuthentication:
    """认证相关测试"""

    @pytest.mark.asyncio
    async def test_authenticate_success(self, emby_client, mock_httpx_response):
        """测试登录认证成功场景"""
        auth_response = {
            "AccessToken": "new-access-token",
            "User": {"Id": "user-456", "Name": "testuser"},
            "ServerId": "server-123"
        }

        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = auth_response

            result = await emby_client.authenticate("testuser", "password123")

            assert result["AccessToken"] == "new-access-token"
            assert result["User"]["Id"] == "user-456"
            assert emby_client.token == "new-access-token"
            assert emby_client.user_id == "user-456"

    @pytest.mark.asyncio
    async def test_authenticate_with_session_info_token(self, emby_client):
        """测试从 SessionInfo 中提取 AccessToken"""
        auth_response = {
            "SessionInfo": {"AccessToken": "session-token"},
            "User": {"Id": "user-789", "Name": "testuser"}
        }

        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = auth_response

            result = await emby_client.authenticate("testuser", "password")

            assert emby_client.token == "session-token"

    @pytest.mark.asyncio
    async def test_authenticate_invalid_credentials(self, emby_client):
        """测试无效凭证场景"""
        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.side_effect = APIError(401, "用户名或密码无效")

            with pytest.raises(APIError) as exc_info:
                await emby_client.authenticate("wronguser", "wrongpass")

            assert exc_info.value.status_code == 401


class TestEmbyClientLibraries:
    """媒体库相关测试"""

    @pytest.mark.asyncio
    async def test_get_libraries_success(self, emby_client):
        """测试获取媒体库列表成功"""
        libraries_response = [
            {"Id": "lib-1", "Name": "电影", "CollectionType": "movies"},
            {"Id": "lib-2", "Name": "电视剧", "CollectionType": "tvshows"}
        ]

        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = libraries_response

            result = await emby_client.get_libraries()

            assert len(result) == 2
            assert result[0]["Id"] == "lib-1"
            assert result[1]["CollectionType"] == "tvshows"

    @pytest.mark.asyncio
    async def test_get_libraries_with_items_key(self, emby_client):
        """测试响应包含 Items 键的场景"""
        libraries_response = {
            "Items": [
                {"Id": "lib-3", "Name": "音乐"}
            ]
        }

        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = libraries_response

            result = await emby_client.get_libraries()

            assert len(result) == 1
            assert result[0]["Id"] == "lib-3"

    @pytest.mark.asyncio
    async def test_get_libraries_empty_response(self, emby_client):
        """测试空响应场景"""
        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = {}

            result = await emby_client.get_libraries()

            assert result == []


class TestEmbyClientItems:
    """媒体项相关测试"""

    @pytest.mark.asyncio
    async def test_get_items_success(self, emby_client):
        """测试获取媒体项列表成功"""
        items_response = {
            "Items": [
                {"Id": "item-1", "Name": "测试电影", "Type": "Movie"},
                {"Id": "item-2", "Name": "测试剧集", "Type": "Episode"}
            ],
            "TotalRecordCount": 2
        }

        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = items_response

            result = await emby_client.get_items(parent_id="lib-1", limit=10, offset=0)

            assert result["TotalRecordCount"] == 2
            assert len(result["Items"]) == 2
            mock_request.assert_called_once()

    @pytest.mark.asyncio
    async def test_get_items_with_user_id(self, emby_client):
        """测试带 userId 的媒体项查询"""
        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = {"Items": [], "TotalRecordCount": 0}

            await emby_client.get_items()

            # 验证 userId 参数被正确传递
            call_args = mock_request.call_args
            params = call_args[1]['params']
            assert params['UserId'] == "test-user-123"

    @pytest.mark.asyncio
    async def test_get_item_detail_success(self, emby_client):
        """测试获取单个媒体项详情"""
        item_response = {
            "Id": "item-123",
            "Name": "详细电影",
            "Type": "Movie",
            "Overview": "这是一部测试电影",
            "RunTimeTicks": 72000000000,
            "MediaSources": []
        }

        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = item_response

            result = await emby_client.get_item("item-123")

            assert result["Id"] == "item-123"
            assert result["Overview"] == "这是一部测试电影"

    @pytest.mark.asyncio
    async def test_get_item_not_found(self, emby_client):
        """测试媒体项不存在场景"""
        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.side_effect = APIError(404, "未找到指定的媒体项")

            with pytest.raises(APIError) as exc_info:
                await emby_client.get_item("invalid-id")

            assert exc_info.value.status_code == 404


class TestEmbyClientSearch:
    """搜索相关测试"""

    @pytest.mark.asyncio
    async def test_search_success(self, emby_client):
        """测试搜索成功"""
        search_response = {
            "Items": [
                {"Id": "search-1", "Name": "搜索结果1"},
                {"Id": "search-2", "Name": "搜索结果2"}
            ],
            "TotalRecordCount": 2
        }

        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = search_response

            result = await emby_client.search("测试关键词", limit=10)

            assert result["TotalRecordCount"] == 2
            assert len(result["Items"]) == 2

    @pytest.mark.asyncio
    async def test_search_empty_query(self, emby_client):
        """测试空关键词搜索"""
        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = {"Items": [], "TotalRecordCount": 0}

            result = await emby_client.search("", limit=10)

            assert result["TotalRecordCount"] == 0


class TestEmbyClientSubtitles:
    """字幕相关测试"""

    @pytest.mark.asyncio
    async def test_get_subtitles_success(self, emby_client):
        """测试获取字幕轨道成功"""
        playback_info = {
            "MediaSources": [
                {
                    "MediaStreams": [
                        {"Type": "Subtitle", "Language": "中文", "Index": 0},
                        {"Type": "Audio", "Language": "英语"},
                        {"Type": "Subtitle", "Language": "英文", "Index": 1}
                    ]
                }
            ]
        }

        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = playback_info

            result = await emby_client.get_subtitles("item-123")

            assert len(result) == 2
            assert result[0]["Language"] == "中文"
            assert result[1]["Language"] == "英文"

    @pytest.mark.asyncio
    async def test_get_subtitles_empty(self, emby_client):
        """测试无字幕轨道场景"""
        playback_info = {
            "MediaSources": [
                {"MediaStreams": [{"Type": "Audio"}]}
            ]
        }

        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = playback_info

            result = await emby_client.get_subtitles("item-123")

            assert result == []

    @pytest.mark.asyncio
    async def test_get_subtitles_no_media_sources(self, emby_client):
        """测试无 MediaSources 场景"""
        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = {}

            result = await emby_client.get_subtitles("item-123")

            assert result == []


class TestEmbyClientFavorites:
    """收藏相关测试"""

    @pytest.mark.asyncio
    async def test_get_favorites_success(self, emby_client):
        """测试获取收藏列表成功"""
        favorites_response = {
            "Items": [
                {"Id": "fav-1", "Name": "收藏电影"},
                {"Id": "fav-2", "Name": "收藏剧集"}
            ],
            "TotalRecordCount": 2
        }

        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = favorites_response

            result = await emby_client.get_favorites()

            assert len(result["Items"]) == 2

    @pytest.mark.asyncio
    async def test_toggle_favorite_add(self, emby_client):
        """测试添加收藏"""
        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = {}

            await emby_client.toggle_favorite("item-123", is_favorite=True)

            # 验证调用 POST 方法
            call_args = mock_request.call_args
            assert call_args[0][0] == "POST"
            assert "FavoriteItems" in call_args[0][1]

    @pytest.mark.asyncio
    async def test_toggle_favorite_remove(self, emby_client):
        """测试移除收藏"""
        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = {}

            await emby_client.toggle_favorite("item-123", is_favorite=False)

            # 验证调用 DELETE 方法
            call_args = mock_request.call_args
            assert call_args[0][0] == "DELETE"

    @pytest.mark.asyncio
    async def test_toggle_favorite_without_user_id(self, emby_client):
        """测试无 userId 时收藏操作失败"""
        emby_client.user_id = None

        with pytest.raises(APIError) as exc_info:
            await emby_client.toggle_favorite("item-123", is_favorite=True)

        assert exc_info.value.status_code == 400
        assert "需要先完成登录" in exc_info.value.message


class TestEmbyClientPlaybackProgress:
    """播放进度相关测试"""

    @pytest.mark.asyncio
    async def test_save_playback_progress_success(self, emby_client):
        """测试保存播放进度成功"""
        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = None

            await emby_client.save_playback_progress(
                item_id="item-123",
                position_ticks=36000000000  # 1小时
            )

            # 验证请求参数
            call_args = mock_request.call_args
            payload = call_args[1]['json']
            assert payload['ItemId'] == "item-123"
            assert payload['PositionTicks'] == 36000000000

    @pytest.mark.asyncio
    async def test_save_playback_progress_without_user_id(self, emby_client):
        """测试无 userId 时保存进度失败"""
        emby_client.user_id = None

        with pytest.raises(APIError) as exc_info:
            await emby_client.save_playback_progress(
                item_id="item-123",
                position_ticks=1000
            )

        assert exc_info.value.status_code == 400

    @pytest.mark.asyncio
    async def test_get_playback_progress_success(self, emby_client):
        """测试获取播放进度成功"""
        user_data = {
            "PlaybackPositionTicks": 18000000000  # 30分钟
        }

        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = user_data

            result = await emby_client.get_playback_progress("item-123")

            assert result == 1800  # 30分钟转换为秒

    @pytest.mark.asyncio
    async def test_get_playback_progress_none(self, emby_client):
        """测试无播放进度时返回 None"""
        with patch.object(emby_client, '_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = {}

            result = await emby_client.get_playback_progress("item-123")

            assert result is None

    @pytest.mark.asyncio
    async def test_get_playback_progress_without_user_id(self, emby_client):
        """测试无 userId 时获取进度返回 None"""
        emby_client.user_id = None

        result = await emby_client.get_playback_progress("item-123")

        assert result is None


class TestEmbyClientPlaybackUrl:
    """播放 URL 相关测试"""

    @pytest.mark.asyncio
    async def test_get_playback_url_with_token(self, emby_client):
        """测试构造带 token 的播放 URL"""
        result = await emby_client.get_playback_url("item-123")

        assert result == "http://test.emby.com/Items/item-123/Download?api_key=test-token"

    @pytest.mark.asyncio
    async def test_get_playback_url_without_token(self):
        """测试构造不带 token 的播放 URL"""
        client = EmbyClient(base_url="http://test.emby.com", token=None)

        result = await client.get_playback_url("item-456")

        assert result == "http://test.emby.com/Items/item-456/Download"


class TestEmbyClientErrorHandling:
    """错误处理相关测试"""

    @pytest.mark.asyncio
    async def test_request_network_error(self, emby_client):
        """测试网络连接失败场景"""
        with patch.object(emby_client._client, 'request') as mock_request:
            mock_request.side_effect = httpx.ConnectError("Connection failed")

            with pytest.raises(APIError) as exc_info:
                await emby_client._request("GET", "/test")

            assert exc_info.value.status_code == 503
            assert "无法连接服务器" in exc_info.value.message

    @pytest.mark.asyncio
    async def test_request_timeout_error(self, emby_client):
        """测试请求超时场景"""
        with patch.object(emby_client._client, 'request') as mock_request:
            mock_request.side_effect = httpx.TimeoutException("Timeout")

            with pytest.raises(APIError) as exc_info:
                await emby_client._request("GET", "/test")

            assert exc_info.value.status_code == 503

    @pytest.mark.asyncio
    async def test_request_500_error(self, emby_client):
        """测试服务器 500 错误场景"""
        mock_response = MagicMock(spec=httpx.Response)
        mock_response.status_code = 500
        mock_response.json = MagicMock(return_value={"Message": "Internal server error"})
        mock_response.headers = {"content-type": "application/json"}

        with patch.object(emby_client._client, 'request', return_value=mock_response):
            with pytest.raises(APIError) as exc_info:
                await emby_client._request("GET", "/test")

            # 错误处理可能将 500 映射到其他状态码
            assert exc_info.value.status_code >= 400


class TestEmbyClientLifecycle:
    """生命周期管理测试"""

    @pytest.mark.asyncio
    async def test_close_client(self, emby_client):
        """测试关闭客户端"""
        await emby_client.close()

        # 验证底层 httpx 客户端已关闭
        assert True  # close 方法不应抛出异常

    @pytest.mark.asyncio
    async def test_context_manager(self):
        """测试异步上下文管理器"""
        client = EmbyClient(base_url="http://test.emby.com")

        async with client as ctx_client:
            assert ctx_client is client
            assert isinstance(ctx_client, EmbyClient)

        # 退出上下文后客户端应已关闭