# v1.18.0 功能恢复 - 实施计划（任务分解与优先级列表）

## [ ] Task 1: 恢复 PlaybackRateNotifier 倍速持久化
- **优先级**：P0
- **依赖**：无
- **描述**：
  - 将 `frontend/lib/providers/video_playback_controller.dart` 中的 `playbackRateProvider` 从 `StateProvider<double>` 恢复为带持久化的 `StateNotifier<PlaybackRateNotifier, double>`
  - `PlaybackRateNotifier` 需从 `AppPreferencesService` 加载初始倍速，并在 `setPlaybackRate` 时保存
  - 检查 `DefaultPlaybackRateNotifier`（位于 `user_preferences_provider.dart`）是否与此重复，如重复则移除其中一个并统一引用
  - 修改点：`video_playback_controller.dart` 中的 provider 定义、`video_controls.dart` 中倍速选择调用
- **验收标准 addressed**：AC-3（倍速持久化）
- **测试要求**：
  - `programmatic` TR-1.1：`PlaybackRateNotifier` 初始化时调用 `AppPreferencesService().load()` 获取保存的倍速
  - `programmatic` TR-1.2：`setPlaybackRate` 方法调用 `AppPreferencesService().setPlaybackRate(rate)` 保存
  - `programmatic` TR-1.3：`gesture_overlay.dart` 中长按恢复倍速时，从 `playbackRateProvider` 读取（当前已是 `ref.read(playbackRateProvider)`，应保持兼容）
  - `programmatic` TR-1.4：`settings_view.dart` 中倍速设置调用 `playbackRateProvider` 而非 `defaultPlaybackRateProvider`（或统一设计）
- **备注**：需注意 `user_preferences_provider.dart` 中已有 `DefaultPlaybackRateNotifier` 和 `defaultPlaybackRateProvider`，设计上需要决定是否合并为单一 provider

## [ ] Task 2: 恢复 isPureModeProvider 纯净模式
- **优先级**：P0
- **依赖**：无
- **描述**：
  - 在 `frontend/lib/providers/video_playback_controller.dart` 中新增 `IsPureModeNotifier` 和 `isPureModeProvider`
  - `IsPureModeNotifier` 需从 `AppPreferencesService` 加载初始状态，并在切换时保存
  - 在 `frontend/lib/widgets/video_page_item.dart` 中恢复纯净模式相关的条件渲染逻辑（隐藏覆盖层）
  - 在 `frontend/lib/widgets/video_controls.dart` 中新增纯净模式切换按钮（或支持键盘快捷键 P）
  - 在 `frontend/lib/utils/app_preferences.dart` 中添加 `isPureMode` 字段和持久化支持
  - 在 `frontend/lib/utils/constants.dart` 中添加相关常量
- **验收标准 addressed**：AC-1（纯净模式可用）
- **测试要求**：
  - `programmatic` TR-2.1：`isPureModeProvider` 存在且为 `StateNotifierProvider`
  - `programmatic` TR-2.2：`IsPureModeNotifier.setEnabled(bool)` 方法存在且调用持久化存储
  - `programmatic` TR-2.3：`video_page_item.dart` 中覆盖层组件使用 `isPureModeProvider` 控制显示/隐藏
  - `human-judgment` TR-2.4：代码审查确认纯净模式不影响手势快进快退（`gesture_overlay.dart`）和 NextUp 连播逻辑
- **备注**：需新增 `kStorageKeyIsPureMode` 常量，以及 `AppPreferences` 中 `isPureMode` 字段

## [ ] Task 3: 恢复 seekDeltaProvider 快进快退设置
- **优先级**：P1
- **依赖**：无
- **描述**：
  - 在 `frontend/lib/providers/video_playback_controller.dart` 中新增 `SeekDeltaNotifier` 和 `seekDeltaProvider`
  - 支持的选项：5、10（默认）、15、30、60 秒
  - 在 `frontend/lib/widgets/gesture_overlay.dart` 中键盘快进/快退逻辑使用 `seekDeltaProvider` 的值
  - 在 `frontend/lib/widgets/video_controls.dart` 中提供 seekDelta 设置入口（如子菜单）
  - 持久化到 `AppPreferencesService`
