# 手势逻辑重构：VideoGestureMixin

**状态**: Draft  
**创建日期**: 2026-07-20  
**目标版本**: 1.x  
**范围**: 手势导航模块

## 背景

`GestureOverlay`（小屏视频手势层）与 `FullscreenVideoPage`（全屏播放页）各自实现了一套几乎相同的视频手势交互逻辑，约 700+ 行代码重复。两套代码独立演进，已出现功能不一致（如全屏页有亮度调节、GestureOverlay 有左侧垂直滑动死区等），增加维护成本和 bug 风险。

### 重复的功能清单

| 功能 | GestureOverlay | FullscreenVideoPage |
|------|---------------|---------------------|
| 单击/双击判定（300ms Timer） | ✅ | ✅ |
| 水平拖动 seek | ✅ | ✅ |
| 垂直拖动（左亮度/右音量） | 部分（右侧音量） | ✅（两侧都有） |
| 长按倍速 | ✅ | ✅ |
| 双击 ±10s seek 反馈 | ✅ | ✅ |
| 双击爱心动画 | ✅ | ✅ |
| 拖动结束延迟隐藏 | ✅ | ✅ |
| HorizontalDrag 模式（小屏） | ✅ | ❌ |
| Pan 模式（全屏） | 可选 | ✅ |

## 目标

1. 抽取共同手势逻辑到 `VideoGestureMixin`，消除 ~80% 代码重复
2. 保持现有 API 和行为不变，零功能退化
3. 两套代码共享同一套 bug 修复，不再出现"修了一边忘另一边"

## 非目标

- 不改变用户可感知的任何交互行为
- 不添加新功能
- 不重构 UI 布局（控制层、进度条等不动）
- 不改动 `VideoPageItem` 或 `FeedView` 的调用方式

## 方案设计

### 方案选择：Mixin 模式

**选择**: Dart mixin on State，状态和方法都在 mixin 中定义。

**原因**:
- 消除状态 + 方法的双重重复
- 可以直接使用 `mounted`、`setState`、`context`（因为 `on State`）
- 不改变现有组件架构
- UI 构建仍由各自 State 负责，视觉风格可独立演进

### 架构概览

```
┌─────────────────────────────────────────────────────┐
│  VideoGestureMixin (on State)                       │
│  ┌───────────────────────────────────────────────┐  │
│  │ 状态变量（全部）                              │  │
│  │ - 单击/双击：_singleTapTimer, _pendingSingleTap│ │
│  │ - 拖动通用：_isDragging, _dragAxis, _dragStart*│ │
│  │ - 水平 seek：_dragStartPosition, _previewPos* │  │
│  │ - 垂直音量：_isVolumeSide, _volumeStartValue  │  │
│  │ - 长按倍速：_isLongPressing, _originalRate    │  │
│  │ - 双击反馈：_lastTapPosition, _showSeek*      │  │
│  │ - 爱心：_showHeart, _heartHideTimer           │  │
│  │ - Timer：_dragHideTimer, _volumeHideTimer     │  │
│  └───────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────┐  │
│  │ 方法（全部）                                  │  │
│  │ - _handleTap()                                │  │
│  │ - _onDoubleTap() 骨架（子类填充具体逻辑）     │  │
│  │ - _seekBySeconds()                            │  │
│  │ - _onLongPressStart/End() 骨架                │  │
│  │ - _onPanStart/Update/End/Cancel()             │  │
│  │ - _onHorizontalDragStart/Update/End/Cancel()  │  │
│  │ - _endDrag()                                  │  │
│  │ - disposeGestureTimers()                      │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
            ▲                         ▲
            │ with                    │ with
            │                         │
┌──────────────────────┐   ┌──────────────────────────┐
│ _GestureOverlayState │   │ _FullscreenVideoPageState │
│  - 填充回调          │   │  - 填充回调               │
│  - build 中渲染 UI   │   │  - build 中渲染 UI        │
└──────────────────────┘   └──────────────────────────┘
```

### 钩子方法（由子类实现）

mixin 定义抽象/空方法，子类填充具体业务逻辑：

| 钩子方法 | 用途 | GestureOverlay 实现 | 全屏页实现 |
|---------|------|---------------------|-----------|
| `_videoController` | 获取 VideoPlayerController | `widget.controller` | `_watchedController` |
| `_onSingleTap()` | 单击回调 | 调 `widget.onSingleTap` | 调 `_toggleControls` |
| `_onDoubleTapLeft()` | 左侧 1/3 双击 | `_seekBySeconds(-10)` | `_seekBySeconds(-10)` |
| `_onDoubleTapRight()` | 右侧 1/3 双击 | `_seekBySeconds(10)` | `_seekBySeconds(10)` |
| `_onDoubleTapCenter()` | 中间双击 | 点赞 + 爱心 | 点赞 + 爱心 |
| `_shouldHandleLeftVerticalDrag` | 左侧垂直滑动是否处理 | `false`（让父级处理） | `true`（亮度调节） |
| `_onLeftVerticalDragUpdate(double delta)` | 左侧垂直拖动 | 空 | 调亮度 |
| `_onSeekTo(Duration target)` | 执行 seek | 调 `controller.seekTo` | 调 `controller.seekTo` |
| `_onSetVolume(double value)` | 设置音量 | 调 `controller.setVolume` | 调 `controller.setVolume` |
| `_item` | 获取当前 MediaItem（用于点赞） | `widget.item` | 当前播放项 |
| `_enableGestures` | 手势是否启用 | `widget.enableGestures` | `!_controlsVisible` |

