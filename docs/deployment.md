# EmbyTok - 部署指南

> 本文件目标：为运维人员提供从本地开发环境到生产部署的完整步骤，包括 Docker Compose 一键部署、本地裸机部署、反向代理配置以及常见问题排查。

---

## 一、部署方案对比

| 方案 | 适用场景 | 优点 | 缺点 |
|------|---------|------|------|
| **Docker Compose** | 推荐用于家庭 NAS / 小团队部署 | 一键启动、依赖隔离、升级简单 | 需要 Docker 环境 |
| **本地裸机** | 开发调试、快速验证 | 调试方便，无需 Docker 知识 | 依赖手动管理，升级复杂 |
| **Docker + 反向代理** | 生产环境、公网暴露 | 安全、可扩展、HTTPS 容易 | 配置步骤较多 |

---

## 二、Docker Compose 一键部署（推荐）

### 2.1 准备工作

| 依赖 | 最低版本 | 验证命令 |
|------|---------|---------|
| Docker Engine | 20.10+ | `docker --version` |
| Docker Compose | 2.0+ | `docker compose version` |

在 Debian / Ubuntu 上安装 Docker：

```bash
# 安装 Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 把当前用户加入 docker 组（避免每次 sudo）
sudo usermod -aG docker $USER

# 重新登录后验证
docker --version
docker compose version
```

### 2.2 准备 docker-compose.yml

项目根目录已提供 `docker-compose.yml`，以下为典型配置（可按需调整）：

```yaml
services:
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: embbytok-backend
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      # （可选）调整服务端口等配置，无配置时使用默认值
      - TZ=Asia/Shanghai
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    # 如需挂载外部配置（目前后端无持久化数据，可跳过）
    # volumes:
    #   - ./backend/data:/app/data
    networks:
      - embbytok-net

  # 如果需要同时部署一个 Web 前端（可选）
  # frontend-web:
  #   build:
  #     context: ./frontend
  #     dockerfile: Dockerfile
  #   container_name: embbytok-frontend-web
  #   restart: unless-stopped
  #   ports:
  #     - "8080:80"
  #   networks:
  #     - embbytok-net

networks:
  embbytok-net:
    driver: bridge
```

### 2.3 启动服务

```bash
cd EmbyTok-Flutter

# 构建并启动（首次需拉取 Python 基础镜像，较慢）
docker compose up -d

# 查看运行状态
docker compose ps

# 查看日志
docker compose logs -f backend
```

启动成功后，`docker compose ps` 应显示：

```
NAME                IMAGE              STATUS          PORTS
embbytok-backend    ...                Up (healthy)    0.0.0.0:8000->8000/tcp
```

### 2.4 验证服务健康

```bash
# 直接调用健康检查端点
curl http://localhost:8000/health

# 预期返回
# {"status":"ok","version":"1.0.0","service":"embbytok-backend"}
```

### 2.5 停止/重启/升级

```bash
# 停止服务（保留容器）
docker compose stop

# 重启服务
docker compose restart

# 升级到最新代码
docker compose down
git pull
docker compose up -d --build

# 彻底清理（包含数据）
docker compose down -v
```

---

## 三、本地裸机部署

### 3.1 安装 Python 环境

```bash
# 需要 Python 3.10+
python3 --version

# 推荐使用 venv 隔离依赖
cd backend
python3 -m venv .venv
source .venv/bin/activate           # Windows: .venv\Scripts\activate

# 安装依赖
pip install --upgrade pip
pip install -r requirements.txt
```

### 3.2 启动服务

**方式 A（直接启动，前台运行）**：

```bash
cd backend
source .venv/bin/activate
uvicorn main:app --host 0.0.0.0 --port 8000
```

**方式 B（生产推荐，使用 systemd）**：

创建 `/etc/systemd/system/embbytok-backend.service`：

```ini
[Unit]
Description=EmbyTok FastAPI Backend
After=network.target emby-server.service
Requires=network.target

[Service]
Type=simple
User=your-user
WorkingDirectory=/path/to/EmbyTok-Flutter/backend
ExecStart=/path/to/EmbyTok-Flutter/backend/.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5
Environment=TZ=Asia/Shanghai

# 资源限制（可选）
MemoryLimit=512M
CPUShares=1024

[Install]
WantedBy=multi-user.target
```

