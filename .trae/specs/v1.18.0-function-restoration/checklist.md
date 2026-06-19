# v1.18.0 功能恢复 - 验证清单

## 代码变更验证

- [ ] Checkpoint 1: `video_playback_controller.dart` 中 `PlaybackRateNotifier` 已恢复为 `StateNotifier`，且 `playbackRateProvider` 从其派生
- [ ] Checkpoint 2: `PlaybackRateNotifier` 初始化时从 `AppPreferencesService().load()` 加载倍速值
- [ ] Checkpoint 3: `PlaybackRateNotifier.setPlaybackRate(double)` 方法调用 `AppPreferencesService().setPlaybackRate(rate)` 持久化
- [ ] Checkpoint 4: `video_playback_controller.dart` 中新增 `IsPureModeNotifier` 类和 `isPureModeProvider`
- [ ] Checkpoint 5: `IsPureModeNotifier` 支持从持久化加载、切换时保存
- [ ] Checkpoint 6: `video_page_item.dart` 中覆盖层组件（进度条、标题、控制按钮等）使用 `isPureModeProvider` 控制条件渲染
- [ ] Checkpoint 7: `video_controls.dart` 中提供纯净模式切换入口（按钮或键盘快捷键 P）
- [ ] Checkpoint 8: `video_playback_controller.dart` 中新增 `SeekDeltaNotifier` 类和 `seekDeltaProvider`
- [ ] Checkpoint 9: `SeekDeltaNotifier` 支持从持久化加载、设置时保存
- [ ] Checkpoint 10: `gesture_overlay.dart` 中键盘左右方向键处理使用 `ref.read(seekDeltaProvider)` 的秒数
- [ ] Checkpoint 11: `embbytok_service.dart` 中 `getFavoriteMovies`、`getFavoriteBoxSets`、`getFavoritePeople` 方法签名恢复 `String? userId` 参数
- [ ] Checkpoint 12: `embbytok_service.dart` 中 `searchItems`、`searchHints` 方法签名恢复 `String? userId` 参数
- [ ] Checkpoint 13: `embbytok_service.dart` 中 `getRecentlyAdded`、`getRandomItems`、`getNextUp`、`getResumeItems` 等方法签名恢复 `String? userId` 参数
- [ ] Checkpoint 14: 上述方法内部使用 `final effectiveUserId = userId ?? _defaultUserId;` 构建 URL 路径
- [ ] Checkpoint 15: `favorites_provider.dart` 中调用 `_service.getFavoriteMovies(...)` 时传递 `userId: userId` 参数
- [ ] Checkpoint 16: `search_provider.dart` 中搜索调用传递 `userId: auth.user?.id` 参数
- [ ] Checkpoint 17: `video_list_provider.dart` 中 latest/random/resume/favorites 调用传递 `userId` 参数
- [ ] Checkpoint 18: `app_preferences.dart` 中 `AppPreferences` 类新增 `isPureMode` 字段和 `setIsPureMode` 方法
- [ ] Checkpoint 19: `app_preferences.dart` 中 `AppPreferences` 类新增 `seekDelta` 字段和 `setSeekDelta` 方法
- [ ] Checkpoint 20: `constants.dart` 中新增 `kStorageKeyIsPureMode`、`kStorageKeySeekDelta`、`kDefaultSeekDeltaSeconds`

## 运行时行为验证

- [ ] Checkpoint 21: 纯净模式开启时，播放界面的覆盖层 UI 全部隐藏；关闭时恢复显示
- [ ] Checkpoint 22: 纯净模式状态在应用重启后保持
- [ ] Checkpoint 23: 修改播放倍速后，下次打开新视频自动使用上次设置的倍速
- [ ] Checkpoint 24: 遥控器左右方向键按 seekDelta 设置的秒数快进/快退
- [ ] Checkpoint 25: 多用户场景下，每个用户看到自己的收藏列表（通过 userId 参数区分）
- [ ] Checkpoint 26: 搜索结果对不同用户显示正确的内容（通过 userId 参数区分）

## 代码质量验证

- [ ] Checkpoint 27: `flutter analyze --no-pub lib` 输出无 `error •` 行
- [ ] Checkpoint 28: 新增代码与现有代码风格一致（命名、缩进、import 组织等）
- [ ] Checkpoint 29: `item_detail_view.dart`、`gesture_overlay.dart`、`empty_state_card.dart`、`error_state_card.dart`、`tv_focusable.dart`、`preload_controller.dart` 中当前版本新增的功能代码未被意外修改
- [ ] Checkpoint 30: NextUp 连播预加载逻辑（`video_page_item.dart`）未被修改

## 架构一致性验证

- [ ] Checkpoint 31: `PlaybackRateNotifier` 与 `DefaultPlaybackRateNotifier`（user_preferences_provider.dart）职责明确划分，无重复定义冲突
- [ ] Checkpoint 32: 所有恢复的 provider 在 `providers.dart` 中有对应的导出（如需要）
- [ ] Checkpoint 33: `providers.dart` 导出列表完整，无循环引用
