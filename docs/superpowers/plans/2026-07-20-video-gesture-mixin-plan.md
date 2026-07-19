# VideoGestureMixin 重构实施计划

> **For agentic workers:** 这是一个大重构任务，建议分批执行，每批完成后 review 再继续。
> Steps 使用 checkbox (`- [ ]`) 语法跟踪。

**Goal:** 抽取 GestureOverlay 与 FullscreenVideoPage 中重复的手势逻辑到 `VideoGestureMixin`，消除约 700 行代码重复。

**Architecture:** Dart mixin on State 模式。状态变量 + 手势逻辑方法全部迁入 mixin，UI 构建仍由各自 State 负责。子类通过实现钩子方法（约 10 个）填充业务差异。

**Tech Stack:** Flutter/Dart，mixin，ValueNotifier

**文件清单：**
- 新建: `lib/widgets/video/video_gesture_mixin.dart` — 核心 mixin
- 修改: `lib/widgets/gesture_overlay.dart` — 迁移到 mixin
- 修改: `lib/views/fullscreen_video_page.dart` — 迁移到 mixin

---

## Phase 1：创建 VideoGestureMixin 骨架 + 状态变量迁移

### Task 1.1：创建 mixin 文件和类声明

**Files:**
- Create: `lib/widgets/video/video_gesture_mixin.dart`

- [ ] **Step 1: 创建文件骨架**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/media_item.dart';

