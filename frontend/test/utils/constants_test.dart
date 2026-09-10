// constants 单元测试
//
// 验证常量定义的存在性和基本格式。

import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/utils/constants.dart';

void main() {
  group('constants - 存储 Key', () {
    test('kStorageKeyConfig 存在且非空', () {
      expect(kStorageKeyConfig, isA<String>());
      expect(kStorageKeyConfig.isNotEmpty, true);
    });

    test('kStorageKeyHistory 存在且非空', () {
      expect(kStorageKeyHistory, isA<String>());
      expect(kStorageKeyHistory.isNotEmpty, true);
    });

    test('kStorageKeySearchHistory 存在且非空', () {
      expect(kStorageKeySearchHistory, isA<String>());
      expect(kStorageKeySearchHistory.isNotEmpty, true);
    });

    test('kStorageKeySubtitle 存在且非空', () {
      expect(kStorageKeySubtitle, isA<String>());
      expect(kStorageKeySubtitle.isNotEmpty, true);
    });

    test('kStorageKeyPlaybackRate 存在且非空', () {
      expect(kStorageKeyPlaybackRate, isA<String>());
      expect(kStorageKeyPlaybackRate.isNotEmpty, true);
    });

    test('kStorageKeyIsMuted 存在且非空', () {
      expect(kStorageKeyIsMuted, isA<String>());
      expect(kStorageKeyIsMuted.isNotEmpty, true);
    });

    test('kStorageKeyIsAutoPlay 存在且非空', () {
      expect(kStorageKeyIsAutoPlay, isA<String>());
      expect(kStorageKeyIsAutoPlay.isNotEmpty, true);
    });

    test('P0-1: kStorageKeyAllowSelfSignedCertificate 存在且非空', () {
      expect(kStorageKeyAllowSelfSignedCertificate, isA<String>());
      expect(kStorageKeyAllowSelfSignedCertificate.isNotEmpty, true);
    });

    test('存储 Key 统一使用 embytok_ 前缀', () {
      final keys = [
        kStorageKeyConfig,
        kStorageKeyHistory,
        kStorageKeySearchHistory,
        kStorageKeySubtitle,
        kStorageKeyPlaybackRate,
        kStorageKeyIsMuted,
        kStorageKeyIsAutoPlay,
        kStorageKeyAllowSelfSignedCertificate,
      ];
      for (final key in keys) {
        expect(key.startsWith('embytok_'), true,
            reason: '存储 Key $key 应使用 embytok_ 前缀');
      }
    });

    test('存储 Key 不包含空格', () {
      final keys = [
        kStorageKeyConfig,
        kStorageKeyHistory,
        kStorageKeySearchHistory,
        kStorageKeySubtitle,
        kStorageKeyPlaybackRate,
      ];
      for (final key in keys) {
        expect(key.contains(' '), false,
            reason: '存储 Key $key 不应包含空格');
      }
    });
  });

  group('constants - 其他常量', () {
    test('kStorageKeyForceDeviceMode 存在', () {
      expect(kStorageKeyForceDeviceMode, isA<String>());
    });

    test('kStorageKeyFeedType 存在', () {
      expect(kStorageKeyFeedType, isA<String>());
    });

    test('kStorageKeyViewMode 存在', () {
      expect(kStorageKeyViewMode, isA<String>());
    });

    test('kStorageKeyOrientationMode 存在', () {
      expect(kStorageKeyOrientationMode, isA<String>());
    });

    test('kStorageKeyHiddenLibraryIds 存在', () {
      expect(kStorageKeyHiddenLibraryIds, isA<String>());
    });

    test('kStorageKeyDefaultPlaybackRate 存在', () {
      expect(kStorageKeyDefaultPlaybackRate, isA<String>());
    });

    test('kStorageKeyDefaultSubtitleLanguage 存在', () {
      expect(kStorageKeyDefaultSubtitleLanguage, isA<String>());
    });

    test('kStorageKeySubtitleSize 存在', () {
      expect(kStorageKeySubtitleSize, isA<String>());
    });
  });
}
