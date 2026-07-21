# 修复"点击全屏观看黑屏"问题 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复用户点击全屏按钮后视频播放区域出现黑屏的问题。

**Architecture:** 核心问题是同一个 `VideoPlayerController` 被两个 `VideoPlayer` widget 同时渲染（VideoPageItem 和 FullscreenVideoPage 各一个）。Flutter 的 `video_player` 插件底层基于平台视图，一个 controller 只能绑定到一个平台视图上，双渲染会导致冲突和黑屏。解决方案是：在打开全屏页前同步设置 `isFullscreenProvider = true`，VideoPageItem 中的 `VideoPlayer` 用 `Offstage(offstage: true)` 隐藏，FullscreenVideoPage 独享 controller 渲染。

**Tech Stack:** Flutter 3.x, Riverpod, video_player, flutter/services (SystemChrome)

---

## 文件结构

| 文件 | 责任 | 操作 |
|------|------|------|
| `lib/providers/video_playback_controller.dart` | 定义 `isFullscreenProvider` | 修改 |
| `lib/widgets/video_page_item.dart` | 监听 `isFullscreenProvider`，用 Offstage 控制 VideoPlayer 显隐 | 修改 |
| `lib/views/feed_view.dart` | 打开全屏页前同步设置 `isFullscreenProvider = true` | 修改 |
| `lib/widgets/video_page_item.dart` | 打开全屏页前同步设置 `isFullscreenProvider = true` | 修改 |
| `lib/views/fullscreen_video_page.dart` | dispose 时重置 `isFullscreenProvider = false` | 修改 |

---

## 前置知识

### 根因分析

1. **VideoPlayerController 的单渲染限制**：`video_player` 插件底层使用平台视图（PlatformView），一个 `VideoPlayerController` 实例只能绑定到一个 `VideoPlayer` widget 上。如果两个 widget 同时尝试用同一个 controller 渲染，平台层会冲突，导致画面变黑或闪烁。

2. **时序问题**：原来打开全屏的流程是：
   ```
   用户点击全屏按钮
   → Navigator.push(FullscreenVideoPage)  // 异步，下一帧才渲染
   → FullscreenVideoPage 的 build 中读取 controller 并渲染 VideoPlayer
   → 此时 VideoPageItem 的 VideoPlayer 还在渲染同一个 controller
   → 双渲染冲突 → 黑屏
   ```

3. **修复原理**：在 `Navigator.push` 之前**同步**设置 `isFullscreenProvider = true`，触发 VideoPageItem 的 rebuild，将其中的 `VideoPlayer` 用 `Offstage(offstage: true)` 隐藏。这样 FullscreenVideoPage 渲染时，VideoPageItem 中的 VideoPlayer 已经不参与渲染了。

---

## Task 1: 添加 isFullscreenProvider 状态

**Files:**
- Modify: `lib/providers/video_playback_controller.dart`

- [ ] **Step 1: 在 video_playback_controller.dart 中添加 isFullscreenProvider**

在文件中找到 `isPlayingProvider` 的定义，在其下方添加：

```dart
/// 是否全屏播放（控制横屏沉浸模式切换）
///
/// 进入全屏前由调用方同步设置为 true，使 VideoPageItem 中的 VideoPlayer
/// 立即 Offstage 隐藏，避免与 FullscreenVideoPage 中的 VideoPlayer
/// 短暂同时渲染同一 controller 导致黑屏。
final isFullscreenProvider = StateProvider<bool>((ref) => false);
```

**验证：** 搜索确认添加位置正确，与其他 Provider 格式一致。

- [ ] **Step 2: Commit**

```bash
git add lib/providers/video_playback_controller.dart
git commit -m "feat: add isFullscreenProvider to prevent dual VideoPlayer rendering"
```

---

## Task 2: 在 VideoPageItem 中用 Offstage 包裹 VideoPlayer

**Files:**
- Modify: `lib/widgets/video_page_item.dart`

