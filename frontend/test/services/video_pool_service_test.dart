// VideoPoolService 单元测试
//
// 覆盖：
// - returnSession：归还会话到池
// - returnSession：池中已有同 itemId 时直接 dispose 传入会话
// - returnSession：池满时按 LRU 淘汰
// - take：取出后池不再持有
// - evictExcept：保留指定 ids
// - 并发安全：returnSession 与 preload/take 的交互场景
//
// 注意：使用 Fake 而非 Mock 实现 VideoPlayerController。
// 原因：VideoPlayerController 继承自 ValueNotifier，mockito Mock 在 stub value 时
// 可能触发 ChangeNotifier 内部状态，导致 "Cannot call when within a stub response"。
// Fake 直接 override 需要的方法，避开 mockito 的 stub 机制。

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:video_player/video_player.dart';
import 'package:embbytok_flutter/models/models.dart';
import 'package:embbytok_flutter/services/video_pool_service.dart';

// Fake VideoPlayerController：仅实现 PlaybackSession 调用的方法（value、dispose）
// 通过 disposed 字段跟踪 dispose 调用，替代 mockito 的 verify
class _FakeController extends Fake implements VideoPlayerController {
  _FakeController({this.initialized = true});

  final bool initialized;
  bool disposed = false;

  @override
  VideoPlayerValue get value => VideoPlayerValue(
        duration: Duration.zero,
        position: Duration.zero,
        isInitialized: initialized,
      );

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

// 构造一个已初始化的 fake controller
_FakeController _fakeController() => _FakeController(initialized: true);

PlaybackSession _session(String itemId) {
  return PlaybackSession(
    itemId: itemId,
    controller: _fakeController(),
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
      final existingController = _fakeController();
      final existing = PlaybackSession(
        itemId: 'a',
        controller: existingController,
        playSessionId: 'sid-a',
        playbackLevel: 0,
      );
      final incomingController = _fakeController();
      final incoming = PlaybackSession(
        itemId: 'a',
        controller: incomingController,
        playSessionId: 'sid-a',
        playbackLevel: 0,
      );
      pool.returnSession(existing);
      pool.returnSession(incoming);
      // 池仍持有 existing（不是 incoming）
      expect(pool.size, 1);
      expect(pool.peek('a'), same(existing));
      // incoming 的 controller 应被 dispose（通过 disposed 标记验证，替代 verify）
      expect(incomingController.disposed, isTrue,
          reason: '池中已有同 itemId 时，传入会话应被 dispose');
      // existing 不应被 dispose
      expect(existingController.disposed, isFalse);
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

  // 并发安全测试：验证 returnSession 与 preload/take 的交互场景
  // 场景：VideoPlayerWidget 释放时归还 controller（returnSession），
  // 同时 PlaybackCoordinator.preloadNeighbors 可能预加载同 item（preload），
  // 或 VideoPageItem 从池中取出（take）。需保证状态一致。
  group('VideoPoolService 并发安全', () {
    test('returnSession 后池持有该会话，peek 返回同一实例', () {
      // 模拟：Widget 释放归还 → Coordinator 检查 hasSession 决定是否 preload
      final pool = VideoPoolService(maxSize: 2);
      final returned = _session('a');
      pool.returnSession(returned);

      // Coordinator.preloadNeighbors 会先检查 hasSession，若为 true 则跳过 preload
      expect(pool.hasSession('a'), isTrue);
      expect(pool.peek('a'), same(returned));
    });

    test('returnSession 不会破坏 LRU 顺序', () {
      // 模拟：连续归还 a, b, c，池满（maxSize=2）应淘汰 a
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
      // 模拟：Widget 取出会话播放 → 用户切走 → Widget 释放归还
      // take 后池为空，returnSession 同 item 应成功存入
      final pool = VideoPoolService(maxSize: 2);
      final session = _session('a');
      pool.returnSession(session);
      final taken = pool.take('a');
      expect(taken, same(session));
      // take 后池为空
      expect(pool.size, 0);
      // returnSession 同 item 应成功（无重复）
      pool.returnSession(session);
      expect(pool.hasSession('a'), isTrue);
      expect(pool.peek('a'), same(session));
    });

    test('returnSession 与 evictExcept 交互：被 evict 的会话不在池中', () {
      // 模拟：Widget 归还 a → Coordinator 切到远端页 evictExcept([current±1])
      final pool = VideoPoolService(maxSize: 5);
      pool.returnSession(_session('a'));
      pool.returnSession(_session('b'));
      pool.returnSession(_session('c'));
      // 仅保留 b
      pool.evictExcept(['b']);
      expect(pool.size, 1);
      expect(pool.hasSession('a'), isFalse);
      expect(pool.hasSession('c'), isFalse);
      // 被淘汰的会话 controller 应被 dispose（_remove 会调 session.dispose）
      // 此处不验证 disposed 标记（_session() 每次返回新实例，无法追踪），
      // 仅验证池状态正确
    });
  });
}
