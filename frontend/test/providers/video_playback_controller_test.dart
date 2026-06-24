// 视频播放控制器 Notifier 测试

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:embbytok_flutter/providers/video_playback_controller.dart';

void main() {
  group('PlaybackLevelNotifier', () {
    test('初始状态为 0 (DirectPlay)', () {
      final container = ProviderContainer();
      final level = container.read(playbackLevelProvider);
      expect(level, 0);
    });

    test('setLevel 接受有效值 0-2', () {
      final container = ProviderContainer();

      container.read(playbackLevelProvider.notifier).setLevel(0);
      expect(container.read(playbackLevelProvider), 0);

      container.read(playbackLevelProvider.notifier).setLevel(1);
      expect(container.read(playbackLevelProvider), 1);

      container.read(playbackLevelProvider.notifier).setLevel(2);
      expect(container.read(playbackLevelProvider), 2);
    });

    test('setLevel 拒绝无效值 (负数)', () {
      final container = ProviderContainer();
      container.read(playbackLevelProvider.notifier).setLevel(0);
      container.read(playbackLevelProvider.notifier).setLevel(-1);
      expect(container.read(playbackLevelProvider), 0);
    });

    test('setLevel 拒绝无效值 (大于2)', () {
      final container = ProviderContainer();
      container.read(playbackLevelProvider.notifier).setLevel(0);
      container.read(playbackLevelProvider.notifier).setLevel(3);
      expect(container.read(playbackLevelProvider), 0);
    });

    test('reset 将等级重置为 0', () {
      final container = ProviderContainer();
      container.read(playbackLevelProvider.notifier).setLevel(2);
      expect(container.read(playbackLevelProvider), 2);

      container.read(playbackLevelProvider.notifier).reset();
      expect(container.read(playbackLevelProvider), 0);
    });
  });

  group('VideoReadyNotifier', () {
    test('初始状态为空 Set', () {
      final container = ProviderContainer();
      final readySet = container.read(videoReadyProvider);
      expect(readySet, isEmpty);
    });

    test('markReady 将 itemId 添加到就绪集合', () {
      final container = ProviderContainer();
      final notifier = container.read(videoReadyProvider.notifier);

      notifier.markReady('item-1');
      expect(container.read(videoReadyProvider), contains('item-1'));

      notifier.markReady('item-2');
      final readySet = container.read(videoReadyProvider);
      expect(readySet, containsAll(['item-1', 'item-2']));
    });

    test('markReady 重复调用不添加重复', () {
      final container = ProviderContainer();
      final notifier = container.read(videoReadyProvider.notifier);

      notifier.markReady('item-1');
      notifier.markReady('item-1');
      notifier.markReady('item-1');

      final readySet = container.read(videoReadyProvider);
      expect(readySet.length, 1);
    });

    test('isReady 返回 itemId 是否已就绪', () {
      final container = ProviderContainer();
      final notifier = container.read(videoReadyProvider.notifier);

      expect(notifier.isReady('item-1'), false);

      notifier.markReady('item-1');
      expect(notifier.isReady('item-1'), true);
      expect(notifier.isReady('item-2'), false);
    });

    test('clear 从就绪集合中移除 itemId', () {
      final container = ProviderContainer();
      final notifier = container.read(videoReadyProvider.notifier);

      notifier.markReady('item-1');
      notifier.markReady('item-2');
      expect(container.read(videoReadyProvider), containsAll(['item-1', 'item-2']));

      notifier.clear('item-1');
      final readySet = container.read(videoReadyProvider);
      expect(readySet, isNot(contains('item-1')));
      expect(readySet, contains('item-2'));
    });

    test('clear 不存在的 itemId 不抛出错误', () {
      final container = ProviderContainer();
      final notifier = container.read(videoReadyProvider.notifier);

      notifier.markReady('item-1');
      notifier.clear('item-nonexistent');

      expect(container.read(videoReadyProvider), contains('item-1'));
    });
  });

  group('PreloadThresholdNotifier', () {
    test('初始状态为默认值 kDefaultPreloadThreshold', () {
      final container = ProviderContainer();
      final threshold = container.read(preloadThresholdProvider);
      expect(threshold, 0.6); // kDefaultPreloadThreshold = 0.6
    });

    test('setThreshold 接受有效值 0.1-0.95', () {
      final container = ProviderContainer();
      final notifier = container.read(preloadThresholdProvider.notifier);

      notifier.setThreshold(0.1);
      expect(container.read(preloadThresholdProvider), 0.1);

      notifier.setThreshold(0.5);
      expect(container.read(preloadThresholdProvider), 0.5);

      notifier.setThreshold(0.95);
      expect(container.read(preloadThresholdProvider), 0.95);
    });

    test('setThreshold 拒绝小于 0.1 的值', () {
      final container = ProviderContainer();
      final notifier = container.read(preloadThresholdProvider.notifier);

      notifier.setThreshold(0.5);
      notifier.setThreshold(0.05);
      expect(container.read(preloadThresholdProvider), 0.5);
    });

    test('setThreshold 拒绝大于 0.95 的值', () {
      final container = ProviderContainer();
      final notifier = container.read(preloadThresholdProvider.notifier);

      notifier.setThreshold(0.5);
      notifier.setThreshold(1.0);
      expect(container.read(preloadThresholdProvider), 0.5);
    });
  });
}
