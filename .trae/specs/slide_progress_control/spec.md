# EmbyTok 滑动进度控制 - 产品需求文档

## Overview
- **Summary**: 在视频流播放页面增加水平滑动进度控制功能：用户在视频画面上水平拖动（左滑快退/右滑快进）时，屏幕中央显示半透明进度条浮层，实时展示当前播放位置、目标时间、进度百分比和方向指示，并提供触觉反馈。拖动结束后，进度条自动淡出。
- **Purpose**: 当前的水平拖动 seek 功能是"盲操作"——用户看不到拖动到了什么位置，只能依靠模糊的感觉。缺少可视化进度反馈导致用户难以精确定位到想要观看的时间点。进度条让用户在拖动过程中明确知道：现在在哪、将滑到哪、滑了多远，大幅提升交互的可控性和用户体验。
- **Target Users**: 所有在手机竖屏模式下浏览视频流的用户，尤其是观看较长内容（电影、电视剧、纪录片）时需要快进/快退定位的用户。

## Goals
1. 在水平拖动期间，屏幕中央显示可视化进度条，清晰展示当前播放位置
2. 进度条显示时间信息：目标时间 / 总时长（如 `00:05:23 / 01:30:00`）
3. 显示方向指示（快进 ⏩ 图标 / 快退 ⏪ 图标）和偏移量（如 `+12s` 或 `-45s`）
4. 拖动期间保持平滑的动画和清晰的视觉反馈（淡入淡出 + 伸缩效果）
5. 与现有手势系统无冲突：不影响单击播放/暂停、双击点赞、长按倍速、垂直滑动切换视频
6. 增强触觉反馈：拖动开始、结束、到达 5 秒边界时触发震动

## Non-Goals (Out of Scope)
- 不修改现有的垂直滑动切换视频功能
- 不增加额外的底部进度条（视频播放器自身可能已有进度条）
- 不改变单击/双击/长按的行为逻辑
- 不增加音量/亮度滑动控制（保持单一的水平方向含义：播放进度）
- 不增加精确到毫秒级的定位精度（5 秒粒度足够）
- 不改变 grid 视图模式的任何逻辑

## Background & Context
- **当前手势系统** (`gesture_overlay.dart`): 已经实现了水平拖动 seek 的业务逻辑 (`_onHorizontalDragStart/Update/End`)，每像素 = 100ms 播放时间，每跨越 5 秒边界触发一次 `HapticFeedback.selectionClick()`。但**没有任何视觉反馈**（除触觉外）。
- **视频控制器**: `VideoPlayerController` 提供 `value.position`（当前位置）、`value.duration`（总时长）、`seekTo(Duration)`（定位）、`value.isInitialized`（是否就绪）。
- **相关常量** (`constants.dart`): `kSeekPerPixelMs = 100`, `kSwipeProgressIntervalSeconds = 5`, `kLongPressPlaybackRate = 2.0`。
- **状态管理**: 使用 Riverpod (`toolbarVisibilityProvider`, `isPlayingProvider`, `playbackRateProvider` 等)，但目前没有专门的"拖动进度状态"provider。
- **布局结构**: `FeedView` → `VideoPageItem` → `GestureOverlay` (包裹 `VideoPlayerWidget`)。进度条应该添加在 `GestureOverlay` 内部的 `Stack` 中，与视频同层，叠加在最上方。

## Functional Requirements
- **FR-1 触发条件**: 用户在视频流播放页面按住并水平拖动（`onHorizontalDragStart` 触发）时，进度条浮层显示。需要视频控制器已初始化 (`controller.value.isInitialized`)。
- **FR-2 进度条显示**: 拖动期间，屏幕中上方显示进度条浮层，包含：
  - 方向 + 偏移量：如 `⏪ -45s` 或 `⏩ +12s`
  - 当前目标时间 / 总时长：如 `00:05:23 / 01:30:00`
  - 可视化进度条：填充部分 = 当前进度百分比，底部为总时长刻度
  - 小三角形指示当前播放位置在进度条上的位置
