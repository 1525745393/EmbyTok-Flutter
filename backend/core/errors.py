"""统一的 API 异常定义与错误映射"""


# 常见错误常量定义
INVALID_CREDENTIALS: int = 401
"""无效的用户名或密码"""

SERVER_UNREACHABLE: int = 503
"""无法连接到 Emby 服务器"""

ITEM_NOT_FOUND: int = 404
"""请求的媒体项不存在"""

BAD_REQUEST: int = 400
"""请求参数不合法"""

FORBIDDEN: int = 403
"""权限不足"""

INTERNAL_ERROR: int = 500
"""服务器内部错误"""


class APIError(Exception):
    """统一 API 异常，携带 HTTP 状态码与可读消息"""

    def __init__(self, status_code: int, message: str) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.message = message

    def __str__(self) -> str:
        return f"[{self.status_code}] {self.message}"


def handle_emby_error(status_code: int, message: str = "") -> APIError:
    """根据 Emby 响应状态码映射为统一的 APIError。

    Args:
        status_code: HTTP 响应状态码。
        message: 原始错误消息，可为空。

    Returns:
        对应的 APIError 实例。
    """
    if status_code == 401:
        return APIError(INVALID_CREDENTIALS, message or "用户名或密码无效")
    if status_code == 403:
        return APIError(FORBIDDEN, message or "没有访问权限")
    if status_code == 404:
        return APIError(ITEM_NOT_FOUND, message or "请求的资源不存在")
    if status_code == 400:
        return APIError(BAD_REQUEST, message or "请求参数不合法")
    if 500 <= status_code < 600:
        return APIError(
            SERVER_UNREACHABLE,
            message or f"服务器返回错误：{status_code}",
        )
    return APIError(status_code or INTERNAL_ERROR, message or "未知错误")
