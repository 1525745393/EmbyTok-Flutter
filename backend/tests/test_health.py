# 基本导入测试
# 验证 FastAPI 应用可正常导入

import os
import sys


def test_backend_module_importable():
    """后端主模块可正常导入，无语法错误或循环依赖"""
    backend_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if backend_root not in sys.path:
        sys.path.insert(0, backend_root)

    # 尝试导入 main，确认没有语法或依赖问题
    import main  # noqa: F401
    assert hasattr(main, "app")


def test_routes_registered():
    """确认应用中注册了核心路由"""
    backend_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if backend_root not in sys.path:
        sys.path.insert(0, backend_root)

    import main

    route_paths = [route.path for route in main.app.routes]
    # 至少包含健康检查或登录等基础路由
    assert any(
        path in route_paths for path in ["/health", "/api/auth/login", "/docs", "/openapi.json"]
    ), f"期望的基础路由未注册，实际路由: {route_paths[:10]}"