- [ ] **Step 1: 在 build 方法中监听 isFullscreenProvider**

找到 `video_page_item.dart` 的 `build` 方法，在现有 `ref.watch` 调用之后添加：

```dart
// 监听全屏状态：进入全屏时隐藏本页 VideoPlayer，
// 避免同一 controller 被两个 VideoPlayer 同时渲染导致黑屏
final isInFullscreen = ref.watch(isFullscreenProvider);
```

- [ ] **Step 2: 用 Offstage 包裹 VideoPlayer**

找到 VideoPlayer 所在的 GestureOverlay 代码块（通常在 `Stack` 的 children 中），用 `Offstage` 包裹：

```dart
// 视频播放区（Gestures + VideoPlayer）
// 进入全屏时 Offstage，避免同一 VideoPlayerController 被两个 VideoPlayer widget 同时渲染导致黑屏
Offstage(
  offstage: isInFullscreen,
  child: AnimatedOpacity(
    opacity: isReady ? 1.0 : 0.0,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
    child: GestureOverlay(
      controller: _videoController,
      item: widget.item,
      // ... 其他参数保持不变
    ),
  ),
),
```

**注意：** `Offstage` 的 `offstage` 为 `true` 时，子 widget 仍保留在 widget tree 中（保持状态），但不会被渲染到屏幕上。这避免了 widget 被移除又重建的性能开销。

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/video_page_item.dart
git commit -m "fix: hide VideoPageItem's VideoPlayer with Offstage when fullscreen active"
```

---

## Task 3: 在打开全屏页前同步设置 isFullscreenProvider

**Files:**
- Modify: `lib/views/feed_view.dart`
- Modify: `lib/widgets/video_page_item.dart`

### FeedView 修改

- [ ] **Step 1: 修改 FeedView 的 _openFullscreenPage 方法**

找到 `feed_view.dart` 中的 `_openFullscreenPage` 方法，在 `Navigator.push` 之前添加同步设置：

```dart
Future<void> _openFullscreenPage() async {
  if (ref.read(currentVideoControllerProvider) == null) return;
  
  ref.read(toolbarVisibilityProvider.notifier).hide();
  
  // 同步设置 isFullscreenProvider，使 VideoPageItem 中的 VideoPlayer 立即 Offstage，
  // 避免与 FullscreenVideoPage 中的 VideoPlayer 短暂同时渲染同一 controller
  ref.read(isFullscreenProvider.notifier).state = true;
  
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const FullscreenVideoPage(),
      fullscreenDialog: true,
    ),
  );
  
  if (mounted) {
    ref.read(toolbarVisibilityProvider.notifier).show();
  }
}
```

**关键点：** `ref.read(isFullscreenProvider.notifier).state = true` 必须在 `Navigator.push` 之前执行，确保 push 动画开始前 VideoPageItem 已经 rebuild 完成。

- [ ] **Step 2: Commit FeedView 修改**

```bash
git add lib/views/feed_view.dart
git commit -m "fix: sync set isFullscreenProvider before push in FeedView"
```

### VideoPageItem 修改

- [ ] **Step 3: 修改 VideoPageItem 的 _openFullscreenPage 方法**

找到 `video_page_item.dart` 中的 `_openFullscreenPage` 方法（通常在底部导航按钮或双击手势触发），同样添加同步设置：

```dart
Future<void> _openFullscreenPage() async {
  // 进入前隐藏工具栏（沉浸感）
  ref.read(toolbarVisibilityProvider.notifier).hide();
  
  // 同步设置 isFullscreenProvider，使 VideoPageItem 中的 VideoPlayer 立即 Offstage，
  // 避免与 FullscreenVideoPage 中的 VideoPlayer 短暂同时渲染同一 controller
  ref.read(isFullscreenProvider.notifier).state = true;
  
  // push 全屏页
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const FullscreenVideoPage(),
      fullscreenDialog: true,
    ),
  );
  
  // 退出全屏后恢复工具栏
  if (mounted) {
    ref.read(toolbarVisibilityProvider.notifier).show();
    // 退出全屏后重新隐藏系统栏（全屏页 dispose 时会恢复 edgeToEdge）
    // feed 模式需要保持沉浸式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
}
```

- [ ] **Step 4: Commit VideoPageItem 修改**

```bash
git add lib/widgets/video_page_item.dart
git commit -m "fix: sync set isFullscreenProvider before push in VideoPageItem"
```

---

## Task 4: 在 FullscreenVideoPage dispose 时重置状态

**Files:**
- Modify: `lib/views/fullscreen_video_page.dart`

- [ ] **Step 1: 在 dispose 方法中重置 isFullscreenProvider**

找到 `fullscreen_video_page.dart` 的 `dispose` 方法，在 `super.dispose()` 之前添加：

```dart
@override
void dispose() {
  // ... 现有的 dispose 代码（removeObserver、cancel timers 等）
  
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: SystemUiOverlay.values,
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  // 重置全屏状态，使 VideoPageItem 中的 VideoPlayer 恢复显示
  ref.read(isFullscreenProvider.notifier).state = false;
  
  super.dispose();
}
```

**注意：** 重置操作在 `super.dispose()` 之前执行，因为 dispose 后不能访问 widget tree，但 `ref.read` 不依赖 widget tree。

- [ ] **Step 2: Commit**

```bash
git add lib/views/fullscreen_video_page.dart
git commit -m "fix: reset isFullscreenProvider on FullscreenVideoPage dispose"
```

---

## Task 5: 验证修复

- [ ] **Step 1: 运行应用并测试全屏功能**

```bash
flutter run
```

**测试步骤：**
1. 打开应用，进入视频 feed 页
2. 点击任意视频，等待视频开始播放
3. 点击全屏按钮（或双击视频区域）
4. **预期结果：** 全屏页正常显示视频，无黑屏
5. 按返回键退出全屏
6. **预期结果：** 回到 feed 页，视频继续正常播放

- [ ] **Step 2: 验证边界情况**

| 场景 | 操作 | 预期结果 |
|------|------|----------|
| 快速切换 | 进入全屏后立即返回 | 无黑屏，视频正常 |
| 多视频滑动 | 播放视频A，滑动到视频B，再滑回视频A，进入全屏 | 无黑屏 |
| 网络切换 | 全屏播放中切换网络（WiFi↔4G） | 无黑屏，可能缓冲但画面恢复 |
| 后台恢复 | 全屏播放中按 Home 键，再返回应用 | 无黑屏 |

- [ ] **Step 3: 检查日志**

观察日志中是否有 `video_player` 相关的错误或警告：

```bash
flutter logs | grep -i "video\|player\|black\|error"
```

预期无异常输出。

- [ ] **Step 4: Commit 验证结果**

```bash
git commit --allow-empty -m "test: verify fullscreen black screen fix"
```

---

## 可选优化：统一全屏导航入口

如果 `FeedView` 和 `VideoPageItem` 中都有 `_openFullscreenPage` 方法，且逻辑高度重复，可以考虑提取为统一工具。

**Files:**
- Create: `lib/utils/fullscreen_navigator.dart`

- [ ] **Step 1: 创建 FullscreenNavigator 工具类**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../views/fullscreen_video_page.dart';

/// 统一的全屏导航工具
///
/// 集中管理进入全屏的前置操作（设置 isFullscreenProvider、隐藏工具栏）
/// 和退出全屏后的恢复操作，避免多个地方重复实现相同逻辑。
class FullscreenNavigator {
  FullscreenNavigator._();

  /// 进入全屏播放页
  ///
  /// [ref] - 用于读取/修改 Provider 状态
  /// [context] - 用于导航
  /// [onExit] - 退出全屏后的回调（可选），用于恢复 UI 状态
  ///
  /// 返回值：是否成功进入全屏
  static Future<bool> open({
    required WidgetRef ref,
    required BuildContext context,
    VoidCallback? onExit,
  }) async {
    final controller = ref.read(currentVideoControllerProvider);
    if (controller == null) return false;

    // 进入前隐藏工具栏（沉浸感）
    ref.read(toolbarVisibilityProvider.notifier).hide();
    // 同步设置 isFullscreenProvider，使 VideoPageItem 中的 VideoPlayer 立即 Offstage，
    // 避免与 FullscreenVideoPage 中的 VideoPlayer 短暂同时渲染同一 controller
    ref.read(isFullscreenProvider.notifier).state = true;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FullscreenVideoPage(),
        fullscreenDialog: true,
      ),
    );

    onExit?.call();
    return true;
  }
}
```

