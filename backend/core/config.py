"""应用全局配置常量与工具函数"""

import os

APP_VERSION: str = "1.0.0"
"""当前应用版本号"""

DEFAULT_PAGE_LIMIT: int = 20
"""默认每页返回条数"""

MAX_PAGE_LIMIT: int = 100
"""允许的最大每页条数"""

EMBY_CLIENT_NAME: str = "EmbyTok"
"""Emby 客户端名称标识"""

# 共享 httpx 客户端的连接池配置（P1：复用 TCP/TLS 连接，避免每次请求新建客户端）
EMBY_CLIENT_TIMEOUT: float = 30.0
"""Emby 客户端默认超时时间（秒）"""

EMBY_CLIENT_MAX_CONNECTIONS: int = 100
"""到 Emby 服务器的最大并发连接数"""

EMBY_CLIENT_MAX_KEEPALIVE: int = 20
"""到 Emby 服务器的 keep-alive 连接数"""

# CORS 允许的来源（B5：从全开收紧到可通过环境变量配置的白名单）
# 生产环境可通过环境变量 CORS_ALLOWED_ORIGINS 设置为逗号分隔的域名列表
# 默认空列表 → 允许所有来源（仅适用于开发环境，生产应显式配置）
def _load_cors_origins() -> list[str]:
    raw = os.environ.get("CORS_ALLOWED_ORIGINS", "")
    if not raw.strip():
        return ["*"]
    return [origin.strip() for origin in raw.split(",") if origin.strip()]


CORS_ALLOWED_ORIGINS: list[str] = _load_cors_origins()
"""CORS 允许的来源列表，默认 ['*']，生产环境应通过环境变量收紧"""


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