- **FR-3 实时更新**: 拖动过程中，随着手指水平移动，进度条的时间、百分比、方向指示**实时更新**（约每 16-33ms 一次，即 30-60 FPS）。
- **FR-4 自动隐藏**: 拖动结束 (`onHorizontalDragEnd` 或 `onHorizontalDragCancel`) 后，进度条在 600ms 内淡出并消失。
- **FR-5 触觉反馈**:
  - 拖动开始时：`HapticFeedback.selectionClick()`（轻触）
  - 拖动过程中每 5 秒跨越：`HapticFeedback.selectionClick()`（已存在）
  - 拖动结束时：`HapticFeedback.lightImpact()`（轻震）
- **FR-6 动画效果**:
  - 进度条进入：`AnimatedOpacity` + `AnimatedContainer` 0 → 1.0 透明度，同时从 80% 宽度扩展到 90% 宽度（150ms 弹性动画）
  - 进度条退出：`AnimatedOpacity` 1.0 → 0（300ms 淡出）
  - 进度条填充动画：随手指移动平滑伸缩（`AnimatedContainer` 或 `TweenAnimationBuilder`）
- **FR-7 边界处理**:
  - 拖动到视频起始（0:00）时，进度条显示 `00:00:00`，且不再允许继续后退
  - 拖动到视频末尾（总时长）时，进度条显示总时长，不再允许继续前进
  - 视频时长为 0 或未初始化时，不显示进度条
- **FR-8 与其他手势的协同**:
  - 水平拖动开始后，单击/双击逻辑不应被触发（通过 `_isDragging` 标志位已实现）
  - 垂直滑动切换视频不会触发进度条（因为使用 `onHorizontalDrag`）
  - 长按倍速与水平拖动是互斥的（由 Flutter `GestureDetector` 的竞技场机制决定）

## Non-Functional Requirements
- **NFR-1 性能**: 进度条的更新不影响视频播放帧率。在中端设备上应保持 55-60 FPS。使用 `setState` 轻量更新，避免频繁重建整个视频播放栈。
- **NFR-2 视觉一致性**: 进度条浮层的配色与现有 UI 风格一致：深色半透明背景 (`overlayBlack`)、粉色强调色 (`primaryPink`)、白色文字 (`textPrimary`)。
- **NFR-3 响应式**: 在不同屏幕尺寸下（小屏 5 寸手机到大屏 7 寸平板），进度条保持合理的尺寸与位置：宽度 = 屏幕宽度的 80-90%，距离屏幕顶部 120-160px。
- **NFR-4 代码组织**: 进度条浮层组件封装在 `gesture_overlay.dart` 内作为私有子组件（类似 `_FlyingHeart` 和 `_SpeedBadge`），保持文件结构清晰，不引入新文件（除非逻辑确实过长，超过 100 行，此时考虑分离为独立文件）。

## Constraints
- **技术**: 使用 Flutter 原生组件和动画（`AnimatedOpacity`, `AnimatedContainer`, `TweenAnimationBuilder`, `Stack`, `Positioned`）。不依赖第三方动画库。
- **平台**: 适配 Android 6.0+。iOS 暂不测试，但应保持 Flutter 跨平台兼容性。
- **向后兼容**: 不破坏现有任何功能（单击/双击/长按倍速/垂直滑动/工具栏切换/网格视图）。
- **依赖**: 现有的 `VideoPlayerController`、`HapticFeedback`、`constants.dart` 中的常量。

## Assumptions
- `_isDragging` 标志位已经可以在 `setState((){})` 的回调中正确触发 UI 重绘来显示/隐藏进度条。
- 手指水平移动时 `_onHorizontalDragUpdate` 被高频调用（~每 16ms），足够实现实时更新。
- `HapticFeedback.selectionClick()` 和 `HapticFeedback.lightImpact()` 在目标设备上都可用。
- 与 `PageView` 的垂直滑动无冲突——Flutter `GestureDetector` 天然区分水平/垂直手势。
- 进度条不需要持久保存用户的拖动行为，拖动结束即消失。

## Acceptance Criteria

### AC-1: 水平拖动触发进度条
- **Given**: 用户在手机竖屏模式下观看视频流，视频已加载并播放
- **When**: 用户用一根手指按住屏幕并水平拖动（`onHorizontalDragStart` 触发）
- **Then**: 屏幕中上方显示半透明进度条浮层，显示当前播放位置信息
- **Verification**: `human-judgment`
- **Notes**: 进度条在 150ms 内淡入，不应有闪烁或跳跃