启动并设置开机自启：

```bash
sudo systemctl daemon-reload
sudo systemctl enable embbytok-backend
sudo systemctl start embbytok-backend

# 查看状态
sudo systemctl status embbytok-backend

# 查看日志
sudo journalctl -u embbytok-backend -f
```

### 3.3 验证

```bash
curl http://localhost:8000/health
# 预期: {"status":"ok","version":"1.0.0","service":"embbytok-backend"}
```

---

## 四、生产环境：Docker + Nginx 反向代理 + HTTPS

### 4.1 完整 docker-compose.yml

```yaml
services:
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: embbytok-backend
    restart: unless-stopped
    expose:
      - "8000"            # 仅暴露给内部网络，不对外直接暴露
    environment:
      - TZ=Asia/Shanghai
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    networks:
      - embbytok-net

  nginx:
    image: nginx:1.27-alpine
    container_name: embbytok-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./nginx/logs:/var/log/nginx
    depends_on:
      - backend
    networks:
      - embbytok-net

networks:
  embbytok-net:
    driver: bridge
```

### 4.2 Nginx 配置

创建 `nginx/conf.d/embbytok.conf`：

```nginx
server {
    listen 80;
    server_name your-domain.com;

    # 把 HTTP 请求重定向到 HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    # SSL 证书（使用 Let's Encrypt / certbot 签发）
    ssl_certificate     /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;

    # SSL 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # 日志
    access_log /var/log/nginx/embbytok-access.log;
    error_log  /var/log/nginx/embbytok-error.log;

    # 客户端请求体大小限制（上传文件时调整）
    client_max_body_size 10M;

    # 后端代理
    location / {
        proxy_pass http://backend:8000;
        proxy_http_version 1.1;

        # 转发客户端真实 IP
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 超时设置
        proxy_connect_timeout 30s;
        proxy_send_timeout    60s;
        proxy_read_timeout    60s;

        # WebSocket 支持（若未来需要）
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Gzip 压缩
    gzip on;
    gzip_types text/plain text/css application/json application/javascript;
    gzip_min_length 1024;
    gzip_comp_level 5;
}
```

### 4.3 申请 SSL 证书（Let's Encrypt）

```bash
# 使用 certbot 申请（需先把域名解析到服务器）
sudo apt install certbot
sudo certbot certonly --standalone -d your-domain.com

# 证书位置
# /etc/letsencrypt/live/your-domain.com/fullchain.pem
# /etc/letsencrypt/live/your-domain.com/privkey.pem

# 复制到 nginx ssl 目录
mkdir -p nginx/ssl
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem nginx/ssl/
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem nginx/ssl/
```

### 4.4 启动完整服务

```bash
docker compose up -d

# 验证所有容器正常运行
docker compose ps

# 测试 HTTPS
curl -I https://your-domain.com/health
```

### 4.5 证书自动续期

Let's Encrypt 证书有效期 90 天，建议配置自动续期：

```bash
# 创建 cron 任务（每天凌晨 3 点检查）
sudo crontab -e

# 添加以下内容：
# 0 3 * * * certbot renew --quiet --post-hook "docker exec embbytok-nginx nginx -s reload"
```

---

## 五、在外部网络访问 EmbyTok

### 5.1 方案 A：Tailscale（推荐，零配置）

```bash
# 在部署后端的机器上安装 Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 登录（用浏览器打开返回的链接）
sudo tailscale up

# 查看这台机器的 Tailscale IP
tailscale ip -4
# 例如: 100.123.45.67
```

然后在手机上也安装 Tailscale，登录同一账号。在 EmbyTok 应用中填写：

```
后端代理地址: http://100.123.45.67:8000
Emby 服务器地址: http://100.123.45.67:8010   # （或 Emby 服务器的 Tailscale IP）
```

**优点**：全程加密、无需公网 IP、无需开放端口

**缺点**：手机端需保持 Tailscale 后台运行

### 5.2 方案 B：frp / ngrok（内网穿透）

