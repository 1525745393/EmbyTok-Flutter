// 视频流页面：竖向全屏滑动 + 顶部媒体库切换 + 分页加载 + 键盘快捷键 + 视图切换
// 新增：跨设备续播（通过 Emby DisplayPreferences 接口与其它设备/EmbyX 共享续播书签）

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';
import '../services/video_pool_service.dart';
import '../utils/app_preferences.dart' show ViewMode, FeedType;
import '../utils/constants.dart';
import '../utils/keyboard_shortcuts.dart';
import '../utils/logger.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/error_state_card.dart';
import '../widgets/library_selector.dart';
import '../widgets/poster_grid_view.dart';
import '../widgets/video_page_item.dart';

class FeedView extends ConsumerStatefulWidget {
  final String? initialItemId; // 初始播放的视频 ID（从其他页面跳转时使用）

  const FeedView({super.key, this.initialItemId});

  @override
  ConsumerState<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends ConsumerState<FeedView>
    with AutomaticKeepAliveClientMixin<FeedView> {
  late PageController _pageController;
  bool _showHelp = false; // 快捷键帮助面板显示状态
  // 当前正在播放的索引（与 _pageController 同步）
  int _currentIndex = 0;

  // 初始播放的视频 ID（从其他页面跳转时使用）
  String? _initialItemId;
  bool _hasScrolledToInitial = false; // 是否已滚动到初始位置

  // 滚动位置持久化相关
  bool _hasRestoredScrollPosition = false; // 是否已恢复视频流滚动位置
  final ScrollController _gridScrollController = ScrollController();
  Timer? _gridScrollSaveTimer; // 网格滚动保存防抖计时器

  // 云同步（跨设备续播）相关
  final EmbytokService _cloudService = EmbytokService();
  MediaItem? _lastReportedItem;

  // 网格视图搜索框控制器（值同步到 gridSearchQueryProvider）
  final TextEditingController _gridSearchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0, viewportFraction: 1.0);
    // 保存初始播放的 itemId
    _initialItemId = widget.initialItemId;
    // 注册全局键盘监听
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    // 监听当前播放条目变化：切换到新视频时保存旧条目的续播信息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.listen<MediaItem?>(currentPlayingItemProvider, (prev, next) {
        _saveCloudSyncIfNeeded(next);
      });
      // 监听视图模式变化：从网格切换到视频流时处理跳转
      ref.listen<ViewMode>(viewModeProvider, (prev, next) {
        if (prev == ViewMode.grid && next == ViewMode.feed) {
          _handleGridToFeedTransition();
        } else if (prev == ViewMode.feed && next == ViewMode.grid) {
          _handleFeedToGridTransition();
        }
      });
    });
    // 跨设备续播：进入页面时检查其它设备是否存在续播信息
    _checkCloudSyncOnStartup();
    // 监听网格滚动位置，防抖保存
    _gridScrollController.addListener(_onGridScrollChanged);
  }

  // 从网格模式切换到视频流模式时的处理
  void _handleGridToFeedTransition() {
    final selectedItemId = ref.read(gridSelectedItemIdProvider);
    // 网格点击切换时，阻止 SharedPreferences 恢复覆盖正确跳转
    if (selectedItemId != null && selectedItemId.isNotEmpty) {
      _hasRestoredScrollPosition = true;
    }
    final items = ref.read(videoListProvider).items;

    // 计算目标索引
    int targetIndex = _currentIndex; // 默认：当前位置
    if (selectedItemId != null && selectedItemId.isNotEmpty) {
      final idx = items.indexWhere((item) => item.id == selectedItemId);
      if (idx >= 0) {
        targetIndex = idx;
      }
      // 清理选中 ID，避免重复触发
      ref.read(gridSelectedItemIdProvider.notifier).state = null;
    }

    // 在下一帧跳转到目标位置（确保 PageView 已构建完成）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final totalItems = ref.read(videoListProvider).items.length;
      if (_pageController.hasClients &&
          targetIndex >= 0 &&
          targetIndex < totalItems) {
        _pageController.jumpToPage(targetIndex);
        _currentIndex = targetIndex;
        ref.read(currentIndexProvider.notifier).state = targetIndex;
      }
    });
  }

  // 从视频流模式切换到网格模式时的处理
  void _handleFeedToGridTransition() {
    // 在下一帧滚动到当前视频位置（确保 GridView 已构建完成）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scrolled = _tryScrollToCurrentVideo();
      if (!scrolled) {
        _restoreGridScrollOffset();
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _pageController.dispose();
    _gridSearchController.dispose();
    _gridScrollController.removeListener(_onGridScrollChanged);
    _gridScrollController.dispose();
    _gridScrollSaveTimer?.cancel();
    // 退出 feed view 时清理所有预加载（当前页面正在使用的由 VideoPageItem 负责）
    unawaited(ref.read(videoPoolProvider).disposeAll());
    super.dispose();
  }

  // ========== 滚动位置持久化 ==========

  // 保存视频流当前索引到 SharedPreferences
  Future<void> _saveVideoIndex(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kStorageKeyLastVideoIndex, index);
    } catch (_) {}
  }

  // 从 SharedPreferences 恢复视频流滚动位置
  Future<void> _restoreVideoIndex(int maxIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastIndex = prefs.getInt(kStorageKeyLastVideoIndex);
      if (lastIndex != null && lastIndex >= 0 && lastIndex <= maxIndex) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(lastIndex);
          _currentIndex = lastIndex;
        }
      }
    } catch (_) {}
  }

  // 网格滚动变化回调，防抖保存
  void _onGridScrollChanged() {
    _gridScrollSaveTimer?.cancel();
    _gridScrollSaveTimer = Timer(const Duration(milliseconds: 500), () {
      _saveGridScrollOffset();
    });

    // 滚动到底部附近时触发加载更多（仅无限滚动模式，分页模式使用按钮翻页）
    final videoState = ref.read(videoListProvider);
    if (videoState.hasMore &&
        !videoState.isLoading &&
        _gridScrollController.hasClients &&
        _gridScrollController.position.pixels >=
            _gridScrollController.position.maxScrollExtent - 200) {
      ref.read(videoListProvider.notifier).loadMore();
    }
  }

  // 保存网格滚动偏移量到 SharedPreferences
  Future<void> _saveGridScrollOffset() async {
    try {
      if (!_gridScrollController.hasClients) return;
      final offset = _gridScrollController.offset;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(kStorageKeyLastGridScrollOffset, offset);
    } catch (_) {}
  }

  // 从 SharedPreferences 恢复网格滚动位置
  Future<void> _restoreGridScrollOffset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastOffset = prefs.getDouble(kStorageKeyLastGridScrollOffset);
      if (lastOffset != null && lastOffset > 0) {
        if (mounted && _gridScrollController.hasClients) {
          final maxScroll = _gridScrollController.position.maxScrollExtent;
          final safeOffset = lastOffset.clamp(0.0, maxScroll);
          _gridScrollController.jumpTo(safeOffset);
        }
      }
    } catch (_) {}
  }

  // 将网格滚动到当前播放视频的位置（垂直居中），返回是否成功滚动
  // 对齐 EmbyX 实现：elTop - (areaHeight / 2) + (elHeight / 2)
  bool _tryScrollToCurrentVideo() {
    if (!_gridScrollController.hasClients) return false;

    final videoState = ref.read(videoListProvider);
    final currentIndex = ref.read(currentIndexProvider);
    final gridStartIndex = videoState.gridStartIndex;
    final gridItems = videoState.gridItems;

    if (gridItems.isEmpty) return false;

    // 计算当前视频在 gridItems 中的索引
    final indexInGrid = currentIndex - gridStartIndex;
    if (indexInGrid < 0 || indexInGrid >= gridItems.length) return false;

    // GridView 配置（与 PosterGridView 保持一致）
    const crossAxisCount = 3;
    const crossAxisSpacing = 8.0;
    const mainAxisSpacing = 8.0;
    const padding = 8.0;
    // Flutter GridView 的 childAspectRatio = crossAxisExtent / mainAxisExtent = 宽/高
    const childAspectRatio = 0.65;

    // 计算每个 item 的尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final viewportHeight = _gridScrollController.position.viewportDimension;
    final itemWidth = (screenWidth - padding * 2 - crossAxisSpacing * (crossAxisCount - 1)) / crossAxisCount;
    final itemHeight = itemWidth / childAspectRatio;
    final rowHeight = itemHeight + mainAxisSpacing;

    // 计算目标行和目标 item 顶部位置
    final targetRow = indexInGrid ~/ crossAxisCount;
    final targetTop = padding + targetRow * rowHeight;

    // 垂直居中对齐：item 中心 = viewport 中心（对齐 EmbyX）
    // 公式：elTop - (areaHeight / 2) + (elHeight / 2)
    final scrollOffset = targetTop - (viewportHeight / 2) + (itemHeight / 2);

    // 限制滚动范围在有效范围内
    final maxScroll = _gridScrollController.position.maxScrollExtent;
    final safeOffset = scrollOffset.clamp(0.0, maxScroll);

    // 平滑滚动到目标位置
    _gridScrollController.animateTo(
      safeOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    return true;
  }

  // ========== 预加载与清理（基于 VideoPoolService）==========

  // 对指定 index 的上一条和下一条视频发起预加载
  // 由 VideoPoolService 负责降级链（DirectPlay → DirectStream → HLS）
  void _preloadNeighbors(int index, List<MediaItem> items, String? embyServerUrl, String? token) {
    if (embyServerUrl == null || token == null) return;
    // 预加载上一条
    if (index - 1 >= 0) {
      final prevItem = items[index - 1];
      if (!ref.read(videoPoolProvider).hasSession(prevItem.id)) {
        unawaited(
          ref.read(videoPoolProvider).preload(item: prevItem, serverUrl: embyServerUrl, token: token),
        );
      }
    }
    // 预加载下一条
    if (index + 1 < items.length) {
      final nextItem = items[index + 1];
      if (!ref.read(videoPoolProvider).hasSession(nextItem.id)) {
        unawaited(
          ref.read(videoPoolProvider).preload(item: nextItem, serverUrl: embyServerUrl, token: token),
        );
      }
    }
  }

  // 预加载相邻视频的封面图（上一条 + 下一条 + 下下条）
  // 使用 precacheImage + CachedNetworkImageProvider，让切换视频时封面已缓存
  void _preloadPosters(int index, List<MediaItem> items, String? embyServerUrl, String? token) {
    if (embyServerUrl == null || token == null) return;
    // 需要预加载的索引列表：上一条、下一条、下下条
    final targetIndices = <int>[];
    if (index - 1 >= 0) targetIndices.add(index - 1);
    if (index + 1 < items.length) targetIndices.add(index + 1);
    if (index + 2 < items.length) targetIndices.add(index + 2);
    // 逐个预加载封面图
    for (final i in targetIndices) {
      final item = items[i];
      final posterUrl = item.primaryUrl(embyServerUrl: embyServerUrl, apiKey: token);
      if (posterUrl != null && posterUrl.isNotEmpty) {
        final headers = item.authHeaders(token);
        precacheImage(
          CachedNetworkImageProvider(posterUrl, headers: headers),
          context,
        );
      }
    }
  }

  // 清理距离当前索引较远的会话（只保留上一条 + 下一条，其余全部清理）
  void _evictFarPreloads(int currentIndex, List<MediaItem> items) {
    final keepIds = <String>[];
    // 当前条目（如存在）：保持在池中（VideoPageItem 已取出，池里不包含）
    // 上一条（如存在）：保留预加载
    if (currentIndex - 1 >= 0) {
      keepIds.add(items[currentIndex - 1].id);
    }
    // 下一条（如存在）：保留预加载
    if (currentIndex + 1 < items.length) {
      keepIds.add(items[currentIndex + 1].id);
    }
    ref.read(videoPoolProvider).evictExcept(keepIds);
  }

  // 从池中取出会话（取出后池不再拥有它，由 VideoPageItem 负责释放）
  PlaybackSession? _takePreloadedSession(String itemId) =>
      ref.read(videoPoolProvider).take(itemId);

  // ========== 跨设备续播云同步 ==========

  // 启动时尝试拉取 DisplayPreferences 中的 "EmbyTok-Resume" 信息
  Future<void> _checkCloudSyncOnStartup() async {
    try {
      final auth = ref.read(authProvider);
      if (!auth.isAuthenticated ||
          auth.embyServerUrl == null ||
          auth.token == null) {
        return;
      }
      final data = await _cloudService.checkCloudSync(
        serverUrl: auth.embyServerUrl!,
        token: auth.token!,
      );
      if (data == null || data.isEmpty) return;
      final lastId = data['lastId'] as String?;
      final deviceName = (data['deviceName'] as String?) ?? '其他设备';
      if (lastId == null || lastId.isEmpty) return;
      // 是否与当前条目相同
      final current = ref.read(currentPlayingItemProvider);
      if (current != null && current.id == lastId) return;
      // 在 UI 上展示：SnackBar 提示
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text('从$deviceName 续播：继续播放此视频？'),
          action: SnackBarAction(
            label: '跳转',
            onPressed: () {
              _seekToItem(lastId);
            },
          ),
        ),
      );
    } catch (e) {
      AppLogger.debug('云同步检查失败', data: {'error': e.toString()});
    }
  }

  // 切换条目时：保存旧条目到云端，作为续播书签
  void _saveCloudSyncIfNeeded(MediaItem? newItem) {
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) return;
    final oldItem = _lastReportedItem;
    _lastReportedItem = newItem;
    if (oldItem == null) return;
    if (newItem != null && oldItem.id == newItem.id) return;
    // 异步 save，避免阻塞 UI
    unawaited(
      _cloudService.saveCloudSync(
        itemId: oldItem.id,
        libraryId: _currentLibraryId(),
        libraryType: '',
        serverUrl: auth.embyServerUrl!,
        token: auth.token!,
      ),
    );
  }

  // 工具：当前媒体库 ID（多选时取第一个，未选则为空字符串）
  String _currentLibraryId() {
    try {
      final libs = ref.read(libraryListProvider);
      if (!libs.hasValue || libs.value!.isEmpty) return '';
      final selectedIds = ref.read(selectedLibraryIdsProvider);
      return selectedIds.isNotEmpty
          ? selectedIds.first
          : libs.value!.first.id;
    } catch (_) {
      return '';
    }
  }

  // 根据 itemId 跳到对应视频（简单版：在 items 线性查找）
  void _seekToItem(String itemId) {
    final items = ref.read(videoListProvider).items;
    if (items.isEmpty) return;
    final idx = items.indexWhere((item) => item.id == itemId);
    if (idx < 0) return;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        idx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // 键盘快捷键处理
  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;

    // 视图模式切换（E）
    final viewMode = ref.read(viewModeProvider);
    if (viewMode != ViewMode.feed) {
      // 网格模式下仅处理 E 键切换回视频流
      if (key == LogicalKeyboardKey.keyE) {
        ref.read(viewModeProvider.notifier).setMode(ViewMode.feed);
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
        _seekBySeconds(-15); // 快退 15 秒
        return true;
      case LogicalKeyboardKey.keyD:
      case LogicalKeyboardKey.arrowRight:
        _seekBySeconds(15); // 快进 15 秒
        return true;
      case LogicalKeyboardKey.keyU:
        _toggleFavorite();
        return true;
      case LogicalKeyboardKey.keyE:
        ref.read(viewModeProvider.notifier).setMode(ViewMode.grid);
        return true;
      case LogicalKeyboardKey.keyR:
        _toggleFeedType();
        return true;
      case LogicalKeyboardKey.keyG:
        LibrarySelector.show(context);
        return true;
      case LogicalKeyboardKey.keyF:
        _toggleFullscreen();
        return true;
      case LogicalKeyboardKey.keyM:
        _toggleMute();
        return true;
      case LogicalKeyboardKey.keyN:
        // 下一集（剧集类内容）
        _jumpToNextEpisodeFromCurrent();
        return true;
      case LogicalKeyboardKey.keyP:
        // 上一集（剧集类内容）—— 回退到上一条视频
        _goToPreviousVideo();
        return true;
      case LogicalKeyboardKey.slash:
        // 按 / 显示帮助面板
        setState(() => _showHelp = !_showHelp);
        return true;
      default:
        return false;
    }
  }

  // 切换到上一个视频
  void _goToPreviousVideo() {
    if (_pageController.hasClients && _pageController.page! > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // 切换到下一个视频
  void _goToNextVideo() {
    final videoState = ref.read(videoListProvider);
    if (_pageController.hasClients &&
        _pageController.page! < videoState.items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // 当前播放位置相对跳转（支持正数=向前，负数=向后）
  // 从 currentVideoControllerProvider 取到当前播放控制器
  void _seekBySeconds(int seconds) {
    final controller = ref.read(currentVideoControllerProvider);
    if (controller == null) return;
    if (!controller.value.isInitialized) return;
    final current = controller.value.position;
    final duration = controller.value.duration;
    final deltaMs = seconds * 1000;
    var newMs = current.inMilliseconds + deltaMs;
    newMs = newMs.clamp(0, duration.inMilliseconds);
    controller.seekTo(Duration(milliseconds: newMs));
  }

  // 暂停/播放切换
  void _togglePlayPause() {
    final isPlaying = ref.read(isPlayingProvider);
    final controller = ref.read(currentVideoControllerProvider);
    // 同步到实际控制器（isPlayingProvider 可能与真实状态不同步）
    if (controller != null && controller.value.isInitialized) {
      if (isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    }
    ref.read(isPlayingProvider.notifier).state = !isPlaying;
  }

  // 收藏切换
  void _toggleFavorite() {
    final item = ref.read(currentPlayingItemProvider);
    if (item != null) {
      ref.read(favoritesProvider.notifier).toggleFavorite(item);
    }
  }

  // 切换浏览模式（最新/随机/收藏/继续观看/推荐）——清理缓存后刷新
  void _toggleFeedType() {
    final current = ref.read(feedTypeProvider);
    final next = switch (current) {
      FeedType.latest => FeedType.random,
      FeedType.random => FeedType.favorites,
      FeedType.favorites => FeedType.resume,
      FeedType.resume => FeedType.recommend,
      FeedType.recommend => FeedType.latest,
    };
    // 切换前清理预加载缓存（不同 feedType 下的视频完全不同）
    unawaited(ref.read(videoPoolProvider).disposeAll());
    ref.read(feedTypeProvider.notifier).setType(next);
    _showModeToast(next);
  }

  // 全屏切换
  void _toggleFullscreen() {
    if (MediaQuery.of(context).size.aspectRatio < 1) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  // 静音切换
  void _toggleMute() {
    final isMuted = ref.read(isMutedProvider);
    ref.read(isMutedProvider.notifier).setMuted(!isMuted);
  }

  // 显示浏览模式提示
  void _showModeToast(FeedType type) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('切换到：${type.zhLabel}'),
        duration: const Duration(seconds: 1),
        backgroundColor: scheme.surface.withOpacity(0.9),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final videoState = ref.watch(videoListProvider);
    final authState = ref.watch(authProvider);
    final viewMode = ref.watch(viewModeProvider);
    final scheme = Theme.of(context).colorScheme;

    // 未登录时直接显示提示卡片，不进入视频列表逻辑
    final isNotAuthenticated = !authState.isAuthenticated ||
        authState.embyServerUrl == null ||
        authState.token == null;

    // 注意：返回键处理由 HomeScaffold 中的 PopScope 统一管理（应用退出确认）
    return Scaffold(
        backgroundColor: scheme.surface,
        body: Stack(
          children: [
            // 主体内容：根据视图模式切换
            if (isNotAuthenticated)
              ErrorStateCard.notLoggedIn()
            else if (viewMode == ViewMode.feed)
              _buildVideoPageView(videoState)
            else
              _buildGridPageView(videoState),

            // 顶部：媒体库切换器 + 视图切换按钮（仅 feed 模式显示，grid 模式使用 PosterGridView 自带 Header）
            if (viewMode == ViewMode.feed)
              Positioned(
                left: 0, right: 0, top: 0,
                child: _buildTopBar(viewMode),
              ),

            // 快捷键帮助面板
            if (_showHelp)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _showHelp = false),
                  child: Container(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.54),
                    alignment: Alignment.center,
                    child: const KeyboardHelpPanel(),
                  ),
                ),
              ),
          ],
        ),
    );
  }

  // 顶部栏：根据视图模式显示不同布局
  Widget _buildTopBar(ViewMode viewMode) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surface.withOpacity(0.87),
            scheme.surface.withOpacity(0.45),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: viewMode == ViewMode.feed
            ? _buildFeedTopBar(scheme, viewMode)
            : _buildGridTopBar(scheme, viewMode),
      ),
    );
  }

  // 视频流模式顶部栏：搜索 + 推荐 + 历史 + 媒体库 + 视图切换
  Widget _buildFeedTopBar(ColorScheme scheme, ViewMode viewMode) {
    final feedType = ref.watch(feedTypeProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 左侧：搜索、推荐和历史按钮
        Row(
          children: [
            // 搜索按钮
            IconButton(
              icon: Icon(
                Icons.search,
                color: scheme.onSurface.withOpacity(0.7),
                size: 22,
              ),
              onPressed: () {
                ref.read(pageNavigationNotifierProvider).goToSearch();
              },
              tooltip: '搜索',
            ),
            // 推荐按钮
            IconButton(
              icon: Icon(
                Icons.auto_awesome,
                color: feedType == FeedType.recommend
                    ? scheme.primary
                    : scheme.onSurface.withOpacity(0.7),
                size: 22,
              ),
              onPressed: () {
                final newType = feedType == FeedType.recommend
                    ? FeedType.latest
                    : FeedType.recommend;
                ref.read(feedTypeProvider.notifier).setType(newType);
              },
              tooltip: feedType == FeedType.recommend ? '关闭推荐' : '推荐',
            ),
            // 历史按钮
            IconButton(
              icon: Icon(
                Icons.history,
                color: scheme.onSurface.withOpacity(0.7),
                size: 22,
              ),
              onPressed: () {
                ref.read(pageNavigationNotifierProvider).goToHistory();
              },
              tooltip: '历史',
            ),
          ],
        ),
        // 右侧：媒体库管理和视图切换按钮
        Row(
          children: [
            // 媒体库管理按钮（打开多选弹窗）
            IconButton(
              icon: Icon(
                Icons.library_books,
                color: scheme.onSurface.withOpacity(0.7),
                size: 22,
              ),
              onPressed: () => LibrarySelector.show(context),
              tooltip: '媒体库',
            ),
            // 视图切换按钮
            IconButton(
              icon: Icon(
                viewMode == ViewMode.feed ? Icons.grid_view : Icons.phone_android,
                color: scheme.onSurface.withOpacity(0.7),
                size: 22,
              ),
              onPressed: () {
                ref.read(viewModeProvider.notifier).setMode(
                  viewMode == ViewMode.feed ? ViewMode.grid : ViewMode.feed,
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // 网格模式顶部栏：视图切换
  Widget _buildGridTopBar(ColorScheme scheme, ViewMode viewMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: const [
          Spacer(),
          // 视图切换按钮
          // 注意：网格模式下悬浮顶部栏已隐藏，视图切换按钮在 PosterGridView 的 Header 中
        ],
      ),
    );
  }

  // 构建网格视图
  Widget _buildGridPageView(VideoListState videoState) {
    return PosterGridView(scrollController: _gridScrollController);
  }

  // 构建视频流 PageView：支持相邻条目预加载、自动连播、resume 模式
  Widget _buildVideoPageView(VideoListState videoState) {
    if (videoState.items.isEmpty && videoState.isLoading) {
      return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
    }
    if (videoState.items.isEmpty && videoState.error != null) {
      return ErrorStateCard(
        title: videoState.error!,
        actionLabel: '重试',
        onAction: () {
          ref.read(videoListProvider.notifier).refresh();
        },
      );
    }
    // 追加失败时用 SnackBar 提示，不清除已有数据
    if (videoState.items.isNotEmpty && videoState.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(videoState.error!),
              action: SnackBarAction(
                label: '重试',
                onPressed: () {
                  ref.read(videoListProvider.notifier).loadMore();
                },
              ),
            ),
          );
          // 清除 error 避免重复弹出
          ref.read(videoListProvider.notifier).clearError();
        }
      });
    }
    if (videoState.items.isEmpty) {
      return EmptyStateCard.noVideos();
    }

    // 初始播放位置（从其他页面跳转过来时使用）
    if (_initialItemId != null && !_hasScrolledToInitial) {
      final initialIndex = videoState.items.indexWhere((item) => item.id == _initialItemId);
      if (initialIndex >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients && !_hasScrolledToInitial) {
            _hasScrolledToInitial = true;
            _currentIndex = initialIndex;
            _pageController.jumpToPage(initialIndex);
          }
        });
      }
    }

    // 首次进入时从 SharedPreferences 恢复滚动位置
    // 如果来自网格点击，跳过恢复（由 _handleGridToFeedTransition 控制跳转）
    final gridSelectedId = ref.read(gridSelectedItemIdProvider);
    if (_initialItemId == null &&
        !_hasRestoredScrollPosition &&
        (gridSelectedId == null || gridSelectedId.isEmpty) &&
        videoState.items.isNotEmpty) {
      _hasRestoredScrollPosition = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _restoreVideoIndex(videoState.items.length - 1);
        }
      });
    }

    final auth = ref.read(authProvider);
    final embyServerUrl = auth.embyServerUrl;
    final token = auth.token;

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: videoState.items.length + (videoState.hasMore ? 1 : 0),
      onPageChanged: (index) {
        _currentIndex = index;
        // 同步更新全局 currentIndexProvider，供"神之一手"裁剪等逻辑使用
        ref.read(currentIndexProvider.notifier).state = index;
        // 保存当前视频索引到 SharedPreferences
        _saveVideoIndex(index);
        if (videoState.hasMore && index >= videoState.items.length - 2) {
          // 使用 ref.read 读取最新状态，避免闭包捕获过期值
          final latestState = ref.read(videoListProvider);
          if (!latestState.isLoading) {
            ref.read(videoListProvider.notifier).loadMore();
          }
        }
        // 预加载上一条和下一条视频（走 VideoPoolService 降级链）
        _preloadNeighbors(index, videoState.items, embyServerUrl, token);
        // 预加载相邻视频的封面图（上一条 + 下一条 + 下下条）
        _preloadPosters(index, videoState.items, embyServerUrl, token);
        // 清理距离较远的预加载缓存（保留上一条 + 下一条）
        _evictFarPreloads(index, videoState.items);
      },
      itemBuilder: (context, index) {
        if (index >= videoState.items.length) {
          return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
        }
        final item = videoState.items[index];
        // 从 VideoPoolService 取出预加载的会话（如存在）
        final preloadedSession = _takePreloadedSession(item.id);
        // 首次构建时对相邻条目发起预加载
        if (index == 0 && preloadedSession == null && ref.read(videoPoolProvider).size == 0) {
          _preloadNeighbors(0, videoState.items, embyServerUrl, token);
          _preloadPosters(0, videoState.items, embyServerUrl, token);
        }
        return VideoPageItem(
          item: item,
          preloadedSession: preloadedSession,
          onVideoEnded: _goToNextVideo,
          startFromResumePosition: item.hasProgress,
          // 下一集：在 items 中查找同系列的下一集（更大的 indexNumber 或同一 series 的后续条目）
          onNextEpisode: item.seriesName != null
              ? () {
                  _jumpToNextEpisode(videoState.items, index);
                }
              : null,
        );
      },
    );
  }

  // 从当前播放位置触发下一集跳转（键盘 N 键调用）
  void _jumpToNextEpisodeFromCurrent() {
    final videoState = ref.read(videoListProvider);
    if (videoState.items.isEmpty) return;
    _jumpToNextEpisode(videoState.items, _currentIndex);
  }

  // 在 videoState.items 中查找当前 item 的下一集（同 series 的更大 indexNumber）
  void _jumpToNextEpisode(List<MediaItem> items, int currentIndex) {
    final current = items[currentIndex];
    final series = current.seriesName;
    if (series == null || series.isEmpty) {
      _goToNextVideo();
      return;
    }
    // 策略1：当前条目是 Episode，则寻找同 series 的下一个 Episode
    int? nextIndex;
    if (current.indexNumber != null && current.parentIndexNumber != null) {
      // 在 items 中找同一季的下一集（indexNumber = current.indexNumber + 1）
      for (int i = 0; i < items.length; i++) {
        final it = items[i];
        if (it.seriesName == series &&
            it.parentIndexNumber == current.parentIndexNumber &&
            it.indexNumber == current.indexNumber! + 1) {
          nextIndex = i;
          break;
        }
      }
      // 若当前季没找到，尝试直接跳到同 series 的后续条目（下一个季的第1集）
      nextIndex ??= items.indexWhere(
        (it) => it.seriesName == series && it.indexNumber == 1 &&
                 it.parentIndexNumber == current.parentIndexNumber! + 1,
      );
      if (nextIndex == -1) nextIndex = null;
    }
    // 策略2：简单匹配 —— 找到下一个 seriesName 相同的条目（按顺序）
    nextIndex ??= items.indexWhere(
      (it) => it.seriesName == series,
      currentIndex + 1,
    );
    if (nextIndex >= 0 && nextIndex < items.length) {
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    } else {
      // 找不到：回到默认的下一条
      _goToNextVideo();
    }
  }
}
