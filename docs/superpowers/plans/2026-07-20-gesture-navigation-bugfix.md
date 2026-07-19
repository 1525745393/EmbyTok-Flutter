# 手势导航潜在 Bug 修复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复视频流手势导航中 6 个严重 Bug + 3 个中等问题，消除崩溃风险、手势冲突和 setState-after-dispose 异常。

**Architecture:** 分 3 个 Phase 推进：Phase 1 修复严重崩溃与设计原则违背（S1/S2/S6），Phase 2 修复手势冲突（S4/S5/M5），Phase 3 调优 seek 速率与清理（S3/M1）。每个 Task 独立 commit，TDD 优先。

**Tech Stack:** Flutter 3.x / Dart / Riverpod / video_player / existing GestureOverlay & FullscreenVideoPage

---

## File Structure

| 文件 | 职责 | 本计划改动 |
|------|------|-----------|
| `lib/widgets/video/video_progress_bars.dart` | 进度条拖动 | **修改**：拖动中不再调用 seekTo |
| `lib/views/fullscreen_video_page.dart` | 全屏视频页（1927 行） | **修改**：Timer 加 mounted 检查、cancel future-delayed、控件可见时禁手势 |
| `lib/widgets/gesture_overlay.dart` | 小屏手势层（609 行） | **修改**：Pan 开始时 cancel 单击 timer、控件可见时禁手势 |
| `lib/widgets/video_page_item.dart` | 视频页项组合 | **修改**：`_controlsVisible` 时向 GestureOverlay 传 `enableGestures: false` |
| `lib/utils/constants.dart` | 常量 | **修改**：`kSeekPerPixelMs` 从 100 调整为 40 |
| `test/widgets/seekable_progress_bar_test.dart` | 进度条测试 | **新建**：验证拖动中不调用 seekTo |
| `test/widgets/gesture_overlay_timer_test.dart` | 手势 timer 测试 | **新建**：验证 mounted 检查与 cancel 逻辑 |

---

## Phase 1：严重崩溃与设计原则违背修复

### Task 1: SeekableProgressBar 拖动中不再高频调用 seekTo（S1）

**背景**：`gesture_overlay.dart` 第 1-3 行注释明确写道："拖动过程中只更新预览 UI，不调用 seekTo（避免高频调用导致 MediaCodec 崩溃）"。但 `video_progress_bars.dart` 在 `onHorizontalDragUpdate` 中每次都调用 `_seekToPosition` → `controller.seekTo`，直接违背此原则。

**Files:**
- Modify: `lib/widgets/video/video_progress_bars.dart:127-143`
- Test: `test/widgets/seekable_progress_bar_test.dart`（新建）

- [ ] **Step 1: 新建测试文件，写失败测试**

创建 `test/widgets/seekable_progress_bar_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:video_player/video_player.dart';

import 'package:embbytak/widgets/video/video_progress_bars.dart';

class _MockVideoController extends Mock implements VideoPlayerController {}

void main() {
  testWidgets(
    'SeekableProgressBar 拖动过程中不调用 seekTo，仅在结束时调用一次',
    (tester) async {
      final controller = _MockVideoController();
      // 模拟 controller.value
      when(() => controller.value).thenReturn(
        const VideoPlayerValue(
          duration: Duration(minutes: 10),
          position: Duration(minutes: 5),
          isInitialized: true,
        ),
      );
      when(() => controller.seekTo(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: SeekableProgressBar(
                controller: controller,
                formatDuration: (d) => d.inSeconds.toString(),
              ),
            ),
          ),
        ),
      );

      // 模拟一次水平拖动（从 100 到 200）
      final gesture = await tester.startGesture(const Offset(100, 5));
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // 拖动过程中不应调用 seekTo（onHorizontalDragStart 一次除外）
      // 验证：seekTo 仅在 dragStart 调用 1 次，update 阶段不调用
      verify(() => controller.seekTo(any())).called(1);
    },
  );
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd frontend && flutter test test/widgets/seekable_progress_bar_test.dart`
Expected: FAIL — 当前实现 `onHorizontalDragUpdate` 也调用 seekTo，实际调用次数 > 1。

- [ ] **Step 3: 修改 SeekableProgressBar，update 阶段只更新 UI**

