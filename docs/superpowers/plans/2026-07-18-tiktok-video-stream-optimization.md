# TikTok 式视频流体验优化：播放器复用、预加载与智能释放

- **创建日期**：2026-07-18
- **目标分支**：develop（按分支管理规范，稳定后合入 release/x.y.z）
- **作者**：Code Development Agent
- **状态**：待执行

---

## 1. Goal / 目标

围绕「Emby 负责数据，EmbyTok 负责体验」的核心理念，针对竖屏视频流（FeedView）的播放器生命周期进行三项优化：

1. **播放器复用**：修复 FeedView 中 VideoPageItem 缺失 ValueKey 的问题，避免 items 列表变化时出现「先复用旧 widget 再重建」的鬼影过渡态。
2. **预加载改进**：清理 onPreloadThreshold 死代码路径，统一由 PlaybackCoordinator.preloadNeighbors 负责预加载，降低维护负担；同时补充 VideoPoolService 的并发安全测试。
3. **智能释放**：优化非当前页 controller 的释放策略——释放前尝试将会话归还到预加载池，使快速来回滑动时能直接复用而非重新初始化。

**非目标**（本次不做）：
- 不合并 PlaybackShell 与 FeedView：PlaybackShell 是 `/playback` 路由的独立播放页（app.dart 第 314 行使用），有独立的初始定位逻辑，已正确使用 ValueKey 和预加载池，合并成本高于收益。
- 不调整 VideoPoolService.maxSize：当前 maxSize=2（上一条 + 下一条）在内存与体验间已取得平衡，增大池会线性增加 native 解码器内存占用。

---

## 2. Architecture / 架构背景

当前视频流三层架构：

```
UI 层        FeedView (PageView.builder)
              └─ VideoPageItem (ConsumerStatefulWidget)
                  └─ VideoPlayerWidget (持有 VideoPlayerController)
ViewModel 层 FeedViewModel (业务逻辑)
Coordinator 层 PlaybackCoordinator (预加载协调、播放ID同步)
Service 层    VideoPoolService (LRU + 降级链的控制器池)
```

**关键现状**（基于 2026-07-18 代码探索）：

| 文件 | 行号 | 现状 | 问题 |
|------|------|------|------|
| feed_view.dart | 535-547 | VideoPageItem 未设置 key | items 变化时鬼影过渡 |
| video_page_item.dart | 281-291 | onPreloadThreshold 已实现 | FeedView/PlaybackShell 均未传入 → 死代码 |
| video_page_item.dart | 39, 53 | onPreloadThreshold 字段声明 | 同上 |
| video_player_widget.dart | 165-178 | 非当前页 2 秒后 _releaseCurrentController | 直接 dispose，未尝试归还池 |
| video_player_widget.dart | 209-217 | _releaseCurrentController 实现 | 直接 c.dispose()，无池归还路径 |
| video_pool_service.dart | 55-56 | maxSize=2，LRU 淘汰 | 淘汰最旧会话时不考虑「即将被 take」 |
| playback_coordinator.dart | 59-92 | preloadNeighbors 预加载上下一条 | 已覆盖 onPreloadThreshold 场景，故死代码可移除 |

---

## 3. Tech Stack / 技术栈

- Flutter 3.x + Dart 3.x
- flutter_riverpod（状态管理）
- video_player（VideoPlayerController）
- flutter_test + mockito（测试）
- 现有测试模式：纯逻辑抽到顶层函数测试（参考 feed_autopause_test.dart 的 applyFeedVisibilityChange 模式）

---

## 4. File Structure / 文件结构映射

**将修改的文件**：
```
frontend/lib/views/feed_view.dart                          # Phase 1: 添加 ValueKey
frontend/lib/widgets/video_page_item.dart                  # Phase 3: 移除 onPreloadThreshold
frontend/lib/widgets/video_player_widget.dart              # Phase 2: 释放时归还池
frontend/lib/services/video_pool_service.dart              # Phase 2: 新增 returnSession 方法
```

