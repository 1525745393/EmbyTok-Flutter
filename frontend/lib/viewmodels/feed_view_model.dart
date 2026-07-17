// Feed 页面的 ViewModel：将业务逻辑从 FeedView 中抽离
//
// 职责边界：
// ✅ 键盘快捷键处理（纯业务，操作 Provider 状态）
// ✅ 云同步（跨设备续播检查与保存）
// ✅ 滚动位置持久化（网格视图滚动偏移保存/恢复）
// ✅ 下一集查找算法（在 items 中找同 series 的下一集）
// ✅ 视图切换协调（播放暂停/恢复，委托给 PlaybackCoordinator）
// ✅ 浏览模式切换（FeedType 循环切换）
// ❌ PageController 操作：依赖 hasClients/mounted，UI 层职责
// ❌ SystemChrome 系统栏：纯 UI 行为
// ❌ Widget build：UI 渲染
// ❌ BuildContext 相关操作（Navigator、SnackBar 等）：通过回调通知 UI

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../coordinators/playback_coordinator.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';
import '../utils/app_preferences.dart' show ViewMode, FeedType;
import '../utils/constants.dart';
import '../utils/logger.dart';

/// Feed 页面的视图模型
///
/// 使用方式：
/// - 在 FeedView 的 initState 中创建实例
/// - 传入 [onJumpToPage] 等回调，用于通知 UI 执行跳页等操作
/// - 在 FeedView 的 dispose 中调用 [dispose]
///
/// 设计原则：
/// - ViewModel 不依赖 BuildContext，不持有 Widget 控制器
/// - 所有需要 UI 操作的场景通过回调通知 View 层
/// - ViewModel 持有 WidgetRef，可直接读写 Provider
class FeedViewModel {
  final WidgetRef _ref;
  final PlaybackCoordinator _playbackCoordinator;

  // UI 回调：通知 View 层执行操作
  final void Function(int index)? onJumpToPage; // 跳转到指定页（带动画）
  final void Function(int index)? onJumpToPageInstant; // 立即跳页（无动画）
  final void Function(String message, {String? actionLabel, void Function()? onAction})? onShowSnackBar;
  final void Function()? onOpenFullscreen; // 打开全屏页
  final void Function()? onShowLibrarySelector; // 显示媒体库选择器
  final void Function(bool visible)? onUpdateHelpVisibility; // 更新帮助面板显隐

  // 云同步相关
  final EmbytokService _cloudService = EmbytokService();
  MediaItem? _lastReportedItem;

  // 已处理的初始播放项 ID（防止重复等待同一 initialId）
  String? _processedInitialItemId;

  // 网格滚动保存防抖
  Timer? _gridScrollSaveTimer;

  FeedViewModel(
    this._ref,
    this._playbackCoordinator, {
    this.onJumpToPage,
    this.onJumpToPageInstant,
    this.onShowSnackBar,
    this.onOpenFullscreen,
    this.onShowLibrarySelector,
    this.onUpdateHelpVisibility,
  });

  // ==================== 生命周期 ====================

  /// 初始化：注册各种 Provider 监听
  ///
  /// 在 FeedView.initState 的末尾调用，此时 Widget 已挂载
  void init() {
    // 监听当前播放条目变化：切换到新视频时保存旧条目的续播信息
    _ref.listen<MediaItem?>(currentPlayingItemProvider, (prev, next) {
      _saveCloudSyncIfNeeded(next);
    });

    // 监听外部跳页请求：全屏页等设置后跳到指定 index
    _ref.listen<int?>(feedViewPageJumpRequestProvider, (prev, next) {
      if (next != null && next != prev) {
        AppLogger.debug('外部请求跳页', data: {'index': next});
        final targetIndex = _playbackCoordinator.consumeJumpRequest();
        if (targetIndex != null) {
          onJumpToPageInstant?.call(targetIndex);
        }
      }
    });

    // 监听视图模式变化：feed↔grid 切换时的播放协调
    // 系统栏显隐是 UI 行为，由 View 层处理
    _ref.listen<ViewMode>(viewModeProvider, (prev, next) {
      if (prev == null) return;
      _playbackCoordinator.handleViewModeChange(prev, next);
    });

    // 监听媒体库列表加载：首次未配置时弹选择器
    _ref.listen<AsyncValue<List<Library>>>(libraryListProvider, (prev, next) {
      next.whenData((_) {
        final configured = _ref.read(feedLibraryConfiguredProvider);
        if (configured) return;
        onShowLibrarySelector?.call();
      });
    });
  }

