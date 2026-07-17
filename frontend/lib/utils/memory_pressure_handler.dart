// 内存压力监听：系统内存警告时主动释放资源
//
// 设计目标：
// 1. 监听 Flutter 的 SystemChannels.system 内存警告信号
// 2. 收到警告时清空图片缓存、释放视频池中非当前播放的控制器
// 3. 避免在低内存设备上因缓存积累导致 OOM 崩溃

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'logger.dart';

/// 内存压力监听器
///
/// 使用方式：在 app 启动时调用 [MemoryPressureHandler.attach]，退出时调用 [detach]。
/// 收到系统内存警告时会：
/// - 清空 Flutter 图片缓存（PaintingBinding.instance.imageCache）
/// - 释放视频池中所有预加载会话（VideoPoolService.disposeAll）
class MemoryPressureHandler {
  static MemoryPressureHandler? _instance;

  final Ref _ref;
  bool _isHandling = false;

  MemoryPressureHandler._(this._ref);

  /// 挂载监听器（全局单例）
  static MemoryPressureHandler? attach(Ref ref) {
    if (kIsWeb) return null; // Web 环境不需要
    _instance ??= MemoryPressureHandler._(ref);
    _instance!._start();
    return _instance;
  }

  /// 卸载监听器
  static void detach() {
    _instance?._stop();
    _instance = null;
  }

  void _start() {
    // SystemChannels.system 是 MethodChannel，通过 setMethodCallHandler 监听
    // native 端发送的 'memoryPressure' 方法调用
    SystemChannels.system.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'memoryPressure') {
        await _handleMemoryPressure();
      }
      return null;
    });
  }

  void _stop() {
    SystemChannels.system.setMethodCallHandler(null);
  }

  /// 处理内存压力：清缓存 + 释放视频池
  Future<void> _handleMemoryPressure() async {
    // 防重入：避免短时间内多次内存警告导致重复释放
    if (_isHandling) return;
    _isHandling = true;

    try {
      // 1. 清空 Flutter 图片缓存（释放已解码的图片内存）
      PaintingBinding.instance.imageCache.clear();
      AppLogger.info('内存压力：已清空图片缓存');

      // 2. 释放视频池中所有预加载会话（保留当前正在播放的）
      final pool = _ref.read(videoPoolProvider);
      if (pool.size > 0) {
        await pool.disposeAll();
        AppLogger.info('内存压力：已释放视频池');
      }
    } catch (e) {
      AppLogger.error('内存压力处理失败', error: e);
    } finally {
      _isHandling = false;
    }
  }
}