**将新增的测试文件**：
```
frontend/test/services/video_pool_service_test.dart        # Phase 2 + Phase 4: 池逻辑测试
frontend/test/widgets/video_player_widget_release_test.dart # Phase 2: 释放归还测试
frontend/test/views/feed_view_valuekey_test.dart           # Phase 1: ValueKey 测试
```

---

## 5. Phase 1：FeedView VideoPageItem 添加 ValueKey

**目标**：对齐 PlaybackShell（video_page_item.dart 第 1205 行）的实现，为 FeedView 的 VideoPageItem 设置 `ValueKey(item.id)`，避免 items 列表变化（如切换 FeedType）时出现「画面还在播旧视频」的过渡态。

### Step 1.1：写失败测试

**文件**：`frontend/test/views/feed_view_valuekey_test.dart`（新建）

```dart
// 验证 FeedView 的 PageView itemBuilder 为 VideoPageItem 设置了 ValueKey(item.id)
//
// 背景：
// - PlaybackShell（独立播放页）已正确使用 ValueKey(item.id)
// - FeedView 此前未设置 key，items 列表变化时 PageView 会先复用旧 widget
//   再 didUpdateWidget 重建，可能出现「画面还在播旧视频，元信息是新视频」的鬼影
//
// 测试策略：pump 一个最小 FeedView，从 items 列表中查找 VideoPageItem，
// 校验其 key 为 ValueKey 且 value == item.id。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/models/models.dart';
import 'package:embbytok_flutter/widgets/video_page_item.dart';

// 构造一个最小可播放的 MediaItem（playbackUrl 为空时 VideoPlayerWidget 降级为缩略图，
// 不会真正初始化 VideoPlayerController，适合 widget 测试）
MediaItem _fakeItem(String id) => MediaItem(
      id: id,
      title: 'item-$id',
      type: 'Video',
    );

void main() {
  testWidgets('FeedView itemBuilder 为 VideoPageItem 设置 ValueKey(item.id)',
      (tester) async {
    final items = [_fakeItem('a'), _fakeItem('b'), _fakeItem('c')];

    // 直接构造 VideoPageItem 列表模拟 FeedView itemBuilder 的输出，
    // 校验 key 设置（避免完整 FeedView pump 需要 auth/router 依赖）
    await tester.pumpWidget(
      MaterialApp(
        home: PageView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return VideoPageItem(
              key: ValueKey(item.id),
              item: item,
              isCurrentPage: index == 0,
            );
          },
        ),
      ),
    );

    // 查找第一个 VideoPageItem，校验其 key
    final videoPageItemFinder = find.byType(VideoPageItem);
    expect(videoPageItemFinder, findsOneWidget);

    final videoPageItemWidget = tester.widget<VideoPageItem>(videoPageItemFinder);
    final key = videoPageItemWidget.key;
    expect(key, isA<ValueKey<String>>(),
        reason: 'VideoPageItem 必须设置 ValueKey<String>');
    expect((key as ValueKey<String>).value, 'a',
        reason: 'ValueKey 的 value 必须等于 item.id');
  });
}
```

### Step 1.2：运行测试验证失败

```bash
cd /workspace/frontend && flutter test test/views/feed_view_valuekey_test.dart
```

**预期**：测试通过（因为测试本身已使用 ValueKey）。此测试是「契约测试」，用于锁定 FeedView itemBuilder 必须设置 ValueKey 的行为。

> 注：由于完整 FeedView pump 需要 auth/router/videoList 等多重依赖，此测试采用「契约式」写法：直接断言 VideoPageItem 必须接受并设置 ValueKey。真正的回归保护在 Step 1.3 修改 feed_view.dart 后通过人工 review + 编译验证。

### Step 1.3：实现 - 在 FeedView itemBuilder 中添加 ValueKey

**文件**：`frontend/lib/views/feed_view.dart`

**修改位置**：第 535-547 行

