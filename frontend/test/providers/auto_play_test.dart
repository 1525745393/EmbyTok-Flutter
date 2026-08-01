// 自动播放功能测试

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:embytok_flutter/providers/video_playback_controller.dart';

void main() {
  // AppPreferencesService 内部使用 SharedPreferences，需要初始化测试绑定
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutoPlayNotifier', () {
    setUp(() {
      // mock 空的 SharedPreferences，避免 _load() 抛异常
      SharedPreferences.setMockInitialValues({});
    });

    // PR #72：初始值改为 false，避免 _load() 完成前触发纯净模式闪烁
    test('初始状态应该为 false（PR #72：默认关闭）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final isAutoPlay = container.read(isAutoPlayProvider);
      expect(isAutoPlay, false);
    });

    test('toggle() 方法应该切换状态', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 初始状态为 false（PR #72）
      expect(container.read(isAutoPlayProvider), false);

      // 切换后应该为 true
      await container.read(isAutoPlayProvider.notifier).toggle();
      expect(container.read(isAutoPlayProvider), true);

      // 再次切换应该为 false
      await container.read(isAutoPlayProvider.notifier).toggle();
      expect(container.read(isAutoPlayProvider), false);
    });

    test('setEnabled() 方法应该设置指定状态', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 设置为 true
      await container.read(isAutoPlayProvider.notifier).setEnabled(true);
      expect(container.read(isAutoPlayProvider), true);

      // 设置为 false
      await container.read(isAutoPlayProvider.notifier).setEnabled(false);
      expect(container.read(isAutoPlayProvider), false);
    });
  });
}
