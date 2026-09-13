// colors 单元测试
//
// 验证颜色常量的存在性和基本属性。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/utils/colors.dart';

void main() {
  group('colors - 主题色', () {
    test('primaryPink 是 Color 类型', () {
      expect(primaryPink, isA<Color>());
    });

    test('primaryPink 值正确', () {
      expect(primaryPink.toARGB32(), 0xFFE91E63);
    });

    test('historyPink 是 Color 类型', () {
      expect(historyPink, isA<Color>());
    });

    test('errorColor 是 Color 类型', () {
      expect(errorColor, isA<Color>());
    });

    test('amberColor 是 Color 类型', () {
      expect(amberColor, isA<Color>());
    });
  });

  group('colors - 背景色', () {
    test('backgroundColor 是纯黑', () {
      expect(backgroundColor, Colors.black);
    });

    test('surfaceColorL1/L2/L3 递增亮度', () {
      // L1 < L2 < L3（数值越大越亮）
      expect(surfaceColorL1.toARGB32() < surfaceColorL2.toARGB32(), true);
      expect(surfaceColorL2.toARGB32() < surfaceColorL3.toARGB32(), true);
    });

    test('surfaceColorL1 值正确', () {
      expect(surfaceColorL1.toARGB32(), 0xFF121212);
    });

    test('surfaceColorL2 值正确', () {
      expect(surfaceColorL2.toARGB32(), 0xFF1E1E1E);
    });

    test('surfaceColorL3 值正确', () {
      expect(surfaceColorL3.toARGB32(), 0xFF2A2A2A);
    });
  });

  group('colors - 文本色', () {
    test('textPrimary 是纯白', () {
      expect(textPrimary, Colors.white);
    });

    test('textSecondary 不透明度 70%', () {
      // 0xB3 = 179 = 255 * 0.7
      expect(textSecondary.alpha, 0xB3);
    });

    test('textTertiary 不透明度 54%', () {
      expect(textTertiary.alpha, 0x8A);
    });

    test('textQuaternary 不透明度 38%', () {
      expect(textQuaternary.alpha, 0x61);
    });

    test('textPlaceholder 不透明度 30%', () {
      expect(textPlaceholder.alpha, 0x4D);
    });

    test('文本色透明度递减', () {
      expect(textPrimary.alpha > textSecondary.alpha, true);
      expect(textSecondary.alpha > textTertiary.alpha, true);
      expect(textTertiary.alpha > textQuaternary.alpha, true);
      expect(textQuaternary.alpha > textPlaceholder.alpha, true);
    });
  });

  group('colors - 功能色', () {
    test('dividerColor 不透明度 12%', () {
      expect(dividerColor.alpha, 0x1F);
    });

    test('progressBackground 不透明度 24%', () {
      expect(progressBackground.alpha, 0x3D);
    });

    test('durationBadgeBackground 不透明度 70%', () {
      expect(durationBadgeBackground.alpha, 0xB3);
    });
  });

  group('colors - 半透明黑色', () {
    test('black54 不透明度 54%', () {
      expect(black54.alpha, 0x8A);
    });

    test('black87 不透明度 87%', () {
      expect(black87.alpha, 0xDE);
    });

    test('overlayBlack 不透明度 67%', () {
      expect(overlayBlack.alpha, 0xAA);
    });

    test('overlayBlackDeep 不透明度 80%', () {
      expect(overlayBlackDeep.alpha, 0xCC);
    });

    test('半透明黑色透明度递增', () {
      expect(black54.alpha < overlayBlack.alpha, true);
      expect(overlayBlack.alpha < overlayBlackDeep.alpha, true);
      expect(overlayBlackDeep.alpha < black87.alpha, true);
    });
  });

  group('colors - 灰色系', () {
    test('grey50 到 grey900 递增', () {
      final greys = [
        grey50, grey100, grey200, grey300, grey400,
        grey500, grey600, grey700, grey800, grey850, grey900,
      ];
      for (var i = 0; i < greys.length - 1; i++) {
        expect(greys[i].toARGB32() > greys[i + 1].toARGB32(), true,
            reason: 'grey${i * 100} 应比 grey${(i + 1) * 100} 亮');
      }
    });

    test('grey500 值正确', () {
      expect(grey500.toARGB32(), 0xFF9E9E9E);
    });

    test('grey900 值正确', () {
      expect(grey900.toARGB32(), 0xFF212121);
    });
  });
}
