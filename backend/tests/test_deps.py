"""X-Emby-Server-Url scheme 白名单校验的回归测试（SSRF 面收敛）"""

from fastapi import Depends, FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.testclient import TestClient

from core.errors import APIError
from routers.deps import get_emby_server_url

app = FastAPI()


@app.exception_handler(APIError)
async def _api_error_handler(_: Request, exc: APIError) -> JSONResponse:
    """与 main.py 一致的 APIError 统一处理（status_code 已在 errors.py 定义）"""
    return JSONResponse(status_code=exc.status_code, content={"error": str(exc)})


@app.get("/deps/url")
async def _probe(url: str = Depends(get_emby_server_url)):
    return {"url": url}


client = TestClient(app)


def test_https_url_ok():
    resp = client.get("/deps/url", headers={"X-Emby-Server-Url": "https://emby.example.com:8920"})
    assert resp.status_code == 200
    assert resp.json()["url"] == "https://emby.example.com:8920"


def test_http_url_ok():
    resp = client.get("/deps/url", headers={"X-Emby-Server-Url": "http://192.168.1.6:8096"})
    assert resp.status_code == 200


def test_scheme_missing_rejected():
    resp = client.get("/deps/url", headers={"X-Emby-Server-Url": "emby.example.com"})
    assert resp.status_code == 400


def test_non_http_scheme_rejected():
    resp = client.get("/deps/url", headers={"X-Emby-Server-Url": "ftp://emby.example.com"})
    assert resp.status_code == 400


def test_empty_netloc_rejected():
    resp = client.get("/deps/url", headers={"X-Emby-Server-Url": "https://"})
    assert resp.status_code == 400


def test_missing_header_rejected():
    resp = client.get("/deps/url")
    assert resp.status_code == 422


def test_direct_call_raises_api_error():
    try:
        get_emby_server_url("ftp://x")
    except APIError as e:
        assert "http" in str(e)
    else:
        raise AssertionError("expected APIError")
