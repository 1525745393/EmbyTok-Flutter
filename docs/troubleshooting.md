# EmbyTok - 故障排查指南

> 本文件目标：按场景汇总用户和开发者在使用 EmbyTok 过程中可能遇到的问题及其解决方法。按从常见到少见排序，建议从上到下排查。
>
> 相关文档：
> - [用户使用指南](user-guide.md)
> - [部署指南](deployment.md)
> - [API 参考](api-reference.md)
> - [开发者指南](developer-guide.md)

---

## 📖 目录

1. [登录相关问题](#1-登录相关问题)
2. [网络连接问题](#2-网络连接问题)
3. [视频播放问题](#3-视频播放问题)
4. [字幕问题](#4-字幕问题)
5. [搜索与收藏问题](#5-搜索与收藏问题)
6. [应用安装与运行问题](#6-应用安装与运行问题)
7. [Docker 部署问题](#7-docker-部署问题)
8. [性能与卡顿问题](#8-性能与卡顿问题)
9. [Flutter 开发构建问题](#9-flutter-开发构建问题)

---

## 1. 登录相关问题

### 问题 1.1：提示"找不到文件 /api/auth/login"

**症状**：登录页面底部红色提示 "找不到文件 '/api/auth/login'"

**可能原因**：

| 原因 | 概率 |
|------|------|
| 后端代理地址填成了 Emby 服务器地址 | 高 |
| FastAPI 后端服务未启动 | 中 |
| FastAPI 后端绑定地址为 127.0.0.1（手机无法访问） | 中 |

**排查步骤**：

```bash
# 步骤 1：确认后端服务正在运行
# 在运行后端的机器上执行：
curl http://localhost:8000/health
# 应该返回: {"status":"ok","version":"1.0.0","service":"embbytok-backend"}

# 步骤 2：确认后端监听的不是 127.0.0.1
# 检查启动命令是否包含 --host 0.0.0.0
ps aux | grep uvicorn
# 应看到: uvicorn main:app --host 0.0.0.0 --port 8000

# 步骤 3：从手机浏览器测试
# 在手机浏览器访问: http://电脑IP:8000/health
# 如果打不开 → 是网络/防火墙问题，继续看问题 2.1
```

**解决方案**：

1. **启动 FastAPI 后端**（如果没运行）：

```bash
cd EmbyTok-Flutter/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

2. **在应用中正确填写地址**：

| 字段 | 填写内容 |
|------|---------|
| 后端代理地址 | `http://电脑IP:8000`（不是 Emby 地址） |
| Emby 服务器地址 | `http://电脑IP:8010`（或 Emby 实际端口） |

---

### 问题 1.2：提示"用户名或密码无效"

**症状**：登录页面底部红色提示 "用户名或密码无效"（HTTP 401）

**排查步骤**：

1. 在 Emby 的 Web 界面用同样的用户名/密码登录一次，确认有效
2. 检查用户名是否区分大小写（Emby 的用户名字段通常不区分，但密码区分）
3. 检查 Emby 日志（通常在 Emby 安装目录的 `logs/` 目录下），看是否有失败的登录尝试

**解决方案**：

- 确认用户名和密码正确
- 如果 Emby 服务启用了两步验证，需要调整后端处理逻辑
- 在 Emby 管理面板中检查该用户是否被禁用

---

### 问题 1.3：Token 过期 / 重新打开应用需要重新登录

**症状**：每天第一次使用应用需要重新登录

**可能原因**：Emby 颁发的 AccessToken 有有效期

**解决方案**：

- 当前实现未实现 Token 自动刷新，需要手动重新登录
- 未来可通过 `POST /api/auth/login` 实现静默刷新

---

## 2. 网络连接问题

### 问题 2.1：提示"网络连接失败，请检查服务器地址"

**症状**：登录后无法加载内容，或连登录都失败

**可能原因和排查**：

| 原因 | 排查方法 | 解决方案 |
|------|---------|---------|
| **手机和电脑不在同一局域网** | 手机连同一 WiFi；查看手机 IP 与电脑 IP 是否在同一网段 | 让手机连接到和电脑相同的局域网 |
| **电脑防火墙拦截** | 在服务器上执行：`sudo ufw status` 或 `sudo iptables -L` | 放行 8000 端口：`sudo ufw allow 8000/tcp` |
| **端口被占用** | `lsof -ti:8000` 或 `netstat -tlnp \| grep 8000` | 杀占用进程或修改端口 |
| **路由器 AP 隔离** | 在路由器管理面板查看"AP 隔离" / "客户端隔离"选项 | 关闭 AP 隔离 |
| **后端服务未启动** | `ps aux \| grep uvicorn` | 启动后端服务（参见 问题 1.1 解决方案） |

**快速验证脚本**：

```bash
# 一次性检查所有可能原因
echo "=== 后端是否在运行 ==="
curl -s http://localhost:8000/health && echo " [OK]" || echo " [FAIL]"

echo ""
echo "=== 8000 端口是否被占用 ==="
if lsof -ti:8000 > /dev/null 2>&1; then
  echo "端口被占用（PID: $(lsof -ti:8000 | head -1)）"
else
  echo "端口空闲"
fi

echo ""
echo "=== 局域网 IP 地址 ==="
hostname -I 2>/dev/null || ipconfig getifaddr en0
```

---

### 问题 2.2：外网（非局域网）无法访问

**症状**：在公司或 4G 环境下无法连接到家中的服务器

**解决方案**（任选其一）：

| 方案 | 难度 | 说明 |
|------|------|------|
| **Tailscale** | ⭐ | 安装客户端后获得虚拟局域网 IP，全程加密 |
| **frp** | ⭐⭐ | 需公网服务器，把内网 8000 端口转发出去 |
| **Cloudflare Tunnel** | ⭐ | 零配置暴露本地服务到公网 |
| **端口转发 + 动态域名** | ⭐⭐ | 路由器配置端口转发，配合 DDNS |

具体配置方法参见 [部署指南](deployment.md) 第五节。

---

## 3. 视频播放问题

### 问题 3.1：视频黑屏 / 无法播放

**症状**：视频播放器区域显示黑屏或转圈，无画面

**排查步骤**：

1. **确认 Emby 直链是否可用**：

```bash
# 用后端 API 获取播放地址
curl -X POST http://电脑IP:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"emby_url":"http://电脑IP:8010","username":"FK","password":"密码"}'
# 记录返回的 access_token

# 用 Token 请求某个视频的播放地址
curl -H "X-Emby-Server-Url: http://电脑IP:8010" \
     -H "X-Emby-Token: 你的token" \
     -H "X-Emby-User-Id: 你的user_id" \
     http://电脑IP:8000/api/items/某个视频ID/playback

# 把返回的 playback_url 复制到浏览器或 VLC 中测试是否能播放
```

2. **检查视频编码**：Flutter 的 video_player 插件对 H.264 + AAC 支持最好。如果视频是 HEVC(H.265)、AV1、VP9 等编码，可能在部分设备上无法播放

3. **检查网络**：确保手机和服务器之间的带宽足够（播放 4K 视频需要 25Mbps+）

**解决方案**：

- 对不兼容的视频，在 Emby 中启用"转码"（Transcoding），让 Emby 在服务端转成兼容格式
- 降低视频分辨率/码率
- 使用有线连接代替 WiFi 测试，确认是否为网络问题

---

### 问题 3.2：视频播放卡顿 / 缓冲频繁

**可能原因**：

| 原因 | 排查方法 |
|------|---------|
| WiFi 信号弱 / 干扰 | 检查 WiFi 信号强度；切换到 5GHz；靠近路由器 |
| 服务器硬盘 IO 不足 | `iotop` 或 `htop` 查看硬盘占用 |
| Emby 转码性能不足 | Emby 需要 GPU 加速（Intel QSV / NVIDIA NVENC） |
| 视频码率过高 | 查看视频文件的码率信息（`ffprobe video.mp4`） |

**通用建议**：

- 确保使用 5GHz WiFi（2.4GHz 穿墙强但速率低）
- 考虑启用 Emby 的硬件转码
- 对大量视频，建议批量转码为 H.264 + AAC，码率控制在 4-8 Mbps

---

### 问题 3.3：进度条不更新 / 切换视频后卡住

**可能原因**：`video_player` 控制器状态未正确同步

**排查**：

1. 用 Chrome DevTools（或 Flutter DevTools）检查 `VideoPlayerController.value.isPlaying` 状态
2. 查看应用日志（`flutter logs`）是否有播放器错误
3. 确认进度上报 API 调用是否成功：`POST /api/items/{id}/progress`

---

## 4. 字幕问题

### 问题 4.1：字幕不显示

**排查**：

1. 确认该视频在 Emby 中确实有字幕文件（SRT / VTT / ASS）
2. 在 Emby Web 界面播放同一视频，确认字幕正常
3. 在 EmbyTok 应用中点击字幕图标，确认字幕开关处于开启状态
4. 查看字幕轨道列表 API：

```bash
curl -H "X-Emby-Server-Url: http://电脑IP:8010" \
     -H "X-Emby-Token: 你的token" \
     -H "X-Emby-User-Id: 你的user_id" \
     http://电脑IP:8000/api/items/视频ID/subtitles
```

预期返回格式：

```json
[{"id":"subtrack-1","name":"简体中文","language":"chi","format":"srt","url":"..."}]
```

---

### 问题 4.2：字幕乱码（显示为方块或乱码字符）

**原因**：字幕文件不是 UTF-8 编码（常见于旧的 GB2312 / GBK 编码的中文字幕）

**解决方案**：

```bash
# 方法 A：用 iconv 转换编码
iconv -f GBK -t UTF-8 old_subtitle.srt > new_subtitle.srt

# 方法 B：用 Python 脚本批量转换
for f in *.srt; do
  chardet "$f" | grep -q "GBK\|GB2312\|Big5" && \
  iconv -f GBK -t UTF-8 "$f" > "${f%.srt}_utf8.srt" && \
  mv "${f%.srt}_utf8.srt" "$f"
done

# 然后把转换后的字幕文件重新关联到 Emby 中的视频
```

---

### 问题 4.3：字幕与视频不同步

**原因**：字幕文件的时间轴与视频不匹配

**解决方案**：在播放器中手动调整字幕延迟，或使用 SubtitleEdit 等工具批量调整时间轴。

---

## 5. 搜索与收藏问题

### 问题 5.1：搜索无结果 / 无响应

**排查**：

1. 确认 Emby 索引已完成（Emby 管理面板 → 计划任务 → 媒体库扫描）
2. 用后端 API 直接测试：

```bash
curl -H "X-Emby-Server-Url: http://电脑IP:8010" \
     -H "X-Emby-Token: 你的token" \
     -H "X-Emby-User-Id: 你的user_id" \
     "http://电脑IP:8000/api/search?q=肖申克&limit=10"
```

3. 如果 API 有结果但前端没显示：可能是前端渲染问题
4. 如果 API 无结果：可能是 Emby 搜索功能未正确配置

---

### 问题 5.2：收藏不生效 / 收藏列表为空

**症状**：双击视频收藏后，再打开"收藏"页面仍然为空

**排查**：

1. 查看后端日志（`docker compose logs -f backend` 或 `journalctl -u embbytok-backend -f`）
2. 检查 Emby 服务器上的用户数据是否已正确记录（登录 Emby Web 界面，查看是否有收藏）
3. 用 curl 手动测试：

```bash
# 添加收藏
curl -X POST http://电脑IP:8000/api/favorites/视频ID \
  -H "X-Emby-Server-Url: http://电脑IP:8010" \
  -H "X-Emby-Token: 你的token" \
  -H "X-Emby-User-Id: 你的user_id"
# 预期返回: {"ok":true}

# 获取收藏列表
curl -H "X-Emby-Server-Url: http://电脑IP:8010" \
     -H "X-Emby-Token: 你的token" \
     -H "X-Emby-User-Id: 你的user_id" \
     http://电脑IP:8000/api/favorites
```

---

## 6. 应用安装与运行问题

### 问题 6.1：APK 安装后打开闪退

**症状**：安装成功后点击图标，屏幕闪烁一下就退出

**可能原因**：

| 原因 | 排查方法 | 解决 |
|------|---------|------|
| ABI 架构不匹配 | 下载的是 arm64 APK，但手机是 armeabi-v7a | 重新下载对应架构的 APK 或使用 `app-release.apk`（通用版） |
| Android 版本过低 | 应用要求 minSdkVersion ≥ 24（Android 7.0） | 升级系统或使用兼容设备 |
| 签名不匹配 | 从不同渠道签名的 APK 安装到同一设备 | 卸载旧版本后重新安装 |

**获取手机架构**：在手机上安装"Termux"或通过 ADB：

```bash
adb shell getprop ro.product.cpu.abi
# 可能的输出:
#   arm64-v8a      ← 现代手机（推荐下载 app-arm64-v8a-release.apk）
#   armeabi-v7a    ← 较旧手机
#   x86_64         ← 模拟器/Intel 平板
```

---

### 问题 6.2：应用崩溃 / 无响应（ANR）

**症状**：应用弹出"EmbyTok 无响应，要关闭吗"或直接闪退

**排查**：

```bash
# 通过 adb 查看崩溃日志
adb logcat --pid=$(adb shell pidof -s com.embbytok.app)

# 或查看所有错误日志
adb logcat *:E
```

**常见崩溃原因**：

- 视频播放组件初始化失败（视频编码不支持）
- 网络请求超时后未正确处理异常
- 内存不足（播放大视频时）

---

### 问题 6.3：iOS 版本无法安装

**说明**：

当前项目重点支持 Android。iOS 需通过以下方式之一安装：

1. 使用 Xcode 从源码构建并签名（需要 Apple 开发者账号）
2. 使用 TestFlight 分发给测试用户
3. 越狱设备（不推荐）

---

## 7. Docker 部署问题

### 问题 7.1：`docker compose up -d` 后容器一直 Restarting

**排查**：

```bash
# 查看容器状态
docker compose ps

# 查看详细日志
docker compose logs backend --tail=50

# 可能的错误:
#   a) 端口被占用: "Address already in use"
#   b) 构建失败: "pip install" 时网络错误
#   c) 容器内路径错误: "No such file or directory"
```

**常见解决方案**：

- **端口被占用**：`sudo lsof -ti:8000 | xargs -r sudo kill -9` 或在 `docker-compose.yml` 中改端口
- **依赖下载失败**：检查宿主机网络；尝试使用国内镜像源（如阿里云 PyPI 镜像）
- **构建缓存问题**：`docker compose build --no-cache backend`

---

### 问题 7.2：容器内无法访问 Emby 服务

**症状**：后端返回 502 Bad Gateway

**原因**：Docker 容器默认使用 bridge 网络，访问宿主机时需要使用正确的 IP

**排查与解决**：

```bash
# 方法 A：使用 host.docker.internal（Docker Desktop / 新版 Docker for Linux 支持）
# 在 docker-compose.yml 中为 backend 添加:
# extra_hosts:
#   - "host.docker.internal:host-gateway"
# 然后后端代理地址填: http://host.docker.internal:8010

# 方法 B：使用容器所在网络的网关 IP
# 查看容器网络:
docker inspect embbytok-backend | grep Gateway
# 输出: "Gateway": "172.18.0.1"
# 则后端代理地址填: http://172.18.0.1:8010

# 方法 C：使用 host 网络模式（最简单，但安全性略低）
# 在 docker-compose.yml backend 服务下添加:
# network_mode: host
# 然后后端代理地址填: http://127.0.0.1:8010
```

---

### 问题 7.3：Docker 镜像体积过大

**优化**：

```bash
# 查看各镜像体积
docker images | grep embbytok

# 清理未使用的镜像
docker image prune -a

# 清理所有未使用的资源（镜像、容器、卷）
docker system prune -a

# 重新构建（多阶段构建可减小体积）
cd backend
docker build -t embbytok-backend:latest --no-cache .
```

---

## 8. 性能与卡顿问题

### 问题 8.1：视频切换有明显延迟

**排查**：

1. 检查视频预加载策略是否启用
2. 检查后端 API 响应时间：

```bash
# 测量媒体库列表 API 响应时间
curl -w "响应时间: %{time_total}s\n" \
  -H "X-Emby-Server-Url: http://电脑IP:8010" \
  -H "X-Emby-Token: 你的token" \
  -H "X-Emby-User-Id: 你的user_id" \
  http://电脑IP:8000/api/libraries
```

3. 如果 API 响应 > 500ms，考虑：
   - 增加 Redis 缓存层
   - 启用 HTTP 连接池
   - 把后端和 Emby 部署在同一台机器（减少网络开销）

---

### 问题 8.2：服务器端 Emby CPU 占用高

**排查**：

```bash
# 查看 CPU 占用
htop  # 或 top

# 查看 Emby 进程资源使用
ps aux | grep -i emby
```

**可能原因**：

- 正在扫描媒体库（扫描完成后自动下降）
- 正在转码视频（需要 GPU 加速）
- 元数据下载失败重试循环

---

## 9. Flutter 开发构建问题

### 问题 9.1：`flutter build apk` 构建失败

**常见错误**：

```
FAILURE: Build failed with an exception.
* What went wrong:
Could not determine the dependencies of task ':app:compileReleaseKotlin'.
> Could not resolve all files for configuration ':app:releaseCompileClasspath'.
```

**解决方案**：

```bash
cd frontend

# 清理构建缓存
flutter clean

# 重新安装依赖
flutter pub get

# 重新构建
flutter build apk --release --split-per-abi

# 如果仍然失败，查看完整错误日志
flutter build apk --release --split-per-abi -v
```

**如果需要构建 debug 版快速验证**：

```bash
flutter build apk --debug
```

---

### 问题 9.2：`flutter pub get` 依赖冲突

**症状**：

```
Because embbytok depends on package_a >=1.0.0 which depends on package_b ^2.0.0,
package_b ^2.0.0 is required.
So, because embbytok depends on package_b ^1.0.0, version solving failed.
```

**解决方案**：

```bash
# 方法 A：升级所有依赖到兼容版本
flutter pub upgrade

# 方法 B：强制使用特定版本
# 在 pubspec.yaml 中明确指定版本号，或使用 dependency_overrides:
#
# dependency_overrides:
#   package_b: 2.0.1
```

---

### 问题 9.3：Android 签名问题

**症状**：构建的 Release APK 无法安装

**排查与解决**：参考 [Android 签名配置说明](../frontend/android/README_ANDROID_SIGN.md)

**快速方法**（使用调试签名仅用于开发测试）：

```bash
# Release 签名需要配置 keystore
# 1. 生成 keystore
keytool -genkey -v -keystore ~/embbytok-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias embbytok

# 2. 配置 frontend/android/key.properties
# storePassword=你的密码
# keyPassword=你的密码
# keyAlias=embbytok
# storeFile=~/embbytok-keystore.jks

# 3. 重新构建
flutter build apk --release --split-per-abi
```

---

## 10. 获取更多帮助

如果以上内容无法解决你的问题：

### 10.1 查看日志

```bash
# Flutter 应用日志
flutter logs

# 后端日志 (systemd)
sudo journalctl -u embbytok-backend -f

# 后端日志 (Docker)
docker compose logs -f backend --tail=200

# Emby 服务器日志
# 通常位于: /var/lib/emby/logs/ 或 /config/logs/ (Docker)
```

### 10.2 在 GitHub 提交 Issue

提交 Issue 时请附上以下信息，有助于快速定位：

```
## 环境信息
- EmbyTok 版本: (如 v1.0.7)
- 手机型号与 Android 版本: (如 小米 13 Pro / Android 14)
- 部署方式: (如 Docker Compose / 本地 uvicorn)
- Emby 服务器版本:

## 问题描述
(简要描述问题)

## 复现步骤
1. 打开应用
2. 点击登录
3. ...

## 预期行为
(应该发生什么)

## 实际行为
(实际发生了什么，包括错误提示文字)

## 相关日志
(粘贴 flutter logs / docker compose logs backend 中与问题相关的部分)
```

---

*文档版本：v1.0 | 最后更新：2026-06-12 | 对应项目版本：EmbyTok-Flutter v1.0.x*
