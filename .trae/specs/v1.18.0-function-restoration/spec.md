# v1.18.0 功能恢复 - 产品需求文档

## 概述

- **问题描述**：从 v1.18.0（commit `cfef715`）到当前 main 分支（commit `6e186a3`），由于大规模的代码重构（引入 `item_detail_view`、`preload_controller`、`empty_state_card`、`error_state_card`、NextUp 连播等），部分 v1.18.0 中已经修复和稳定工作的功能被移除或简化，导致用户体验降级。

- **核心问题**：
  1. `isPureMode`（纯净模式）被完全移除，用户无法一键隐藏所有覆盖层
  2. `seekDelta`（遥控器快进快退粒度设置）被移除
  3. `PlaybackRateNotifier`（倍速持久化）被简化为不持久化的 `StateProvider`
  4. `embbytok_service.dart` 中多个方法的 `userId` 参数被移除，改为使用 `_defaultUserId`，可能导致多用户场景下的数据混乱

- **目标用户**：EmbyTok Flutter 应用最终用户，尤其是使用遥控器操作的 TV 场景用户

## 目标

- 恢复 v1.18.0 中存在但当前缺失的核心功能
- 保留当前版本新增的功能（item_detail_view、预加载、手势快进快退等）
- 确保代码质量通过 `flutter analyze`，不引入新的错误

## 非目标（超出范围）

- 不进行大规模架构重构
- 不引入新的第三方依赖包
- 不修改服务端 API 逻辑

## 背景与上下文

v1.18.0（`cfef715`）是经过多次迭代修复后的稳定版本。之后的 "EmbyX 对接" 系列提交（`1bc2421` 及其之前的大量 commit）引入了新功能（详情页、预加载、手势快进快退、NextUp 连播等），但**在合并分支 `trae/solo-agent-H6ZsFh` 时，部分 v1.18.0 的功能被简化或误删**。

`git diff v1.18.0 HEAD --stat` 显示 `frontend/lib` 目录下有 40+ 个文件发生变更，总计数千行代码变更。核心变化包括：

- `video_playback_controller.dart`: 从复杂的 `StateNotifier` 组简化为简单的 `StateProvider`
- `video_page_item.dart`: 526 行变更，引入 NextUp 连播但移除了 isPureMode
- `embbytok_service.dart`: 232 行变更，主要是移除 `userId` 参数
- `video_list_provider.dart`: 175 行变更，重写为 feedType 模式

## 功能需求

### FR-1: 恢复纯净模式（isPureMode）
- 恢复 `isPureModeProvider`，允许用户在全屏播放时隐藏所有覆盖层 UI
- 纯净模式状态需要持久化到 `AppPreferencesService`
- `video_page_item.dart` 中需要恢复纯净模式相关的条件渲染逻辑
- 在 `video_controls.dart` 中提供纯净模式切换入口（如键盘快捷键 P）

### FR-2: 恢复 seekDelta 倍进/快退设置
- 恢复 `seekDeltaProvider`，允许用户设置遥控器快进/快退的秒数
- 支持常见值：5s、10s、15s、30s、60s
- 设置需要持久化

### FR-3: 恢复倍速持久化（PlaybackRate）
- 将 `playbackRateProvider` 从 `StateProvider<double>` 恢复为带持久化的 `StateNotifier<PlaybackRateNotifier, double>`
- 倍速变化时自动保存到 `AppPreferencesService`
- 启动时从持久化加载默认倍速
- 注意避免与 `DefaultPlaybackRateNotifier`（位于 `user_preferences_provider.dart`）冲突，需统一设计

### FR-4: 统一 userId 参数处理
- 确保 `embbytok_service.dart` 中所有需要用户身份的 API 调用正确传递 `userId`
- 当前实现使用 `_defaultUserId` 作为回退，但部分方法（如 `getFavoriteMovies`、`getFavoriteBoxSets`）丢失了显式 `userId` 参数
- 需恢复 `userId` 参数支持，优先使用调用方传入的 `userId`，其次回退到 `_defaultUserId`

### FR-5: search_provider 恢复 userId 支持
- `search_provider.dart` 中搜索方法丢失 `userId` 参数，需恢复

## 非功能需求

### NFR-1: 代码质量
- 所有修改必须通过 `flutter analyze` 检查，无 error 级别问题
- 保持现有代码风格（与修改文件中的风格一致）

### NFR-2: 向后兼容
- 恢复的功能不得破坏当前版本新增的功能（如手势快进快退、NextUp 连播、item_detail_view 等）

### NFR-3: 增量修改
- 修改应尽量最小化，避免对现有架构的大规模改动

## 约束

- **技术**：必须使用与现有代码相同的框架（Flutter + Riverpod + Dio + video_player）
- **依赖**：不得引入新的第三方依赖包
- **版本**：当前 pubspec.yaml 版本需在完成后更新

## 假设

- v1.18.0 中 `isPureModeProvider`、`seekDeltaProvider`、`PlaybackRateNotifier` 的实现是正确且可用的
- 移除 `userId` 参数不会影响单用户场景（但多用户场景可能有问题）
- CI/CD 流程可正常运行

## 验收标准

### AC-1: 纯净模式可用
- **给定**用户在视频播放全屏界面
- **当**用户按下快捷键 P 或点击纯净模式按钮
- **则**所有覆盖层 UI（进度条、标题、控制按钮等）隐藏，仅保留视频画面
- **再次操作**则恢复显示
- **验证**：`programmatic` — 在 `video_page_item.dart` 中查找 `isPureMode` 相关条件渲染，确保逻辑完整
- **备注**：状态需持久化，重启应用后恢复

### AC-2: seekDelta 设置生效
- **给定**用户在播放界面使用遥控器左右方向键
- **当**用户按下方向键
- **则**视频按 `seekDeltaProvider` 中设置的秒数前进/后退
- **验证**：`programmatic` — 检查 `gesture_overlay.dart` 中快捷键处理逻辑使用 `seekDeltaProvider`

### AC-3: 倍速持久化
- **给定**用户在播放界面设置了 1.5x 倍速
- **当**用户退出应用并重新打开
- **则**新播放的视频默认使用 1.5x 倍速
- **验证**：`programmatic` — 检查 `PlaybackRateNotifier` 中 `setPlaybackRate` 方法调用持久化存储

### AC-4: API 调用携带正确 userId
- **给定**用户已登录且 userId 已保存
- **当**用户进行收藏切换、搜索、获取 NextUp 等操作
- **则**API 请求 URL 中包含正确的 userId 路径段
- **验证**：`programmatic` — 检查 `embbytok_service.dart` 中相关方法签名和 URL 构建逻辑

### AC-5: flutter analyze 通过
- **给定**完成所有代码修改
- **当**运行 `flutter analyze --no-pub lib`
- **则**输出中无 error 级别问题
- **验证**：`programmatic` — 执行命令后检查退出码为 0

### AC-6: 不破坏现有新功能
- **给定**完成所有恢复修改
- **当**检查 gesture_overlay.dart、NextUp 连播逻辑、item_detail_view 路由等
- **则**这些新功能正常工作，不受恢复操作影响
- **验证**：`human-judgment` — 代码审查确认新功能代码块未被修改

## 开放问题

- [ ] `DefaultPlaybackRateNotifier`（user_preferences_provider.dart）与 `PlaybackRateNotifier`（video_playback_controller.dart）的职责划分？
- [ ] 是否需要在 settings_view.dart 中新增 seekDelta 和 isPureMode 的设置 UI？
- [ ] userId 参数的移除是否在单用户场景下没有问题？是否所有 API 都支持无 userId 调用？
