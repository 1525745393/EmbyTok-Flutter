# 播放器控制功能增强 - 实施计划

## [ ] Task 1：新增基础 Provider - 纯净模式、自动播放状态
- **优先级**：P0
- **依赖**：无
- **描述**：
  - 新增 `isPureModeProvider` (StateNotifier)：纯净模式开关，支持持久化。
  - 确认 `isAutoPlayProvider`（检查是否已有，没有则创建）：自动播放下一条开关，支持持久化。
  - 新增 `playbackRatesProvider`：提供 6 档速度列表与当前索引。
  - 在 `lib/utils/app_preferences.dart`（如已存在）中扩展读写键。
- **验收标准**：AC-1（纯净模式状态基础）、AC-8（自动播放状态基础）
- **测试需求**：
  - 代码走查 `programmatic`：新 Provider 正确初始化、更新、持久化。
  - `programmatic`：热重启后状态保持不变。
- **备注**：注意 `flutter_riverpod` 版本差异（`ref.watch` vs `ref.read` 用法）

## [ ] Task 2：扩展 `video_controls.dart` - 播放速度选择面板
- **优先级**：P0
- **依赖**：Task 1
- **描述**：
  - 将倍速按钮从 TextButton 改为可触发 showModalBottomSheet 的按钮。
  - 面板展示 6 档速度（0.5x/0.75x/1.0x/1.25x/1.5x/2.0x）。
  - 当前速度高亮，选中后更新 `playbackRateProvider` state。
  - 更新 VideoPlayerController 的 setPlaybackSpeed。
  - 保留长按倍速逻辑 - 长按期间临时 2x，松开回到用户选择的基准倍速。
- **验收标准**：AC-2、AC-3
- **测试需求**：
  - `programmatic`：点击倍速按钮能正确弹出面板；选择面板中的速度后视频播放速度变更。
  - `human-judgement`：选择面板样式与整体 TikTok 风格一致，视觉协调。
  - `programmatic`：长按期间为 2x，松开恢复到用户之前选择的速度。
- **备注**：面板高度需考虑安全区，避免被底部导航遮挡

## [ ] Task 3：扩展 `video_controls.dart` - 上一集/下一集按钮
- **优先级**：P0
- **依赖**：Task 1
- **描述**：
  - 在播放/暂停按钮两侧增加 skip_previous / skip_next 图标按钮。
  - 需要新的 Provider 暴露当前播放列表索引及切换函数（如 `currentIndexProvider` 的扩展）。
  - `video_page_item.dart` 中提供回调 `onSkipNext` / `onSkipPrevious`。
  - 按钮在首条（上一集）或末条（下一集）时显示为禁用状态。
- **验收标准**：AC-4
- **测试需求**：
  - `programmatic`：按钮可用性逻辑在首条/中间/末条正确切换。
  - `human-judgement`：按钮位置与视觉风格与整体一致，触摸目标 >= 44dp。

## [ ] Task 4：智能进度条策略 - 时长阈值判断
- **优先级**：P0
- **依赖**：无
- **描述**：
  - `video_page_item.dart` 中的 `_ThinProgressBar` 渲染前置判断：仅当 `controller.value.duration >= 3 分钟` 时才渲染。
  - 新增常量 `kMinDurationForProgressBar`（Duration(minutes: 3)）。
  - 拖动预览条 `_SeekPreviewBar` 不受此限制，始终在拖动时渲染。
- **验收标准**：AC-5
- **测试需求**：
  - `programmatic`：短/长两条测试视频在播放时底部进度条表现符合预期。
  - `programmatic`：拖动时两条视频均能显示预览条与时间戳。

## [ ] Task 5：纯净模式 UI 隐藏逻辑
- **优先级**：P1
- **依赖**：Task 1
- **描述**：
  - 在 `video_page_item.dart` 的 Stack 中，为右侧操作栏、底部渐变标题、底部控制条等包裹 AnimatedOpacity，绑定 `isPureModeProvider` 状态。
  - 单击逻辑扩展：纯净模式下单击屏幕会先退出纯净模式（同时显示控制条），否则切换控制条显示（保持原逻辑）。
  - 动画时长：300ms。
  - 在右侧操作栏增加"纯净模式"切换按钮（图标：visibility_off / visibility）。
- **验收标准**：AC-1
- **测试需求**：
  - `programmatic`：纯净模式开启后所有覆盖 UI 渐隐，单击后重新渐显。
  - `human-judgement`：动画流畅，无闪烁感。