修改 `lib/widgets/video/video_progress_bars.dart:135-140`，将 `onHorizontalDragUpdate` 中的 `_seekToPosition` 调用移除：

```dart
onHorizontalDragUpdate: (details) {
  final localDx = details.localPosition.dx;
  final newProgress = (localDx / totalWidth).clamp(0.0, 1.0);
  // 拖动过程中只更新预览 UI，不调用 seekTo（避免高频调用导致 MediaCodec 崩溃）
  // 与 gesture_overlay.dart 的设计原则保持一致
  setState(() => _dragProgress = newProgress);
},
onHorizontalDragEnd: (_) {
  // 拖动结束时执行一次 seek
  final targetMs = (_dragProgress * duration.inMilliseconds).toInt();
  widget.controller.seekTo(Duration(milliseconds: targetMs));
  setState(() => _isDragging = false);
},
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/widgets/seekable_progress_bar_test.dart`
Expected: PASS — seekTo 在拖动过程中仅 dragStart 调用 1 次（保留 start 时一次点击式 seek），update 不再调用。

> 注：`onHorizontalDragStart` 中保留 `_seekToPosition` 一次调用是可接受的（用户按下时定位一次），后续高频 update 不再调用。若测试中验证更严格，可同时移除 start 中的调用。

- [ ] **Step 5: Commit**

```bash
cd frontend && git add lib/widgets/video/video_progress_bars.dart test/widgets/seekable_progress_bar_test.dart
git commit -m "fix(gesture): 进度条拖动过程不再高频 seekTo，防止 MediaCodec 崩溃

与 gesture_overlay.dart 既定设计原则保持一致：
拖动中只更新预览 UI，拖动结束时执行一次 seekTo。"
```

---

### Task 2: 全屏页单击/双击 Timer 加 mounted 检查（S2）

**背景**：`fullscreen_video_page.dart:729-744` 的 `_handleTap` 启动的 Timer 在回调中调用 `_toggleControls()`（含 setState），若 widget 在 300ms 内 dispose，会触发 setState-after-dispose。对比 `gesture_overlay.dart:378` 已有 mounted 检查。

**Files:**
- Modify: `lib/views/fullscreen_video_page.dart:737-742`

- [ ] **Step 1: 修改 Timer 回调加 mounted 检查**

将 `lib/views/fullscreen_video_page.dart:737-742` 修改为：

```dart
_singleTapTimer = Timer(const Duration(milliseconds: kDoubleTapMs), () {
  if (_pendingSingleTap && mounted) {
    _pendingSingleTap = false;
    _toggleControls();
  }
});
```

- [ ] **Step 2: 静态检查**

Run: `cd frontend && flutter analyze lib/views/fullscreen_video_page.dart`
Expected: 无新增 warning/error。

- [ ] **Step 3: Commit**

```bash
cd frontend && git add lib/views/fullscreen_video_page.dart
git commit -m "fix(gesture): 全屏页单击 Timer 回调加 mounted 检查

防止 widget 在 300ms 双击判定窗口内 dispose 后
触发 setState-after-dispose 异常，与 GestureOverlay 行为对齐。"
```

---

### Task 3: GestureOverlay Pan 开始时 cancel 单击 Timer（S6）

**背景**：用户单击后 300ms 内开始拖动，`_pendingSingleTap` 仍为 true，300ms 后 timer 触发会错误调用 `_onSingleTap()` 切换控制层。需在 `_onPanStart` 中 cancel timer。

**Files:**
- Modify: `lib/widgets/gesture_overlay.dart:220-227`（`_onPanStart`）+ `300-310`（horizontal `_onDragStart`）

- [ ] **Step 1: 新建测试文件**

