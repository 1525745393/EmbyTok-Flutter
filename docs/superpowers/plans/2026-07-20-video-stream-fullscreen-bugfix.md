# 视频流与全屏观看 Bug 修复 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复视频流播放和全屏观看中的 7 个严重 Bug 和 3 个中等 Bug，涉及 controller 生命周期管理、listener 泄漏、预加载池状态、进度上报、全屏切换时序等

**Architecture:** 逐个修复审查发现的 Bug，每个 Task 聚焦一个独立问题，按优先级从 P0（预加载永久失效、dispose 崩溃、进度上报泄漏）到 P1（listener 泄漏、全屏重试、双 VideoPlayer 渲染）依次处理

**Tech Stack:** Flutter, Riverpod, video_player

---

## 文件结构

### 待修改文件

| 文件 | 职责 | 修改的 Bug |
|------|------|-----------|
| `lib/services/video_pool_service.dart` | 视频池服务 | S1（_disposed 永久为 true）、S3（归还池 listener 残留）、M2（LRU peek 不更新访问顺序） |
| `lib/widgets/video_page_item.dart` | 视频页项 | S2（切换 controller 未移除旧 listener）、S4（_recordWatchStats 崩溃）、S5（进度定时器空转） |
| `lib/widgets/video_player_widget.dart` | 视频播放器组件 | S3（归还池时清理 listener）、M3（_subtitleCues 未清空） |
| `lib/views/fullscreen_video_page.dart` | 全屏播放页 | S6（重试无效）、S7（isFullscreenProvider 延迟设置）、M1（_watchedController 同步） |
| `lib/providers/video_playback_controller.dart` | 播放控制器 Provider | S6（新增 videoRetryRequestProvider） |

---

## Task 1: Bug S1 - 修复 disposeAll 后 _disposed 永久为 true（P0）

**问题**：`disposeAll()` 设置 `_disposed = true` 但不自动重置，导致系统内存警告、App 切后台、切换 FeedType 后预加载功能永久失效。

**Files:**
- Modify: `lib/services/video_pool_service.dart:254-278`

- [ ] **Step 1: 修改 disposeAll 末尾重置 _disposed**

在 `lib/services/video_pool_service.dart` 中找到 `disposeAll` 方法（约第 254 行），将末尾的：

```dart
    // _disposed 不自动重置：保持"曾销毁"语义，由 reset() 显式重置
    // 防止并发 preload 在 disposeAll 完成后写入已 dispose 的 controller
    _disposing = false;
  }
```

替换为：

```dart
    // disposeAll 完成后重置标记，使池可继续接受新预加载请求
    // 并发安全性：disposeAll 执行期间 _disposed=true 会阻止 preload 写入；
    // 完成后重置，此时 _sessions 已清空，新 preload 会创建全新 controller
    _disposing = false;
    _disposed = false;
  }
```

- [ ] **Step 2: 更新 updateAuth 方法，移除 .then() 中的 _disposed 重置**

在同一个文件中找到 `updateAuth` 方法（约第 88 行），将：

```dart
    _disposing = true;
    _disposed = true;
    // Token 变更：所有已存在的 controller 持有的 headers 已失效
    // 异步释放，不阻塞当前调用链
    unawaited(disposeAll().then((_) {
      // 释放完成后重置标记，池可继续接受新预加载请求
      // 此时 _inflight 已清空，并发 preload 的 await 也会检查到 _disposed=true 而拒绝写入
      _disposed = false;
    }));
```

替换为：

```dart
    _disposing = true;
    _disposed = true;
    // Token 变更：所有已存在的 controller 持有的 headers 已失效
    // 异步释放，不阻塞当前调用链
    // disposeAll 完成后会自动重置 _disposed 和 _disposing
    unawaited(disposeAll());
```

- [ ] **Step 3: 更新 disposeAll 的文档注释**

将 `disposeAll` 方法的文档注释：

```dart
  /// 注意：本方法不会重置 `_disposed` 标志，由调用方（如 updateAuth）负责
  /// 在 `.then()` 回调中重置，或通过 `reset()` 显式重置。
```

替换为：

```dart
  /// 本方法在完成后会自动重置 `_disposed` 和 `_disposing` 标志，
  /// 使池可继续接受新预加载请求。
```

- [ ] **Step 4: Commit**