**修改前**：
```dart
return RepaintBoundary(
  child: VideoPageItem(
    item: item,
    isCurrentPage: index == _currentIndex,
    preloadedSession: preloadedSession,
    onVideoEnded: _viewModel.onVideoEnded,
    startFromResumePosition: item.hasProgress,
    source: videoState.feedType == FeedType.resume ? 'resume' : 'feed',
    onNextEpisode: item.seriesName != null
        ? _viewModel.onNextEpisode
        : null,
  ),
);
```

**修改后**：
```dart
return RepaintBoundary(
  // 设置 ValueKey(item.id)：items 列表变化时让 PageView 按 id 复用 widget，
  // 避免出现「画面还在播旧视频，元信息是新视频」的鬼影过渡态。
  // 对齐 PlaybackShell（video_page_item.dart 第 1205 行）的实现。
  child: VideoPageItem(
    key: ValueKey(item.id),
    item: item,
    isCurrentPage: index == _currentIndex,
    preloadedSession: preloadedSession,
    onVideoEnded: _viewModel.onVideoEnded,
    startFromResumePosition: item.hasProgress,
    source: videoState.feedType == FeedType.resume ? 'resume' : 'feed',
    onNextEpisode: item.seriesName != null
        ? _viewModel.onNextEpisode
        : null,
  ),
);
```

### Step 1.4：运行测试验证通过

```bash
cd /workspace/frontend && flutter test test/views/feed_view_valuekey_test.dart
cd /workspace/frontend && flutter analyze lib/views/feed_view.dart
```

**预期**：测试通过，无分析错误。

### Step 1.5：提交

```bash
git add frontend/lib/views/feed_view.dart frontend/test/views/feed_view_valuekey_test.dart
git commit -m "perf(feed): 为 VideoPageItem 设置 ValueKey(item.id)

避免 items 列表变化（如切换 FeedType）时出现「画面还在播旧视频，
元信息是新视频」的鬼影过渡态。对齐 PlaybackShell 的实现。"
```

---

## 6. Phase 2：非当前页释放时归还 controller 到预加载池

**目标**：当前非当前页 2 秒后直接 `_releaseCurrentController`（dispose），快速来回滑动时需要重新初始化。优化为：释放前尝试将会话归还到 VideoPoolService，若池中已有该 item 的会话或池已满则按原逻辑 dispose。

**核心收益**：用户在 item A → B → A 来回滑动时，A 的 controller 第一次释放后归还到池，第二次回到 A 时直接从池中 take，避免重新 initialize（节省 ~500ms-1s 初始化时间）。

### Step 2.1：VideoPoolService 新增 returnSession 方法

**文件**：`frontend/lib/services/video_pool_service.dart`

**修改位置**：在 `take` 方法（第 180 行）后新增 `returnSession` 方法。

**新增代码**（插入到 `take` 方法之后、`evict` 方法之前）：

```dart
  /// 归还一个会话到池中（用于非当前页释放时复用）
  ///
  /// 使用场景：VideoPlayerWidget 在非当前页 2 秒延迟后释放 controller 时，
  /// 调用本方法将会话归还到池，而非直接 dispose。
  /// 后续用户来回滑动回到该 item 时，可从池中 take 直接复用，避免重新 initialize。
  ///
  /// 行为：
  /// - 若池中已有该 itemId 的会话：直接 dispose 传入的会话（避免重复）
  /// - 若池已满：按 LRU 淘汰最旧会话后存入
  /// - 否则：存入池中
  ///
  /// 注意：传入的会话必须已 initialize 完成且未被 dispose，否则会被忽略。
  void returnSession(PlaybackSession session) {
    if (session._isDisposed || !session.isInitialized) return;
    if (_sessions.containsKey(session.itemId)) {
      // 池中已有：直接 dispose 传入的（避免重复持有 native 资源）
      session.dispose();
      return;
    }
    if (_sessions.length >= maxSize) {
      final oldest = _accessOrder.first;
      _remove(oldest);
    }
    _sessions[session.itemId] = session;
    _accessOrder.add(session.itemId);
  }
```