/// 视频手势交互 mixin
///
/// 封装视频播放页通用的手势逻辑：单击/双击判定、水平拖动 seek、
/// 垂直拖动音量、长按倍速、双击 seek 反馈、爱心动画等。
///
/// 使用方式：
/// ```dart
/// class _MyPageState extends State<MyPage> with VideoGestureMixin {
///   @override
///   VideoPlayerController? get _videoController => _controller;
///   // ... 实现其他钩子方法
/// }
/// ```
mixin VideoGestureMixin<T extends StatefulWidget> on State<T> {
  // ========== 钩子方法（子类必须实现/重写）==========

  /// 获取视频控制器
  VideoPlayerController? get _videoController;

  /// 单击回调
  void _onSingleTap();

  /// 左侧 1/3 区域双击回调
  void _onDoubleTapLeft() => _seekBySeconds(-10);

  /// 右侧 1/3 区域双击回调
  void _onDoubleTapRight() => _seekBySeconds(10);

  /// 中间区域双击回调
  void _onDoubleTapCenter();

  /// 左侧垂直滑动是否处理（false = 让父级处理）
  bool get _handleLeftVerticalDrag => false;

  /// 左侧垂直拖动更新（亮度调节等）
  void _onLeftVerticalDragUpdate(double delta) {}

  /// 执行 seek
  void _onSeekTo(Duration target) {
    _videoController?.seekTo(target);
  }

  /// 设置音量
  void _onSetVolume(double value) {
    _videoController?.setVolume(value);
  }

  /// 当前视频项（用于点赞）
  MediaItem? get _currentItem => null;

  /// 手势是否启用
  bool get _gesturesEnabled => true;

  // ========== 常量 ==========

  static const _kSingleTapDelay = Duration(milliseconds: 300);
  static const _kSeekPerPixelMs = 40;
  static const _kDragHideDelay = Duration(milliseconds: 800);
  static const _kLongPressRate = 2.0;

  // ========== 状态变量（单击/双击）==========

  Timer? _singleTapTimer;
  bool _pendingSingleTap = false;
  Offset? _lastTapPosition;

  // ========== 状态变量（拖动通用）==========

  bool _isDragging = false;
  String? _dragAxis; // 'h' | 'v' | null
  double _dragStartX = 0.0;
  double _dragStartY = 0.0;

  // ========== 状态变量（水平 seek）==========

  Duration _dragStartPosition = Duration.zero;
  final _previewPositionNotifier = ValueNotifier<Duration>(Duration.zero);

  // ========== 状态变量（垂直音量）==========

  bool _isVolumeSide = false;
  double _volumeStartValue = 0.0;
  final _previewVolumeNotifier = ValueNotifier<double>(0.0);
  final _showVolumeUINotifier = ValueNotifier<bool>(false);
  Timer? _volumeHideTimer;

  // ========== 状态变量（长按倍速）==========

  bool _isLongPressing = false;
  double _originalRate = 1.0;
  final _showSpeedBadgeNotifier = ValueNotifier<bool>(false);

  // ========== 状态变量（双击 seek 反馈）==========

  bool _showSeekFeedback = false;
  bool _isSeekForward = false;
  int _seekFeedbackCount = 0;
  Timer? _seekFeedbackResetTimer;

  // ========== 状态变量（爱心动画）==========

  bool _showHeart = false;
  Timer? _heartHideTimer;

  // ========== 状态变量（拖动隐藏延迟）==========

  Timer? _dragHideTimer;
}
```

- [ ] **Step 2: 验证文件可编译**

确认文件语法正确（无 import 错误、类型正确）。

---

## Phase 1.5：核心手势方法迁移

### Task 1.2：单击/双击逻辑

**Files:**
- Modify: `lib/widgets/video/video_gesture_mixin.dart`

- [ ] **Step 1: 添加单击处理方法**

在 mixin 中添加：

```dart
  // ========== 单击/双击逻辑 ==========

  void _handleTap() {
    if (!_gesturesEnabled) return;

    if (_pendingSingleTap) {
      _pendingSingleTap = false;
      _singleTapTimer?.cancel();
      _singleTapTimer = null;
      _onDoubleTap();
      return;
    }

    _pendingSingleTap = true;
    _singleTapTimer = Timer(_kSingleTapDelay, () {
      if (mounted && _pendingSingleTap) {
        _pendingSingleTap = false;
        _onSingleTap();
      }
    });
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_gesturesEnabled) return;
    _lastTapPosition = details.globalPosition;
  }

  void _onDoubleTap() {
    if (!_gesturesEnabled) return;
    final pos = _lastTapPosition;
    if (pos == null) return;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final dx = pos.dx;

    if (dx < screenWidth / 3) {
      _showSeekFeedbackAnimation(false);
      _onDoubleTapLeft();
    } else if (dx > screenWidth * 2 / 3) {
      _showSeekFeedbackAnimation(true);
      _onDoubleTapRight();
    } else {
      _onDoubleTapCenter();
    }
  }

  void _showSeekFeedbackAnimation(bool forward) {
    setState(() {
      _showSeekFeedback = true;
      _isSeekForward = forward;
      _seekFeedbackCount++;
    });

    _seekFeedbackResetTimer?.cancel();
    _seekFeedbackResetTimer = Timer(_kDragHideDelay, () {
      if (mounted) {
        setState(() {
          _showSeekFeedback = false;
          _seekFeedbackCount = 0;
        });
      }
    });
  }

  void _seekBySeconds(int seconds) {
    final controller = _videoController;
    if (controller == null) return;
    final current = controller.value.position;
    final target = current + Duration(seconds: seconds);
    _onSeekTo(target.clamp(Duration.zero, controller.value.duration));
  }

  void _cancelSingleTap() {
    _singleTapTimer?.cancel();
    _singleTapTimer = null;
    _pendingSingleTap = false;
  }
