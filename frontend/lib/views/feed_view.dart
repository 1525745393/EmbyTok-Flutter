// 视频流页面：竖向全屏滑动 + 顶部媒体库切换 + 分页加载 + 键盘快捷键 + 视图切换
// 新增：跨设备续播（通过 Emby DisplayPreferences 接口与其它设备/EmbyX 共享续播书签）

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';
import '../services/video_pool_service.dart';
import '../utils/app_preferences.dart' show ViewMode, FeedType;
import '../utils/keyboard_shortcuts.dart';
import '../utils/logger.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/error_state_card.dart';
import '../widgets/library_selector.dart';
import '../widgets/poster_grid_view.dart';
import '../widgets/video_page_item.dart';

/// 排序选项枚举
enum SortOption {
  recentlyAdded('最近添加'),
  rating('评分'),
  title('标题');

  final String label;
  const SortOption(this.label);
}

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

  // 云同步（跨设备续播）相关
  final EmbytokService _cloudService = EmbytokService();
  MediaItem? _lastReportedItem;

  // 网格视图搜索和排序状态
  final TextEditingController _searchController = TextEditingController();
  SortOption _sortOption = SortOption.recentlyAdded;
  String _searchQuery = '';

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
    });
    // 跨设备续播：进入页面时检查其它设备是否存在续播信息
    _checkCloudSyncOnStartup();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _pageController.dispose();
    _searchController.dispose();
    // 退出 feed view 时清理所有预加载（当前页面正在使用的由 VideoPageItem 负责）
    ref.read(videoPoolProvider).disposeAll();
    super.dispose();
  }

  // ========== 预加载与清理（基于 VideoPoolService）==========

  // 对指定 index 的下一条视频发起预加载
  // 由 VideoPoolService 负责降级链（DirectPlay → DirectStream → HLS）
  void _preloadNextVideo(int index, List<MediaItem> items, String? embyServerUrl, String? token) {
    if (index + 1 >= items.length) return;
    if (embyServerUrl == null || token == null) return;
    final nextItem = items[index + 1];
    if (ref.read(videoPoolProvider).hasSession(nextItem.id)) return;
    // 异步发起，不 await，不阻塞 UI
    ref
        .read(videoPoolProvider)
        .preload(item: nextItem, serverUrl: embyServerUrl, token: token);
  }

  // 清理距离当前索引较远的会话（只保留当前 + 下一条，其余全部清理）
  void _evictFarPreloads(int currentIndex, List<MediaItem> items) {
    final keepIds = <String>[];
    // 当前条目（如存在）：保持在池中（VideoPageItem 已取出，池里不包含）
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

  // 过滤并排序视频列表（用于网格视图）
  List<MediaItem> _filterAndSortItems(List<MediaItem> items) {
    var filtered = items;

    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return item.title.toLowerCase().contains(query) ||
            (item.seriesName?.toLowerCase().contains(query) ?? false) ||
            item.displayGenres.any((g) => g.toLowerCase().contains(query));
      }).toList();
    }

    // 排序
    switch (_sortOption) {
      case SortOption.recentlyAdded:
        // 按 productionYear 降序（较新的在前）
        filtered.sort((a, b) => (b.productionYear ?? 0).compareTo(a.productionYear ?? 0));
        break;
      case SortOption.rating:
        // 按评分降序
        filtered.sort((a, b) => (b.displayRating ?? 0).compareTo(a.displayRating ?? 0));
        break;
      case SortOption.title:
        // 按标题升序
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }

    return filtered;
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

  // 切换浏览模式（最新/随机/收藏/继续观看）——清理缓存后刷新
  void _toggleFeedType() {
    final current = ref.read(feedTypeProvider);
    final next = switch (current) {
      FeedType.latest => FeedType.random,
      FeedType.random => FeedType.favorites,
      FeedType.favorites => FeedType.resume,
      FeedType.resume => FeedType.latest,
    };
    // 切换前清理预加载缓存（不同 feedType 下的视频完全不同）
    ref.read(videoPoolProvider).disposeAll();
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
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: PosterGridView(
                    items: _filterAndSortItems(videoState.items),
                    hasMore: videoState.hasMore && _searchQuery.isEmpty,
                    isLoading: videoState.isLoading,
                    onLoadMore: () {
                      if (!videoState.isLoading) {
                        ref.read(videoListProvider.notifier).loadMore();
                      }
                    },
                  ),
                ),
              ),

            // 顶部：媒体库切换器 + 视图切换按钮
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

  // 视频流模式顶部栏：搜索 + 历史 + 媒体库 + 视图切换
  Widget _buildFeedTopBar(ColorScheme scheme, ViewMode viewMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 左侧：搜索和历史按钮
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

  // 网格模式顶部栏：搜索框 + 排序 + 视图切换
  Widget _buildGridTopBar(ColorScheme scheme, ViewMode viewMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // 搜索框
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索视频...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(width: 8),
          // 排序选择器
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outline.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SortOption>(
                value: _sortOption,
                isDense: true,
                items: SortOption.values.map((option) {
                  return DropdownMenuItem(
                    value: option,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sort, size: 16, color: scheme.primary),
                        const SizedBox(width: 4),
                        Text(option.label),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _sortOption = value);
                  }
                },
              ),
            ),
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
    );
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

    // 如果有初始播放 itemId，且尚未滚动到该位置，则查找并滚动
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

    final auth = ref.read(authProvider);
    final embyServerUrl = auth.embyServerUrl;
    final token = auth.token;

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: videoState.items.length + (videoState.hasMore ? 1 : 0),
      onPageChanged: (index) {
        _currentIndex = index;
        if (videoState.hasMore && index >= videoState.items.length - 2) {
          // 使用 ref.read 读取最新状态，避免闭包捕获过期值
          final latestState = ref.read(videoListProvider);
          if (!latestState.isLoading) {
            ref.read(videoListProvider.notifier).loadMore();
          }
        }
        // 预加载下一条视频（走 VideoPoolService 降级链）
        _preloadNextVideo(index, videoState.items, embyServerUrl, token);
        // 清理距离较远的预加载缓存（保留当前 + 下一条）
        _evictFarPreloads(index, videoState.items);
      },
      itemBuilder: (context, index) {
        if (index >= videoState.items.length) {
          return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
        }
        final item = videoState.items[index];
        // 从 VideoPoolService 取出预加载的会话（如存在）
        final preloadedSession = _takePreloadedSession(item.id);
        // 首次构建时对下一条发起预加载
        if (index == 0 && preloadedSession == null && ref.read(videoPoolProvider).size == 0) {
          _preloadNextVideo(0, videoState.items, embyServerUrl, token);
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
