# Checklist

## 媒体库列表获取

- [x] `getLibraries` 方法使用 `/Users/{userId}/Views` 路径
- [x] `getLibraries` 方法正确接收和使用 userId 参数
- [x] `getLibraries` 返回的 Library 列表完整（包含电影、剧集等所有类型）

## 收藏 API

- [x] `markAsPlayed` 使用 `POST /Users/{userId}/FavoriteItems/{itemId}`
- [x] `markAsUnplayed` 使用 `DELETE /Users/{userId}/FavoriteItems/{itemId}`
- [x] 收藏状态变更后 UI 正确更新
- [x] 多用户场景下收藏数据正确隔离

## 视频列表 API

- [x] `getLibraryItems` 使用 `/Users/{userId}/Items` 路径
- [x] `getRecentlyAdded` 使用 `/Users/{userId}/Items/Latest` 路径
- [x] `getResumeItems` 使用用户视角路径
- [x] 所有视频列表方法正确传递 userId 参数

## Provider 层

- [x] `favorites_provider.dart` 正确传递 userId
- [x] `library_provider.dart` 正确传递 userId
- [x] `video_list_provider.dart` 正确传递 userId
- [x] `item_detail_provider.dart` 正确传递 userId
- [x] `search_provider.dart` 正确传递 userId

## 代码质量

- [x] flutter analyze 无 error
- [x] 无新增 warning
- [x] 代码风格与现有代码一致

## 功能验证

- [x] 媒体库选择器显示用户所有可访问的库
- [x] 点赞功能正常工作
- [x] 取消点赞功能正常工作
- [x] 多用户场景下数据正确隔离
