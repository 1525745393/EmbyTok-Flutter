// 移动端专项 #1 回归：TMDB key 安全存储迁移
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/services/tmdb_service.dart';

void main() {
  const legacyKey = 'tmdb_api_key';

  setUp(() {
    TmdbService.resetForTest();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('TmdbService key 存储', () {
    test('setUserKey/getUserKey 走安全存储往返', () async {
      await TmdbService.setUserKey('secret-key-abc');
      TmdbService.resetForTest(); // 模拟冷启动，走读取路径
      expect(await TmdbService.getUserKey(), 'secret-key-abc');

      // 安全存储中确有值，且 SharedPreferences 无明文残留
      final sp = await SharedPreferences.getInstance();
      expect(sp.getString(legacyKey), isNull);
    });

    test('清除 key 后 getUserKey 返回 null 且安全存储删除', () async {
      await TmdbService.setUserKey('secret-key-abc');
      await TmdbService.setUserKey('');
      TmdbService.resetForTest();
      expect(await TmdbService.getUserKey(), isNull);
    });

    test('旧版 SharedPreferences 明文自动迁移到安全存储并删除明文', () async {
      // 模拟旧版本：明文存在于 SharedPreferences
      SharedPreferences.setMockInitialValues({legacyKey: 'legacy-key-xyz'});
      TmdbService.resetForTest();

      expect(await TmdbService.getUserKey(), 'legacy-key-xyz');

      // 明文键已删除，新值在安全存储
      final sp = await SharedPreferences.getInstance();
      expect(sp.getString(legacyKey), isNull);
      TmdbService.resetForTest();
      expect(await TmdbService.getUserKey(), 'legacy-key-xyz');
    });

    test('无任何存储时 getUserKey 返回 null', () async {
      TmdbService.resetForTest();
      expect(await TmdbService.getUserKey(), isNull);
    });
  });
}