```bash
cd /workspace/frontend
git add lib/services/video_pool_service.dart
git commit -m "fix: disposeAll 完成后重置 _disposed，修复预加载永久失效

disposeAll() 之前不自动重置 _disposed，导致系统内存警告、
App 切后台、切换 FeedType 后 preload() 永远返回 null，
预加载功能永久失效。现在 disposeAll 完成后自动重置。"
```

---

## Task 2: Bug S4 - 修复 _recordWatchStats 访问已 dispose 的 controller 崩溃（P0）

**问题**：`VideoPageItem.dispose()` 中调用 `_recordWatchStats()`，但子 widget `VideoPlayerWidget` 可能已 dispose controller，访问 `.value` 抛异常。

**Files:**
- Modify: `lib/widgets/video_page_item.dart:289-303`

- [ ] **Step 1: 给 _recordWatchStats 添加 try-catch**

在 `lib/widgets/video_page_item.dart` 中找到 `_recordWatchStats` 方法（约第 289 行），将整个方法替换为：

```dart
  /// 记录观看统计（完播率）
  void _recordWatchStats() {
    final controller = _videoController;
    if (controller == null) return;
    try {
      if (!controller.value.isInitialized) return;
      final position = controller.value.position;
      final duration = controller.value.duration;
      if (duration.inMilliseconds <= 0) return;
      final completionRate = position.inMilliseconds / duration.inMilliseconds;
      ref.read(watchStatsProvider.notifier).recordWatch(
            itemId: widget.item.id,
            itemType: widget.item.type,
            itemTitle: widget.item.title,
            completionRate: completionRate,
            source: widget.source,
          );
    } catch (e) {
      // controller 可能已被子 widget VideoPlayerWidget dispose，
      // 此时跳过统计记录，避免 dispose 链中断
      AppLogger.debug('recordWatchStats 跳过：controller 不可访问',
          data: {'itemId': widget.item.id, 'error': e.toString()});
    }
  }
```

注意：如果文件中未 import `AppLogger`，需要添加 `import '../utils/app_logger.dart';`。

- [ ] **Step 2: Commit**

```bash
cd /workspace/frontend
git add lib/widgets/video_page_item.dart
git commit -m "fix: _recordWatchStats 添加 try-catch 防止 dispose 后访问 controller 崩溃

VideoPageItem.dispose() 中调用 _recordWatchStats() 时，
子 widget VideoPlayerWidget 可能已 dispose controller，
访问 .value 抛 A VideoPlayerController was used after being disposed。
添加 try-catch 保护，跳过统计记录。"
```

---

## Task 3: Bug S5 - 修复 didUpdateWidget 不处理 isCurrentPage true→false（P0）

**问题**：用户滑到下一页时，旧页 `isCurrentPage` 变 false，但 `_progressTimer` 继续运行，持续向 Emby 上报无效进度。

**Files:**
- Modify: `lib/widgets/video_page_item.dart:209-217`

- [ ] **Step 1: 在 didUpdateWidget 中添加 true→false 处理**

在 `lib/widgets/video_page_item.dart` 中找到 `didUpdateWidget` 方法（约第 209 行），将：

```dart
  @override
  void didUpdateWidget(covariant VideoPageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentPage && !oldWidget.isCurrentPage && _videoController != null) {
      // 由相邻预加载页变为当前页：补齐播放/进度上报（此前因非当前页被静音暂停）
      ref.read(currentVideoControllerProvider.notifier).state = _videoController;
      _startPlaybackIfCurrent();
    }
  }
```

替换为：

```dart
  @override
  void didUpdateWidget(covariant VideoPageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentPage && !oldWidget.isCurrentPage && _videoController != null) {
      // 由相邻预加载页变为当前页：补齐播放/进度上报（此前因非当前页被静音暂停）
      ref.read(currentVideoControllerProvider.notifier).state = _videoController;
      _startPlaybackIfCurrent();
    } else if (!widget.isCurrentPage && oldWidget.isCurrentPage) {
      // 由当前页变为非当前页：停止进度上报定时器，避免持续向 Emby 发送无效进度
      _progressTimer?.cancel();
      _progressTimer = null;
      // 上报一次 Pause 事件，确保 Emby 收到最新播放进度
      if (_hasStartedReported && !_hasStoppedReported) {
        _reportPlaybackProgress(isPauseEvent: true);
      }
      // 取消 UI 定时器，避免非当前页触发 setState
      _infoHideTimer?.cancel();
      _controlsHideTimer?.cancel();
    }
  }
```

- [ ] **Step 2: Commit**