```bash
# 1. 你需要一台公网服务器（例如阿里云、腾讯云轻量应用服务器）
# 2. 在公网服务器上运行 frps：
wget https://github.com/fatedier/frp/releases/download/v0.58.0/frp_0.58.0_linux_amd64.tar.gz
tar -xzf frp_0.58.0_linux_amd64.tar.gz
cd frp_0.58.0_linux_amd64
./frps -c frps.toml   # 默认监听 7000 端口

# 3. 在部署后端的机器上运行 frpc：
# frpc.toml:
# serverAddr = "你的公网服务器IP"
# serverPort = 7000
# [[proxies]]
# name = "embbytok-backend"
# type = "tcp"
# localIP = "127.0.0.1"
# localPort = 8000
# remotePort = 18000
./frpc -c frpc.toml
```

在 EmbyTok 应用中填写：

```
后端代理地址: http://你的公网服务器IP:18000
Emby 服务器地址: http://你的公网服务器IP:18010   # （需同样转发 Emby 的端口）
```

### 5.3 方案 C：路由器端口转发（适合有公网 IP 的家庭用户）

```
路由器管理面板 → 端口转发 / UPnP
  外部端口 8000 → 内部机器IP:8000
  外部端口 8010 → 内部机器IP:8010
```

**安全警告**：直接暴露端口到公网时务必使用 HTTPS + 强密码认证，避免中间人攻击。

---

## 六、环境变量参考

后端 FastAPI 当前为无状态，无需复杂配置。若有需要，可通过以下方式调整：

| 配置项 | 默认值 | 说明 | 配置方式 |
|--------|--------|------|---------|
| **服务端口** | 8000 | HTTP 监听端口 | uvicorn `--port` 参数 |
| **监听地址** | 0.0.0.0 | 外部可访问 | uvicorn `--host` 参数 |
| **工作进程数** | 1 | Uvicorn worker 数 | `--workers` 参数 |
| **超时** | 30s | 请求超时 | uvicorn `--timeout-keep-alive` 参数 |

多 worker 启动（适合生产环境，多核机器推荐）：

```bash
# 使用 4 个 worker（与 CPU 核数相当）
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4

# 或使用 gunicorn + uvicorn worker（更好的进程管理）
pip install gunicorn
gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker -b 0.0.0.0:8000
```

---

## 七、常见运维命令速查

| 任务 | 命令 |
|------|------|
| **查看容器状态** | `docker compose ps` |
| **查看后端日志** | `docker compose logs -f --tail=100 backend` |
| **重启后端** | `docker compose restart backend` |
| **重新构建并启动** | `docker compose up -d --build backend` |
| **查看健康检查** | `curl http://localhost:8000/health` |
| **进入容器调试** | `docker exec -it embbytok-backend bash` |
| **清理未使用的镜像** | `docker image prune -a` |
| **磁盘占用统计** | `docker system df` |
| **systemd 查看状态** | `sudo systemctl status embbytok-backend` |
| **systemd 查看日志** | `sudo journalctl -u embbytok-backend -f -n 100` |

---

## 八、性能与资源监控

### 8.1 容器资源使用

```bash
# 实时查看所有容器的 CPU / 内存 / 磁盘 IO
docker stats

# 输出示例：
# CONTAINER   CPU %    MEM USAGE / LIMIT   MEM %    NET I/O         BLOCK I/O
# embbytok...  0.12%   85.2MiB / 1.94GiB   4.29%    45.6kB / 123kB  0B / 0B
```

### 8.2 后端资源预期

| 场景 | 预计 CPU | 预计内存 | 磁盘占用 |
|------|---------|---------|---------|
| 单用户本地 | < 5% | < 100MB | ~100MB |
| 5-10 并发用户 | ~10% | ~200MB | ~100MB |
| 50+ 并发用户 | 需缓存层（Redis） | 500MB+ | ~200MB |

后端的压力主要来源：
1. **Emby 服务器的压力**（视频转码、元数据查询）→ 在 Emby 端优化
2. **网络带宽**（手机端播放视频时，流量经过后端→Emby）→ 确保服务器带宽足够

---

## 九、备份与恢复

### 9.1 需要备份的内容

| 内容 | 路径 | 频率 |
|------|------|------|
| **项目配置** | `docker-compose.yml`、`nginx/` | 每次修改后 |
| **SSL 证书** | `nginx/ssl/` 或 `/etc/letsencrypt/` | 每月 |
| **系统日志** | `nginx/logs/`、容器日志 | 按需 |

**注意**：EmbyTok 后端本身无持久化数据，所有用户数据、观看历史、收藏等均存储在 Emby 服务器上。备份 Emby 服务器即可。

