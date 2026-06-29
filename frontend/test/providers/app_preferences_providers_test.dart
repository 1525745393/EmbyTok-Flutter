/// AppPreferencesProviders 测试
///
/// 重点验证：
/// - DeviceModeNotifier: 设备模式切换（standard / tv）
/// - FeedTypeNotifier: 浏览模式切换
/// - ViewModeNotifier: 视图模式切换（feed / grid）
/// - OrientationModeNotifier: 方向过滤模式切换
/// - HiddenLibraryIdsNotifier: 隐藏媒体库集合管理

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embbytok_flutter/providers/app_preferences_providers.dart';
import 'package:embbytok_flutter/utils/app_preferences.dart';

void main() {
  group('DeviceModeNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初始状态为 standard', () {
      final state = container.read(deviceModeProvider);
      expect(state, DeviceMode.standard);
    });

    test('setMode 切换到 tv', () async {
      final notifier = container.read(deviceModeProvider.notifier);
      await notifier.setMode(DeviceMode.tv);
      final state = container.read(deviceModeProvider);
      expect(state, DeviceMode.tv);
    });
  });

  group('FeedTypeNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初始状态为 latest', () {
      final state = container.read(feedTypeProvider);
      expect(state, FeedType.latest);
    });

    test('setType 切换到 favorites', () async {
      final notifier = container.read(feedTypeProvider.notifier);
      await notifier.setType(FeedType.favorites);
      final state = container.read(feedTypeProvider);
      expect(state, FeedType.favorites);
    });

    test('setType 切换到 random', () async {
      final notifier = container.read(feedTypeProvider.notifier);
      await notifier.setType(FeedType.random);
      final state = container.read(feedTypeProvider);
      expect(state, FeedType.random);
    });

    test('setType 切换到 resume', () async {
      final notifier = container.read(feedTypeProvider.notifier);
      await notifier.setType(FeedType.resume);
      final state = container.read(feedTypeProvider);
      expect(state, FeedType.resume);
    });
  });

  group('ViewModeNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初始状态为 feed', () {
      final state = container.read(viewModeProvider);
      expect(state, ViewMode.feed);
    });

    test('setMode 切换到 grid', () async {
      final notifier = container.read(viewModeProvider.notifier);
      await notifier.setMode(ViewMode.grid);
      final state = container.read(viewModeProvider);
      expect(state, ViewMode.grid);
    });
  });

  group('OrientationModeNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初始状态为 both', () {
      final state = container.read(orientationModeProvider);
      expect(state, OrientationMode.both);
    });

    test('setMode 切换到 vertical', () async {
      final notifier = container.read(orientationModeProvider.notifier);
      await notifier.setMode(OrientationMode.vertical);
      final state = container.read(orientationModeProvider);
      expect(state, OrientationMode.vertical);
    });

    test('setMode 切换到 horizontal', () async {
      final notifier = container.read(orientationModeProvider.notifier);
      await notifier.setMode(OrientationMode.horizontal);
      final state = container.read(orientationModeProvider);
      expect(state, OrientationMode.horizontal);
    });
  });

  group('HiddenLibraryIdsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初始状态为空集合', () {
      final state = container.read(hiddenLibraryIdsProvider);
      expect(state, isEmpty);
    });

    test('toggle 添加一个库 ID', () async {
      final notifier = container.read(hiddenLibraryIdsProvider.notifier);
      await notifier.toggle('lib-123');
      final state = container.read(hiddenLibraryIdsProvider);
      expect(state, contains('lib-123'));
    });

    test('toggle 再次调用移除库 ID', () async {
      final notifier = container.read(hiddenLibraryIdsProvider.notifier);
      await notifier.toggle('lib-123');
      await notifier.toggle('lib-456');
      await notifier.toggle('lib-123'); // 再次调用，应移除
      final state = container.read(hiddenLibraryIdsProvider);
      expect(state, isNot(contains('lib-123')));
      expect(state, contains('lib-456'));
    });

    test('clear 清空所有库 ID', () async {
      final notifier = container.read(hiddenLibraryIdsProvider.notifier);
      await notifier.toggle('lib-1');
      await notifier.toggle('lib-2');
      await notifier.clear();
      final state = container.read(hiddenLibraryIdsProvider);
      expect(state, isEmpty);
    });
  });

  // ============== PR #85：用户控制（完播率门控 + 时间衰减） ==============
  group('RecommendUseWatchHistoryNotifier (PR #85)', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初始状态为 true', () {
      final state = container.read(recommendUseWatchHistoryProvider);
      expect(state, true);
    });

    test('setUse 切换到 false', () async {
      final notifier = container.read(recommendUseWatchHistoryProvider.notifier);
      await notifier.setUse(false);
      final state = container.read(recommendUseWatchHistoryProvider);
      expect(state, false);
    });
  });

  group('RecommendHalfLifeDaysNotifier (PR #85)', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初始状态为 14.0', () {
      final state = container.read(recommendHalfLifeDaysProvider);
      expect(state, 14.0);
    });

    test('setDays 接受合法值', () async {
      final notifier = container.read(recommendHalfLifeDaysProvider.notifier);
      await notifier.setDays(7.0);
      final state = container.read(recommendHalfLifeDaysProvider);
      expect(state, 7.0);
    });

    test('setDays 限制在 [0, 90]', () async {
      final notifier = container.read(recommendHalfLifeDaysProvider.notifier);
      await notifier.setDays(200.0);
      expect(container.read(recommendHalfLifeDaysProvider), 90.0);
      await notifier.setDays(-5.0);
      expect(container.read(recommendHalfLifeDaysProvider), 0.0);
    });
  });

  // ============== PR #88：用户控制（反推荐疲劳） ==============
  group('RecommendAntiFatigueEnabledNotifier (PR #88)', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初始状态为 true', () {
      final state = container.read(recommendAntiFatigueEnabledProvider);
      expect(state, true);
    });

    test('setEnabled 切换到 false', () async {
      final notifier = container.read(recommendAntiFatigueEnabledProvider.notifier);
      await notifier.setEnabled(false);
      final state = container.read(recommendAntiFatigueEnabledProvider);
      expect(state, false);
    });
  });

  group('RecommendAntiFatigueDaysNotifier (PR #88)', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初始状态为 30', () {
      final state = container.read(recommendAntiFatigueDaysProvider);
      expect(state, 30);
    });

    test('setDays 接受合法值', () async {
      final notifier = container.read(recommendAntiFatigueDaysProvider.notifier);
      await notifier.setDays(7);
      final state = container.read(recommendAntiFatigueDaysProvider);
      expect(state, 7);
    });

    test('setDays 限制在 [1, 90]', () async {
      final notifier = container.read(recommendAntiFatigueDaysProvider.notifier);
      await notifier.setDays(200);
      expect(container.read(recommendAntiFatigueDaysProvider), 90);
      await notifier.setDays(0);
      expect(container.read(recommendAntiFatigueDaysProvider), 1);
    });
  });

  group('RecentlyShownItemIdsNotifier (PR #88)', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初始状态为空集合', () {
      final state = container.read(recentlyShownItemIdsProvider);
      expect(state, isEmpty);
    });

    test('addAll 添加 itemIds', () async {
      final notifier = container.read(recentlyShownItemIdsProvider.notifier);
      await notifier.addAll(['a', 'b', 'c']);
      final state = container.read(recentlyShownItemIdsProvider);
      expect(state, containsAll(['a', 'b', 'c']));
    });

    test('addAll 空集合无变化', () async {
      final notifier = container.read(recentlyShownItemIdsProvider.notifier);
      await notifier.addAll(<String>[]);
      final state = container.read(recentlyShownItemIdsProvider);
      expect(state, isEmpty);
    });

    test('addAll 去重', () async {
      final notifier = container.read(recentlyShownItemIdsProvider.notifier);
      await notifier.addAll(['a', 'b']);
      await notifier.addAll(['b', 'c', 'a']);
      final state = container.read(recentlyShownItemIdsProvider);
      expect(state.length, 3);
    });

    test('clear 清空所有 itemId', () async {
      final notifier = container.read(recentlyShownItemIdsProvider.notifier);
      await notifier.addAll(['a', 'b']);
      await notifier.clear();
      final state = container.read(recentlyShownItemIdsProvider);
      expect(state, isEmpty);
    });

    test('addAll 容量限制 500（FIFO 清理）', () async {
      final notifier = container.read(recentlyShownItemIdsProvider.notifier);
      // 一次添加 600 个（501..1100）
      final ids = List<String>.generate(600, (i) => 'item-$i');
      await notifier.addAll(ids);
      final state = container.read(recentlyShownItemIdsProvider);
      // 应该裁剪到 500 个最新的（即 item-100..item-599）
      expect(state.length, 500);
      // 最早的 item-0 已被淘汰
      expect(state.contains('item-0'), false);
      // 最新的 item-599 保留
      expect(state.contains('item-599'), true);
    });
  });
}