```bash
cd /workspace/frontend
git add lib/widgets/video_page_item.dart
git commit -m "fix: didUpdateWidget 处理 isCurrentPage true→false，停止旧页进度上报

用户滑动到下一页时，旧页的 _progressTimer 继续运行，
每 5 秒向 Emby 上报无效进度。现在 isCurrentPage 变 false 时
取消定时器并上报一次 Pause 事件。"
```

---

## Task 4: Bug S2 - 修复 onControllerReady 切换 controller 时未移除旧 listener（P1）

**问题**：切换 controller 时，旧 controller 上的 `_onVideoChanged` listener 未被移除，导致内存泄漏和状态错乱。

**Files:**
- Modify: `lib/widgets/video_page_item.dart:744-769`

- [ ] **Step 1: 在 onControllerReady 中添加旧 listener 移除**

在 `lib/widgets/video_page_item.dart` 中找到 `onControllerReady` 回调（约第 744 行），将：

```dart
              onControllerReady: (c) {
                // 异步回调中 setState 前必须检查 mounted，避免 widget 已销毁时抛异常
                if (!mounted) return;
                // 判断是否为新的 controller 实例（非当前持有的）
                // 场景：首次初始化（_videoController==null）、controller 被释放后重新初始化、
                // 用户切换画质后 _userInitiatedReinit 创建新 controller
                final isNewController = !identical(_videoController, c);
                setState(() => _videoController = c);
                ref.read(videoReadyProvider.notifier).markReady(widget.item.id);
                c.addListener(_onVideoChanged);
```

替换为：

```dart
              onControllerReady: (c) {
                // 异步回调中 setState 前必须检查 mounted，避免 widget 已销毁时抛异常
                if (!mounted) return;
                // 判断是否为新的 controller 实例（非当前持有的）
                // 场景：首次初始化（_videoController==null）、controller 被释放后重新初始化、
                // 用户切换画质后 _userInitiatedReinit 创建新 controller
                final isNewController = !identical(_videoController, c);
                // 切换 controller 前先移除旧 controller 上的 listener，
                // 避免内存泄漏和旧 controller 状态变化时误触发 _onVideoChanged
                if (isNewController && _videoController != null) {
                  _videoController!.removeListener(_onVideoChanged);
                }
                setState(() => _videoController = c);
                ref.read(videoReadyProvider.notifier).markReady(widget.item.id);
                c.addListener(_onVideoChanged);
```

- [ ] **Step 2: Commit**

```bash
cd /workspace/frontend
git add lib/widgets/video_page_item.dart
git commit -m "fix: onControllerReady 切换 controller 时移除旧 listener

切换 controller 时旧 controller 上的 _onVideoChanged listener
未被移除，导致内存泄漏和归还池后被复用时状态错乱。
现在 isNewController 时先 removeListener 再 addListener。"
```

---

## Task 5: Bug S3 - 修复归还池时未清理外部 listeners（P1）

**问题**：`_releaseCurrentController` 归还 controller 到池时，外部 listener（VideoPageItem 的 `_onVideoChanged`）仍附着，复用时触发陈旧 listener。

采用方案 A（最简、最安全）：放弃归还池复用，始终 dispose。代价是失去 controller 复用带来的快速滑动体验，但彻底消除 listener 残留问题。

**Files:**
- Modify: `lib/widgets/video_player_widget.dart:200-232`

- [ ] **Step 1: 简化 _releaseCurrentController，始终 dispose**

在 `lib/widgets/video_player_widget.dart` 中找到 `_releaseCurrentController` 方法（约第 200 行），将整个方法替换为：

```dart
  // 释放当前 controller 的资源
  // 始终 dispose 而非归还池，避免外部 listener（VideoPageItem 的 _onVideoChanged）
  // 残留在归还池的 controller 上，复用时触发陈旧 listener 导致状态错乱
  void _releaseCurrentController() {
    final c = _controller;
    if (c != null) {
      try { c.removeListener(_onControllerChanged); } catch (_) {}
      try { c.pause(); } catch (_) {}
      try { c.dispose(); } catch (_) {}
    }
    _controller = null;
    _wasSizeEmpty = false;
  }
```

- [ ] **Step 2: Commit**

```bash
cd /workspace/frontend
git add lib/widgets/video_player_widget.dart
git commit -m "fix: _releaseCurrentController 始终 dispose，避免归还池 listener 残留

归还池的 controller 上附着外部 listener（VideoPageItem 的
_onVideoChanged），复用时触发陈旧 listener 导致状态错乱。
改为始终 dispose，彻底消除 listener 残留问题。"
```