## [ ] Task 6：自动播放控制与提示
- **优先级**：P1
- **依赖**：Task 1
- **描述**：
  - 在 `video_controls.dart` 右侧增加自动播放开关图标（如 autoplay / toggle）。
  - 图标绑定 `isAutoPlayProvider` 状态，状态 On/Off 有视觉区分。
  - 在 `video_page_item.dart` 监听 `video_player` 的 `initialized` + `position == duration`（视频播放完成）时，如 `isAutoPlay` 开启则自动触发 `onSkipNext` 回调。
  - 在进度条接近末尾时（剩余 < 3 秒）展示"即将播放下一条"提示（可选）。
- **验收标准**：AC-8
- **测试需求**：
  - `programmatic`：自动播放开启时视频结束后自动切换下一条；关闭时停止在当前视频末尾。
  - `human-judgement`：自动播放状态图标清晰，点击反馈流畅。

## [ ] Task 7：TV 模式与遥控器支持
- **优先级**：P1
- **依赖**：Task 5、Task 6
- **描述**：
  - 新增 `isTvModeProvider`：TV 模式开关，基于屏幕尺寸（短边 > 800dp）自动检测，提供手动覆盖。
  - `video_page_item.dart` 中包裹 `Shortcuts` + `Intent` + `Actions` 处理遥控器按键：
    - 方向键上/下 -> 切换视频上一条/下一条
    - 方向键左/右 -> 快退/快进 10 秒
    - OK/Enter -> 播放/暂停
    - ESC/返回 -> 退出全屏/返回
  - TV 模式下字体与间距整体放大（`textScaleFactor` 或自定义主题）。
  - `Focus` widget 管理焦点，当前聚焦元素边框高亮 + 轻微缩放。
- **验收标准**：AC-6
- **测试需求**：
  - `human-judgement`：在大屏设备/模拟器上，遥控器按键响应正确，焦点高亮明显。
  - `programmatic`：非 TV 模式下 TV 相关逻辑不触发，不影响普通触摸操作。
- **备注**：这是最大的一个任务，建议拆分子提交

## [ ] Task 8：随机浏览模式
- **优先级**：P2
- **依赖**：无
- **描述**：
  - 在顶部工具栏（或媒体库选择器）新增"随机"模式选项。
  - 随机模式：调用 `getLibraryItems` 时 `sortBy=Random`（如 Emby API 支持），或拉取一批后客户端 shuffle。
  - 拉取数量：80 条（与参考项目一致），由新常量 `kRandomListSize` 控制。
  - 与"最新"、"收藏"并列的状态管理：可能需要新的 `feedTypeProvider`。
- **验收标准**：AC-7
- **测试需求**：
  - `programmatic`：切换到随机模式后播放列表刷新为新的随机内容。
  - `human-judgement`：切换动画与进入"最新"模式一致，体验流畅。

## [ ] Task 9：播放状态上报一致性增强
- **优先级**：P2
- **依赖**：Task 2、Task 3、Task 6
- **描述**：
  - 确认倍速变更时触发 `_reportPlaybackProgress`（当前已有节流逻辑，需要确保速度变更在节流中）。
  - 确认 skip next/prev 触发 `_reportPlaybackStopped`（停止旧）+ `_reportPlaybackStart`（新视频）。
  - 确认 seek 操作上报正确的新位置（拖动结束时）。
  - 检查 `video_list_provider.dart` 中播放列表是否正确映射到 `currentPlayingItemProvider`。
- **验收标准**：AC-9
- **测试需求**：
  - `programmatic`：在倍速变更、切换视频、拖动进度后 Emby 服务器侧播放状态反映了这些操作。

## [ ] Task 10：整体集成测试与文档
- **优先级**：P2
- **依赖**：Task 1-9 全部完成
- **描述**：
  - 端到端走查：登录 -> 选择库 -> 切换浏览模式 -> 播放视频 -> 测试所有新功能。
  - 检查长视频/短视频、横屏/竖屏视频在不同模式下的表现。
  - 更新 README_CN.md（如需要）中的功能清单截图。
  - 检查所有常量/键名/文件名的一致性与英文命名规范。
- **验收标准**：AC-10
- **测试需求**：
  - `human-judgement`：完整流程测试，无明显 Bug 或体验缺陷。
  - `programmatic`：确认无编译警告、无未使用 import、`flutter analyze` 通过。
