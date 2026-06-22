# Tasks

## Task 1: 修复媒体库列表获取 - 使用用户视角 API

修改 `embbytok_service.dart` 中的 `getLibraries` 方法，使用 `/Users/{userId}/Views` 替代 `/Library/VirtualFolders`。

- [x] SubTask 1.1: 检查当前 `getLibraries` 方法实现
- [x] SubTask 1.2: 修改 API 路径为 `/Users/{userId}/Views`
- [x] SubTask 1.3: 确保 userId 参数正确传递
- [x] SubTask 1.4: 验证返回的 Library 模型兼容新 API 响应

## Task 2: 修复收藏 API - 使用用户视角端点

修改 `embbytok_service.dart` 中的收藏相关方法，使用 `/Users/{userId}/FavoriteItems/{itemId}` 替代 `/UserFavoriteItems/{itemId}`。

- [x] SubTask 2.1: 检查当前 `markAsPlayed`/`markAsUnplayed` 方法实现
- [x] SubTask 2.2: 修改 API 路径为 `/Users/{userId}/FavoriteItems/{itemId}`
- [x] SubTask 2.3: 确保使用正确的 HTTP 方法（POST 添加，DELETE 取消）
- [x] SubTask 2.4: 验证收藏状态变更正确同步

## Task 3: 修复视频列表 API - 使用用户视角路径

修改 `embbytok_service.dart` 中获取视频列表的方法（如 `getLibraryItems`、`getRecentlyAdded`、`getResumeItems` 等），确保使用 `/Users/{userId}/Items` 路径。

- [x] SubTask 3.1: 检查 `getLibraryItems` 方法
- [x] SubTask 3.2: 检查 `getRecentlyAdded` 方法
- [x] SubTask 3.3: 检查 `getResumeItems` 方法
- [x] SubTask 3.4: 确保所有方法使用用户视角路径

## Task 4: 更新 Provider 层调用

确保 `favorites_provider.dart`、`library_provider.dart`、`video_list_provider.dart` 等 Provider 正确传递 userId 参数。

- [x] SubTask 4.1: 检查 favorites_provider 调用
- [x] SubTask 4.2: 检查 library_provider 调用
- [x] SubTask 4.3: 检查 video_list_provider 调用
- [x] SubTask 4.4: 确保所有 API 调用传递正确 userId

## Task 5: Flutter analyze 通过

确保所有修改后 `flutter analyze --no-pub lib` 无 error。

- [x] SubTask 5.1: 运行 flutter analyze 检查
- [x] SubTask 5.2: 修复任何 analyzer 错误

# Task Dependencies

- Task 1, 2, 3 可并行执行（各自修改 service 层不同方法）
- Task 4 依赖 Task 1、2、3（需要 service 方法先修改完成）
- Task 5 依赖 Task 4（所有代码修改完成后进行）