### 9.2 示例备份脚本

```bash
#!/bin/bash
# backup.sh — 备份 EmbyTok 配置

BACKUP_DIR="/opt/backups/embbytok-$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR

# 备份项目配置文件
cp -r /path/to/EmbyTok-Flutter/docker-compose.yml $BACKUP_DIR/
cp -r /path/to/EmbyTok-Flutter/nginx $BACKUP_DIR/ 2>/dev/null

# 打包压缩
tar -czf $BACKUP_DIR.tar.gz $BACKUP_DIR
rm -rf $BACKUP_DIR

echo "备份完成: $BACKUP_DIR.tar.gz"
```

定期执行：

```bash
# 每周日凌晨 2 点自动备份
sudo crontab -e
# 0 2 * * 0 /opt/backups/backup.sh >> /var/log/embbytok-backup.log 2>&1
```

---

## 十、故障排查（快速指南）

本节为部署相关的快速问题。应用使用层面的问题请参考 [故障排查指南](troubleshooting.md)。

### 问题 1：`docker compose up -d` 后服务无法启动

**症状**：`docker compose ps` 显示 `STATUS: Restarting`

**排查**：

```bash
# 查看具体错误日志
docker compose logs backend --tail=50

# 常见原因:
# 1. 端口被占用（8000 已被其他服务使用）
sudo lsof -i :8000    # 或: netstat -tlnp | grep 8000

# 2. 镜像构建失败（依赖下载失败）
docker compose build --no-cache backend

# 3. 文件权限问题（Dockerfile 中的文件拷贝失败）
ls -la backend/
```

### 问题 2：手机端无法连接后端

**症状**：登录页面显示"网络连接失败"

**排查**：

```bash
# 1. 确认容器正在运行
docker compose ps

# 2. 在服务器本地测试
curl http://localhost:8000/health

# 3. 在同一局域网的另一台机器上测试（用服务器的局域网 IP）
curl http://192.168.1.6:8000/health

# 如果步骤 3 失败但步骤 2 成功：
# → 检查防火墙是否放行 8000 端口
sudo ufw allow 8000/tcp     # Ubuntu/Debian
sudo firewall-cmd --permanent --add-port=8000/tcp && sudo firewall-cmd --reload  # CentOS/RHEL
```

### 问题 3：容器内无法访问 Emby 服务

**症状**：后端正常但登录失败，502 Bad Gateway

**排查**：

```bash
# 进入后端容器，测试是否能访问 Emby
docker exec -it embbytok-backend bash
curl http://192.168.1.6:8010/   # 填入你的 Emby 地址

# 如果失败，检查 Docker 网络配置
# 1. 后端容器与 Emby 是否在同一主机？
# 2. 如果 Emby 在另一台机器，确保两个容器能互通
# 3. 如果 Emby 也在 Docker 中，需要把两个容器放在同一 Docker network
```

### 问题 4：HTTPS 证书过期

**症状**：浏览器访问 `https://your-domain.com` 提示证书过期

**解决**：

```bash
# 手动续签
sudo certbot renew

# 重新加载 Nginx 配置
docker exec embbytok-nginx nginx -s reload
```

---

## 十一、安全建议

| 建议 | 说明 |
|------|------|
| **使用 HTTPS** | 公网暴露时必须使用 HTTPS，避免密码和 Token 明文传输 |
| **限制端口暴露** | 仅暴露必要端口（80/443），后端 8000 端口通过 Docker 内部网络访问 |
| **强密码** | Emby 账号设置强密码，启用两步验证（如 Emby 支持） |
| **定期更新** | `docker compose pull && docker compose up -d --build` 更新基础镜像 |
| **不要在容器中运行 root** | Dockerfile 中应使用非 root 用户运行 uvicorn |
| **限制来源 IP** | 如果只有固定几个设备访问，在 Nginx 或防火墙中限制来源 IP |

---

## 十二、升级到新版本

```bash
cd EmbyTok-Flutter

# 1. 拉取最新代码
git pull

# 2. 重新构建镜像并重启（零停机）
docker compose up -d --build

# 3. 验证新版本
curl http://localhost:8000/health
docker compose ps
```

---

*文档版本：v1.0 | 最后更新：2026-06-12 | 对应项目版本：EmbyTok-Flutter v1.0.x*
