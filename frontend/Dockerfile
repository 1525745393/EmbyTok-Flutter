# ===========================================================
# EmbyTok Flutter Web 生产镜像
# 注：Flutter Web 构建在 CI 中完成（build/web 目录）
# 本 Dockerfile 仅打包已构建的静态资源
# ===========================================================

FROM nginx:1.27-alpine

# 从构建上下文复制 Flutter Web 静态资源
# 构建上下文需要在 CI 中先执行 flutter build web
COPY build/web /usr/share/nginx/html

# 复制自定义 nginx 配置
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 暴露 80 端口
EXPOSE 80

# 启动 nginx
CMD ["nginx", "-g", "daemon off;"]