### AC-2: 进度条显示方向和时间信息
- **Given**: 用户正在水平拖动视频
- **When**: 用户向右滑动（快进）或向左滑动（快退）
- **Then**: 进度条显示：方向图标（右滑显示 `⏩`，左滑显示 `⏪`）、偏移量（如 `+12s` 或 `-45s`）、目标时间/总时长（如 `00:05:23 / 01:30:00`）
- **Verification**: `human-judgment`

### AC-3: 进度条实时更新
- **Given**: 用户正在水平拖动视频
- **When**: 手指水平移动
- **Then**: 进度条的时间信息、偏移量、填充宽度实时更新（跟随手指移动）
- **Verification**: `human-judgment`
- **Notes**: 更新应流畅（30+ FPS），无明显延迟

### AC-4: 拖动结束进度条淡出
- **Given**: 用户正在水平拖动视频
- **When**: 用户松开手指（`onHorizontalDragEnd` 或 `onHorizontalDragCancel`）
- **Then**: 进度条在 300ms 内平滑淡出，视频从新位置继续播放
- **Verification**: `human-judgment`

### AC-5: 触觉反馈
- **Given**: 用户正在水平拖动视频
- **When**: 拖动开始、拖动结束、每跨越 5 秒边界
- **Then**: 设备触发触觉反馈（`selectionClick` 或 `lightImpact`）
- **Verification**: `human-judgment`
- **Notes**: 5 秒边界的反馈应轻柔（selectionClick），结束时稍强（lightImpact）

### AC-6: 边界保护
- **Given**: 用户正在水平拖动视频
- **When**: 拖动目标位置 < 0 或 > 总时长
- **Then**: 进度条停在 0% 或 100%，不显示无效的时间，不触发错误
- **Verification**: `human-judgment`

### AC-7: 不与其他手势冲突
- **Given**: 用户在视频播放页面
- **When**: 用户单击暂停/播放、双击点赞、长按倍速、垂直滑动切换视频
- **Then**: 相应功能正常工作，进度条不会被错误触发
- **Verification**: `human-judgment`

### AC-8: 不影响网格视图
- **Given**: 用户切换到网格视图（`ViewMode.grid`）
- **When**: 浏览视频卡片网格
- **Then**: 水平滑动在卡片上的行为保持原样，不触发进度条
- **Verification**: `human-judgment`

### AC-9: 性能表现
- **Given**: 用户在中端 Android 设备（如 Pixel 5 / 小米 10 同等性能）上使用
- **When**: 进行快速的水平拖动和释放
- **Then**: 视频播放保持流畅，动画无丢帧，进度条更新响应及时
- **Verification**: `human-judgment`

### AC-10: 代码组织清晰
- **Given**: 开发人员审阅代码
- **When**: 查看 `gesture_overlay.dart`
- **Then**: 进度条浮层封装为独立的 `_ProgressBarOverlay` 子组件，代码有清晰的中文注释，逻辑与 UI 分离合理
- **Verification**: `human-judgment`

## Open Questions
- [ ] 进度条的具体位置？是屏幕中上方（距离顶部 120-160px），还是屏幕底部（距离底部 200px）？ 当前设计选择中上方，因为那里与视频内容重叠最少，且工具栏/导航栏在那。
- [ ] 时间显示格式？ `HH:MM:SS` 还是 `MM:SS`？总时长超过 1 小时时用前者，否则用后者。
- [ ] 是否需要在进度条下方增加一个小的"圆点指示器"，表明手指当前的相对位置？当前设计已有填充比例，可能已经足够。
- [ ] 拖动结束后，是否需要短暂显示最终位置（如 "已快进到 00:05:23" 提示）？还是直接淡出？为简洁起见，当前设计选择直接淡出。
- [ ] 是否需要"锁定"拖动（即用户可以先锁定到某个方向，避免误触垂直 PageView）？Flutter GestureDetector 的 `onHorizontalDrag` 天然与垂直滑动不冲突，这个应该不是问题。
