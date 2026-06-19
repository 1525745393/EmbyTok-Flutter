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
}