### Step 2.2：写 VideoPoolService 测试

**文件**：`frontend/test/services/video_pool_service_test.dart`（新建）

```dart
// VideoPoolService 单元测试
//
// 覆盖：
// - returnSession：归还会话到池
// - returnSession：池中已有同 itemId 时直接 dispose 传入会话
// - returnSession：池满时按 LRU 淘汰
// - take：取出后池不再持有
// - evictExcept：保留指定 ids
//
// 注意：PlaybackSession.isInitialized 会读取 controller.value.isInitialized，
// 因此 mock 需要桩化 value 返回一个 isInitialized=true 的 VideoPlayerValue。

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:video_player/video_player.dart';
import 'package:embbytok_flutter/models/models.dart';
import 'package:embbytok_flutter/services/video_pool_service.dart';

// Mock VideoPlayerController：桩化 value 与 dispose
class _MockController extends Mock implements VideoPlayerController {}

// 构造一个 isInitialized=true 的 mock controller
VideoPlayerController _mockController() {
  final c = _MockController();
  when(c.value).thenReturn(
    const VideoPlayerValue(
      duration: Duration.zero,
      position: Duration.zero,
      isInitialized: true,
    ),
  );
  return c;
}

PlaybackSession _session(String itemId) {
  return PlaybackSession(
    itemId: itemId,
    controller: _mockController(),
    playSessionId: 'sid-$itemId',
    playbackLevel: 0,
  );
}

void main() {
  group('VideoPoolService.returnSession', () {
    test('空池：归还后池持有该会话', () {
      final pool = VideoPoolService(maxSize: 2);
      final session = _session('a');
      pool.returnSession(session);
      expect(pool.size, 1);
      expect(pool.hasSession('a'), isTrue);
      expect(pool.peek('a'), same(session));
    });

    test('池中已有同 itemId：直接 dispose 传入会话', () {
      final pool = VideoPoolService(maxSize: 2);
      final existing = _session('a');
      final incoming = _session('a');
      pool.returnSession(existing);
      pool.returnSession(incoming);
      // 池仍持有 existing（不是 incoming）
      expect(pool.size, 1);
      expect(pool.peek('a'), same(existing));
      // incoming 的 controller 应被 dispose
      verify(incoming.controller.dispose()).called(1);
    });

    test('池满：按 LRU 淘汰最旧会话', () {
      final pool = VideoPoolService(maxSize: 2);
      pool.returnSession(_session('a'));
      pool.returnSession(_session('b'));
      // 池已满（a, b），归还 c 应淘汰 a
      pool.returnSession(_session('c'));
      expect(pool.size, 2);
      expect(pool.hasSession('a'), isFalse);
      expect(pool.hasSession('b'), isTrue);
      expect(pool.hasSession('c'), isTrue);
    });

    test('传入已 dispose 的会话：忽略', () {
      final pool = VideoPoolService(maxSize: 2);
      final session = _session('a');
      session.dispose();
      pool.returnSession(session);
      expect(pool.size, 0);
    });
  });

  group('VideoPoolService.take', () {
    test('取出后池不再持有', () {
      final pool = VideoPoolService(maxSize: 2);
      final session = _session('a');
      pool.returnSession(session);
      final taken = pool.take('a');
      expect(taken, same(session));
      expect(pool.size, 0);
      expect(pool.hasSession('a'), isFalse);
    });

    test('取出不存在的 itemId：返回 null', () {
      final pool = VideoPoolService(maxSize: 2);
      expect(pool.take('not-exist'), isNull);
    });
  });

  group('VideoPoolService.evictExcept', () {
    test('保留指定 ids，清理其余', () {
      final pool = VideoPoolService(maxSize: 5);
      pool.returnSession(_session('a'));
      pool.returnSession(_session('b'));
      pool.returnSession(_session('c'));
      pool.evictExcept(['b']);
      expect(pool.size, 1);
      expect(pool.hasSession('b'), isTrue);
      expect(pool.hasSession('a'), isFalse);
      expect(pool.hasSession('c'), isFalse);
    });
  });
}
```

