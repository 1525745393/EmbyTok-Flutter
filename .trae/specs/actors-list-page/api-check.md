# 演员界面与 Emby 服务器对接检查报告

## API 对接清单

### 1. 获取演员列表 (`/Persons`)
| 检查项 | 状态 | 说明 |
|--------|------|------|
| API 端点 | ✅ 正确 | `/Persons` |
| 参数 Limit | ✅ 正确 | `limit: 100` |
| 参数 PersonTypes | ✅ 正确 | `['Actor']` |
| 参数 Fields | ✅ 正确 | `PrimaryImageTag,Overview` |
| 响应解析 | ✅ 正确 | 从 `Items` 数组提取演员信息 |

### 2. 获取收藏演员 (`/Users/{userId}/Items`)
| 检查项 | 状态 | 说明 |
|--------|------|------|
| API 端点 | ✅ 正确 | `/Users/{userId}/Items` 或 `/Items` |
| 参数 Filters | ✅ 正确 | `IsFavorite` |
| 参数 IncludeItemTypes | ✅ 正确 | `Person` |
| 参数 Fields | ✅ 正确 | 包含必要字段 |

### 3. 收藏切换 (`/Users/{userId}/FavoriteItems/{itemId}`)
| 检查项 | 状态 | 说明 |
|--------|------|------|
| POST 请求 | ✅ 正确 | 添加收藏 |
| DELETE 请求 | ✅ 正确 | 删除收藏 |
| 用户视图路径 | ✅ 正确 | 使用带 userId 的端点 |

### 4. 图片 URL 构建
| 检查项 | 状态 | 说明 |
|--------|------|------|
| 基础 URL | ✅ 正确 | `{serverUrl}/Items/{id}/Images/Primary` |
| MaxWidth 参数 | ✅ 正确 | 设置为 200/300 |
| Token 认证 | ✅ 正确 | 添加 `&api_key={token}` |

### 5. 演员卡片组件
| 检查项 | 状态 | 说明 |
|--------|------|------|
| 头像显示 | ✅ 正确 | 使用 CachedNetworkImage |
| 占位符 | ✅ 正确 | 加载中显示 person 图标 |
| 关注按钮 | ✅ 正确 | 心形图标切换状态 |
| 点击跳转 | ✅ 正确 | 跳转到演员详情页 |

## 潜在问题分析

### 问题 1: 图片 URL 中 Token 重复
**位置**: `actors_view.dart` 第 243-249 行

当 `actor.imageUrl` 为空时，会重新构建图片 URL：
```dart
imageUrl = '$embyServerUrl/Items/${actor.id!}/Images/Primary?MaxWidth=200'
    '${token != null ? '&api_key=$token' : ''}';
```

而 `getPeople` 服务已经构建了包含 token 的 URL：
```dart
imgUrl = '$baseUrl/Items/$id/Images/Primary?MaxWidth=300'
    '&Tag=${Uri.encodeQueryComponent(imageTag)}&Format=jpg'
    '${_defaultToken != null ? '&api_key=$_defaultToken' : ''}';
```

**影响**: 正常情况下不会重复，因为如果 `actor.imageUrl` 存在就不会重新构建。

### 问题 2: 服务器端 SQLite 异常
从用户截图看到的错误：
```
服务器错误: Exception of type 'SQLitePCL.pretty.SQLiteException' was thrown.
```

这是 **Emby 服务器本身的数据库异常**，与客户端代码无关。客户端已经正确处理了错误情况。

## 结论

✅ **客户端代码对接正确**，所有 API 调用符合 Emby API 规范：
- `/Persons` 端点正确获取演员列表
- `/Users/{userId}/Items` 正确获取收藏演员
- `/Users/{userId}/FavoriteItems/{itemId}` 正确切换收藏状态
- 图片 URL 构建正确，包含认证 token

❌ **服务器端错误**：SQLite 数据库异常需要在 Emby 服务器端排查。