// 视频流页面：竖向全屏滑动 + 顶部媒体库切换 + 分页加载 + 键盘快捷键 + 视图切换
// 新增：跨设备续播（通过 Emby DisplayPreferences 接口与其它设备/EmbyX 共享续播书签）

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';
import '../utils/app_preferences.dart' show ViewMode, FeedType;
import '../utils/keyboard_shortcuts.dart';
import '../utils/logger.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/error_state_card.dart';
import '../widgets/library_selector.dart';
import '../widgets/poster_grid_view.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/video_page_item.dart';

class FeedView extends ConsumerStatefulWidget {
  const FeedView({super.key});

  @override
  ConsumerState<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends ConsumerState<FeedView>
    with AutomaticKeepAliveClientMixin<FeedView> {
  late PageController _pageController;
  bool _showHelp = false; // 快捷键帮助面板显示状态
  // 预加载控制器缓存：key = index，value = VideoPlayerController
  // 在 onPageChanged 时构建下一条的 controller，在 VideoPageItem 中复用
  final Map<int, VideoPlayerController> _preloadCache =
      <int, VideoPlayerController>{};
  // 当前正在播放的索引（与 _pageController 同步）
  int _currentIndex = 0;

  // 云同步（跨设备续播）相关
  final EmbytokService _cloudService = EmbytokService();
  MediaItem? _lastReportedItem;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0, viewportFraction: 1.0);
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
    // 清理所有预加载控制器
    for (final controller in _preloadCache.values) {
      try {
        controller.dispose();
      } catch (_) {}
    }
    _preloadCache.clear();
    super.dispose();
  }

  // ========== 预加载与清理 ==========

  // 对指定 index 的 MediaItem 构建 VideoPlayerController 并 initialize()，
  // 不调用 play()，只做初始化，以便滑动过来时立即播放。
  // 设计原则：_preloadCache 只持有"尚未显示的"预加载项，一旦页面构建时从
  // cache 取出一个 controller，就把它从 cache 中移除，交给 VideoPageItem
  // 作为唯一的管理者，避免双重 dispose。
  void _preloadNextVideo(int index, List<MediaItem> items, String? embyServerUrl, String? token) {
    if (index + 1 >= items.length) return;
    final nextIndex = index + 1;
    // 限制最多同时预加载 1 个（当前 + 下一条），避免内存占用过高
    if (_preloadCache.length >= 1) return;
    if (_preloadCache.containsKey(nextIndex)) return;
    final nextItem = items[nextIndex];
    final url = nextItem.computePlaybackUrl(embyServerUrl, token);
    if (url == null || url.isEmpty) return;
    try {
      final headers = nextItem.authHeaders(token);
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
      );
      controller.initialize().then((_) {
        // 初始化完成后，如果 cache 仍持有该 index，则保留
        // 否则立即释放，避免泄漏
        if (_preloadCache[nextIndex] != controller) {
          try { controller.dispose(); } catch (_) {}
        }
      }).catchError((_) {
        try { controller.dispose(); } catch (_) {}
        _preloadCache.remove(nextIndex);
      });
      _preloadCache[nextIndex] = controller;
    } catch (_) {}
  }

  // 清理所有预加载控制器（在翻页时调用）
  // 设计原则：除了当前 index 的下一条，其余全部释放
  void _evictFarPreloads(int currentIndex) {
    final keepIndex = currentIndex + 1;
    final toRemove = <int>[];
    for (final idx in _preloadCache.keys) {
      if (idx != keepIndex) toRemove.add(idx);
    }
    for (final idx in toRemove) {
      try {
        _preloadCache[idx]?.dispose();
      } catch (_) {}
      _preloadCache.remove(idx);
    }
  }

  // 从 cache 取出某个 index 的预加载 controller，并从 cache 移除
  // 取出后，controller 的生命周期交给调用方（VideoPageItem）管理
  VideoPlayerController? _takePreloadedController(int index) {
    final controller = _preloadCache[index];
    if (controller != null) {
      _preloadCache.remove(index);
      return controller;
    }
    return null;
  }

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

  // 工具：当前媒体库 ID（未选则为空字符串）
  String _currentLibraryId() {
    try {
      final libs = ref.read(libraryListProvider);
      if (!libs.hasValue || libs.value!.isEmpty) return '';
      // selectedLibraryIdProvider 返回 String（选中的库 id），非空则直接用
      final selectedId = ref.watch(selectedLibraryIdProvider);
      return (selectedId != null && selectedId.isNotEmpty)
          ? selectedId
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
    for (final c in _preloadCache.values) {
      try { c.dispose(); } catch (_) {}
    }
    _preloadCache.clear();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('切换到：${type.zhLabel}'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.black87,
      ),
    );
  }

  // 选择媒体库
  Future<void> _selectLibrary(Library lib) async {
    ref.read(selectedLibraryIdProvider.notifier).setLibrary(lib.id);
    await ref.read(videoListProvider.notifier).refresh(libraryId: lib.id);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final librariesAsync = ref.watch(libraryListProvider);
    final videoState = ref.watch(videoListProvider);
    final viewMode = ref.watch(viewModeProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 主体内容：根据视图模式切换
          if (viewMode == ViewMode.feed)
            _buildVideoPageView(videoState)
          else
            const PosterGridView(),

          // 顶部：媒体库切换器 + 视图切换按钮
          Positioned(
            left: 0, right: 0, top: 0,
            child: _buildTopBar(librariesAsync, viewMode),
          ),

          // 快捷键帮助面板
          if (_showHelp)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showHelp = false),
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: const KeyboardHelpPanel(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 顶部栏：媒体库切换 + 视图切换按钮
  Widget _buildTopBar(AsyncValue<List<Library>> librariesAsync, ViewMode viewMode) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.black45, Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // 媒体库切换器（横向滚动）
            Expanded(child: _buildLibraryChips(librariesAsync)),
            // 视图切换按钮
            IconButton(
              icon: Icon(
                viewMode == ViewMode.feed ? Icons.grid_view : Icons.phone_android,
                color: Colors.white70,
                size: 22,
              ),
              onPressed: () {
                ref.read(viewModeProvider.notifier).setMode(
                  viewMode == ViewMode.feed ? ViewMode.grid : ViewMode.feed,
                );
              },
            ),
            // 媒体库选择器按钮（快捷键 G）
            IconButton(
              icon: const Icon(Icons.library_books, color: Colors.white70, size: 22),
              onPressed: () => LibrarySelector.show(context),
            ),
          ],
        ),
      ),
    );
  }

  // 构建视频流 PageView：支持相邻条目预加载、自动连播、resume 模式
  Widget _buildVideoPageView(VideoListState videoState) {
    if (videoState.items.isEmpty && videoState.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)));
    }
    if (videoState.items.isEmpty && videoState.error != null) {
      final err = videoState.error!;
      // 未登录场景特殊处理
      if (err.contains('登录') || err.contains('认证')) {
        return ErrorStateCard.notLoggedIn();
      }
      return ErrorStateCard(
        title: err,
        actionLabel: '重试',
        onAction: () {
          final libId = ref.read(selectedLibraryIdProvider);
          ref.read(videoListProvider.notifier).refresh(libraryId: libId);
        },
      );
    }
    if (videoState.items.isEmpty) {
      return EmptyStateCard.noVideos();
    }

    final isResumeMode = videoState.feedType == FeedType.resume;
    final auth = ref.read(authProvider);
    final embyServerUrl = auth.embyServerUrl;
    final token = auth.token;

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: videoState.items.length + (videoState.hasMore ? 1 : 0),
      onPageChanged: (index) {
        _currentIndex = index;
        if (videoState.hasMore && index >= videoState.items.length - 2 && !videoState.isLoading) {
          ref.read(videoListProvider.notifier).loadMore();
        }
        // 预加载下一条视频
        _preloadNextVideo(index, videoState.items, embyServerUrl, token);
        // 清理距离较远的预加载缓存（>±2）
        _evictFarPreloads(index);
      },
      itemBuilder: (context, index) {
        if (index >= videoState.items.length) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)));
        }
        final item = videoState.items[index];
        // 从 cache 取出预加载 controller，取出后就从 cache 移除，
        // controller 的生命周期交给 VideoPageItem 管理
        final preloadedController = _takePreloadedController(index);
        // 首次构建时对当前条目 + 1 预加载
        if (index == 0 && !_preloadCache.containsKey(1) && _preloadCache.isEmpty) {
          _preloadNextVideo(0, videoState.items, embyServerUrl, token);
        }
        return VideoPageItem(
          item: item,
          preloadedController: preloadedController,
          onVideoEnded: _goToNextVideo,
          startFromResumePosition: isResumeMode,
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
    if (nextIndex != null && nextIndex >= 0 && nextIndex < items.length) {
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

  // 顶部媒体库横向切换器
  Widget _buildLibraryChips(AsyncValue<List<Library>> librariesAsync) {
    return librariesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (libraries) {
        if (libraries.isEmpty) return const SizedBox.shrink();
        final selectedId = ref.watch(selectedLibraryIdProvider);
        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: libraries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final lib = libraries[index];
              final isSelected = lib.id == selectedId;
              return TvFocusable(
                key: Key('lib_${lib.id}'),
                onTap: () => _selectLibrary(lib),
                borderRadius: 20,
                borderWidth: 2,
                autofocus: index == 0 && selectedId == null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE91E63) : Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? const Color(0xFFE91E63) : Colors.white24),
                  ),
                  child: Text(lib.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