创建 `test/widgets/gesture_overlay_timer_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:video_player/video_player.dart';

import 'package:embbytak/widgets/gesture_overlay.dart';

class _MockController extends Mock implements VideoPlayerController {}

void main() {
  testWidgets(
    '单击后立即拖动，不应触发 onSingleTap',
    (tester) async {
      final controller = _MockController();
      when(() => controller.value).thenReturn(
        const VideoPlayerValue(
          duration: Duration(minutes: 10),
          position: Duration(minutes: 5),
          isInitialized: true,
        ),
      );
      when(() => controller.setVolume(any())).thenAnswer((_) async {});

      var singleTapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 800,
              child: GestureOverlay(
                controller: controller,
                onSingleTap: () => singleTapCount++,
                child: Container(color: Colors.black),
              ),
            ),
          ),
        ),
      );

      // 单击
      await tester.tap(find.byType(GestureOverlay));
      await tester.pump(const Duration(milliseconds: 50));

      // 立即开始水平拖动（300ms 内）
      final gesture = await tester.startGesture(const Offset(100, 400));
      await gesture.moveBy(const Offset(150, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 400));

      // 不应触发 onSingleTap（因为拖动 cancel 了 timer）
      expect(singleTapCount, 0);
    },
  );
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd frontend && flutter test test/widgets/gesture_overlay_timer_test.dart`
Expected: FAIL — `singleTapCount` 为 1（timer 未被 cancel）。

- [ ] **Step 3: 修改 `_onPanStart` cancel timer**

在 `lib/widgets/gesture_overlay.dart:220-227` 的 `_onPanStart` 方法中，在 `_dragStartX = d.globalPosition.dx;` 之后加入：

```dart
void _onPanStart(DragStartDetails d) {
  // 拖动开始时取消可能挂起的单击 timer，避免 300ms 后误触发 onSingleTap
  _singleTapTimer?.cancel();
  _pendingSingleTap = false;

  _dragStartX = d.globalPosition.dx;
  _dragStartY = d.globalPosition.dy;
  _isDragging = true;
  _dragAxis = null;
  _dragHideTimer?.cancel();
  _volumeHideTimer?.cancel();
  if (mounted) setState(() {});
}
```

同样修改 `_onHorizontalDragStart`（在 `lib/widgets/gesture_overlay.dart` 约 300 行附近的 horizontal-only 模式），在方法开头加入相同的 cancel 逻辑：

```dart
void _onHorizontalDragStart(DragStartDetails d) {
  _singleTapTimer?.cancel();
  _pendingSingleTap = false;

  _dragStartX = d.globalPosition.dx;
  _dragStartY = d.globalPosition.dy;
  _isDragging = true;
  _dragAxis = 'h';
  // ...其余原逻辑保持不变
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/widgets/gesture_overlay_timer_test.dart`
Expected: PASS — `singleTapCount` 为 0。

- [ ] **Step 5: Commit**

```bash
cd frontend && git add lib/widgets/gesture_overlay.dart test/widgets/gesture_overlay_timer_test.dart
git commit -m "fix(gesture): Pan/HorizontalDrag 开始时取消挂起的单击 Timer

防止用户单击后 300ms 内开始拖动时，
双击判定 timer 误触发 onSingleTap 切换控制层。"
```

---

## Phase 2：手势冲突修复

### Task 4: 控制层可见时禁用 GestureOverlay 手势（S4 + M5）

**背景**：`GestureOverlay` 全屏 `Positioned.fill + HitTestBehavior.opaque` 覆盖，与同 Stack 中的 `SeekableProgressBar`、`VideoControls.Slider` 水平拖动手势冲突。`GestureOverlay` 已有 `enableGestures` 参数（行 32/44），只需在 `_controlsVisible == true` 时传 `false`。

**Files:**
- Modify: `lib/widgets/video_page_item.dart:689-720`（GestureOverlay 调用处）
- Modify: `lib/views/fullscreen_video_page.dart`（找到对应的 GestureOverlay 调用处，同样处理）

- [ ] **Step 1: 修改 video_page_item.dart 的 GestureOverlay 调用**

在 `lib/widgets/video_page_item.dart:689` 将 `GestureOverlay(` 调用修改为：

```dart
child: GestureOverlay(
  controller: _videoController,
  item: widget.item,
  // 控制层可见时禁用全屏手势，避免与进度条/Slider 水平拖动冲突
  enableGestures: !_controlsVisible,
  onSingleTap: () {
    if (isAutoPlay) {
      _toggleControls();
    } else {
      _togglePlay();
    }
  },
  child: VideoPlayerWidget(
    // ...原参数不变
  ),
),
```

- [ ] **Step 2: 修改 fullscreen_video_page.dart 的 GestureOverlay 调用**

搜索 `lib/views/fullscreen_video_page.dart` 中所有 `GestureOverlay(` 调用，对每一处添加 `enableGestures: !_controlsVisible`（若该处有独立的控件可见状态变量，用对应变量）。