- [ ] **Step 2: 在 FeedView 和 VideoPageItem 中改用 FullscreenNavigator**

```dart
// feed_view.dart
import '../utils/fullscreen_navigator.dart';

Future<void> _openFullscreenPage() async {
  await FullscreenNavigator.open(
    ref: ref,
    context: context,
    onExit: () {
      if (mounted) {
        ref.read(toolbarVisibilityProvider.notifier).show();
      }
    },
  );
}
```

```dart
// video_page_item.dart
import '../utils/fullscreen_navigator.dart';

Future<void> _openFullscreenPage() async {
  await FullscreenNavigator.open(
    ref: ref,
    context: context,
    onExit: () {
      if (mounted) {
        ref.read(toolbarVisibilityProvider.notifier).show();
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    },
  );
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/utils/fullscreen_navigator.dart lib/views/feed_view.dart lib/widgets/video_page_item.dart
git commit -m "refactor: extract FullscreenNavigator for unified fullscreen entry"
```

---

## 故障排查

### 问题：修改后仍出现黑屏

**可能原因 1：** `isFullscreenProvider` 设置时机太晚

**排查：** 确认 `ref.read(isFullscreenProvider.notifier).state = true` 在 `Navigator.push` 之前执行，而不是在 `MaterialPageRoute` 的 `builder` 中。

