// 内存压力监听：系统内存警告时主动释放资源
//
// 设计目标：
// 1. 监听 Flutter 的 WidgetsBindingObserver 内存警告回调
// 2. 收到警告时清空图片缓存、释放视频池、清除内存缓存
// 3. 避免在低内存设备上因缓存积累导致 OOM 崩溃

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'logger.dart';

/// 内存压力监听器
///
/// 使用方式：在 Widget/State 的 initState 中创建实例，dispose 时调用 [dispose]。
/// 由持有者负责生命周期管理，避免静态单例持有 WidgetRef 造成泄漏。
/// 收到系统内存警告时会：
/// - 清空 Flutter 图片缓存（PaintingBinding.instance.imageCache）
/// - 释放视频池中所有预加载会话（VideoPoolService.disposeAll）
/// - 清空所有内存缓存（媒体列表、收藏、续播等分页数据）
class MemoryPressureHandler with WidgetsBindingObserver {
  final WidgetRef ref;
  bool _isHandling = false;

  MemoryPressureHandler(this.ref) {
    WidgetsBinding.instance.addObserver(this);
  }

  /// 释放资源：移除监听器
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  /// 系统内存压力警告回调（来自 WidgetsBindingObserver）
  @override
  void didHaveMemoryPressure() {
    _handleMemoryPressure();
  }

  /// 处理内存压力：清缓存 + 释放视频池
  Future<void> _handleMemoryPressure() async {
    if (_isHandling) return;
    _isHandling = true;

    try {
      PaintingBinding.instance.imageCache.clear();
      AppLogger.info('内存压力：已清空图片缓存');

      final pool = ref.read(videoPoolProvider);
      if (pool.size > 0) {
        await pool.disposeAll();
        AppLogger.info('内存压力：已释放视频池');
      }

      try {
        ref.read(cacheControllerProvider).invalidateAll();
        AppLogger.info('内存压力：已清空内存缓存');
      } catch (e) {
        AppLogger.warn('内存压力：清空内存缓存失败', data: {'error': e.toString()});
      }
    } catch (e) {
      AppLogger.error('内存压力处理失败', error: e);
    } finally {
      _isHandling = false;
    }
  }
}
