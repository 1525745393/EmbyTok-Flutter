import contextlib
from typing import AsyncIterator

import uvicorn
from fastapi import FastAPI, Request
from fastapi.exceptions import HTTPException, RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

from clients.emby_client import close_shared_http_client, get_shared_http_client
from core.config import CORS_ALLOWED_ORIGINS
from core.errors import APIError, INTERNAL_ERROR
from core.version import __version__
from routers import auth, favorites, items, libraries, search, subtitles


@contextlib.asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    """应用生命周期：启动时初始化共享 httpx.AsyncClient，退出时关闭连接池"""
    # 启动：初始化共享客户端（P1：复用连接池）
    get_shared_http_client()
    try:
        yield
    finally:
        # 退出：释放连接池资源
        await close_shared_http_client()


app = FastAPI(
    title="EmbyTok Backend",
    version=__version__,
    description="EmbyTok 后端 API 服务",
    lifespan=lifespan,
)

# CORS 配置（B5：从 allow_origins=["*"] 收紧为可通过环境变量配置的白名单）
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ALLOWED_ORIGINS,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
    allow_headers=["*"],
    allow_credentials=CORS_ALLOWED_ORIGINS != ["*"],
)


@app.exception_handler(APIError)
async def api_error_handler(_: Request, exc: APIError) -> JSONResponse:
    """统一处理 APIError，返回统一 JSON 错误格式"""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": True,
            "status_code": exc.status_code,
            "message": exc.message,
        },
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(_: Request, exc: HTTPException) -> JSONResponse:
    """增强 HTTPException 处理，返回统一 JSON 格式"""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": True,
            "status_code": exc.status_code,
            "message": str(exc.detail) if exc.detail else "请求错误",
        },
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
    """处理请求参数校验错误"""
    return JSONResponse(
        status_code=400,
        content={
            "error": True,
            "status_code": 400,
            "message": "请求参数不合法",
            "details": exc.errors(),
        },
    )


@app.exception_handler(Exception)
async def general_exception_handler(_: Request, exc: Exception) -> JSONResponse:
    """兜底异常处理，避免未捕获异常泄露堆栈"""
    return JSONResponse(
        status_code=INTERNAL_ERROR,
        content={
            "error": True,
            "status_code": INTERNAL_ERROR,
            "message": "服务器内部错误",
        },
    )


@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "version": __version__,
        "service": "embbytok-backend",
    }


@app.get("/")
def root():
    return {
        "message": "EmbyTok API - Use /docs for Swagger UI",
        "version": __version__,
    }


app.include_router(auth.router)
app.include_router(libraries.router)
app.include_router(items.router)
app.include_router(subtitles.router)
app.include_router(search.router)
app.include_router(favorites.router)


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000)
