/// UserPreferencesProvider 测试
///
/// 重点验证：
/// - DefaultPlaybackRateNotifier: 倍速设置
/// - DefaultSubtitleLanguageNotifier: 默认字幕语言
/// - CacheSizeNotifier: 缓存大小

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:embbytok_flutter/providers/user_preferences_provider.dart';

void main() {
  group('DefaultPlaybackRateNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初始状态为 1.0x', () {
      final state = container.read(defaultPlaybackRateProvider);
      expect(state, 1.0);
    });

    test('set 设置合法倍速', () {
      final notifier = container.read(defaultPlaybackRateProvider.notifier);
      notifier.set(1.5);
      final state = container.read(defaultPlaybackRateProvider);
      expect(state, 1.5);
    });

    test('set 拒绝小于最小倍速的值', () {
      final notifier = container.read(defaultPlaybackRateProvider.notifier);
      notifier.set(0.1); // 小于 0.25，被拒绝
      final state = container.read(defaultPlaybackRateProvider);
      expect(state, 1.0); // 保持原值
    });

    test('set 拒绝大于最大倍速的值', () {
      final notifier = container.read(defaultPlaybackRateProvider.notifier);
      notifier.set(5.0); // 大于 3.0，被拒绝
      final state = container.read(defaultPlaybackRateProvider);
      expect(state, 1.0); // 保持原值
    });
  });

  group('DefaultSubtitleLanguageNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初始状态为空字符串', () {
      final state = container.read(defaultSubtitleLanguageProvider);
      expect(state, '');
    });

    test('set 设置默认语言', () {
      final notifier = container.read(defaultSubtitleLanguageProvider.notifier);
      notifier.set('chi');
      final state = container.read(defaultSubtitleLanguageProvider);
      expect(state, 'chi');
    });

    test('set 设置为空表示关闭字幕', () {
      final notifier = container.read(defaultSubtitleLanguageProvider.notifier);
      notifier.set('eng');
      notifier.set('');
      final state = container.read(defaultSubtitleLanguageProvider);
      expect(state, '');
    });
  });

  group('CacheSizeNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初始状态为 0', () {
      final state = container.read(cacheSizeProvider);
      expect(state, 0);
    });

    test('set 设置缓存大小', () {
      final notifier = container.read(cacheSizeProvider.notifier);
      notifier.set(1024 * 1024); // 1MB
      final state = container.read(cacheSizeProvider);
      expect(state, 1024 * 1024);
    });

    test('clear 清空缓存大小', () {
      final notifier = container.read(cacheSizeProvider.notifier);
      notifier.set(1024 * 1024);
      notifier.clear();
      final state = container.read(cacheSizeProvider);
      expect(state, 0);
    });
  });
}
