# EmbyTok Backend

EmbyTok 项目的后端 API 服务，基于 FastAPI 构建。

## 项目简介

EmbyTok Backend 是一个使用 FastAPI 开发的 RESTful API 服务，提供 EmbyTok 项目所需的后端接口。FastAPI 是一个现代、高性能的 Web 框架，支持自动生成 Swagger UI 文档。

## 环境要求

- Python 3.11 或更高版本

## 安装依赖

在项目根目录下执行以下命令安装依赖：

```bash
pip install -r requirements.txt
```

## 开发环境启动

使用 `--reload` 参数启动服务，代码修改后会自动重载：

```bash
uvicorn main:app --reload --port 8000
```

启动后可在浏览器访问以下地址：

- API 服务：http://localhost:8000
- Swagger UI 文档：http://localhost:8000/docs
- ReDoc 文档：http://localhost:8000/redoc

## 生产环境启动

```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

## API 文档

访问 `/docs` 可以查看交互式 Swagger UI 文档，并在线测试 API 接口。

## 健康检查

使用 curl 测试健康检查端点：

```bash
curl http://localhost:8000/health
```

预期返回：

```json
{
    "status": "ok",
    "version": "1.0.0",
    "service": "embbytok-backend"
}
```

## OpenAPI 规范

```bash
curl http://localhost:8000/openapi.json
```

## 项目结构

```
backend/
├── __init__.py
├── main.py          # 主程序入口
├── requirements.txt # 依赖列表
└── README.md
```