### 状态变量迁移清单

**全部迁入 mixin 的状态**（两边完全一致）：

```dart
// 单击/双击
Timer? _singleTapTimer;
bool _pendingSingleTap = false;
Offset? _lastTapPosition;

// 拖动通用
bool _isDragging = false;
String? _dragAxis;  // 'h' / 'v' / null
double _dragStartX = 0.0;
double _dragStartY = 0.0;

// 水平拖动 seek
Duration _dragStartPosition = Duration.zero;
Duration _previewPosition = Duration.zero;
// 注：ValueNotifier 版也一并迁入

// 垂直音量
bool _isVolumeSide = false;
double _volumeStartValue = 0.0;

// 长按倍速
bool _isLongPressing = false;
double _originalRate = 1.0;
bool _showSpeedBadge = false;

// 双击 seek 反馈
bool _showSeekFeedback = false;
bool _isSeekForward = false;
int _seekFeedbackCount = 0;
Timer? _seekFeedbackResetTimer;

// 爱心
bool _showHeart = false;
Timer? _heartHideTimer;

// 拖动隐藏延迟
Timer? _dragHideTimer;
Timer? _volumeHideTimer;
```

**不迁入 mixin 的状态**（两边差异大）：

- `_showSeekPreview`（两边都有但逻辑略不同，各自保留）
- `_showVolumeUI`（两边都有，逻辑一致，可以迁入）
- `_volumePreviewValue` / `_previewVolume`（命名不同，逻辑一致，迁入后统一命名）
- 亮度相关状态（仅全屏页有，不迁入）
- 控制层显隐（仅全屏页有，不迁入）

### UI 构建

mixin **不**提供 build 方法。各自的 `GestureDetector` 仍在各自的 build 中配置，但回调直接调 mixin 方法。

手势反馈 UI（SeekPreviewBar、音量指示器、倍速徽章、爱心、seek 反馈）仍由各自的 build 方法构建，但状态从 mixin 读取。

mixin 可以提供一个辅助方法 `buildGestureFeedbackWidgets()` 返回 `List<Widget>`，两边在 Stack children 末尾 `...spread` 进去，减少 UI 代码重复。

## 实施阶段

### Phase 1：创建 mixin 骨架 + GestureOverlay 迁移

1. 新建 `lib/widgets/video/video_gesture_mixin.dart`
2. 定义 `VideoGestureMixin<T extends StatefulWidget> on State<T>`
3. 迁移状态变量 + 核心方法到 mixin
4. `_GestureOverlayState` 改为 `with VideoGestureMixin`
5. 填充 GestureOverlay 侧的钩子方法实现
6. 验证 GestureOverlay 行为不变

### Phase 2：FullscreenVideoPage 迁移

1. `_FullscreenVideoPageState` 改为 `with VideoGestureMixin`
2. 删除全屏页中重复的状态和方法
3. 填充全屏页侧的钩子方法实现
4. 验证全屏页行为不变

### Phase 3：收尾 + 测试

1. 提取 `buildGestureFeedbackWidgets()` 辅助方法，减少 UI 重复
2. 补充测试（如果有 widget 测试框架）
3. 代码 review + 清理

## 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| mixin 状态与子类状态命名冲突 | 中 | 编译错误 | 迁移时逐步删除子类变量，IDE 会报错 |
| 行为不一致（如 seek 灵敏度） | 低 | 用户感知 | 两边都用 mixin 同一套常量，反而更一致 |
| 改动过大导致回归 bug | 中 | 功能异常 | 分两阶段迁移，每阶段单独验证 |
| 钩子方法数量过多 | 低 | 代码复杂度 | 控制在 10 个以内，默认实现减少子类工作量 |

## 测试策略

- 手动回归测试：小屏（FeedView）和全屏各测一遍所有手势
- 检查清单：单击、双击左/中/右、水平拖动 seek、垂直音量、长按倍速、爱心动画、seek 反馈

## 成功标准

1. `GestureOverlay` 和 `FullscreenVideoPage` 都能编译通过
2. 所有手势行为与重构前一致（无功能退化）
3. 代码行数减少约 500+ 行（消除重复）
4. 新增 `video_gesture_mixin.dart` 约 500 行