```

- [ ] **Step 2: 验证语法正确**

---

### Task 1.3：拖动逻辑（水平 seek + 垂直音量）

**Files:**
- Modify: `lib/widgets/video/video_gesture_mixin.dart`

- [ ] **Step 1: 添加 Pan 手势方法**

```dart
  // ========== Pan 拖动（全屏模式）==========

  void _onPanStart(DragStartDetails details) {
    if (!_gesturesEnabled) return;
    _cancelSingleTap();

    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    final size = MediaQuery.sizeOf(context);
    _isVolumeSide = details.globalPosition.dx > size.width / 2;

    setState(() {
      _isDragging = true;
      _dragAxis = null;
      _dragStartX = details.globalPosition.dx;
      _dragStartY = details.globalPosition.dy;
      _dragStartPosition = controller.value.position;
      _volumeStartValue = controller.value.volume;
    });

    _dragHideTimer?.cancel();
    _volumeHideTimer?.cancel();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_gesturesEnabled || !_isDragging) return;
    final controller = _videoController;
    if (controller == null) return;

    final dx = details.globalPosition.dx - _dragStartX;
    final dy = details.globalPosition.dy - _dragStartY;

    // 方向判定
    if (_dragAxis == null) {
      if (dx.abs() > dy.abs() && dx.abs() > 10) {
        setState(() {
          _dragAxis = 'h';
          _previewPositionNotifier.value = _dragStartPosition;
        });
      } else if (dy.abs() > dx.abs() && dy.abs() > 10) {
        setState(() {
          _dragAxis = 'v';
          if (_isVolumeSide) {
            _showVolumeUINotifier.value = true;
            _previewVolumeNotifier.value = _volumeStartValue;
          }
        });
      }
      return;
    }

    // 水平拖动 seek
    if (_dragAxis == 'h') {
      final size = MediaQuery.sizeOf(context);
      final deltaMs = dx * _kSeekPerPixelMs;
      final targetMs = _dragStartPosition.inMilliseconds + deltaMs;
      final duration = controller.value.duration.inMilliseconds;
      final clamped = targetMs.clamp(0, duration).toInt();
      _previewPositionNotifier.value = Duration(milliseconds: clamped);
      return;
    }

    // 垂直拖动
    if (_dragAxis == 'v') {
      final size = MediaQuery.sizeOf(context);
      final deltaRatio = -dy / size.height; // 向上 = 增大

      if (_isVolumeSide) {
        // 右侧：音量
        final newVolume = (_volumeStartValue + deltaRatio).clamp(0.0, 1.0);
        _previewVolumeNotifier.value = newVolume;
        _onSetVolume(newVolume);
      } else if (_handleLeftVerticalDrag) {
        // 左侧：亮度等（子类实现）
        _onLeftVerticalDragUpdate(deltaRatio);
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _endDrag();
  }

  void _onPanCancel() {
    _endDrag();
  }
```

- [ ] **Step 2: 添加 HorizontalDrag 手势方法**

```dart
  // ========== 水平拖动（小屏模式，只处理水平方向）==========

  void _onHorizontalDragStart(DragStartDetails details) {
    if (!_gesturesEnabled) return;
    _cancelSingleTap();

    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() {
      _isDragging = true;
      _dragAxis = 'h';
      _dragStartX = details.globalPosition.dx;
      _dragStartPosition = controller.value.position;
    });

    _dragHideTimer?.cancel();
    _previewPositionNotifier.value = _dragStartPosition;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_gesturesEnabled || !_isDragging || _dragAxis != 'h') return;
    final controller = _videoController;
    if (controller == null) return;

    final dx = details.globalPosition.dx - _dragStartX;
    final deltaMs = dx * _kSeekPerPixelMs;
    final targetMs = _dragStartPosition.inMilliseconds + deltaMs;
    final duration = controller.value.duration.inMilliseconds;
    final clamped = targetMs.clamp(0, duration).toInt();
    _previewPositionNotifier.value = Duration(milliseconds: clamped);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _endDrag();
  }

  void _onHorizontalDragCancel() {
    _endDrag();
  }
```

- [ ] **Step 3: 添加 _endDrag 公共结束方法**

```dart
  // ========== 拖动结束 ==========

  void _endDrag() {
    final controller = _videoController;
    if (!_isDragging || controller == null) {
      setState(() {
        _isDragging = false;
        _dragAxis = null;
      });
      return;
    }

    final isHorizontal = _dragAxis == 'h';
    final wasVolume = _dragAxis == 'v' && _isVolumeSide;

    setState(() {
      _isDragging = false;
      _dragAxis = null;
    });

    // 水平 seek：拖动结束时真正执行 seek
    if (isHorizontal) {
      final target = _previewPositionNotifier.value;
      _onSeekTo(target);

      _dragHideTimer = Timer(_kDragHideDelay, () {
        if (mounted) {
          _previewPositionNotifier.value = Duration.zero;
        }
      });
    }

    // 音量 UI 延迟隐藏
    if (wasVolume) {
      _volumeHideTimer = Timer(_kDragHideDelay, () {
        if (mounted) {
          _showVolumeUINotifier.value = false;
        }
      });
    }
  }
