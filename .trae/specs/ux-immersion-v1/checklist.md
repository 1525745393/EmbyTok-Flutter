# EmbyTok 沉浸式体验优化 - Verification Checklist

## 核心功能验证

- [ ] Checkpoint 1: 视频切换动画存在且时长为 200ms
  - `video_page_item.dart` 中动画组件的 `duration = 200ms`（通过代码审查或 `AnimatedOpacity` 的参数）
  - 切换到新视频时视觉上可感知渐入效果

- [ ] Checkpoint 2: `isReady` 状态正确传递
  - `video_playback_controller.dart` 中存在一个可被 `ref.watch` 的 provider，返回当前视频是否"初始化完成且首帧可渲染"
  - 未 ready 时 `AnimatedOpacity` 保持透明（或显示骨架屏），ready 后渐变

- [ ] Checkpoint 3: 预加载阈值默认 60%，可通过 provider 读取
  - `ref.watch(preloadThresholdProvider)` 返回 0.6
  - 若支持用户偏好覆盖，`user_preferences_provider.dart` 中能读到对应字段

- [ ] Checkpoint 4: 预加载缓存最大 2 个 controller，超出自动 dispose
  - 代码中可见 LRU/大小限制逻辑，或明确的 map 清理逻辑
  - dispose 路径在 `VideoPageItemState.dispose` 或 `FeedViewState.dispose` 中覆盖

- [ ] Checkpoint 5: 非 WiFi 环境预加载降级
  - 代码中存在 `ConnectivityResult` 或等效的网络状态判断
  - 非 WiFi 下不会预取完整视频（仅首段或不预取）

- [ ] Checkpoint 6: 播放器错误 UI 正确显示并可重试
  - `controller.value.hasError == true` 时，视频区域被错误卡片覆盖
  - 点击"重试"按钮触发 `initialize() + play()`
  - 最多重试 3 次（代码中的重试计数器可见）
  - 3 次失败后显示降级错误 UI："无法播放此视频"

- [ ] Checkpoint 7: 8 秒加载超时
  - `video_player_widget.dart` 中存在 8 秒超时检测 Timer
  - 超时触发后，`hasError` 被设置为 true，日志中记录 "video load timeout"

- [ ] Checkpoint 8: 空列表状态正确显示
  - `filteredVideoListProvider` 返回空列表且加载完成时，feed 视图显示空状态卡片
  - 卡片中包含可操作的按钮（如"选择其他媒体库"），点击有响应

- [ ] Checkpoint 9: 双击点赞触发 haptic 反馈
  - `gesture_overlay.dart` 的 `_onDoubleTap` 中调用 `HapticFeedback.lightImpact()`
  - 同时保留原有的 heart 动画

- [ ] Checkpoint 10: 长按与水平拖动有 haptic 反馈
  - 长按：`HapticFeedback.mediumImpact()`
  - 水平拖动进度每跨越 5 秒：`HapticFeedback.selectionClick()`

- [ ] Checkpoint 11: Web 平台 haptic 降级为视觉动画
  - 代码中存在 `kIsWeb` 判断
  - Web 下双击点赞触发 scale 抖动动画（替代 haptic）

- [ ] Checkpoint 12: 首次使用引导显示并在 3 次滑动后消失
  - `app_preferences` 中存在 `feedGuideShown` 键，可读写
  - `feed_view.dart` 中引导层在 onPageChanged 计数 ≥ 3 后淡出并从 tree 移除
  - 清除数据后重新进入 feed 视图可再次看到（持久化正确）

- [ ] Checkpoint 13: 颜色常量一致性
  - 本次新增/修改的所有 Dart 文件中，颜色值均来自 `utils/colors.dart`
  - `grep -n "Colors\.\|Color(0x" lib/views/<modified_files> lib/widgets/<modified_files>` 无新的硬编码颜色

- [ ] Checkpoint 14: `flutter analyze lib` 通过，无 error
  - CI 中的 `flutter analyze lib` 步骤通过，exit code 为 0

- [ ] Checkpoint 15: 可访问性标签完整
  - 所有新增交互组件（错误按钮、引导层操作等）都有 `Semantics` 标签
  - 视频播放区的 `Semantics` 描述清晰（如"双击点赞此视频"）

## 性能与内存验证

- [ ] Checkpoint 16: 滑动帧率稳定
  - Profile 模式下，连续滑动 20 条视频，平均帧率 ≥ 55fps
  - 单帧重建耗时 < 16ms（Flutter Performance Overlay 观察）

- [ ] Checkpoint 17: 内存可控
  - 连续滑动 50 条视频后，内存峰值相比优化前不增长 > 15%
  - dispose 路径正确，无明显泄漏（DevTools 内存快照对比）
