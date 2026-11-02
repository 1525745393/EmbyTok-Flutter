"""认证登录契约测试:参数校验 + 上游错误映射(不依赖真实 Emby)"""

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.testclient import TestClient

from core.errors import APIError
from routers import auth as auth_router_mod
from routers.auth import router

app = FastAPI()


@app.exception_handler(APIError)
async def _api_error_handler(_: Request, exc: APIError) -> JSONResponse:
    """与 main.py 一致的 APIError 统一处理"""
    return JSONResponse(status_code=exc.status_code, content={"error": str(exc)})


app.include_router(router)
client = TestClient(app)


class _FakeEmbyClient:
    """替身:模拟 EmbyClient 的 async with + authenticate 契约"""

    authenticate_result = {"AccessToken": "tok-abc", "User": {"Id": "u1", "Name": "alice"}, "ServerId": "srv1"}

    def __init__(self, base_url: str, token: str | None = None) -> None:
        self.base_url = base_url

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return False

    async def authenticate(self, username: str, password: str) -> dict:
        return type(self).authenticate_result


def _patch_client(monkeypatch, result):
    class Fake(_FakeEmbyClient):
        authenticate_result = result

    monkeypatch.setattr(auth_router_mod, "EmbyClient", Fake)


def test_login_success(monkeypatch):
    _patch_client(monkeypatch, {"AccessToken": "tok-abc", "User": {"Id": "u1", "Name": "alice"}, "ServerId": "srv1"})
    resp = client.post("/api/auth/login", json={
        "emby_url": "https://emby.example.com:8920",
        "username": "alice",
        "password": "pw",
    })
    assert resp.status_code == 200
    body = resp.json()
    assert body["access_token"] == "tok-abc"
    assert body["user_id"] == "u1"
    assert body["username"] == "alice"
    assert body["server_id"] == "srv1"


def test_login_empty_url_rejected():
    resp = client.post("/api/auth/login", json={"emby_url": "", "username": "a", "password": "b"})
    assert resp.status_code == 400


def test_login_ftp_scheme_rejected():
    resp = client.post("/api/auth/login", json={"emby_url": "ftp://emby.example.com", "username": "a", "password": "b"})
    assert resp.status_code == 400


def test_login_no_scheme_rejected():
    resp = client.post("/api/auth/login", json={"emby_url": "emby.example.com", "username": "a", "password": "b"})
    assert resp.status_code == 400


def test_login_invalid_credentials(monkeypatch):
    _patch_client(monkeypatch, {})  # 无 AccessToken/User -> 401
    resp = client.post("/api/auth/login", json={
        "emby_url": "https://emby.example.com",
        "username": "a",
        "password": "b",
    })
    assert resp.status_code == 401


def test_login_upstream_401_passthrough(monkeypatch):
    def _raise(self, username, password):
        raise APIError(401, "用户名或密码无效")

    monkeypatch.setattr(auth_router_mod.EmbyClient, "authenticate", _raise)
    resp = client.post("/api/auth/login", json={
        "emby_url": "https://emby.example.com",
        "username": "a",
        "password": "b",
    })
    assert resp.status_code == 401


def test_login_upstream_unreachable_maps_to_502(monkeypatch):
    def _raise(self, username, password):
        raise APIError(503, "无法连接 Emby 服务器")

    monkeypatch.setattr(auth_router_mod.EmbyClient, "authenticate", _raise)
    resp = client.post("/api/auth/login", json={
        "emby_url": "https://emby.example.com",
        "username": "a",
        "password": "b",
    })
    assert resp.status_code == 502