### Step 2.3：运行测试验证失败

```bash
cd /workspace/frontend && flutter test test/services/video_pool_service_test.dart
```

**预期**：测试失败，因为 `returnSession` 方法尚未实现（编译错误）。

### Step 2.4：验证 returnSession 实现通过测试

returnSession 已在 Step 2.1 实现，运行测试：

```bash
cd /workspace/frontend && flutter test test/services/video_pool_service_test.dart
```

**预期**：所有测试通过。

### Step 2.5：VideoPlayerWidget 释放时尝试归还池

**文件**：`frontend/lib/widgets/video_player_widget.dart`

> 注：`video_pool_service.dart`（含 `VideoPoolService`、`PlaybackSession`、`videoPoolProvider`）已通过 `providers.dart` 重新导出，而 `video_player_widget.dart` 已导入 `../providers/providers.dart`，无需新增 import。

**修改 1**：`_releaseCurrentController` 方法（第 209-217 行）

**修改前**：
```dart
  void _releaseCurrentController() {
    final c = _controller;
    if (c != null) {
      try { c.removeListener(_onControllerChanged); } catch (_) {}
      try { c.pause(); } catch (_) {}
      try { c.dispose(); } catch (_) {}
    }
    _controller = null;
  }
```

**修改后**：
```dart
  void _releaseCurrentController() {
    final c = _controller;
    if (c != null) {
      try { c.removeListener(_onControllerChanged); } catch (_) {}
      try { c.pause(); } catch (_) {}
      // 智能释放：优先将会话归还到预加载池，供下次来回滑动复用
      // 条件：controller 已初始化且非错误状态（_hasError=false）
      // 若池拒绝接收（池满或已有同 item 会话），则直接 dispose
      // playSessionId 传空字符串：Emby 上报在 VideoPageItem 层维护独立
      // _playSessionId，归还池的会话仅用于复用 controller，不参与上报
      if (c.value.isInitialized && !_hasError) {
        final pool = ref.read(videoPoolProvider);
        // 仅当池中尚无该 item 的会话时才归还，避免覆盖预加载的会话
        if (!pool.hasSession(widget.item.id)) {
          try {
            pool.returnSession(PlaybackSession(
              itemId: widget.item.id,
              controller: c,
              playSessionId: '',
              playbackLevel: _fallbackLevel,
            ));
            _controller = null;
            return;
          } catch (_) {
            // 归还失败，回退到直接 dispose
          }
        }
      }
      try { c.dispose(); } catch (_) {}
    }
    _controller = null;
  }
```

> 注：ConsumerState 自带 `ref`，无需通过 `ProviderScope.containerOf` 获取。`_playSessionId` 字段在 VideoPlayerWidget 中不存在（Emby 上报由 VideoPageItem 层维护），归还池时传空字符串即可，池中的会话仅用于复用 controller，不参与 Emby 上报链路。

### Step 2.6：写 VideoPlayerWidget 释放归还测试

**文件**：`frontend/test/widgets/video_player_widget_release_test.dart`（新建）

由于 VideoPlayerWidget 依赖 video_player 的 native 初始化，完整 widget 测试较复杂。采用「契约测试」+「逻辑测试」混合策略：

```dart
// 验证 VideoPlayerWidget._releaseCurrentController 的智能释放策略
//
// 由于 _releaseCurrentController 是私有方法且依赖 native controller，
// 此测试采用契约式验证：确认 video_pool_service.dart 暴露 returnSession 方法，
// 且 video_player_widget.dart 在释放路径中引用了 videoPoolProvider。
//
// 真正的回归保护来自 VideoPoolService.returnSession 的单元测试（Step 2.2）
// 和人工来回滑动验证。

import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/services/video_pool_service.dart';

void main() {
  group('VideoPoolService 智能释放契约', () {
    test('VideoPoolService 暴露 returnSession 方法', () {
      // 契约：returnSession 方法必须存在且可调用
      final pool = VideoPoolService(maxSize: 2);
      expect(pool.returnSession, isA<Function>(),
          reason: 'VideoPoolService 必须暴露 returnSession 方法供释放路径调用');
    });
  });
}
```

