// 播放协调器：协调 video_list / currentPlaying / videoPool 之间的状态同步
//
// 背景：
// feed_view.dart 原本承担了大量播放协调逻辑（预加载、ID 同步、视图切换暂停等），
// 导致 View 层职责过重。本协调器将这些逻辑抽离到独立的逻辑层，
// 让 FeedView 专注于 UI 渲染和生命周期管理。
//
// 职责边界：
// ✅ 预加载协调：上下相邻视频的预加载与远端会话清理
// ✅ 播放 ID 同步：将当前播放的 itemId / MediaItem 写入全局 Provider
// ✅ 视图切换协调：feed ↔ grid 切换时的视频暂停/恢复
// ✅ 路由跳转辅助：等待目标 item 加载完成（触发 loadMore）
// ❌ PageController 跳页：UI 层职责（依赖 hasClients）
// ❌ 云同步：独立业务，后续可单独抽离到 CloudSyncService
// ❌ 沉浸式系统栏：纯 UI 行为

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/video_pool_service.dart';
import '../utils/app_preferences.dart' show ViewMode;
import '../utils/logger.dart';

/// 播放协调器
///
/// 使用方式：
/// - 在 FeedView 的 initState 中创建实例，传入 [onPageIndexReady] 回调
/// - onPageIndexReady 由 FeedView 提供，负责执行实际的 PageController.jumpToPage
/// - 在 FeedView 的 dispose 中调用 [detach]
///
/// 类型说明：
/// - 持有 [WidgetRef]（而非 [Ref]），因为 Coordinator 由 ConsumerState 直接创建，
///   需要读写 Provider 状态（read/notifier.state）以及监听变化
/// - WidgetRef 完整支持这些操作，无需绕道 Ref
class PlaybackCoordinator {
  final WidgetRef _ref;

  // 路由跳转：当目标 item 已加载时，通过此回调通知 UI 跳页
  // 返回 true 表示 PageController 已 attach 并成功跳页
  final bool Function(int targetIndex)? _onPageIndexReady;

  // 防止重复等待同一 initialId（与 FeedView 的 _processedInitialItemId 对应）
  String? _processedInitialItemId;
  Timer? _waitTimer;

  PlaybackCoordinator(this._ref, {bool Function(int targetIndex)? onPageIndexReady})
      : _onPageIndexReady = onPageIndexReady;

  // ==================== 预加载协调 ====================

  /// 对指定 index 的上一条和下一条视频发起预加载
  ///
  /// 由 VideoPoolService 负责降级链（DirectPlay → DirectStream → HLS）。
  /// 只对尚未在池中的 item 发起预加载，避免重复创建 controller。
  void preloadNeighbors({
    required int index,
    required List<MediaItem> items,
  }) {
    final auth = _ref.read(authProvider);
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    if (serverUrl == null || token == null) return;

    final pool = _ref.read(videoPoolProvider);

    // 预加载上一条
    if (index - 1 >= 0) {
      final prevItem = items[index - 1];
      if (!pool.hasSession(prevItem.id)) {
        unawaited(pool.preload(
          item: prevItem,
          serverUrl: serverUrl,
          token: token,
        ));
      }
    }
    // 预加载下一条
    if (index + 1 < items.length) {
      final nextItem = items[index + 1];
      if (!pool.hasSession(nextItem.id)) {
        unawaited(pool.preload(
          item: nextItem,
          serverUrl: serverUrl,
          token: token,
        ));
      }
    }
  }

  /// 清理距离当前索引较远的会话（只保留上一条 + 下一条）
  ///
  /// 设计：当前播放的视频已被 VideoPageItem 从池中取出，池里只有预加载的会话。
  /// 保留上一条和下一条用于快速来回滑动，其余全部清理。
  void evictFarPreloads({
    required int currentIndex,
    required List<MediaItem> items,
  }) {
    final keepIds = <String>[];
    if (currentIndex - 1 >= 0) {
      keepIds.add(items[currentIndex - 1].id);
    }
    if (currentIndex + 1 < items.length) {
      keepIds.add(items[currentIndex + 1].id);
    }
    _ref.read(videoPoolProvider).evictExcept(keepIds);
  }

  /// 从池中取出预加载会话（取出后池不再拥有它，由 VideoPageItem 负责释放）
  PlaybackSession? takePreloadedSession(String itemId) =>
      _ref.read(videoPoolProvider).take(itemId);

  /// 释放所有预加载会话（用于切换 FeedType、退出页面等场景）
  Future<void> disposeAllPreloads() async {
    await _ref.read(videoPoolProvider).disposeAll();
  }

  // ==================== 播放 ID 同步 ====================