**可能原因 2：** VideoPageItem 中的 `Offstage` 包裹范围不够

**排查：** 确认 `Offstage` 包裹的是整个 `GestureOverlay`（包含 `VideoPlayer` widget），而不仅仅是某个子组件。如果 `VideoPlayer` 在其他地方（如 `build` 方法中直接创建）也需要被包裹。

**可能原因 3：** `FullscreenVideoPage` 中创建了新的 controller

**排查：** 确认 `FullscreenVideoPage` 使用的是 `currentVideoControllerProvider` 中已有的 controller，而不是创建新的。如果创建新的，需要确保旧的已被正确释放。

### 问题：退出全屏后视频消失或位置重置

**排查：** 确认 `FullscreenVideoPage.dispose()` 中正确设置了 `isFullscreenProvider = false`。如果忘记设置，VideoPageItem 中的 `Offstage` 会一直保持 `offstage: true`。

---

## Self-Review

### 1. Spec coverage

| 需求 | 对应任务 |
|------|----------|
| 点击全屏按钮不黑屏 | Task 1-4 |
| 退出全屏后正常恢复 | Task 4 |
| 避免双渲染冲突 | Task 2 (Offstage) |
| 同步状态切换 | Task 3 |
| 代码复用（可选） | Task 5 |

### 2. Placeholder scan

- ✅ 无 "TBD", "TODO", "implement later"
- ✅ 无 "Add appropriate error handling" 等模糊描述
- ✅ 每个步骤包含完整代码
- ✅ 无 "Similar to Task N" 引用

### 3. Type consistency

- ✅ `isFullscreenProvider` 类型：`StateProvider<bool>`
- ✅ `Offstage.offstage` 类型：`bool`
- ✅ `ref.read(...notifier).state` 赋值类型一致
- ✅ `FullscreenNavigator.open` 参数类型一致

---

**Plan complete and saved to `docs/superpowers/plans/2026-07-21-fix-fullscreen-black-screen.md`.**

Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
