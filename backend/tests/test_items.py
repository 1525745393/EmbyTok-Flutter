"""items 契约测试:依赖头校验 + 进度参数转换 + 错误映射(mock EmbyClient)"""

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.testclient import TestClient

from core.errors import APIError
from routers import items as items_mod
from routers.items import router

app = FastAPI()


@app.exception_handler(APIError)
async def _api_error_handler(_: Request, exc: APIError) -> JSONResponse:
    return JSONResponse(status_code=exc.status_code, content={"error": str(exc)})


app.include_router(router)  # router 自带 /api/items 前缀
client = TestClient(app)

_HEADERS = {
    "X-Emby-Server-Url": "https://emby.example.com",
    "X-Emby-Token": "tok-1",
    "X-Emby-UserId": "u1",
}


class _RecordingEmbyClient:
    """替身:记录调用并返回预设结果,验证路由层契约"""

    calls: list[tuple[str, tuple, dict]] = []

    def __init__(self, base_url: str, token: str | None = None) -> None:
        self.base_url = base_url
        self.user_id = None

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return False

    async def get_item(self, item_id: str):
        type(self).calls.append(("get_item", (item_id,), {}))
        return {"Id": item_id, "Name": "测试影片", "Type": "Movie"}

    async def get_playback_url(self, item_id: str) -> str:
        type(self).calls.append(("get_playback_url", (item_id,), {}))
        return f"{self.base_url}/Videos/{item_id}/stream"

    async def save_playback_progress(self, item_id: str, position_ticks: int, is_paused: bool):
        type(self).calls.append(
            ("save_playback_progress", (item_id,), {"position_ticks": position_ticks, "is_paused": is_paused})
        )


def test_get_item_requires_headers():
    resp = client.get("/api/items/movie1")
    assert resp.status_code == 400  # get_emby_server_url 缺头 -> APIError(400)


def test_get_item_success(monkeypatch):
    _RecordingEmbyClient.calls.clear()
    monkeypatch.setattr(items_mod, "EmbyClient", _RecordingEmbyClient)
    resp = client.get("/api/items/movie1", headers=_HEADERS)
    assert resp.status_code == 200
    body = resp.json()
    assert body["id"] == "movie1"
    assert _RecordingEmbyClient.calls[0][0] == "get_item"


def test_get_item_non_dict_404(monkeypatch):
    class Fake(_RecordingEmbyClient):
        async def get_item(self, item_id):
            return None

    monkeypatch.setattr(items_mod, "EmbyClient", Fake)
    resp = client.get("/api/items/movie1", headers=_HEADERS)
    assert resp.status_code == 404


def test_get_playback_success(monkeypatch):
    _RecordingEmbyClient.calls.clear()
    monkeypatch.setattr(items_mod, "EmbyClient", _RecordingEmbyClient)
    resp = client.get("/api/items/movie1/playback", headers=_HEADERS)
    assert resp.status_code == 200
    assert resp.json()["playback_url"].endswith("/stream")
    assert resp.json()["format"] == "direct"


def test_save_progress_negative_rejected(monkeypatch):
    """负数被 pydantic ge=0 边界拦截(422),路由层防御为第二道闸"""
    monkeypatch.setattr(items_mod, "EmbyClient", _RecordingEmbyClient)
    resp = client.post("/api/items/movie1/progress", headers=_HEADERS, json={"position_seconds": -1})
    assert resp.status_code == 422


def test_save_progress_converts_seconds_to_ticks(monkeypatch):
    _RecordingEmbyClient.calls.clear()
    monkeypatch.setattr(items_mod, "EmbyClient", _RecordingEmbyClient)
    resp = client.post("/api/items/movie1/progress", headers=_HEADERS, json={"position_seconds": 12.5})
    assert resp.status_code == 200
    assert resp.json() == {"ok": True}
    name, args, kwargs = _RecordingEmbyClient.calls[0]
    assert name == "save_playback_progress"
    assert kwargs["position_ticks"] == 125_000_000  # 12.5s * 10M
    assert kwargs["is_paused"] is False