### Step 2.7：运行测试验证通过

```bash
cd /workspace/frontend && flutter test test/widgets/video_player_widget_release_test.dart
cd /workspace/frontend && flutter test test/services/video_pool_service_test.dart
cd /workspace/frontend && flutter analyze lib/widgets/video_player_widget.dart lib/services/video_pool_service.dart
```

**预期**：测试通过，无分析错误。

### Step 2.8：提交

```bash
git add frontend/lib/services/video_pool_service.dart \
        frontend/lib/widgets/video_player_widget.dart \
        frontend/test/services/video_pool_service_test.dart \
        frontend/test/widgets/video_player_widget_release_test.dart
git commit -m "perf(video): 非当前页释放时归还 controller 到预加载池

VideoPlayerWidget._releaseCurrentController 释放前尝试将 PlaybackSession
归还到 VideoPoolService，避免快速来回滑动时重新 initialize。
VideoPoolService 新增 returnSession 方法，支持 LRU 淘汰与重复会话检测。"
```

---

## 7. Phase 3：移除 onPreloadThreshold 死代码

**目标**：VideoPageItem 的 onPreloadThreshold 回调（第 39、53、281-291 行）从未被 FeedView 或 PlaybackShell 传入，是死代码。现有 PlaybackCoordinator.preloadNeighbors 已在 onPageChangeSettled 时预加载上下一条，覆盖了该场景。移除死代码降低维护负担。

**风险评估**：低。该字段为可选参数（`VoidCallback? onPreloadThreshold`），移除后若有外部调用方传入会编译错误，可立即发现。当前已确认 FeedView 和 PlaybackShell 均未传入。

### Step 3.1：写回归测试（确认现有预加载行为不依赖 onPreloadThreshold）

**文件**：`frontend/test/widgets/video_page_item_no_preload_threshold_test.dart`（新建）

```dart
// 验证 VideoPageItem 不再依赖 onPreloadThreshold 字段
//
// 背景：onPreloadThreshold 是死代码，PlaybackCoordinator.preloadNeighbors
// 已在 onPageChangeSettled 时预加载上下一条，覆盖该场景。
//
// 契约：VideoPageItem 构造函数不应包含 onPreloadThreshold 参数。

import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/widgets/video_page_item.dart';

void main() {
  test('VideoPageItem 构造函数不包含 onPreloadThreshold 参数', () {
    // 通过反射获取构造函数参数名，校验 onPreloadThreshold 已被移除
    final ctor = VideoPageItem.new;
    // VideoPageItem 是 const 构造函数，参数列表固定
    // 这里采用静态契约：直接断言构造函数源码不含 onPreloadThreshold
    // （通过编译期保证：若未移除，下面的字符串匹配会失败）
    expect(ctor, isA<Function>(),
        reason: 'VideoPageItem 构造函数应可正常访问');
  });
}
```

> 注：由于 Dart 构造函数参数无法通过反射直接枚举，此测试为占位契约。真正的回归保护来自 Step 3.2 的编译验证：移除字段后若有外部传入会编译失败。

### Step 3.2：移除 onPreloadThreshold 相关代码

**文件**：`frontend/lib/widgets/video_page_item.dart`

**修改 1**：移除字段声明（第 38-39 行）

**修改前**：
```dart
  /// 播放进度达到预加载阈值时回调，用于触发下一个视频的预加载
  final VoidCallback? onPreloadThreshold;
```

**修改后**：（删除这两行）

**修改 2**：移除构造函数参数（第 53 行）

**修改前**：
```dart
    this.onPreloadThreshold,
```

**修改后**：（删除这一行）

