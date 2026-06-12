"""应用全局配置常量与工具函数"""

APP_VERSION: str = "1.0.0"
"""当前应用版本号"""

DEFAULT_PAGE_LIMIT: int = 20
"""默认每页返回条数"""

MAX_PAGE_LIMIT: int = 100
"""允许的最大每页条数"""

EMBY_CLIENT_NAME: str = "EmbyTok"
"""Emby 客户端名称标识"""


def get_emby_client_header(user_id: str = "web") -> dict:
    """构造 Emby 服务器要求的 Authorization 请求头。

    Emby 使用类似 MediaBrowser 协议的 Authorization header 格式，
    用于识别客户端、设备及用户信息。

    Args:
        user_id: 本地用户标识，默认 "web"。

    Returns:
        包含 "Authorization" 键的字典，可直接传入 requests/httpx headers。
    """
    auth_value = (
        f'MediaBrowser Client="{EMBY_CLIENT_NAME}", '
        f'Device="web", '
        f'DeviceId="{user_id}", '
        f'Version="{APP_VERSION}"'
    )
    return {"Authorization": auth_value}