```

- [ ] **Step 4: 验证语法正确**

---

### Task 1.4：长按倍速 + 爱心 + dispose

**Files:**
- Modify: `lib/widgets/video/video_gesture_mixin.dart`

- [ ] **Step 1: 添加长按倍速逻辑**

```dart
  // ========== 长按倍速 ==========

  void _onLongPressStart(LongPressStartDetails details) {
    if (!_gesturesEnabled) return;
    final controller = _videoController;
    if (controller == null || !controller.value.isPlaying) return;

    _cancelSingleTap();
    _originalRate = controller.value.playbackSpeed;
    _isLongPressing = true;
    _showSpeedBadgeNotifier.value = true;
    controller.setPlaybackSpeed(_kLongPressRate);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_isLongPressing) return;
    _isLongPressing = false;
    _showSpeedBadgeNotifier.value = false;
    _videoController?.setPlaybackSpeed(_originalRate);
  }
```

- [ ] **Step 2: 添加爱心动画逻辑**

```dart
  // ========== 爱心动画 ==========

  void _triggerHeart() {
    setState(() {
      _showHeart = true;
    });

    _heartHideTimer?.cancel();
    _heartHideTimer = Timer(_kDragHideDelay, () {
      if (mounted) {
        setState(() {
          _showHeart = false;
        });
      }
    });
  }
```

- [ ] **Step 3: 添加 dispose 方法**

```dart
  // ========== 资源清理 ==========

  void _disposeGestureTimers() {
    _singleTapTimer?.cancel();
    _dragHideTimer?.cancel();
    _volumeHideTimer?.cancel();
    _heartHideTimer?.cancel();
    _seekFeedbackResetTimer?.cancel();
    _previewPositionNotifier.dispose();
    _previewVolumeNotifier.dispose();
    _showVolumeUINotifier.dispose();
    _showSpeedBadgeNotifier.dispose();
  }
