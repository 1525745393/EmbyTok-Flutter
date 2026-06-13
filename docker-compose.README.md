# 🐳 EmbyTok Docker Compose 配置说明

> 本目录包含多份 Docker Compose 配置文件，针对不同使用场景。**请根据你的需求选择合适的一份**。

---

## 📋 配置文件对比

| 配置文件 | 包含服务 | 镜像来源 | 占用端口 | 推荐用户 |
|---------|---------|---------|---------|---------|
| **`docker-compose.yml`** | 后端（从源码构建） | 本地构建 `./backend` | 8000 | 开发者 / 想自定义源码 |
| **`docker-compose.prod.yml`** | 后端 + 前端 Web | Docker Hub 拉取 | 8000, 8080 | 想同时用 App 和 Web 界面 |
| **`docker-compose.minimal.yml`** | 仅后端 | Docker Hub 拉取 | 8000 | **大多数用户**（只用手机 App） |

---

## 🚀 快速开始

### 方案 A：最小版（推荐手机 App 用户）

只运行后端 API，手机 App 通过 8000 端口连接。**资源占用最低**。

```bash
# 拉取镜像并启动
docker compose -f docker-compose.minimal.yml up -d

# 或使用老版本 Docker
docker-compose -f docker-compose.minimal.yml up -d
```

### 方案 B：完整版（后端 + 前端 Web）

同时运行后端 API 和前端 Web 界面，可以通过浏览器访问 Web 界面。

```bash
# 拉取镜像并启动
docker compose -f docker-compose.prod.yml up -d
```

### 方案 C：从源码构建（开发者）

使用本地源码构建镜像，适合开发者或想自定义源码的用户。

```bash
# 构建并启动
docker compose up -d --build
```

---

## ✅ 验证服务运行

### 查看容器状态

```bash
# 查看所有 EmbyTok 容器状态
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep embbytok
```

应看到类似输出：

```
NAMES                  STATUS                    PORTS
embbytok-backend       Up 2 minutes (healthy)    0.0.0.0:8000->8000/tcp
embbytok-frontend      Up 2 minutes (healthy)    0.0.0.0:8080->80/tcp
```

### 测试后端 API

```bash
# 健康检查
curl http://localhost:8000/health
# 应返回：{"status":"ok","version":"1.0.0","service":"embbytok-backend"}

# 根路径
curl http://localhost:8000/
# 应返回：{"message":"EmbyTok API - Use /docs for Swagger UI","version":"1.0.0"}

# 浏览器访问 Swagger API 文档
# http://你的NAS_IP:8000/docs
```

### 测试前端 Web（仅完整版）

浏览器访问：`http://你的NAS_IP:8080`

---

## 📱 手机 App 登录配置

| 字段 | 填写内容 | 示例 |
|------|---------|------|
| **后端服务地址** | `http://NAS的IP:8000` | `http://192.168.1.100:8000` |
| **Emby 服务器地址** | 你的 Emby 服务器地址 | `http://192.168.1.100:8096` |
| **Emby 用户名** | 你的 Emby 账号用户名 | `admin` |
| **Emby 密码** | 你的 Emby 账号密码 | `********` |

---

## 🔧 常用命令速查

```bash
# ========== 启动 / 停止 ==========

# 启动服务（最小版）
docker compose -f docker-compose.minimal.yml up -d

# 启动服务（完整版）
docker compose -f docker-compose.prod.yml up -d

# 停止服务
docker compose -f docker-compose.minimal.yml stop

# 重启服务
docker compose -f docker-compose.minimal.yml restart

# 停止并删除容器（保留镜像）
docker compose -f docker-compose.minimal.yml down

# 完全卸载（删除容器、镜像、网络）
docker compose -f docker-compose.minimal.yml down -v --rmi all


# ========== 日志查看 ==========

# 查看所有服务的实时日志
docker compose -f docker-compose.minimal.yml logs -f

# 查看最近 100 行日志
docker compose -f docker-compose.minimal.yml logs -f --tail=100

# 只看后端日志
docker logs -f embbytok-backend

# 只看前端日志
docker logs -f embbytok-frontend


# ========== 镜像更新 ==========

# 拉取最新镜像
docker compose -f docker-compose.minimal.yml pull

# 用新镜像重启容器
docker compose -f docker-compose.minimal.yml up -d

# 一步到位：拉取最新镜像并重启
docker compose -f docker-compose.minimal.yml pull && docker compose -f docker-compose.minimal.yml up -d


# ========== 进入容器（调试用） ==========

# 进入后端容器
docker exec -it embbytok-backend sh

# 进入前端容器
docker exec -it embbytok-frontend sh
```

