# ===========================================================
# EmbyTok Flutter Web 多阶段构建镜像
# ===========================================================

# Stage 1: 构建 Flutter Web 应用
FROM cirrusci/flutter:3.24.0 AS builder

WORKDIR /app

# 只复制依赖文件以利用 Docker 层缓存
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# 复制源代码并构建
COPY . .
RUN flutter build web --release --source-maps

# Stage 2: Nginx 生产镜像
FROM nginx:1.27-alpine AS production

# 从 builder 阶段复制构建产物
COPY --from=builder /app/build/web /usr/share/nginx/html

# 复制自定义 nginx 配置
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 暴露 80 端口
EXPOSE 80

# 启动 nginx
CMD ["nginx", "-g", "daemon off;"]