---

## Task 6: Bug S7 - 修复全屏进入时 isFullscreenProvider 延迟设置导致双 VideoPlayer 渲染（P1）

**问题**：`isFullscreenProvider` 在 `postFrameCallback` 中才设为 true，导致进入全屏时 VideoPageItem 和 FullscreenVideoPage 短暂同时渲染同一 controller。

**Files:**
- Modify: `lib/views/fullscreen_video_page.dart:225-243`
- Modify: `lib/widgets/video_page_item.dart`（找到 `_openFullscreenPage` 或调用 Navigator.push 进入全屏的位置）

- [ ] **Step 1: 在 FullscreenVideoPage.initState 中移除 isFullscreenProvider 的延迟设置**

在 `lib/views/fullscreen_video_page.dart` 中找到 `initState`（约第 225 行），将 `postFrameCallback` 中的：

```dart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = ref.read(currentVideoControllerProvider);
      if (ctrl != null && ctrl.value.isInitialized) {
        final size = ctrl.value.size;
        final isLandscapeVideo = size.width >= size.height;
        _orientationPref =
            isLandscapeVideo ? _OrientationPref.landscape : _OrientationPref.sensor;
      }
      _setupControllerListener(ctrl);
      _applyOrientations();
      _applySystemUI();
      ref.read(isFullscreenProvider.notifier).state = true;
    });
```

替换为（移除最后一行 `isFullscreenProvider` 设置）：

```dart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = ref.read(currentVideoControllerProvider);
      if (ctrl != null && ctrl.value.isInitialized) {
        final size = ctrl.value.size;
        final isLandscapeVideo = size.width >= size.height;
        _orientationPref =
            isLandscapeVideo ? _OrientationPref.landscape : _OrientationPref.sensor;
      }
      _setupControllerListener(ctrl);
      _applyOrientations();
      _applySystemUI();
      // isFullscreenProvider 由调用方在 Navigator.push 前同步设置，
      // 避免 VideoPageItem 和 FullscreenVideoPage 短暂同时渲染同一 controller
    });
```

- [ ] **Step 2: 在调用方同步设置 isFullscreenProvider**

在 `lib/widgets/video_page_item.dart` 中搜索 `_openFullscreenPage` 或 `FullscreenVideoPage` 的调用位置（使用 Grep 搜索 `FullscreenVideoPage`），在 `Navigator.push` 之前添加：

```dart
    // 同步设置 isFullscreenProvider，使 VideoPageItem 中的 VideoPlayer 立即 Offstage，
    // 避免与 FullscreenVideoPage 中的 VideoPlayer 短暂同时渲染同一 controller
    ref.read(isFullscreenProvider.notifier).state = true;
```

具体修改位置取决于代码结构，通常在 `Navigator.of(context).push(...)` 之前。

- [ ] **Step 3: Commit**

```bash
cd /workspace/frontend
git add lib/views/fullscreen_video_page.dart lib/widgets/video_page_item.dart
git commit -m "fix: 全屏进入时同步设置 isFullscreenProvider，避免双 VideoPlayer 渲染

isFullscreenProvider 之前在 postFrameCallback 中才设为 true，
导致 VideoPageItem 和 FullscreenVideoPage 短暂同时渲染同一
controller，可能黑屏/闪烁。改为由调用方在 Navigator.push 前同步设置。"
```

---

## Task 7: Bug S6 - 修复全屏页 _retryVideo 不实际重新初始化 controller（P1）

**问题**：全屏页重试按钮仅调用 `controller.play()`，不重建 controller，错误状态无法清除。

**Files:**
- Modify: `lib/providers/video_playback_controller.dart`（新增 `videoRetryRequestProvider`）
- Modify: `lib/views/fullscreen_video_page.dart:571-579`
- Modify: `lib/widgets/video_page_item.dart`（监听 retry 请求）
- Modify: `lib/widgets/video_player_widget.dart`（暴露 retry 方法）

- [ ] **Step 1: 新增 videoRetryRequestProvider**

在 `lib/providers/video_playback_controller.dart` 文件末尾添加：

```dart
/// 视频重试请求 Provider
/// 全屏页通过设置 itemId 请求 VideoPageItem 重新初始化 controller
final videoRetryRequestProvider = StateProvider<String?>((ref) => null);
```