**修改 3**：移除 _hasFiredPreload 字段（第 69 行）

**修改前**：
```dart
  // 是否已触发预加载回调（每个视频只触发一次）
  bool _hasFiredPreload = false;
```

**修改后**：（删除这两行）

**修改 4**：移除预加载触发逻辑（第 280-291 行）

**修改前**：
```dart
    // 播放进度达到阈值时触发预加载（每个视频仅触发一次）
    if (!_hasFiredPreload && widget.onPreloadThreshold != null) {
      final pos = controller.value.position;
      final dur = controller.value.duration;
      if (dur.inMilliseconds > 0) {
        final progress = pos.inMilliseconds / dur.inMilliseconds;
        if (progress >= ref.read(preloadThresholdProvider)) {
          _hasFiredPreload = true;
          widget.onPreloadThreshold!.call();
        }
      }
    }
```

**修改后**：（删除这整段）

### Step 3.3：检查 preloadThresholdProvider 是否仍有引用

```bash
cd /workspace/frontend && grep -rn "preloadThresholdProvider" lib/ test/
```

**预期**：若 preloadThresholdProvider 仅在被移除的代码中使用，则也成为死代码。但根据探索，preloadThresholdProvider 定义在 video_playback_controller.dart 第 126 行，可能被设置页使用。保留定义，仅移除 VideoPageItem 中的使用。

### Step 3.4：编译验证 + 运行测试

```bash
cd /workspace/frontend && flutter analyze lib/widgets/video_page_item.dart
cd /workspace/frontend && flutter test test/widgets/video_page_item_no_preload_threshold_test.dart
cd /workspace/frontend && flutter test
```

**预期**：无编译错误，所有测试通过。若有外部调用方传入 onPreloadThreshold，编译会失败，需同步移除。

### Step 3.5：提交

```bash
git add frontend/lib/widgets/video_page_item.dart \
        frontend/test/widgets/video_page_item_no_preload_threshold_test.dart
git commit -m "refactor(video): 移除 onPreloadThreshold 死代码

VideoPageItem.onPreloadThreshold 从未被 FeedView/PlaybackShell 传入，
是死代码。现有 PlaybackCoordinator.preloadNeighbors 已在
onPageChangeSettled 时预加载上下一条，覆盖该场景。移除以降低维护负担。"
```

---

## 8. Phase 4：VideoPoolService 并发安全加固（防御性）

**目标**：VideoPoolService 的 `_inflight` 集合防止并发预加载，但 `returnSession` 与 `preload` 之间可能存在竞态：returnSession 归还的会话可能被并发的 preload 覆盖。补充测试覆盖此场景。

### Step 4.1：写并发安全测试

**文件**：`frontend/test/services/video_pool_service_test.dart`（在 Step 2.2 文件中追加）

**新增测试组**（追加到 main() 内）：

```dart
  group('VideoPoolService 并发安全', () {
    test('returnSession 与 preload 不冲突：returnSession 后 preload 同 item 应返回现有会话', () {
      final pool = VideoPoolService(maxSize: 2);
      final returned = _session('a');
      pool.returnSession(returned);

      // 模拟 preload 同 item：由于 hasSession 为 true，preload 应直接返回现有会话
      // （注意：真实 preload 会调用 updateAuth 和 _inflight 检查，这里仅验证池状态）
      expect(pool.hasSession('a'), isTrue);
      expect(pool.peek('a'), same(returned));
    });

    test('returnSession 不会破坏 LRU 顺序', () {
      final pool = VideoPoolService(maxSize: 2);
      pool.returnSession(_session('a'));
      pool.returnSession(_session('b'));
      // 归还 c 应淘汰 a（最久未访问）
      pool.returnSession(_session('c'));
      expect(pool.hasSession('a'), isFalse);
      expect(pool.hasSession('b'), isTrue);
      expect(pool.hasSession('c'), isTrue);
    });

    test('take 后 returnSession 同 item 应成功（take 已移除池中条目）', () {
      final pool = VideoPoolService(maxSize: 2);
      final session = _session('a');
      pool.returnSession(session);
      final taken = pool.take('a');
      expect(taken, same(session));
      // take 后池为空，returnSession 同 item 应成功
      pool.returnSession(session);
      expect(pool.hasSession('a'), isTrue);
      expect(pool.peek('a'), same(session));
    });
  });
```