```

> 注意：子类需要在自己的 `dispose()` 中调用 `_disposeGestureTimers()`。
> mixin 无法 override dispose（Dart 限制）。

- [ ] **Step 4: 验证 mixin 文件完整可编译**

---

## Phase 2：GestureOverlay 迁移

### Task 2.1：GestureOverlay 导入并 with mixin

**Files:**
- Modify: `lib/widgets/gesture_overlay.dart`

- [ ] **Step 1: 导入 mixin**

在文件顶部添加 import：
```dart
import 'video/video_gesture_mixin.dart';
```

- [ ] **Step 2: State 类 with mixin**

```dart
class _GestureOverlayState extends State<GestureOverlay>
    with VideoGestureMixin {
```

- [ ] **Step 3: 实现钩子方法**

删除 GestureOverlay 中与 mixin 重复的状态变量，替换为钩子方法实现：

```dart
  // ===== VideoGestureMixin 钩子实现 =====

  @override
  VideoPlayerController? get _videoController => widget.controller;

  @override
  bool get _gesturesEnabled => widget.enableGestures;

  @override
  void _onSingleTap() {
    widget.onSingleTap?.call();
  }

  @override
  void _onDoubleTapLeft() {
    super._onDoubleTapLeft();
    widget.onDoubleTap?.call();
  }

  @override
  void _onDoubleTapRight() {
    super._onDoubleTapRight();
    widget.onDoubleTap?.call();
  }

  @override
  void _onDoubleTapCenter() {
    widget.onDoubleTap?.call();
    widget.onFavoriteToggle?.call(widget.item);
    _triggerHeart();
  }

  @override
  bool get _handleLeftVerticalDrag => false;

  @override
  MediaItem? get _currentItem => widget.item;

  @override
  void _onSeekTo(Duration target) {
    _videoController?.seekTo(target);
  }

  @override
  void _onSetVolume(double value) {
    _videoController?.setVolume(value);
  }
```

- [ ] **Step 4: dispose 中调用 mixin 清理**

```dart
  @override
  void dispose() {
    _disposeGestureTimers();
    super.dispose();
  }
```

- [ ] **Step 5: 删除重复的状态变量和方法**

删除 GestureOverlay 中已迁入 mixin 的变量和方法（约 300+ 行）：
- 单击/双击相关变量和方法
- 拖动相关变量和方法
- 长按倍速变量和方法
- 爱心相关变量和方法
- 双击 seek 反馈变量和方法

注意保留：
- `enableVerticalVolumeDrag`（如果还在用）
- `_showSeekPreview` 等 UI 状态
- build 方法中的 UI 构建代码

- [ ] **Step 6: 修改 GestureDetector 回调指向 mixin 方法**

将 build 中 `GestureDetector` 的回调从 `_onTap`、`_onPanStart` 等改为 `_handleTap`、`_onPanStart` 等 mixin 方法。

- [ ] **Step 7: 验证编译通过**

---

### Task 2.2：GestureOverlay UI 部分适配

**Files:**
- Modify: `lib/widgets/gesture_overlay.dart`

- [ ] **Step 1: UI 中读取 mixin 状态**

确保 build 中所有引用状态的地方都能从 mixin 正确读取：
- `_isDragging` → mixin 成员，直接访问
- `_previewPositionNotifier` → mixin 成员，直接访问
- `_showVolumeUINotifier` → mixin 成员，直接访问
- `_showSpeedBadgeNotifier` → mixin 成员，直接访问
- `_showHeart` → mixin 成员，直接访问
- `_showSeekFeedback` → mixin 成员，直接访问
- `_isSeekForward` → mixin 成员，直接访问

- [ ] **Step 2: 验证 UI 渲染正确**

- [ ] **Step 3: 提交 Phase 2**

```bash
git add lib/widgets/video/video_gesture_mixin.dart lib/widgets/gesture_overlay.dart
git commit -m "refactor: 抽取 VideoGestureMixin，GestureOverlay 完成迁移

将共同的手势逻辑（单击/双击、水平/垂直拖动、长按倍速、
爱心动画、双击 seek 反馈）从 GestureOverlay 抽到
VideoGestureMixin，消除 ~300 行重复。"
```

---

## Phase 3：FullscreenVideoPage 迁移

### Task 3.1：FullscreenVideoPage 导入并 with mixin

**Files:**
- Modify: `lib/views/fullscreen_video_page.dart`

- [ ] **Step 1: 导入 mixin**

```dart
import '../widgets/video/video_gesture_mixin.dart';
```

- [ ] **Step 2: State 类 with mixin**

```dart
class _FullscreenVideoPageState extends State<FullscreenVideoPage>
    with VideoGestureMixin {
```

- [ ] **Step 3: 实现钩子方法**

```dart
  // ===== VideoGestureMixin 钩子实现 =====

  @override
  VideoPlayerController? get _videoController => _watchedController;

  @override
  bool get _gesturesEnabled => !_controlsVisible;

  @override
  void _onSingleTap() {
    _toggleControls();
  }

  @override
  void _onDoubleTapLeft() {
    super._onDoubleTapLeft();
  }

  @override
  void _onDoubleTapRight() {
    super._onDoubleTapRight();
  }

  @override
  void _onDoubleTapCenter() {
    // 双击中间：点赞 + 爱心
    widget.onFavoriteToggle?.call(widget.item);
    _triggerHeart();
  }

  @override
  bool get _handleLeftVerticalDrag => true;

  @override
  void _onLeftVerticalDragUpdate(double delta) {
    // 亮度调节
    // 全屏页原有的亮度逻辑需要保留在这里
    // 但亮度状态变量（_previewBrightness 等）仍在全屏页自己管理
  }

  @override
  MediaItem? get _currentItem => widget.item;

  @override
  void _onSeekTo(Duration target) {
    _watchedController?.seekTo(target);
  }

  @override
  void _onSetVolume(double value) {
    _watchedController?.setVolume(value);
  }
```

- [ ] **Step 4: dispose 中调用 mixin 清理**

在 dispose() 开头添加 `_disposeGestureTimers();`

- [ ] **Step 5: 删除重复的状态变量和方法**

删除全屏页中已迁入 mixin 的变量和方法（约 400+ 行）：
- `_singleTapTimer`、`_pendingSingleTap`、`_lastTapPosition`
- `_isDragging`、`_dragAxis`、`_dragStartX/Y`
- `_dragStartPosition`、`_previewPositionNotifier`
- `_isVolumeSide`、`_volumeStartValue`、`_previewVolumeNotifier`、`_showVolumeUINotifier`、`_volumeHideTimer`
- `_isLongPressing`、`_originalRate`、`_showSpeedBadgeNotifier`
- `_showSeekFeedback`、`_isSeekForward`、`_seekFeedbackCount`、`_seekFeedbackResetTimer`
- `_showHeart`、`_heartHideTimer`
- `_dragHideTimer`
- 对应的方法：`_onTap`、`_onDoubleTap`、`_onPanStart/Update/End/Cancel`、`_onLongPressStart/End`、`_seekBySeconds`、`_endDrag` 等

注意保留：
- 亮度相关状态（`_previewBrightnessNotifier`、`_showBrightnessUINotifier`、`_brightnessHideTimer`）
- 控制层显隐（`_controlsVisible`、`_hideControlsTimer`）
- 所有 build UI 代码
- `_brightnessIconFor`、`_volumeIconFor` 辅助方法

- [ ] **Step 6: 修改 GestureDetector 回调指向 mixin 方法**

- [ ] **Step 7: 验证编译通过**

---

### Task 3.2：FullscreenVideoPage UI 适配 + 亮度逻辑整合

**Files:**
- Modify: `lib/views/fullscreen_video_page.dart`

- [ ] **Step 1: UI 中读取 mixin 状态**

确保 build 中 4 个手势反馈 UI 区块正确引用 mixin 中的 notifier。

- [ ] **Step 2: 亮度拖动整合到 mixin 钩子**

`_onLeftVerticalDragUpdate` 中调用全屏页自己的亮度调节逻辑。
亮度状态变量和 UI 仍在全屏页自己管理（mixin 不处理亮度）。

- [ ] **Step 3: 验证所有手势行为一致**

手动检查：
- 单击 → 切换控制层
- 双击左/右 → ±10s + 反馈动画
- 双击中间 → 爱心 + 点赞
- 水平拖动 → seek 预览条 + 结束时 seek
- 右侧垂直拖动 → 音量
- 左侧垂直拖动 → 亮度
- 长按 → 2x 倍速 + 徽章

- [ ] **Step 4: 提交 Phase 3**

```bash
git add lib/views/fullscreen_video_page.dart
git commit -m "refactor: FullscreenVideoPage 迁移到 VideoGestureMixin

删除全屏页中 ~400 行重复的手势状态和逻辑，
统一使用 VideoGestureMixin。
亮度调节作为左侧垂直拖动的特有逻辑保留在全屏页。"
```

---

## Phase 4：收尾

### Task 4.1：代码 review + 清理

**Files:**
- Review: `lib/widgets/video/video_gesture_mixin.dart`
- Review: `lib/widgets/gesture_overlay.dart`
- Review: `lib/views/fullscreen_video_page.dart`

- [ ] **Step 1: 检查代码行数变化**

```bash
wc -l lib/widgets/gesture_overlay.dart lib/views/fullscreen_video_page.dart lib/widgets/video/video_gesture_mixin.dart
```

预期：总减少约 400-500 行

- [ ] **Step 2: 检查未使用的 import**

- [ ] **Step 3: 检查命名一致性**

- [ ] **Step 4: 检查注释完整度**

- [ ] **Step 5: 提交收尾**

```bash
git commit -a -m "refactor: VideoGestureMixin 重构收尾

清理未使用 import，统一命名，补充注释。"
```

---

## 测试验证清单

- [ ] 小屏 FeedView 中：单击播放/暂停
- [ ] 小屏 FeedView 中：双击左右 ±10s
- [ ] 小屏 FeedView 中：双击中间爱心
- [ ] 小屏 FeedView 中：水平拖动 seek
- [ ] 小屏 FeedView 中：右侧垂直滑动音量（如果启用）
- [ ] 小屏 FeedView 中：长按倍速
- [ ] 全屏页中：单击切换控制层
- [ ] 全屏页中：双击左右 ±10s
- [ ] 全屏页中：双击中间爱心
- [ ] 全屏页中：水平拖动 seek
- [ ] 全屏页中：右侧垂直滑动音量
- [ ] 全屏页中：左侧垂直滑动亮度
- [ ] 全屏页中：长按倍速
- [ ] 两个页面行为完全一致

## 风险提示

1. **改动量大**：涉及两个核心文件的大量删减，务必分阶段验证
2. **命名冲突**：mixin 成员与子类成员可能重名，IDE 会报错，逐步修复
3. **行为差异**：如果两边原有行为有细微差异，统一后可能导致一方行为"变了"
4. **亮度逻辑**：mixin 不处理亮度，需要在全屏页 `_onLeftVerticalDragUpdate` 中正确调用原有亮度逻辑
