// 视频预加载控制器：监听当前播放进度，提前初始化下一条视频的 controller
// 最多保留 2 个预加载 controller（当前 + 下一条），避免内存浪费

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
  /// `items` 是完整播放列表，`currentIndex` 是当前播放位置
  void startWatching(List<MediaItem> items, int currentIndex, double threshold) {
    _currentItemId = items[currentIndex].id;
    _threshold = threshold;
    _thresholdTriggered = false;

    // 标记当前 item 不需要预加载（自身正在播放）
    _preloadedIds[_currentItemId!] = true;

    // 清理当前播放位置前后窗口之外的旧预加载 controller，避免快速滚动时内存堆积
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
        // 超出窗口，立即 dispose 以释放 MediaCodec
        try {
          e.controller.dispose();
        } catch (_) {}
      }
    }
    state = newList;
  }

  /// 更新当前播放进度：由 FeedView 在播放中调用
  /// 当 progress > 阈值 时预取下一条
  void updateProgress(double progress, List<MediaItem> items, int currentIndex,
      {String? embyServerUrl, String? token}) {
    if (_thresholdTriggered) return;
    if (progress < _threshold) return;

    // 达到预加载阈值，预取下一条
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
    // 已预加载过则跳过
    if (_preloadedIds.containsKey(item.id) && _preloadedIds[item.id] == true) return;
    _preloadedIds[item.id] = true;

    // 构造播放 URL（与 VideoPlayerWidget 保持一致）
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

      // 成功初始化，加入缓存
      final entry = _PreloadEntry(
        itemId: item.id,
        controller: controller,
        preloadedAt: DateTime.now(),
      );

      final newList = [...state, entry];
      // 超过缓存上限，dispose 最早的（但保留最近 1 个+当前）
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
    // 消费后也在 _preloadedIds 中清除，以便未来可以重新预加载
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

final preloadProvider =
    StateNotifierProvider<PreloadNotifier, List<_PreloadEntry>>(
  (ref) => PreloadNotifier(),
);

/// 当前正在播放的 item 的 index（FeedView 设置）
final currentPlayingIndexProvider = StateProvider<int>((ref) => 0);