- [ ] **Step 2: 修改 FullscreenVideoPage._retryVideo**

在 `lib/views/fullscreen_video_page.dart` 中找到 `_retryVideo` 方法（约第 571 行），替换为：

```dart
  void _retryVideo() {
    // 全屏页不拥有 controller，通过 Provider 通知 VideoPageItem 触发重试
    final item = ref.read(currentPlayingItemProvider);
    if (item != null) {
      ref.read(videoRetryRequestProvider.notifier).state = item.id;
      setState(() => _retryKey++);
    }
  }
```

- [ ] **Step 3: 在 VideoPlayerWidget 中暴露 retry 方法**

在 `lib/widgets/video_player_widget.dart` 中，将 `_retryInitialization` 方法改为 public（去掉下划线）或添加 public 包装：

```dart
  /// 重新初始化视频（供外部通过 GlobalKey 调用）
  void retryInitialization() {
    _retryInitialization();
  }
```

- [ ] **Step 4: 在 VideoPageItem 中监听 retry 请求**

在 `lib/widgets/video_page_item.dart` 的 `initState` 中添加监听（找到已有的 `ref.listen` 区域）：

```dart
    // 监听全屏页的重试请求
    ref.listen<String?>(videoRetryRequestProvider, (prev, next) {
      if (next != null && next == widget.item.id) {
        _videoPlayerKey.currentState?.retryInitialization();
        // 清除请求，避免重复触发
        ref.read(videoRetryRequestProvider.notifier).state = null;
      }
    });
```

同时确保 VideoPageWidget 使用 GlobalKey：

```dart
final GlobalKey<VideoPlayerWidgetState> _videoPlayerKey = GlobalKey<VideoPlayerWidgetState>();
```

并在 VideoPlayerWidget 构造时传入 key。

- [ ] **Step 5: Commit**

```bash
cd /workspace/frontend
git add lib/providers/video_playback_controller.dart lib/views/fullscreen_video_page.dart lib/widgets/video_player_widget.dart lib/widgets/video_page_item.dart
git commit -m "fix: 全屏页重试按钮通过 Provider 触发 controller 重新初始化

全屏页 _retryVideo 之前仅调用 controller.play()，不重建 controller，
错误状态无法清除。现在通过 videoRetryRequestProvider 通知
VideoPageItem 调用 VideoPlayerWidget.retryInitialization() 重建 controller。"
```

---

## Task 8: Bug M1 - 修复全屏页 _watchedController 首帧不同步（P2）

**问题**：首次 build 时 `_watchedController` 为 null，`ref.listen` 不立即触发，第一帧渲染时 listener 未正确设置。

**Files:**
- Modify: `lib/views/fullscreen_video_page.dart`（build 方法中同步调用 `_setupControllerListener`）

- [ ] **Step 1: 在 build 中同步调用 _setupControllerListener**

在 `lib/views/fullscreen_video_page.dart` 的 `build` 方法中，找到 `final controller = ref.watch(currentVideoControllerProvider);` 之后，添加：

```dart
    // 同步更新 _watchedController，确保第一帧时 listener 已正确设置
    _setupControllerListener(controller);
```

- [ ] **Step 2: Commit**

```bash
cd /workspace/frontend
git add lib/views/fullscreen_video_page.dart
git commit -m "fix: 全屏页 build 中同步调用 _setupControllerListener

首次 build 时 _watchedController 为 null，ref.listen 不立即触发，
第一帧渲染时 listener 未正确设置，导致 UI 短暂显示错误状态。"
```

---

## Task 9: Bug M3 - 修复 _reinitForNewItem 未清空 _subtitleCues（P2）

**问题**：切换视频时旧字幕数据未清空，新字幕加载完成前短暂显示旧字幕。

**Files:**
- Modify: `lib/widgets/video_player_widget.dart:235-257`

- [ ] **Step 1: 在 _reinitForNewItem 的 setState 中清空 _subtitleCues**

在 `lib/widgets/video_player_widget.dart` 中找到 `_reinitForNewItem` 方法（约第 235 行），找到其中的 `setState`：

```dart
  setState(() {
    _initialized = false;
    _hasError = false;
    _errorMessage = null;
  });
```

替换为：

```dart
  setState(() {
    _initialized = false;
    _hasError = false;
    _errorMessage = null;
    _subtitleCues = const <SubtitleCue>[]; // 清空旧字幕，避免新视频初始时显示旧字幕
  });
```