---

## 🔩 自定义配置

### 修改端口

如果端口被占用，可以编辑 compose 文件中的 `ports` 字段：

```yaml
ports:
  - "8001:8000"    # 把主机端口从 8000 改成 8001
```

### 修改时区

将 `TZ` 环境变量改为你的时区：

```yaml
environment:
  - TZ=Asia/Shanghai    # 上海（默认）
  # - TZ=Asia/Tokyo     # 东京
  # - TZ=America/New_York  # 纽约
  # - TZ=Europe/London  # 伦敦
```

### 调整资源限制

根据你的硬件性能调整资源限制：

```yaml
mem_limit: 512m        # 最大内存 512MB（低配 NAS 可调低到 256m）
mem_reservation: 128m  # 预留内存 128MB
cpus: "1.0"            # 最多使用 1 个 CPU 核心
```

---

## 🌐 Docker Hub 镜像地址

| 服务 | 镜像地址 |
|------|---------|
| 后端 | [`1525745393/embbytok-backend`](https://hub.docker.com/r/1525745393/embbytok-backend) |
| 前端 | [`1525745393/embbytok-frontend`](https://hub.docker.com/r/1525745393/embbytok-frontend) |

支持的架构：`linux/amd64`、`linux/arm64`（通过 GitHub Actions 自动构建多架构镜像）

---

## 🔒 NAS 防火墙端口开放

确保你的 NAS 开放了以下端口的 **TCP 入站**访问（至少内网需要开放）：

| 端口 | 服务 | 必须开放 |
|------|------|---------|
| **8000** | 后端 API | ✅ 是 |
| **8080** | 前端 Web | ⚠️ 可选（完整版需要） |

### 群晖（Synology）

控制面板 → 安全性 → 防火墙 → 编辑规则，确保内网 IP 段可以访问这两个端口。

### 通用 Linux

```bash
# 使用 ufw
sudo ufw allow 8000/tcp
sudo ufw allow 8080/tcp
sudo ufw reload

# 使用 firewalld（CentOS / RHEL）
sudo firewall-cmd --permanent --add-port=8000/tcp
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

---

## ❓ 常见问题

### Q1：`docker: command not found`

请先安装 Docker 和 Docker Compose：
- **群晖**：套件中心安装 "Container Manager"（DSM 7.2+）或 "Docker"
- **Linux**：`curl -fsSL https://get.docker.com | sh`
- **Windows / macOS**：安装 Docker Desktop

### Q2：`manifest for 1525745393/embbytok-backend:latest not found`

Docker Hub 上还没有该镜像。请确保：
1. 已经推送 Git tag 触发 CI 构建（`git tag v1.0.8 && git push origin v1.0.8`）
2. 或者使用本地构建版本 `docker compose up -d --build`

### Q3：容器启动后立即退出

查看日志找原因：

```bash
docker logs embbytok-backend
```

常见原因：端口被占用、权限不足、磁盘空间不足。

### Q4：手机 App 提示 "网络连接失败"

1. 确认容器正在运行：`docker ps | grep embbytok`
2. 确认健康检查通过：状态应为 `healthy`
3. 确认 NAS 防火墙开放了 8000 端口
4. 手机和 NAS 在同一局域网（或外网需要端口映射）
5. App 中填写的地址格式应为：`http://NAS_IP:8000`

### Q5：如何更新到最新版本？

```bash
# 拉取最新镜像并重启
docker compose -f docker-compose.minimal.yml pull
docker compose -f docker-compose.minimal.yml up -d

# 验证版本
curl http://localhost:8000/health
```

---

## 📚 更多文档

- [用户使用指南](docs/user-guide.md) - 完整的安装和使用教程
- [部署指南](docs/deployment.md) - 更多部署方案
- [故障排查指南](docs/troubleshooting.md) - 解决常见问题
- [架构总览](docs/architecture.md) - 了解系统设计