  /// 释放资源
  void dispose() {
    _gridScrollSaveTimer?.cancel();
    _lastReportedItem = null;
    _processedInitialItemId = null;
  }

  // ==================== 路由跳转辅助 ====================

  /// 等待路由透传的初始播放项出现在 items 中
  /// 防止重复等待同一 initialId（与 FeedView build 中的去重对应）
  void waitForInitialItem(String itemId) {
    if (_processedInitialItemId == itemId) return;
    _processedInitialItemId = itemId;
    _playbackCoordinator.waitForInitialItem(itemId);
  }

  // ==================== 键盘快捷键 ====================

  /// 处理键盘事件，返回 true 表示已消费
  bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;

    final viewMode = _ref.read(viewModeProvider);
    if (viewMode != ViewMode.feed) {
      // 网格模式下仅处理 E 键切换回视频流
      if (key == LogicalKeyboardKey.keyE) {
        _ref.read(viewModeProvider.notifier).setMode(ViewMode.feed);
        return true;
      }
      return false;
    }

    switch (key) {
      case LogicalKeyboardKey.keyW:
      case LogicalKeyboardKey.arrowUp:
        _goToPreviousVideo();
        return true;
      case LogicalKeyboardKey.keyS:
      case LogicalKeyboardKey.arrowDown:
        _goToNextVideo();
        return true;
      case LogicalKeyboardKey.space:
        _togglePlayPause();
        return true;
      case LogicalKeyboardKey.keyA:
      case LogicalKeyboardKey.arrowLeft:
        _seekBySeconds(-15);
        return true;
      case LogicalKeyboardKey.keyD:
      case LogicalKeyboardKey.arrowRight:
        _seekBySeconds(15);
        return true;
      case LogicalKeyboardKey.keyU:
        _toggleFavorite();
        return true;
      case LogicalKeyboardKey.keyE:
        _ref.read(viewModeProvider.notifier).setMode(ViewMode.grid);
        return true;
      case LogicalKeyboardKey.keyR:
        _toggleFeedType();
        return true;
      case LogicalKeyboardKey.keyG:
        onShowLibrarySelector?.call();
        return true;
      case LogicalKeyboardKey.keyF:
        onOpenFullscreen?.call();
        return true;
      case LogicalKeyboardKey.keyM:
        _toggleMute();
        return true;
      case LogicalKeyboardKey.keyN:
        _jumpToNextEpisodeFromCurrent();
        return true;
      case LogicalKeyboardKey.keyP:
        _goToPreviousVideo();
        return true;
      case LogicalKeyboardKey.slash:
        final isVisible = _ref.read(feedHelpVisibleProvider);
        _ref.read(feedHelpVisibleProvider.notifier).state = !isVisible;
        onUpdateHelpVisibility?.call(!isVisible);
        return true;
      default:
        return false;
    }
  }

  // ==================== 视频播放控制 ====================

  void _goToPreviousVideo() {
    final current = _ref.read(feedCurrentIndexProvider);
    if (current > 0) {
      onJumpToPage?.call(current - 1);
    }
  }

  void _goToNextVideo() {
    final videoState = _ref.read(videoListProvider);
    final current = _ref.read(feedCurrentIndexProvider);
    if (current < videoState.items.length - 1) {
      onJumpToPage?.call(current + 1);
    }
  }

  void _seekBySeconds(int seconds) {
    final controller = _ref.read(currentVideoControllerProvider);
    if (controller == null) return;
    if (!controller.value.isInitialized) return;
    final current = controller.value.position;
    final duration = controller.value.duration;
    final deltaMs = seconds * 1000;
    var newMs = current.inMilliseconds + deltaMs;
    newMs = newMs.clamp(0, duration.inMilliseconds);
    controller.seekTo(Duration(milliseconds: newMs));
  }

  void _togglePlayPause() {
    final isPlaying = _ref.read(isPlayingProvider);
    final controller = _ref.read(currentVideoControllerProvider);
    if (controller != null && controller.value.isInitialized) {
      if (isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    }
    _ref.read(isPlayingProvider.notifier).state = !isPlaying;
  }

  void _toggleFavorite() {
    final item = _ref.read(currentPlayingItemProvider);
    if (item != null) {
      _ref.read(favoritesProvider.notifier).toggleFavorite(item);
    }
  }

  void _toggleMute() {
    final isMuted = _ref.read(isMutedProvider);
    _ref.read(isMutedProvider.notifier).setMuted(!isMuted);
  }

  // ==================== 浏览模式切换 ====================

  void _toggleFeedType() {
    final current = _ref.read(feedTypeProvider);
    final next = switch (current) {
      FeedType.latest => FeedType.random,
      FeedType.random => FeedType.favorites,
      FeedType.favorites => FeedType.resume,
      FeedType.resume => FeedType.latest,
    };
    // 切换前清理预加载缓存（不同 feedType 下的视频完全不同）
    unawaited(_playbackCoordinator.disposeAllPreloads());
    _ref.read(feedTypeProvider.notifier).setType(next);
    onShowSnackBar?.call('切换到：${next.zhLabel}');
  }

  // ==================== 云同步（跨设备续播） ====================

  /// 启动时检查其它设备是否存在续播信息
  Future<void> checkCloudSyncOnStartup() async {
    try {
      final auth = _ref.read(authProvider);
      final serverUrl = auth.embyServerUrl;
      final token = auth.token;
      if (!auth.isAuthenticated || serverUrl == null || token == null) {
        return;
      }
      final data = await _cloudService.checkCloudSync(
        serverUrl: serverUrl,
        token: token,
      );
      if (data == null || data.isEmpty) return;
      final lastId = data['lastId'] as String?;
      final deviceName = (data['deviceName'] as String?) ?? '其他设备';
      if (lastId == null || lastId.isEmpty) return;
      final current = _ref.read(currentPlayingItemProvider);
      if (current != null && current.id == lastId) return;
      // 通知 UI 展示 SnackBar 提示
      onShowSnackBar?.call(
        '从$deviceName 续播：继续播放此视频？',
        actionLabel: '跳转',
        onAction: () => _seekToItem(lastId),
      );
    } catch (e) {
      AppLogger.debug('云同步检查失败', data: {'error': e.toString()});
    }
  }

  /// 切换条目时保存旧条目到云端
  void _saveCloudSyncIfNeeded(MediaItem? newItem) {
    final auth = _ref.read(authProvider);
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    if (!auth.isAuthenticated || serverUrl == null || token == null) return;
    final oldItem = _lastReportedItem;
    _lastReportedItem = newItem;
    if (oldItem == null) return;
    if (newItem != null && oldItem.id == newItem.id) return;
    unawaited(
      _cloudService.saveCloudSync(
        itemId: oldItem.id,
        libraryId: _currentLibraryId(),
        libraryType: '',
        serverUrl: serverUrl,
        token: token,
      ),
    );
  }

  /// 当前媒体库 ID（多选时取第一个，未选则为空字符串）
  String _currentLibraryId() {
    try {
      final libs = _ref.read(libraryListProvider);
      final libValue = libs.value;
      if (!libs.hasValue || libValue == null || libValue.isEmpty) return '';
      final selectedIds = _ref.read(selectedLibraryIdsProvider);
      return selectedIds.isNotEmpty
          ? selectedIds.first
          : libValue.first.id;
    } catch (_) {
      return '';
    }
  }

  /// 根据 itemId 跳到对应视频（在 items 线性查找）
  void _seekToItem(String itemId) {
    final items = _ref.read(videoListProvider).items;
    if (items.isEmpty) return;
    final idx = items.indexWhere((item) => item.id == itemId);
    if (idx < 0) return;
    onJumpToPage?.call(idx);
  }

  // ==================== 下一集查找 ====================

  /// 从当前播放位置触发下一集跳转
  void _jumpToNextEpisodeFromCurrent() {
    final videoState = _ref.read(videoListProvider);
    final currentIndex = _ref.read(feedCurrentIndexProvider);
    if (videoState.items.isEmpty) return;
    _jumpToNextEpisode(videoState.items, currentIndex);
  }

  /// 在 items 中查找当前条目的下一集（同 series 的下一个）
  void _jumpToNextEpisode(List<MediaItem> items, int currentIndex) {
    final current = items[currentIndex];
    final series = current.seriesName;
    if (series == null || series.isEmpty) {
      _goToNextVideo();
      return;
    }

    // 策略1：当前条目是 Episode，寻找同季下一集或下一季第1集
    int? nextIndex;
    if (current.indexNumber != null && current.parentIndexNumber != null) {
      for (int i = 0; i < items.length; i++) {
        final it = items[i];
        if (it.seriesName == series &&
            it.parentIndexNumber == current.parentIndexNumber &&
            it.indexNumber == current.indexNumber! + 1) {
          nextIndex = i;
          break;
        }
      }
      // 同季没找到，找下一季第1集
      nextIndex ??= items.indexWhere(
        (it) =>
            it.seriesName == series &&
            it.indexNumber == 1 &&
            it.parentIndexNumber == current.parentIndexNumber! + 1,
      );
      if (nextIndex == -1) nextIndex = null;
    }

    // 策略2：找到下一个 seriesName 相同的条目（按顺序）
    nextIndex ??= items.indexWhere(
      (it) => it.seriesName == series,
      currentIndex + 1,
    );

    if (nextIndex >= 0 && nextIndex < items.length) {
      onJumpToPage?.call(nextIndex);
    } else {
      _goToNextVideo();
    }
  }

  // ==================== 滚动位置持久化 ====================

  /// 保存网格滚动偏移量（防抖调用）
  ///
  /// [getOffset] 回调由 View 层提供当前滚动偏移
  void saveGridScrollOffset(double Function() getOffset) {
    _gridScrollSaveTimer?.cancel();
    _gridScrollSaveTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final offset = getOffset();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(kStorageKeyLastGridScrollOffset, offset);
      } catch (_) {}
    });
  }

  /// 从 SharedPreferences 恢复网格滚动位置
  ///
  /// [onRestored] 回调通知 View 层执行实际的 jumpTo
  Future<void> restoreGridScrollOffset({
    required double Function() getMaxScrollExtent,
    required void Function(double offset) onRestored,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastOffset = prefs.getDouble(kStorageKeyLastGridScrollOffset);
      if (lastOffset != null && lastOffset > 0) {
        final maxScroll = getMaxScrollExtent();
        final safeOffset = lastOffset.clamp(0.0, maxScroll);
        onRestored(safeOffset);
      }
    } catch (_) {}
  }

  // ==================== 页面变更回调（由 View 层 onPageChanged 调用） ====================

  /// 页面切换完成时调用（同步播放状态、触发预加载、加载更多等）
  ///
  /// 返回是否需要加载更多
  bool onPageChanged(int index, List<MediaItem> items, bool hasMore, bool isLoading) {
    // 同步当前播放 ID
    _playbackCoordinator.syncCurrentPlaying(index: index, items: items);
    // 更新当前索引（供键盘快捷键等使用）
    _ref.read(feedCurrentIndexProvider.notifier).state = index;
    // 判断是否需要加载更多
    if (hasMore && index >= items.length - 2 && !isLoading) {
      return true; // 通知 View 层触发 loadMore
    }
    return false;
  }

  /// 页面切换防抖结束后调用（执行预加载和清理）
  void onPageChangeSettled(int index, List<MediaItem> items) {
    _playbackCoordinator.preloadNeighbors(index: index, items: items);
    _playbackCoordinator.evictFarPreloads(currentIndex: index, items: items);
  }

  // ==================== 视频事件回调（由 VideoPageItem 调用） ====================

  /// 视频播放结束：跳到下一个视频
  void onVideoEnded() {
    _goToNextVideo();
  }

  /// 触发下一集跳转
  void onNextEpisode() {
    _jumpToNextEpisodeFromCurrent();
  }
}

// ==================== 辅助 Provider ====================

/// Feed 视图当前播放索引（与 PageController 同步）
///
/// 用于 ViewModel 中需要知道当前索引的场景（键盘快捷键、下一集查找等），
/// 避免 ViewModel 直接持有 PageController。
final feedCurrentIndexProvider = StateProvider<int>((ref) => 0);

/// Feed 视图帮助面板可见性
final feedHelpVisibleProvider = StateProvider<bool>((ref) => false);