- [ ] **Step 2: Commit**

```bash
cd /workspace/frontend
git add lib/widgets/video_player_widget.dart
git commit -m "fix: _reinitForNewItem 清空 _subtitleCues，避免切换视频后显示旧字幕

切换视频时旧字幕数据未清空，新 controller 初始化完成但新字幕
未加载完成期间，build 会使用旧字幕数据。"
```

---

## Task 10: Bug M5 - 修复 _inflight.add 在 try 块外可能不释放（P2）

**问题**：`_inflight.add(item.id)` 在 try 块外，若后续代码抛异常，`finally` 不执行，`_inflight` 中残留 item.id。

**Files:**
- Modify: `lib/services/video_pool_service.dart:130-189`

- [ ] **Step 1: 将 _inflight.add 移入 try 块**

在 `lib/services/video_pool_service.dart` 中找到 `preload` 方法（约第 130 行），找到：

```dart
    if (_inflight.contains(item.id)) return null;
    _inflight.add(item.id);

    if (_sessions.length >= maxSize) {
      final oldest = _accessOrder.first;
      _remove(oldest);
    }

```

将其改为（将 `_inflight.add` 和后续逻辑包入 try）：

```dart
    if (_inflight.contains(item.id)) return null;

    try {
      _inflight.add(item.id);

      if (_sessions.length >= maxSize) {
        final oldest = _accessOrder.first;
        _remove(oldest);
      }

```

然后在对应 `finally` 块中保持 `_inflight.remove(item.id)`。注意调整缩进，确保 try-finally 包裹所有逻辑。

- [ ] **Step 2: Commit**

```bash
cd /workspace/frontend
git add lib/services/video_pool_service.dart
git commit -m "fix: _inflight.add 移入 try 块，防止异常时 _inflight 残留

_inflight.add 之前在 try 块外，若后续 _accessOrder.first 抛异常，
finally 不执行，_inflight 中残留 item.id，后续 preload 永远返回 null。"
```

---

## Task 11: 全局验证与提交

- [ ] **Step 1: 搜索是否有遗漏的编译错误**

```bash
cd /workspace/frontend
grep -r "playbackLevel\|videoQualityProvider\|autoFallbackEnabledProvider\|startLevel\|fallbackLevel" lib/ --include="*.dart"
```

- [ ] **Step 2: 推送到远程**

```bash
cd /workspace
git remote set-url origin https://<user>:<token>@github.com/1525745393/EmbyTok-Flutter.git
git pull --rebase origin main
git push origin main
```

---

## Self-Review

**1. Spec coverage:**
- ✅ Bug S1（_disposed 永久为 true）→ Task 1
- ✅ Bug S2（切换 controller 未移除旧 listener）→ Task 4
- ✅ Bug S3（归还池 listener 残留）→ Task 5
- ✅ Bug S4（_recordWatchStats 崩溃）→ Task 2
- ✅ Bug S5（进度定时器空转）→ Task 3
- ✅ Bug S6（全屏重试无效）→ Task 7
- ✅ Bug S7（双 VideoPlayer 渲染）→ Task 6
- ✅ Bug M1（_watchedController 不同步）→ Task 8
- ✅ Bug M3（_subtitleCues 未清空）→ Task 9
- ✅ Bug M5（_inflight.add 在 try 外）→ Task 10
- ⏭️ Bug M2（LRU peek 不更新访问顺序）→ 未包含，影响小
- ⏭️ Bug M4（toggle 语义）→ 未包含，设计决策
- ⏭️ Bug M6（退出全屏时序）→ 未包含，与 Task 6 相关
- ⏭️ Bug M7（dispose 中 ref.read）→ 未包含，理论问题
- ⏭️ Bug L1-L4（轻微）→ 未包含

**2. Placeholder scan:**
- Task 6 Step 2 需要确认 `_openFullscreenPage` 的具体位置（已在步骤中说明使用 Grep 搜索）
- Task 7 Step 4 需要确认 GlobalKey 的使用方式（已在步骤中说明）
- 其余步骤均包含完整代码

**3. Type consistency:**
- `videoRetryRequestProvider` 在 Task 7 Step 1 定义，Step 2 和 Step 4 使用，类型一致（`StateProvider<String?>`）
- `retryInitialization()` 方法名在 Task 7 Step 3 和 Step 4 一致
- `_videoPlayerKey` 在 Task 7 Step 4 定义和使用一致

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-20-video-stream-fullscreen-bugfix.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
