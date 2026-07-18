// VideoPoolService 单元测试
//
// 覆盖：
// - returnSession：归还会话到池
// - returnSession：池中已有同 itemId 时直接 dispose 传入会话
// - returnSession：池满时按 LRU 淘汰
// - take：取出后池不再持有
// - evictExcept：保留指定 ids
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
}