- **验收标准 addressed**：AC-2（seekDelta 设置生效）
- **测试要求**：
  - `programmatic` TR-3.1：`seekDeltaProvider` 存在且返回 `int` 类型
  - `programmatic` TR-3.2：`gesture_overlay.dart` 中键盘左右方向键处理使用 `seekDeltaProvider` 的秒数
  - `programmatic` TR-3.3：`AppPreferencesService` 中 `seekDelta` 字段的 load/save 实现
- **备注**：需在常量文件中新增 `kDefaultSeekDeltaSeconds` 和 `kStorageKeySeekDelta`

## [ ] Task 4: 恢复 embbytok_service 显式 userId 支持
- **优先级**：P0
- **依赖**：无
- **描述**：
  - 在 `frontend/lib/services/embbytok_service.dart` 中恢复以下方法的 `String? userId` 参数：
    - `getRecentlyAdded`
    - `getFavorites` / `getFavoriteMovies` / `getFavoriteBoxSets` / `getFavoritePeople`
    - `getItemsByGenre` / `getItemsByStudio`
    - `getNextUp`
    - `getResumeItems`
    - `getTrailers`
    - `searchItems` / `searchHints`
    - `getLibraryItems` / `queryItems`
  - 每个方法内部使用 `final effectiveUserId = userId ?? _defaultUserId;` 构建 URL 路径
  - 在 `frontend/lib/providers/favorites_provider.dart` 中恢复调用时传递 `userId: auth.user?.id`
  - 在 `frontend/lib/providers/search_provider.dart` 中恢复调用时传递 `userId: auth.user?.id`
  - 在 `frontend/lib/providers/video_list_provider.dart` 中恢复调用时传递 `userId: auth.user?.id`
- **验收标准 addressed**：AC-4（API 调用携带正确 userId）
- **测试要求**：
  - `programmatic` TR-4.1：上述方法签名包含可选参数 `String? userId`
  - `programmatic` TR-4.2：方法内部 `effectiveUserId` 正确赋值
  - `programmatic` TR-4.3：`favorites_provider.dart` 中 `_service.getFavoriteMovies` 等调用传递 `userId: userId`
  - `programmatic` TR-4.4：`search_provider.dart` 中搜索调用传递 `userId: auth.user?.id`
  - `programmatic` TR-4.5：`video_list_provider.dart` 中 latest/random/resume/favorites 调用传递 `userId`
- **备注**：需小心处理 feedType 模式下的代码，避免破坏现有逻辑结构

## [ ] Task 5: Flutter analyze 通过检查与修复
- **优先级**：P0
- **依赖**：Task 1, 2, 3, 4
- **描述**：
  - 运行 `flutter analyze --no-pub lib` 检查修改后是否有新的 error 级别问题
  - 修复所有引入的错误（未使用的 import、类型不匹配等）
  - 确认 warning 级别问题不影响构建（可保留）
- **验收标准 addressed**：AC-5（flutter analyze 通过）、AC-6（不破坏新功能）
- **测试要求**：
  - `programmatic` TR-5.1：`flutter analyze --no-pub lib` 输出中无 `error •` 行
  - `human-judgment` TR-5.2：代码审查确认 `item_detail_view.dart`、`gesture_overlay.dart`、`empty_state_card.dart`、`error_state_card.dart`、`tv_focusable.dart` 未被意外修改
- **备注**：这是一个整合检查任务，必须在所有代码修改完成后执行

## 任务依赖关系图

```
Task 1 (PlaybackRate) ──┐
Task 2 (isPureMode)  ───┤
Task 3 (seekDelta)   ───┼──> Task 5 (analyze 检查)
Task 4 (userId)      ───┘
```

Task 1-4 可并行执行，Task 5 在 1-4 全部完成后执行。
