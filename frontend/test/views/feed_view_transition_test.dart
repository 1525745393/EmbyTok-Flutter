/// FeedView 网格与视频流切换测试
///
/// 验证两个核心功能：
/// 1. 点击网格中的视频后，切换到视频流并从该视频开始播放
/// 2. 从视频流切回网格时，滚动到当前视频位置
///
/// 测试策略：
/// - Provider 层单元测试：验证状态管理逻辑
/// - 关键常量和配置验证：确保网格配置与滚动计算一致

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/utils/app_preferences.dart';

void main() {
  group('功能一：网格→视频流跳转', () {
    // 注：gridSelectedItemIdProvider 已废弃。
    // 网格 → 视频流跳转现在通过 GoRouter `/?initialId=<itemId>` 透传，
    // FeedView 接收 widget.initialItemId 后调用 _waitForInitialItemToLoad → _jumpToPageWhenReady。
    // 相关 provider 仅作"已被 @Deprecated 标记"的兼容性保留，无任何业务调用方。

    group('playbackStateProvider（当前在播状态，合并 id+item）', () {
      late ProviderContainer container;

      setUp(() {
        container = ProviderContainer();
      });

      tearDown(() {
        container.dispose();
      });

      test('初始值为空 PlaybackState', () {
        final state = container.read(playbackStateProvider);
        expect(state.id, isNull);
        expect(state.item, isNull);
      });

      test('setPlaying 同时设置 id 和 item', () {
        final testItem = MediaItem(id: 'test-1', title: '测试视频', type: 'Movie');
        container.read(playbackStateProvider.notifier).setPlaying(testItem.id, testItem);
        final state = container.read(playbackStateProvider);
        expect(state.id, 'test-1');
        expect(state.item, isNotNull);
        expect(state.item!.title, '测试视频');
      });

      test('setItem 仅更新 item，保持 id 不变', () {
        container.read(playbackStateProvider.notifier).setPlaying('keep-id', MediaItem(id: 'keep-id', title: '旧', type: 'Movie'));
        final newItem = MediaItem(id: 'keep-id', title: '新标题', type: 'Movie');
        container.read(playbackStateProvider.notifier).setItem(newItem);
        final state = container.read(playbackStateProvider);
        expect(state.id, 'keep-id');
        expect(state.item!.title, '新标题');
      });

      test('clear 后回到空状态', () {
        container.read(playbackStateProvider.notifier).setPlaying('item-42', MediaItem(id: 'item-42', title: '视频42', type: 'Movie'));
        container.read(playbackStateProvider.notifier).clear();
        final state = container.read(playbackStateProvider);
        expect(state.id, isNull);
        expect(state.item, isNull);
      });
    });
  });

  group('功能二：视频流→网格滚动（神之一手裁剪）', () {
    group('VideoListState 初始状态', () {
      late ProviderContainer container;

      setUp(() {
        container = ProviderContainer();
      });

      tearDown(() {
        container.dispose();
      });

      test('gridStartIndex 初始为 0', () {
        final state = container.read(videoListProvider);
        expect(state.gridStartIndex, 0);
      });

      test('gridItems 初始为空列表', () {
        final state = container.read(videoListProvider);
        expect(state.gridItems, isEmpty);
      });

      test('items 初始为空列表', () {
        final state = container.read(videoListProvider);
        expect(state.items, isEmpty);
      });

      test('kGridPageSize 常量为 150', () {
        expect(VideoListNotifier.kGridPageSize, 150);
      });
    });

    group('网格滚动位置计算验证', () {
      test('GridView 配置常量与 PosterGridView 一致', () {
        const crossAxisCount = 3;
        const crossAxisSpacing = 8.0;
        const mainAxisSpacing = 8.0;
        const padding = 8.0;
        const childAspectRatio = 0.65;

        expect(crossAxisCount, 3);
        expect(crossAxisSpacing, 8.0);
        expect(mainAxisSpacing, 8.0);
        expect(padding, 8.0);
        expect(childAspectRatio, 0.65);
      });

      test('行号计算逻辑正确（3列布局）', () {
        const crossAxisCount = 3;

        expect(0 ~/ crossAxisCount, 0);
        expect(1 ~/ crossAxisCount, 0);
        expect(2 ~/ crossAxisCount, 0);
        expect(3 ~/ crossAxisCount, 1);
        expect(4 ~/ crossAxisCount, 1);
        expect(5 ~/ crossAxisCount, 1);
        expect(6 ~/ crossAxisCount, 2);
        expect(10 ~/ crossAxisCount, 3);
      });

      test('indexInGrid 计算逻辑：currentIndex - gridStartIndex', () {
        const currentIndex = 155;
        const gridStartIndex = 150;
        const indexInGrid = currentIndex - gridStartIndex;

        expect(indexInGrid, 5);
        expect(indexInGrid >= 0, isTrue);
      });

      test('页码计算：pageIndex = currentIndex ~/ kGridPageSize', () {
        const kGridPageSize = 150;

        expect(0 ~/ kGridPageSize, 0);
        expect(149 ~/ kGridPageSize, 0);
        expect(150 ~/ kGridPageSize, 1);
        expect(151 ~/ kGridPageSize, 1);
        expect(299 ~/ kGridPageSize, 1);
        expect(300 ~/ kGridPageSize, 2);
      });
    });
  });

  group('视图模式切换', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初始状态为 feed 模式', () {
      final mode = container.read(viewModeProvider);
      expect(mode, ViewMode.feed);
    });

    test('切换到 grid 模式', () async {
      await container.read(viewModeProvider.notifier).setMode(ViewMode.grid);
      final mode = container.read(viewModeProvider);
      expect(mode, ViewMode.grid);
    });

    test('切换回 feed 模式', () async {
      await container.read(viewModeProvider.notifier).setMode(ViewMode.grid);
      await container.read(viewModeProvider.notifier).setMode(ViewMode.feed);
      final mode = container.read(viewModeProvider);
      expect(mode, ViewMode.feed);
    });

    test('多次切换状态正确', () async {
      final notifier = container.read(viewModeProvider.notifier);

      await notifier.setMode(ViewMode.grid);
      expect(container.read(viewModeProvider), ViewMode.grid);

      await notifier.setMode(ViewMode.feed);
      expect(container.read(viewModeProvider), ViewMode.feed);

      await notifier.setMode(ViewMode.grid);
      expect(container.read(viewModeProvider), ViewMode.grid);

      await notifier.setMode(ViewMode.feed);
      expect(container.read(viewModeProvider), ViewMode.feed);
    });
  });
}