  /// 同步当前播放的 itemId 和 MediaItem 到全局 Provider
  ///
  /// onPageChanged 是 PageView 真正切换完成时的回调，
  /// 比控制器的 onControllerReady 更可靠。
  /// 这是 feed 内部唯一权威的“当前在播”信号源。
  void syncCurrentPlaying({
    required int index,
    required List<MediaItem> items,
  }) {
    if (index < 0 || index >= items.length) return;
    final playingItem = items[index];
    _ref.read(currentPlayingIdProvider.notifier).state = playingItem.id;
    _ref.read(currentPlayingItemProvider.notifier).state = playingItem;
  }

  /// 清除当前播放状态（用于媒体库切换、退出等场景）
  void clearCurrentPlaying() {
    _ref.read(currentPlayingIdProvider.notifier).state = null;
    _ref.read(currentPlayingItemProvider.notifier).state = null;
  }

  // ==================== 视图切换协调 ====================

  /// 处理 feed ↔ grid 视图切换的播放协调
  ///
  /// 返回值：
  /// - 'pause'：需要暂停视频
  /// - 'resume'：需要恢复播放
  /// - null：无需操作
  ///
  /// 注意：系统栏显隐是 UI 层职责，本方法不处理。
  String? handleViewModeChange(ViewMode prev, ViewMode next) {
    final controller = _ref.read(currentVideoControllerProvider);
    if (prev == ViewMode.feed && next == ViewMode.grid) {
      if (controller != null && controller.isPlaying) {
        controller.pause();
      }
      return 'pause';
    } else if (prev == ViewMode.grid && next == ViewMode.feed) {
      if (controller != null && !controller.isPlaying) {
        controller.play();
      }
      return 'resume';
    }
    return null;
  }

  // ==================== 路由跳转辅助 ====================

  /// 等待路由透传的初始播放项出现在 items 中
  ///
  /// - 目标项不在当前已加载的列表时，自动 loadMore 连续加载直到找到
  /// - 找到后通过 _onPageIndexReady 回调通知 UI 跳页
  /// - 最多等待约5秒（100帧），超时则放弃
  ///
  /// 返回 true 表示已触发跳页，false 表示仍在等待或超时。
  bool waitForInitialItem(String itemId) {
    // 防止重复处理同一 initialId
    if (_processedInitialItemId == itemId) return false;
    _processedInitialItemId = itemId;
    _waitForInitialItemViaTimer(itemId, tick: 0);
    return true;
  }

  /// 用 100ms 定时代替逐帧轮询（原 addPostFrameCallback 在静态界面下约 60fps 空转）。
  /// 最多约 5 秒（50 次），超时放弃。
  void _waitForInitialItemViaTimer(String itemId, {required int tick}) {
    _waitTimer?.cancel();
    _waitTimer = Timer(const Duration(milliseconds: 100), () {
      _tickInitialItem(itemId, tick: tick);
    });
  }

  void _tickInitialItem(String itemId, {required int tick}) {
    // 最多等待约 5 秒（50 次 × 100ms），超时则放弃
    if (tick > 50) {
      AppLogger.error('路由初始项：等待目标视频超时', data: {'itemId': itemId});
      _processedInitialItemId = null;
      return;
    }

    final videoState = _ref.read(videoListProvider);
    final targetIndex =
        videoState.items.indexWhere((item) => item.id == itemId);

    if (targetIndex >= 0) {
      AppLogger.debug('路由初始项：找到目标视频并跳转',
          data: {'index': targetIndex, 'itemId': itemId});
      // 同步播放状态（避免 UI 闪烁）
      syncCurrentPlaying(index: targetIndex, items: videoState.items);
      // 通知 UI 跳页
      final jumped = _onPageIndexReady?.call(targetIndex) ?? false;
      if (!jumped) {
        // PageController 未 attach，稍后重试
        _waitForInitialItemViaTimer(itemId, tick: tick + 1);
      }
      return;
    }

    if (videoState.isLoading) {
      _waitForInitialItemViaTimer(itemId, tick: tick + 1);
      return;
    }

    if (videoState.hasMore) {
      AppLogger.debug('路由初始项：目标视频不在当前列表，加载更多', data: {
        'currentItemCount': videoState.items.length,
        'itemId': itemId,
      });
      _ref.read(videoListProvider.notifier).loadMore();
    }

    _waitForInitialItemViaTimer(itemId, tick: tick + 1);
  }

  /// 处理外部跳页请求（来自 FullscreenVideoPage 等）
  ///
  /// 返回目标 index，或 null（无请求或已处理）。
  /// UI 层负责执行实际的 PageController.jumpToPage。
  int? consumeJumpRequest() {
    final request = _ref.read(feedViewPageJumpRequestProvider);
    if (request == null) return null;
    // 重置避免重复触发
    _ref.read(feedViewPageJumpRequestProvider.notifier).state = null;

    // 同步播放状态
    final items = _ref.read(videoListProvider).items;
    if (request < items.length) {
      syncCurrentPlaying(index: request, items: items);
    }
    return request;
  }

  // ==================== 生命周期 ====================

  /// 释放协调器资源
  void detach() {
    _waitTimer?.cancel();
    _waitTimer = null;
    _processedInitialItemId = null;
  }
}

