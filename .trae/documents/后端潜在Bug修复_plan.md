# 后端潜在 Bug 修复计划

## 概述

修复后端代码中 3 个已确认的潜在 Bug：
1. 版本号不一致（config.py 硬编码 vs version.py 实际版本）
2. get_playback_progress 静默吞噬所有 APIError
3. auth.py 异常处理意图不清晰 + 502 缺少常量定义

## 当前状态分析

### Bug 1：版本号不一致
- [config.py:5](file:///workspace/backend/core/config.py#L5)：`APP_VERSION = "1.0.0"` 硬编码
- [version.py:8](file:///workspace/backend/core/version.py#L8)：`__version__ = '1.3.2'`（发布脚本自动维护）
- `get_emby_client_header()` 使用 `APP_VERSION`，导致向 Emby 报告版本始终为 1.0.0
- `version.py` 无任何 import，从 `config.py` 导入它不存在循环依赖风险

### Bug 2：get_playback_progress 吞噬异常
- [emby_client.py:373](file:///workspace/backend/clients/emby_client.py#L373)：`except APIError: return None`
- 调用方 [items.py:91](file:///workspace/backend/routers/items.py#L91) 无法区分"无进度数据"与"查询失败"
- 404（用户数据不存在）可安全返回 None，401/5xx 应重新抛出

### Bug 3：auth.py 异常处理缺陷
- [auth.py:43](file:///workspace/backend/routers/auth.py#L43)：裸 `raise` 意图不清晰
- [auth.py:46](file:///workspace/backend/routers/auth.py#L46)：裸 `raise` 同上
- [auth.py:22](file:///workspace/backend/routers/auth.py#L22) 和 [auth.py:45](file:///workspace/backend/routers/auth.py#L45)：502 状态码缺少常量定义
- [errors.py](file:///workspace/backend/core/errors.py) 已有 401/403/404/400/500/503 常量，唯独没有 502

## 修改方案

### 修改 1：errors.py 新增 BAD_GATEWAY 常量
- 文件：`backend/core/errors.py`
- 内容：在 `SERVER_UNREACHABLE` 后新增 `BAD_GATEWAY: int = 502`
- 原因：为 auth.py 中的 502 状态码提供命名常量，与现有错误常量风格一致

### 修改 2：config.py 从 version.py 导入版本号
- 文件：`backend/core/config.py`
- 内容：
  - 删除 `APP_VERSION: str = "1.0.0"` 硬编码
  - 改为 `from core.version import __version__ as APP_VERSION`
- 原因：统一版本来源，Emby 客户端 header 报告真实版本
- 无循环依赖风险：version.py 无 import

### 修改 3：emby_client.py 精确异常处理
- 文件：`backend/clients/emby_client.py`
- 内容：修改 `get_playback_progress` 的 except 块
  - 从 `except APIError: return None`
  - 改为：仅捕获 404 返回 None，其他异常重新抛出
  - 需导入 `ITEM_NOT_FOUND`（已导入 `APIError`，需补充导入 `ITEM_NOT_FOUND`）
- 原因：401/5xx 等错误应向上传播，调用方可正确处理认证失败和服务器不可达

### 修改 4：auth.py 显式异常处理
- 文件：`backend/routers/auth.py`
- 内容：
  - 导入新增的 `BAD_GATEWAY` 常量
  - 将 auth.py:22 的 `APIError(502, ...)` 改为 `APIError(BAD_GATEWAY, ...)`
  - 将 auth.py:43 的裸 `raise` 改为 `raise exc`
  - 将 auth.py:45 的 `APIError(502, ...)` 改为 `APIError(BAD_GATEWAY, ...)`
  - 将 auth.py:46 的裸 `raise` 改为 `raise exc`
- 原因：意图清晰化 + 使用常量替代魔法数字

## 验证步骤

1. 检查 `config.py` 导入 `version.py` 后无循环依赖
2. 运行后端测试：`cd /workspace/backend && python -m pytest tests/ -v`
3. 确认 `get_emby_client_header()` 输出的 Version 字段为 1.3.2
4. 确认 `get_playback_progress` 对 404 返回 None，对 401/5xx 抛出异常
5. 确认 auth.py 中所有 502 均使用 `BAD_GATEWAY` 常量