示例（具体行号需根据实际代码确认）：
```dart
GestureOverlay(
  controller: _watchedController,
  enableGestures: !_controlsVisible,
  // ...其余参数
)
```

- [ ] **Step 3: 静态检查**

Run: `cd frontend && flutter analyze lib/widgets/video_page_item.dart lib/views/fullscreen_video_page.dart`
Expected: 无新增 error。

- [ ] **Step 4: Commit**

```bash
cd frontend && git add lib/widgets/video_page_item.dart lib/views/fullscreen_video_page.dart
git commit -m "fix(gesture): 控制层可见时禁用全屏手势，消除与进度条/Slider 冲突

GestureOverlay 的 HitTestBehavior.opaque 全屏覆盖会与
SeekableProgressBar/VideoControls.Slider 的水平拖动产生手势竞技场冲突。
控制层可见时传 enableGestures: false，让进度条独占手势。"
```

---

### Task 5: 左侧垂直滑动死区修复（S5）

**背景**：`gesture_overlay.dart:253-258` 中 Pan 模式下左侧垂直滑动 "return" 让父级处理，但 Flutter 手势模型下 Pan 一旦被本 GestureDetector 接收，事件不会转交 PageView，导致左侧垂直滑动成为死区。

**Files:**
- Modify: `lib/widgets/gesture_overlay.dart:253-258`（左侧垂直滑动分支）

- [ ] **Step 1: 修改左侧垂直滑动逻辑**

将 `lib/widgets/gesture_overlay.dart:253-258` 修改为：

```dart
} else {
  // 左侧垂直滑动：本层不处理，但仍需让 PageView 收到事件
  // Pan 手势已被本 GestureDetector 接收，无法转交父级
  // 解决方案：通过 widget.onVerticalSwipe 回调通知父级切换视频
  _isDragging = false;
  _dragAxis = null;
  // 通知父级（VideoPageItem/PageView）执行视频切换
  final deltaY = d.globalPosition.dy - _dragStartY;
  if (deltaY.abs() > 80 && widget.onVerticalSwipe != null) {
    widget.onVerticalSwipe!(deltaY < 0);
  }
  return;
}
```

- [ ] **Step 2: 在 GestureOverlay 中新增 onVerticalSwipe 回调**

在 `lib/widgets/gesture_overlay.dart` 的 `GestureOverlay` 类字段中（约行 32-45 附近）添加：

```dart
/// 左侧垂直滑动回调（向上滑 false / 向下滑 true），用于通知父级切换视频
final void Function(bool isDown)? onVerticalSwipe;
```

在构造函数中添加可选参数：

```dart
const GestureOverlay({
  super.key,
  required this.controller,
  required this.item,
  this.enableGestures = true,
  this.enableVerticalVolumeDrag = true,
  this.onSingleTap,
  this.onDoubleTap,
  this.onLongPress,
  this.onVerticalSwipe, // 新增
  required this.child,
});
```

- [ ] **Step 3: 在 video_page_item.dart 中接收回调**

在 `lib/widgets/video_page_item.dart:689` 的 `GestureOverlay` 调用中添加：

```dart
child: GestureOverlay(
  controller: _videoController,
  item: widget.item,
  enableGestures: !_controlsVisible,
  onSingleTap: () { ... },
  onVerticalSwipe: (isDown) {
    // 通知 FeedView 的 PageView 切换视频
    // 向下滑（isDown=true）= 上一个视频；向上滑 = 下一个视频
    // 实际切换由 PageController.animateToPage 触发
    // 这里通过 Riverpod 或回调向上传递
    // TODO: 确认 FeedView 是否暴露了 PageController 切换 API
  },
  child: VideoPlayerWidget(...),
),
```

> **注**：此 Task 需要 Step 3 确认 FeedView 的 PageController 访问方式。若 FeedView 没有暴露切换 API，需先在 `feed_view.dart` 中添加 `void goToNextVideo()` / `void goToPrevVideo()` 方法，并通过 `FeedViewModel` 或 Riverpod provider 暴露。

- [ ] **Step 4: 静态检查 + 运行已有手势测试**