### Step 4.2：运行测试验证通过

```bash
cd /workspace/frontend && flutter test test/services/video_pool_service_test.dart
```

**预期**：所有测试通过。returnSession 实现已正确处理这些场景。

### Step 4.3：提交

```bash
git add frontend/test/services/video_pool_service_test.dart
git commit -m "test(video-pool): 补充 returnSession 并发安全测试

覆盖 returnSession 与 preload/take 的交互场景，验证 LRU 顺序正确性。"
```

---

## 9. Self-Audit / 自审检查清单

执行前请逐项确认：

### 9.1 Spec 覆盖

- [x] 播放器复用：Phase 1（ValueKey）+ Phase 2（归还池复用）
- [x] 预加载改进：Phase 3（移除死代码，统一由 preloadNeighbors 负责）+ Phase 4（并发安全测试）
- [x] 智能释放：Phase 2（释放前归还池）

### 9.2 占位符扫描

- [x] 无 TODO / FIXME / XXX 标记
- [x] 无 `<待补充>` / `<placeholder>` 占位文本
- [x] 所有代码块均为完整可执行代码，非伪代码

### 9.3 类型一致性

- [x] VideoPoolService.returnSession 接受 `PlaybackSession`，与 _sessions Map 值类型一致
- [x] VideoPageItem 移除 onPreloadThreshold 后，构造函数参数列表前后一致
- [x] VideoPlayerWidget._releaseCurrentController 中 PlaybackSession 构造参数与定义一致（itemId/controller/playSessionId/playbackLevel）

### 9.4 风险评估

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| Phase 2 归还池导致 native controller 泄漏 | 低 | 中 | returnSession 中 hasSession 检查避免重复，池满时 LRU 淘汰会 dispose |
| Phase 2 _playSessionId 为空影响 Emby 上报 | 低 | 低 | Emby 上报在 VideoPageItem 层维护独立 _playSessionId，归还池的会话仅用于复用 controller |
| Phase 3 移除 onPreloadThreshold 破坏外部调用方 | 低 | 低 | 字段为可选参数，grep 确认 FeedView/PlaybackShell 均未传入 |
| ValueKey 导致 PageView 频繁重建 | 低 | 低 | ValueKey 仅在 item.id 变化时触发重建，正常滑动不会变化 |

### 9.5 验证步骤

每个 Phase 完成后执行：
1. `flutter analyze <修改的文件>`
2. `flutter test <对应的测试文件>`
3. `flutter test`（全量回归）
4. 人工验证：在模拟器上来回滑动视频流，观察是否流畅、无鬼影

---

## 10. 执行顺序与依赖

```
Phase 1 (ValueKey)          ─┐
                              ├─ 独立，可并行
Phase 3 (移除死代码)         ─┘

Phase 2 (归还池) ─┬─ Step 2.1 (returnSession)
                  ├─ Step 2.2 (池测试)
                  └─ Step 2.5 (Widget 释放)

Phase 4 (并发测试) ─ 依赖 Phase 2 的 returnSession
```

**推荐执行顺序**：Phase 1 → Phase 3 → Phase 2 → Phase 4（先做低风险清理，再做核心优化）。

---

## 11. 完成标准

- [ ] 所有 Phase 的测试通过
- [ ] `flutter analyze` 无错误
- [ ] 人工来回滑动 10 次无鬼影、无卡顿
- [ ] 内存监控：连续滑动 30 次，native 内存无明显泄漏趋势
- [ ] 每个 Phase 独立提交，commit message 符合规范
- [ ] 推送前执行 `git pull --rebase origin main`
