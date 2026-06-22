/// SubtitleSettingsProvider 测试
///
/// 重点验证：
/// - 初始状态
/// - 设置语言、字号、颜色、位置
/// - 持久化到 SharedPreferences

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embbytok_flutter/providers/subtitle_settings_provider.dart';
import 'package:embbytok_flutter/utils/constants.dart';

void main() {
  group('SubtitleSettings', () {
    test('初始状态正确（语言为空，其他为默认值）', () {
      const settings = SubtitleSettings();
      expect(settings.language, '');
      expect(settings.enabled, false);
      expect(settings.size, kSubtitleSizeMedium);
      expect(settings.color, kSubtitleColorWhite);
      expect(settings.position, kSubtitlePosBottom);
      expect(settings.fontSize, 18.0);
    });

    test('copyWith 正确更新字段', () {
      const original = SubtitleSettings();
      final updated = original.copyWith(
        language: 'zh',
        size: kSubtitleSizeSmall,
        color: kSubtitleColorYellow,
        position: kSubtitlePosCenter,
      );
      expect(updated.language, 'zh');
      expect(updated.enabled, true);
      expect(updated.size, kSubtitleSizeSmall);
      expect(updated.color, kSubtitleColorYellow);
      expect(updated.position, kSubtitlePosCenter);
      expect(updated.fontSize, 14.0);
    });

    test('toJson / fromJson 序列化与反序列化', () {
      final original = const SubtitleSettings(
        language: 'chi',
        size: kSubtitleSizeLarge,
        color: kSubtitleColorWhite,
        position: kSubtitlePosLower,
      );
      final json = original.toJson();
      final restored = SubtitleSettings.fromJson(json);
      expect(restored.language, 'chi');
      expect(restored.size, kSubtitleSizeLarge);
      expect(restored.color, kSubtitleColorWhite);
      expect(restored.position, kSubtitlePosLower);
    });
  });

  group('SubtitleSettingsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初始状态：language为空', () async {
      final state = container.read(subtitleSettingsProvider);
      expect(state.language, '');
      expect(state.enabled, false);
    });

    test('setLanguage 更新语言', () async {
      final notifier = container.read(subtitleSettingsProvider.notifier);
      notifier.setLanguage('chi');
      // Provider 状态需要短暂延迟让异步写入
      await Future.delayed(const Duration(milliseconds: 20));
      final state = container.read(subtitleSettingsProvider);
      expect(state.language, 'chi');
      expect(state.enabled, true);
    });

    test('setSize 更新字号', () async {
      final notifier = container.read(subtitleSettingsProvider.notifier);
      notifier.setSize(kSubtitleSizeLarge);
      await Future.delayed(const Duration(milliseconds: 20));
      final state = container.read(subtitleSettingsProvider);
      expect(state.size, kSubtitleSizeLarge);
    });

    test('setColor 更新颜色', () async {
      final notifier = container.read(subtitleSettingsProvider.notifier);
      notifier.setColor(kSubtitleColorYellow);
      await Future.delayed(const Duration(milliseconds: 20));
      final state = container.read(subtitleSettingsProvider);
      expect(state.color, kSubtitleColorYellow);
    });

    test('setPosition 更新位置', () async {
      final notifier = container.read(subtitleSettingsProvider.notifier);
      notifier.setPosition(kSubtitlePosCenter);
      await Future.delayed(const Duration(milliseconds: 20));
      final state = container.read(subtitleSettingsProvider);
      expect(state.position, kSubtitlePosCenter);
    });

    test('update 批量更新设置', () async {
      final notifier = container.read(subtitleSettingsProvider.notifier);
      notifier.update(
        language: 'eng',
        size: kSubtitleSizeSmall,
        color: kSubtitleColorWhite,
        position: kSubtitlePosBottom,
      );
      await Future.delayed(const Duration(milliseconds: 20));
      final state = container.read(subtitleSettingsProvider);
      expect(state.language, 'eng');
      expect(state.size, kSubtitleSizeSmall);
      expect(state.color, kSubtitleColorWhite);
      expect(state.position, kSubtitlePosBottom);
    });

    test('从 SharedPreferences 恢复设置', () async {
      SharedPreferences.setMockInitialValues({
        kStorageKeySubtitle: json.encode({
          'language': 'chi',
          'size': kSubtitleSizeLarge,
          'color': kSubtitleColorYellow,
          'position': kSubtitlePosCenter,
        }),
      });

      final newContainer = ProviderContainer();
      await Future.delayed(const Duration(milliseconds: 100));

      final state = newContainer.read(subtitleSettingsProvider);
      expect(state.language, 'chi');
      expect(state.size, kSubtitleSizeLarge);
      expect(state.color, kSubtitleColorYellow);
      expect(state.position, kSubtitlePosCenter);

      newContainer.dispose();
    });

    test('SharedPreferences 配置损坏时忽略错误', () async {
      SharedPreferences.setMockInitialValues({
        kStorageKeySubtitle: 'invalid json {{{',
      });

      final newContainer = ProviderContainer();
      await Future.delayed(const Duration(milliseconds: 100));

      final state = newContainer.read(subtitleSettingsProvider);
      // 损坏的配置被忽略，使用默认值
      expect(state.language, '');
      expect(state.size, kSubtitleSizeMedium);

      newContainer.dispose();
    });
  });
}