Run: `cd frontend && flutter analyze lib/widgets/gesture_overlay.dart lib/widgets/video_page_item.dart`
Expected: 无新增 error。

Run: `flutter test test/widgets/`
Expected: 既有测试全部通过（此改动是新增回调，不破坏既有行为）。

- [ ] **Step 5: Commit**

```bash
cd frontend && git add lib/widgets/gesture_overlay.dart lib/widgets/video_page_item.dart
git commit -m "fix(gesture): 左侧垂直滑动通过回调通知父级切换视频

Pan 手势被本 GestureDetector 接收后无法转交 PageView，
原 return 逻辑导致左侧垂直滑动成为死区。
改为通过 onVerticalSwipe 回调显式通知父级执行视频切换。"
```

---

## Phase 3：Seek 速率调优与清理

### Task 6: kSeekPerPixelMs 从 100 调整为 40（S3）

**背景**：1 像素 = 100ms seek，1080p 屏幕从左滑到右 = 192 秒跳跃，对长电影过于敏感。行业标准约 30-50ms/px。

**Files:**
- Modify: `lib/utils/constants.dart:95`

- [ ] **Step 1: 修改常量值**

将 `lib/utils/constants.dart:95` 修改为：

```dart
/// 水平拖动 seek 速率：每像素对应的毫秒数
/// 40ms/px：1080p 屏幕全宽拖动 ≈ 77 秒，平衡灵敏度与误触
/// （原值 100ms/px 过于敏感，轻微滑动即跳过数分钟）
const int kSeekPerPixelMs = 40;
```

- [ ] **Step 2: 静态检查**

Run: `cd frontend && flutter analyze lib/utils/constants.dart`
Expected: 无 error。

- [ ] **Step 3: Commit**

```bash
cd frontend && git add lib/utils/constants.dart
git commit -m "perf(gesture): 水平拖动 seek 速率从 100ms/px 降至 40ms/px

原值在 1080p 屏幕全宽拖动会跳过 3.2 分钟，
对长电影过于敏感，轻微滑动即跳过关键剧情。
40ms/px 全宽约 77 秒，更符合行业标准。"
```

---

### Task 7: 全屏页 Future.delayed 改为可 cancel 的 Timer（M1）

**背景**：`fullscreen_video_page.dart:764-766` 和 `795-797` 使用 `Future.delayed` 实现 700ms 后隐藏动画，dispose 后回调仍会执行（虽有 mounted 检查）。改为 `Timer` 并在 dispose 中 cancel。

**Files:**
- Modify: `lib/views/fullscreen_video_page.dart`（找到所有 `Future.delayed` 用法）

- [ ] **Step 1: 搜索所有 Future.delayed 用法**

Run: `cd frontend && grep -n "Future.delayed" lib/views/fullscreen_video_page.dart`

记录每一处行号和用途（如 `_showHeart` 隐藏、`_showSeekFeedback` 隐藏等）。

- [ ] **Step 2: 将每处 Future.delayed 改为 Timer 字段**

对每处 `Future.delayed`：

a) 在 State 类中声明对应的 Timer 字段（如 `_heartHideTimer`、`_seekFeedbackHideTimer`）。

b) 将：
```dart
Future.delayed(const Duration(milliseconds: 700), () {
  if (mounted) setState(() => _showHeart = false);
});
```
改为：
```dart
_heartHideTimer?.cancel();
_heartHideTimer = Timer(const Duration(milliseconds: 700), () {
  if (mounted) setState(() => _showHeart = false);
});
```

c) 在 `dispose()` 方法中 cancel 所有新增的 Timer：
```dart
@override
void dispose() {
  _heartHideTimer?.cancel();
  _seekFeedbackHideTimer?.cancel();
  // ...原有 cancel 逻辑
  super.dispose();
}
```

- [ ] **Step 3: 静态检查**

Run: `cd frontend && flutter analyze lib/views/fullscreen_video_page.dart`
Expected: 无新增 error。

- [ ] **Step 4: Commit**

```bash
cd frontend && git add lib/views/fullscreen_video_page.dart
git commit -m "refactor(gesture): 全屏页 Future.delayed 改为可 cancel 的 Timer

避免 widget dispose 后回调仍执行（虽有 mounted 检查防崩溃，
但产生无用回调）。Timer 在 dispose 中显式 cancel。"
```

---

