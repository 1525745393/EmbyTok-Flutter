// 画中画（PiP）工具：通过 MethodChannel 调用 Android 原生 PiP
//
// P0 差距项：横屏播放器支持画中画模式。
// Android 12+ 原生支持，iOS 需 MDP 配置（暂不支持）。

import 'package:flutter/services.dart';

class PipUtil {
  static const MethodChannel _channel = MethodChannel('embytok/pip');

  /// 检查当前平台是否支持 PiP
  static Future<bool> isPipSupported() async {
    try {
      return await _channel.invokeMethod('isPipSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 进入画中画模式
  static Future<bool> enterPip() async {
    try {
      return await _channel.invokeMethod('enterPip') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 检查当前是否处于 PiP 模式
  static Future<bool> isInPip() async {
    try {
      return await _channel.invokeMethod('isInPip') ?? false;
    } catch (_) {
      return false;
    }
  }
}
