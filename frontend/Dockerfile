# ===========================================================
# EmbyTok Flutter Web 生产镜像
# 注意：Flutter Web 已在 CI 工作流中构建完成
# 本 Dockerfile 仅将构建产物打包到 nginx 轻量镜像中
# ===========================================================

FROM nginx:1.27-alpine

# 复制构建产物（工作流已通过 flutter build web 构建）
COPY build/web /usr/share/nginx/html

# 复制自定义 nginx 配置（支持 SPA 路由）
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 暴露端口
EXPOSE 80

# 启动 nginx
CMD ["nginx", "-g", "daemon off;"]