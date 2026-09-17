// Android 系统手势排除工具
//
// 配合 MainActivity 的「com.embytok/system_gesture」MethodChannel：
// 全屏播放时排除屏幕左右边缘的返回手势区域，避免用户从边缘起手
// 水平拖动进度时被系统返回手势抢占而退出全屏。
// 退出全屏时清除，恢复系统边缘返回手势。
//
// 非 Android 平台（iOS/桌面/Web）自动忽略；Android 10 以下（API < 29）
// 原生侧忽略，均无副作用。

import 'package:flutter/services.dart';

class SystemGestureExclusion {
  SystemGestureExclusion._();

  static const MethodChannel _channel =
      MethodChannel('com.embytok/system_gesture');

  /// 启用/停用全屏边缘手势排除
  ///
  /// [enabled] 为 true 时排除左右边缘（原生按当前窗口尺寸计算，
  /// 旋转后需重新调用以按新尺寸重算）。
  static Future<void> setFullscreenExclusion(bool enabled) async {
    try {
      await _channel
          .invokeMethod('setFullscreenExclusion', {'enabled': enabled});
    } catch (_) {
      // 通道不存在（iOS/桌面/Web）或调用失败时静默忽略，
      // 不影响播放功能，仅失去边缘手势排除能力
    }
  }
}
