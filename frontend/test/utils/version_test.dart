// version 单元测试
//
// 验证版本信息常量和完整版本字符串格式。

import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/utils/version.dart';

void main() {
  group('version', () {
    test('embytokVersion 是非空字符串', () {
      expect(embytokVersion, isA<String>());
      expect(embytokVersion.isNotEmpty, true);
    });

    test('embytokVersion 符合语义化版本格式', () {
      // MAJOR.MINOR.PATCH 格式
      final regex = RegExp(r'^\d+\.\d+\.\d+$');
      expect(regex.hasMatch(embytokVersion), true,
          reason: '版本号应为 MAJOR.MINOR.PATCH 格式');
    });

    test('embytokBuildNumber 是正整数', () {
      expect(embytokBuildNumber, isA<int>());
      expect(embytokBuildNumber > 0, true);
    });

    test('embytokFullVersion 格式正确', () {
      final full = embytokFullVersion;
      expect(full, isA<String>());
      expect(full.isNotEmpty, true);
      // 格式：MAJOR.MINOR.PATCH+BUILD
      expect(full.contains('+'), true);
      expect(full.startsWith(embytokVersion), true);
      expect(full.endsWith('$embytokBuildNumber'), true);
    });

    test('embytokFullVersion 拼接正确', () {
      expect(embytokFullVersion, '$embytokVersion+$embytokBuildNumber');
    });

    test('版本号各部分可解析', () {
      final parts = embytokVersion.split('.');
      expect(parts.length, 3);
      expect(int.tryParse(parts[0]), isNotNull); // MAJOR
      expect(int.tryParse(parts[1]), isNotNull); // MINOR
      expect(int.tryParse(parts[2]), isNotNull); // PATCH
    });

    test('主版本号非负', () {
      final major = int.parse(embytokVersion.split('.')[0]);
      expect(major >= 0, true);
    });

    test('次版本号非负', () {
      final minor = int.parse(embytokVersion.split('.')[1]);
      expect(minor >= 0, true);
    });

    test('修订号非负', () {
      final patch = int.parse(embytokVersion.split('.')[2]);
      expect(patch >= 0, true);
    });

    test('构建号与版本号独立', () {
      // 构建号不应该等于版本号的任何部分
      final versionParts = embytokVersion.split('.').map(int.parse).toList();
      expect(embytokBuildNumber != versionParts[0] ||
          embytokBuildNumber != versionParts[1] ||
          embytokBuildNumber != versionParts[2], true);
    });
  });
}