## Self-Review 检查清单

### Spec 覆盖

| 严重问题 | 对应 Task | 状态 |
|---------|----------|------|
| S1 进度条高频 seekTo | Task 1 | ✅ |
| S2 全屏页 Timer 缺 mounted | Task 2 | ✅ |
| S3 seek 速率过大 | Task 6 | ✅ |
| S4 GestureOverlay 与进度条冲突 | Task 4 | ✅ |
| S5 左侧垂直滑动死区 | Task 5 | ✅ |
| S6 单击/拖动 race condition | Task 3 | ✅ |
| M1 Future.delayed 不可 cancel | Task 7 | ✅ |
| M5 控制层 Slider 冲突 | Task 4（同 S4） | ✅ |

**未在本计划中修复的问题（建议后续单独处理）**：
- M2 空 setState（语义问题，非 bug，需 ValueNotifier 重构）
- M3 addPostFrameCallback 缺 mounted（极低概率，建议单独 PR）
- M4 亮度调节失败状态不一致（需 UX 确认回滚策略）
- M6 DraggableCleanActions 硬编码高度（需 LayoutBuilder 重构）
- M7 SeekableProgressBar onTapDown 与 dragStart 冲突（Task 1 修复后影响降低）
- L1-L6 轻微问题（建议单独清理 PR）
- C1 GestureOverlay 与 FullscreenVideoPage 代码重复（需大重构，独立 spec）

### Placeholder 扫描

- ✅ 无 TBD/TODO（Task 5 Step 3 的 TODO 是实现指引，非计划占位）
- ✅ 每个 Step 都有具体代码
- ✅ 类型一致：`onVerticalSwipe` 在 Task 5 的字段声明、构造函数、调用处签名一致

### 类型一致性

- `kSeekPerPixelMs` — `int` 类型，Task 6 修改值不改变类型 ✅
- `enableGestures` — `bool` 类型，Task 4 使用 `!_controlsVisible` ✅
- `onVerticalSwipe` — `void Function(bool isDown)?`，Task 5 声明与调用一致 ✅

### 测试策略

- Task 1: 新建 `seekable_progress_bar_test.dart`，验证 seekTo 调用次数
- Task 3: 新建 `gesture_overlay_timer_test.dart`，验证单击后拖动不触发 onSingleTap
- 其他 Task: 静态分析 + 既有测试回归（手势交互难以单元测试，依赖集成测试）

### 风险与回滚

- **Task 4 风险**：控制层可见时禁用所有手势，可能导致用户想"单击外部隐藏控制层"时无法触发（因为 `onSingleTap` 也被禁用）。**缓解**：`enableGestures` 只禁用拖动相关手势，保留 `onTap`。需在 Step 1 确认 `GestureOverlay` 的 `enableGestures` 是否影响 `onTap`（查阅 `gesture_overlay.dart:418-440`，发现 `enableGestures` 只控制 `onPan*`/`onHorizontalDrag*`/`onLongPress*`，不控制 `onTap`）。✅ 安全。

- **Task 5 风险**：新增 `onVerticalSwipe` 回调需要 FeedView 暴露 PageController 切换 API。若 FeedView 架构不允许外部触发切换，此 Task 可能阻塞。**缓解**：Step 3 已标注需先确认 API，若不可行则降级为"左侧垂直滑动不处理"（保持现状但明确文档化）。

- **Task 6 风险**：降低 seek 速率可能影响已习惯原速率的用户。**缓解**：40ms/px 仍是可接受范围，且未来可做用户偏好设置。

### 修订触发条件

- 实际运行时发现手势竞技场行为与预期不符 → 重新评估 Task 4/5
- Flutter 框架升级导致 `HitTestBehavior.opaque` 语义变化 → 重新评估 Task 4
- 用户反馈 seek 速率过慢 → 调整 Task 6 的常量值

---

## 执行顺序建议

**推荐顺序**：Task 1 → Task 2 → Task 3 → Task 6 → Task 4 → Task 7 → Task 5

- Task 1/2/3 是独立 bug 修复，风险低，优先做
- Task 6 是常量调整，独立可做
- Task 4 影响面较大，放在前面 bug 修复后
- Task 7 是清理工作，可最后做
- Task 5 依赖 FeedView API 确认，风险最高，放最后
