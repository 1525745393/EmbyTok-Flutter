/// 视频预加载控制器：监听当前播放进度，提前初始化下一条视频的 controller
///
/// 通过 `preloadProvider` 管理预加载缓存，最多保留 `kMaxPreloadControllers` 个
/// 预加载 controller。当当前视频播放到 `kDefaultPreloadThreshold`（默认 75%）时，
/// 自动预取下一条视频，实现无缝切换。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// 预加载缓存记录：item -> controller
class _PreloadEntry {
  final String itemId;
  final VideoPlayerController controller;
  final DateTime preloadedAt;

  _PreloadEntry({
    required this.itemId,
    required this.controller,
    required this.preloadedAt,
  });
}

/// 预加载管理器：单例（通过 StateNotifierProvider 共享）
class PreloadNotifier extends StateNotifier<List<_PreloadEntry>> {
  PreloadNotifier() : super([]);

  String? _currentItemId;
  double _threshold = kDefaultPreloadThreshold;
  bool _thresholdTriggered = false;
  final Map<String, bool> _preloadedIds = {};

  /// 开始为某个 item 监听播放进度，达到阈值时预取下一条
  void startWatching(List<MediaItem> items, int currentIndex, double threshold) {
    _currentItemId = items[currentIndex].id;
    _threshold = threshold;
    _thresholdTriggered = false;
    _preloadedIds[_currentItemId!] = true;
    _evictOutsideWindow(items, currentIndex);
  }

  /// 回收超出 [currentIndex - kWindowSize, currentIndex + kWindowSize] 范围的 controller
  void _evictOutsideWindow(List<MediaItem> items, int currentIndex) {
    const kWindowSize = 3;
    final keepIds = <String>{};
    for (int i = currentIndex - kWindowSize;
        i <= currentIndex + kWindowSize;
        i++) {
      if (i >= 0 && i < items.length) keepIds.add(items[i].id);
    }
    final newList = <_PreloadEntry>[];
    for (final e in state) {
      if (keepIds.contains(e.itemId)) {
        newList.add(e);
      } else {
        try {
          e.controller.dispose();
        } catch (_) {}
      }
    }
    state = newList;
  }

  /// 更新当前播放进度：由 FeedView 在播放中调用，当 progress > 阈值时预取下一条
  void updateProgress(double progress, List<MediaItem> items, int currentIndex,
      {String? embyServerUrl, String? token}) {
    if (_thresholdTriggered) return;
    if (progress < _threshold) return;

    _thresholdTriggered = true;
    final nextIndex = currentIndex + 1;
    if (nextIndex >= items.length) return;

    final nextItem = items[nextIndex];
    _preloadOne(nextItem, embyServerUrl: embyServerUrl, token: token);
  }

  /// 预加载指定索引的下一条（从 feed view 页面切换时调用）
  void preloadNext(List<MediaItem> items, int currentIndex,
      {String? embyServerUrl, String? token}) {
    final nextIndex = currentIndex + 1;
    if (nextIndex >= items.length) return;
    _preloadOne(items[nextIndex], embyServerUrl: embyServerUrl, token: token);
  }

  /// 预加载单个 item（不 play，仅 initialize）
  Future<void> _preloadOne(
    MediaItem item, {
    String? embyServerUrl,
    String? token,
  }) async {
    if (_preloadedIds.containsKey(item.id) && _preloadedIds[item.id] == true) return;
    _preloadedIds[item.id] = true;

    final url = item.playbackUrl ?? item.computePlaybackUrl(embyServerUrl, token);
    if (url == null || url.isEmpty) {
      AppLogger.warn('预加载跳过：无可用 URL', data: {'itemId': item.id});
      return;
    }

    AppLogger.info('开始预加载', data: {'itemId': item.id, 'url': url});

    try {
      final headers = item.authHeaders(token);
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
      );
      await controller.initialize().timeout(
        const Duration(seconds: kLoadTimeoutSeconds),
        onTimeout: () {
          throw Exception('preload timeout');
        },
      );

      final entry = _PreloadEntry(
        itemId: item.id,
        controller: controller,
        preloadedAt: DateTime.now(),
      );

      final newList = [...state, entry];
      while (newList.length > kMaxPreloadControllers) {
        final toRemove = newList.removeAt(0);
        if (toRemove.itemId != _currentItemId) {
          AppLogger.info('回收旧预加载 controller', data: {'itemId': toRemove.itemId});
          await toRemove.controller.dispose();
        }
      }
      state = newList;
      AppLogger.info('预加载成功', data: {'itemId': item.id});
    } catch (e) {
      AppLogger.error('预加载失败', error: e, data: {'itemId': item.id});
    }
  }

  /// 获取并移除某个 item 的预加载 controller
  VideoPlayerController? consume(String itemId) {
    final idx = state.indexWhere((e) => e.itemId == itemId);
    if (idx < 0) return null;
    final entry = state[idx];
    state = [...state]..removeAt(idx);
    _preloadedIds.remove(itemId);
    return entry.controller;
  }

  /// 检查某个 item 是否有预加载缓存
  bool has(String itemId) => state.any((e) => e.itemId == itemId);

  /// 清理所有缓存（用于切换视图或退出）
  Future<void> clear() async {
    for (final e in state) {
      try {
        await e.controller.dispose();
      } catch (_) {}
    }
    state = [];
    _preloadedIds.clear();
    _currentItemId = null;
    _threshold = kDefaultPreloadThreshold;
    _thresholdTriggered = false;
  }
}

/// 顶层预加载管理器 Provider
final preloadProvider =
    StateNotifierProvider<PreloadNotifier, List<_PreloadEntry>>(
  (ref) => PreloadNotifier(),
);

/// 当前正在播放的 item 的 index（由 FeedView 设置）
final currentPlayingIndexProvider = StateProvider<int>((ref) => 0);
