# 使用官方 Python 3.11 轻量级基础镜像
FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 设置 Python 环境变量
# PYTHONDONTWRITEBYTECODE=1 禁止生成 .pyc 字节码文件
# PYTHONUNBUFFERED=1 使 Python 输出直接输出到终端（便于日志查看
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# 先复制依赖清单，利用 Docker 层缓存加速构建
COPY requirements.txt .

# 安装系统依赖（curl 用于健康检查）和 Python 依赖
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir -r requirements.txt

# 复制整个 backend 项目代码到容器
COPY . .

# 暴露 8000 端口供外部访问
EXPOSE 8000

# 默认启动命令：使用 uvicorn 启动 FastAPI 应用
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
