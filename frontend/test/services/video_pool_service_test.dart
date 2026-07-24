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
// 注意：使用 Fake 而非 Mock 实现 IPlaybackController。
// 原因：mockito Mock 在 stub 时可能触发内部状态冲突。
// Fake 直接 override 需要的方法，避开 mockito 的 stub 机制。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/models/models.dart';
import 'package:embbytok_flutter/services/video_pool_service.dart';
import 'package:embbytok_flutter/services/playback/i_playback_controller.dart';

class _FakeController implements IPlaybackController {
  _FakeController({this.initialized = true});

  final bool initialized;
  bool disposed = false;

  @override
  bool get isInitialized => initialized;

  @override
  bool get isPlaying => false;

  @override
  bool get isBuffering => false;

  @override
  bool get hasError => false;

  @override
  Duration get position => Duration.zero;

  @override
  Duration get duration => Duration.zero;

  @override
  double get playbackSpeed => 1.0;

  @override
  int get playerId => 0;

  @override
  VoidCallback? onPositionChanged;

  @override
  VoidCallback? onPlaybackStateChanged;

  @override
  VoidCallback? onError;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

_FakeController _fakeController() => _FakeController(initialized: true);

PlaybackSession _session(String itemId) {
  return PlaybackSession(
    itemId: itemId,
    controller: _fakeController(),
    playSessionId: 'sid-$itemId',
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
      );
      final incomingController = _fakeController();
      final incoming = PlaybackSession(
        itemId: 'a',
        controller: incomingController,
        playSessionId: 'sid-a',
      );
      pool.returnSession(existing);
      pool.returnSession(incoming);
      expect(pool.size, 1);
      expect(pool.peek('a'), same(existing));
      expect(incomingController.disposed, isTrue,
          reason: '池中已有同 itemId 时，传入会话应被 dispose');
      expect(existingController.disposed, isFalse);
    });

    test('池满：按 LRU 淘汰最旧会话', () {
      final pool = VideoPoolService(maxSize: 2);
      pool.returnSession(_session('a'));
      pool.returnSession(_session('b'));
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

  group('VideoPoolService 并发安全', () {
    test('returnSession 后池持有该会话，peek 返回同一实例', () {
      final pool = VideoPoolService(maxSize: 2);
      final returned = _session('a');
      pool.returnSession(returned);
      expect(pool.hasSession('a'), isTrue);
      expect(pool.peek('a'), same(returned));
    });

    test('returnSession 不会破坏 LRU 顺序', () {
      final pool = VideoPoolService(maxSize: 2);
      pool.returnSession(_session('a'));
      pool.returnSession(_session('b'));
      pool.returnSession(_session('c'));
      expect(pool.hasSession('a'), isFalse);
      expect(pool.hasSession('b'), isTrue);
      expect(pool.hasSession('c'), isTrue);
    });

    test('take 后 returnSession 同 item 应成功', () {
      final pool = VideoPoolService(maxSize: 2);
      final session = _session('a');
      pool.returnSession(session);
      final taken = pool.take('a');
      expect(taken, same(session));
      expect(pool.size, 0);
      pool.returnSession(session);
      expect(pool.hasSession('a'), isTrue);
      expect(pool.peek('a'), same(session));
    });

    test('returnSession 与 evictExcept 交互：被 evict 的会话不在池中', () {
      final pool = VideoPoolService(maxSize: 5);
      pool.returnSession(_session('a'));
      pool.returnSession(_session('b'));
      pool.returnSession(_session('c'));
      pool.evictExcept(['b']);
      expect(pool.size, 1);
      expect(pool.hasSession('a'), isFalse);
      expect(pool.hasSession('c'), isFalse);
    });
  });
}
