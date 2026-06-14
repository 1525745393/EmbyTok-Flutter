// 自动播放功能测试

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:embbytok_flutter/providers/video_playback_controller.dart';

void main() {
  group('AutoPlayNotifier', () {
    test('初始状态应该为 true（默认开启）', () {
      final container = ProviderContainer();
      final isAutoPlay = container.read(isAutoPlayProvider);
      expect(isAutoPlay, true);
    });

    test('toggle() 方法应该切换状态', () async {
      final container = ProviderContainer();
      
      // 初始状态为 true
      expect(container.read(isAutoPlayProvider), true);
      
      // 切换后应该为 false
      await container.read(isAutoPlayProvider.notifier).toggle();
      expect(container.read(isAutoPlayProvider), false);
      
      // 再次切换应该为 true
      await container.read(isAutoPlayProvider.notifier).toggle();
      expect(container.read(isAutoPlayProvider), true);
    });

    test('setEnabled() 方法应该设置指定状态', () async {
      final container = ProviderContainer();
      
      // 设置为 false
      await container.read(isAutoPlayProvider.notifier).setEnabled(false);
      expect(container.read(isAutoPlayProvider), false);
      
      // 设置为 true
      await container.read(isAutoPlayProvider.notifier).setEnabled(true);
      expect(container.read(isAutoPlayProvider), true);
    });
  });
}
