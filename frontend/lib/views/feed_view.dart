// 视频流页面：竖向全屏滑动 + 顶部媒体库切换 + 分页加载 + 键盘快捷键 + 视图切换
// 新增：跨设备续播（通过 Emby DisplayPreferences 接口与其它设备/EmbyX 共享续播书签）
//
// 路由 + 起始 itemId 透传模式：
// - 路由 `/` 支持 `?initialId=<itemId>`，FeedView 接收后等待目标在 items 中出现，jumpToPage
// - onPageChanged 同步写入 currentPlayingIdProvider（全局“当前在播”信号源）
// - 网格等其他视图只读 currentPlayingIdProvider 用于高亮回显

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../coordinators/playback_coordinator.dart';
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
import 'fullscreen_video_page.dart';

class FeedView extends ConsumerStatefulWidget {
  // 路由透传的初始播放视频 ID：来自 GoRouter `/?initialId=`
  // - 网格点击 → 跳转前 context.go('/?initialId=$id')
  // - 搜索/收藏/演员详情 → 跳转前 context.go('/?initialId=$id')
  // - 跨进程清空：每次新路由都是一次新的“起点”
  final String? initialItemId;

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
  // 当前位置指示器（N/总数），用 ValueNotifier 驱动，避免每次翻页都 setState
  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier<int>(0);

  // 滚动位置持久化相关（仅网格视图，视频流不持久化）
  final ScrollController _gridScrollController = ScrollController();
  Timer? _gridScrollSaveTimer; // 网格滚动保存防抖计时器

  // 云同步（跨设备续播）相关
  final EmbytokService _cloudService = EmbytokService();
  MediaItem? _lastReportedItem;

  // 已处理的初始播放项 ID（防止重复跳转）
  String? _processedInitialItemId;

  // 页面切换防抖：快速滑动时只在静止后执行预加载和清理
  Timer? _pageChangeDebounce;

  // 播放协调器：抽离自原 feed_view.dart 的播放协调逻辑
  // 在 initState 中创建，dispose 中 detach
  late final PlaybackCoordinator _playbackCoordinator;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0, viewportFraction: 1.0);
    // 创建播放协调器：传入跳页回调，用于路由跳转时通知 UI 执行 PageController.jumpToPage
    _playbackCoordinator = PlaybackCoordinator(ref, onPageIndexReady: _jumpToPageByIndex);
    // 注册全局键盘监听
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    // 监听当前播放条目变化：切换到新视频时保存旧条目的续播信息
    ref.listen<MediaItem?>(currentPlayingItemProvider, (prev, next) {
      _saveCloudSyncIfNeeded(next);
    });
    // 监听外部跳页请求：全屏页 FullscreenVideoPage 等设置后跳到指定 index（PR #62）
    // 设计：FullscreenVideoPage 切“上一集/下一集”时不能直接调用 _pageController，
    // 所以通过 feedViewPageJumpRequestProvider 通知 FeedView 跳转
    ref.listen<int?>(feedViewPageJumpRequestProvider, (prev, next) {
      if (next != null && next != prev) {
        AppLogger.debug('外部请求跳页', data: {'index': next});
        final targetIndex = _playbackCoordinator.consumeJumpRequest();
        if (targetIndex != null) {
          _jumpToPageWhenReady(targetIndex);
        }
      }
    });
    // 监听视图模式变化：feed↔grid 切换时通过协调器处理播放暂停/恢复
    // 系统栏显隐是 UI 行为，由本视图处理
    // 注：listen 回调的 prev 首次为 null，需判空（handleViewModeChange 要求非空 ViewMode）
    ref.listen<ViewMode>(viewModeProvider, (prev, next) {
      if (prev == null) return;
      _playbackCoordinator.handleViewModeChange(prev, next);
      if (prev == ViewMode.feed && next == ViewMode.grid) {
        // 切到网格：恢复系统栏（便于操作 AppBar）
        _restoreSystemBars();
      } else if (prev == ViewMode.grid && next == ViewMode.feed) {
        // 切回视频流：隐藏系统栏（沉浸式）
        _hideSystemBars();
      }
    });
    // 跨设备续播：进入页面时检查其它设备是否存在续播信息
    _checkCloudSyncOnStartup();
    // 监听网格滚动位置，防抖保存
    _gridScrollController.addListener(_onGridScrollChanged);
    // 沉浸式：进入 feed view 时，若当前是视频流模式则隐藏系统栏
    // 网格模式保持系统栏可见，便于操作 AppBar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(viewModeProvider) == ViewMode.feed) {
        _hideSystemBars();
      }
    });
    // PR #66：首次未配置视频流媒体库 → 强制弹 LibrarySelector 让用户选一次
    // 监听 libraryListProvider 加载完成（不打断首帧）
    ref.listen<AsyncValue<List<Library>>>(libraryListProvider, (prev, next) {
      next.whenData((_) {
        // 等到下一帧再弹，避免 build 期间触发 setState
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final configured = ref.read(feedLibraryConfiguredProvider);
          if (configured) return;
          // 媒体库列表已加载但用户没配置过 → 弹 LibrarySelector
          LibrarySelector.show(context, scope: LibraryScope.feed);
        });
      });
    });
  }

  // 已处理的初始播放项 ID（防止重复跳转）。见 build 中的初始 ID 处理。

  /// 帧轮询：等到 PageController 已 attach 后执行 jumpToPage
  /// 用于路由透传 initialId 时，PageController 还没 attach 的场景
  void _jumpToPageWhenReady(int targetIndex, {int retryCount = 0}) {
    if (!mounted) return;
    if (retryCount > 30) return;

    if (_pageController.hasClients) {
      _currentIndex = targetIndex;
      _currentIndexNotifier.value = targetIndex;
      _pageController.jumpToPage(targetIndex);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToPageWhenReady(targetIndex, retryCount: retryCount + 1);
    });
  }

  /// 协调器跳页回调：返回 true 表示已成功跳页
  /// 由 PlaybackCoordinator.waitForInitialItem 在目标 item 加载完成后调用
  bool _jumpToPageByIndex(int targetIndex) {
    if (!mounted || !_pageController.hasClients) return false;
    _currentIndex = targetIndex;
    _currentIndexNotifier.value = targetIndex;
    _pageController.jumpToPage(targetIndex);
    return true;
  }

  /// 等待路由透传的初始播放项出现在 items 中
  /// 委托给 PlaybackCoordinator 处理（loadMore 触发 + 播放 ID 同步）
  void _waitForInitialItemToLoad(String itemId) {
    _playbackCoordinator.waitForInitialItem(itemId);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _pageChangeDebounce?.cancel();
    _currentIndexNotifier.dispose();
    _pageController.dispose();
    _gridScrollController.removeListener(_onGridScrollChanged);
    _gridScrollController.dispose();
    _gridScrollSaveTimer?.cancel();
    // 退出 feed view 时清理所有预加载（当前页面正在使用的由 VideoPageItem 负责）
    unawaited(_playbackCoordinator.disposeAllPreloads());
    _playbackCoordinator.detach();
    // 退出 feed view 时恢复系统栏（其他页面需要可见的系统栏）
    _restoreSystemBars();
    super.dispose();
  }

  // ========== 沉浸式系统栏控制 ==========
  // 视频流模式：immersiveSticky（滑动边缘可临时唤出，无人操作几秒后自动隐藏）
  // 网格模式 / 退出页面：edgeToEdge（系统栏常驻）
  void _hideSystemBars() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _restoreSystemBars() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // ========== 滚动位置持久化 ==========
  // 注意：视频流内部的 currentIndex 不持久化。
  // 设计原则：每次进入视频流从 index 0 开始；跨视图定位完全靠路由/Provider 透传 ID。

  // 网格滚动变化回调，防抖保存
  void _onGridScrollChanged() {
    _gridScrollSaveTimer?.cancel();
    _gridScrollSaveTimer = Timer(const Duration(milliseconds: 500), () {
      _saveGridScrollOffset();
    });
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

  // ========== 预加载与清理 ==========
  // 已迁移到 PlaybackCoordinator，这里只保留薄封装供 onPageChanged 调用

  // ========== 跨设备续播云同步 ==========

  // 启动时尝试拉取 DisplayPreferences 中的 “EmbyTok-Resume” 信息
  Future<void> _checkCloudSyncOnStartup() async {
    try {
      final auth = ref.read(authProvider);
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
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    if (!auth.isAuthenticated || serverUrl == null || token == null) return;
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
        serverUrl: serverUrl,
        token: token,
      ),
    );
  }

  // 工具：当前媒体库 ID（多选时取第一个，未选则为空字符串）
  String _currentLibraryId() {
    try {
      final libs = ref.read(libraryListProvider);
      final libValue = libs.value;
      if (!libs.hasValue || libValue == null || libValue.isEmpty) return '';
      final selectedIds = ref.read(selectedLibraryIdsProvider);
      return selectedIds.isNotEmpty
          ? selectedIds.first
          : libValue.first.id;
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
        // F 键进入全屏页（复用全局 controller，进度不丢）
        _openFullscreenPage();
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
  // 注：“推荐”已从 FeedType 移除（PR #57），改为独立路由 /recommend
  // 顶部操作栏的“推荐”图标按钮现在直接 context.go('/recommend')
  void _toggleFeedType() {
    final current = ref.read(feedTypeProvider);
    final next = switch (current) {
      FeedType.latest => FeedType.random,
      FeedType.random => FeedType.favorites,
      FeedType.favorites => FeedType.resume,
      FeedType.resume => FeedType.latest,
    };
    // 切换前清理预加载缓存（不同 feedType 下的视频完全不同）
    unawaited(_playbackCoordinator.disposeAllPreloads());
    ref.read(feedTypeProvider.notifier).setType(next);
    _showModeToast(next);
  }

  // 全屏切换：push 到 FullscreenVideoPage
  // 复用全局 currentVideoControllerProvider，零额外内存，进度 100% 不丢
  Future<void> _openFullscreenPage() async {
    // 防御：仅在有 controller 时才进全屏
    if (ref.read(currentVideoControllerProvider) == null) return;
    ref.read(toolbarVisibilityProvider.notifier).hide();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FullscreenVideoPage(),
        fullscreenDialog: true,
      ),
    );
    if (mounted) {
      ref.read(toolbarVisibilityProvider.notifier).show();
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
    // PR #72：监听工具栏可见性（纯净模式 / 全屏页面时隐藏）
    final toolbarVisible = ref.watch(toolbarVisibilityProvider);
    final scheme = Theme.of(context).colorScheme;

    // 未登录时直接显示提示卡片，不进入视频列表逻辑
    final isNotAuthenticated = !authState.isAuthenticated ||
        authState.embyServerUrl == null ||
        authState.token == null;

    // 注意：返回键处理由 HomeScaffold 中的 PopScope 统一管理（应用退出确认）
    // 使用 IndexedStack 保持 feed/grid 两个视图的状态：
    //   - 避免切换时 PageView 和 VideoPlayerController 被 dispose
    //   - 切回视频流时保持之前的播放位置和控制器状态
    //   - 切回网格时保持滚动位置
    return Scaffold(
        backgroundColor: scheme.surface,
        body: Stack(
          children: [
            // 主体内容：使用 IndexedStack 保持两个视图存活
            if (isNotAuthenticated)
              ErrorStateCard.notLoggedIn()
            else
              IndexedStack(
                index: viewMode == ViewMode.feed ? 0 : 1,
                children: [
                  _buildVideoPageView(videoState),
                  _buildGridPageView(videoState),
                ],
              ),

            // 顶部：媒体库切换器 + 视图切换按钮（仅视频流模式显示，网格模式由 PosterGridView 自带 header）
            // PR #72：包裹 toolbarVisible，纯净模式 / 全屏页面时同步隐藏
            if (viewMode == ViewMode.feed)
              Positioned(
                left: 0, right: 0, top: 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: kToolbarAnimMs),
                  curve: Curves.easeOut,
                  offset: toolbarVisible ? Offset.zero : const Offset(0, -1),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: kToolbarAnimMs),
                    opacity: toolbarVisible ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !toolbarVisible,
                      child: _buildTopBar(viewMode),
                    ),
                  ),
                ),
              ),

            // 当前位置指示：N / 总数（仅视频流模式）
            if (viewMode == ViewMode.feed && videoState.items.isNotEmpty)
              Positioned(
                right: 12,
                bottom: 16,
                child: ValueListenableBuilder<int>(
                  valueListenable: _currentIndexNotifier,
                  builder: (context, idx, _) {
                    final total = videoState.items.length;
                    final pos = (idx + 1).clamp(1, total);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.surface.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$pos / $total',
                        style: TextStyle(
                          color: scheme.onSurface.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
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

  // 顶部栏：视频流模式使用
  Widget _buildTopBar(ViewMode viewMode) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surface.withOpacity(0.92),
            scheme.surface.withOpacity(0.62),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: _buildFeedTopBar(scheme, viewMode),
      ),
    );
  }

  // 视频流模式顶部栏：搜索 + 历史 + 推荐 + 视频流 + 视图切换
  // 横向可滚动（PR #77）：用 SingleChildScrollView 包裹，按钮溢出时支持左右滑动
  // 排序：搜索 → 历史 → 推荐 → 视频流 → 视图切换
  Widget _buildFeedTopBar(ColorScheme scheme, ViewMode viewMode) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // 内容不足一屏时不滚动；溢出时启用弹性滚动
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 搜索按钮
          _buildTopBarButton(
            icon: Icons.search,
            label: '搜索',
            onTap: () => ref.read(pageNavigationNotifierProvider).goToSearch(),
          ),
          // 历史按钮
          _buildTopBarButton(
            icon: Icons.history,
            label: '历史',
            onTap: () => ref.read(pageNavigationNotifierProvider).goToHistory(),
          ),
          // 推荐按钮：跳到独立路由 /recommend（PR #57：与 FeedType 解耦）
          _buildTopBarButton(
            icon: Icons.auto_awesome,
            label: '推荐',
            onTap: () => context.push('/recommend'),
          ),
          // 视频流按钮：切到视频流模式（ViewMode.feed）
          // 已经在视频流模式时不重复 setMode；可扩展为「回到第一个视频」
          _buildTopBarButton(
            icon: Icons.play_circle_outline,
            label: '视频流',
            onTap: () {
              if (viewMode != ViewMode.feed) {
                ref.read(viewModeProvider.notifier).setMode(ViewMode.feed);
              }
            },
          ),
          // 视图切换按钮：feed ↔ grid
          _buildTopBarButton(
            icon: viewMode == ViewMode.feed
                ? Icons.grid_view
                : Icons.phone_android,
            label: viewMode == ViewMode.feed ? '网格' : '视频流',
            onTap: () {
              ref.read(viewModeProvider.notifier).setMode(
                    viewMode == ViewMode.feed
                        ? ViewMode.grid
                        : ViewMode.feed,
                  );
            },
          ),
        ],
      ),
    );
  }

  // 顶部栏统一按钮：图标 + 中文文字
  // 设计：横向可滚动按钮组（PR #77），所有按钮统一样式
  Widget _buildTopBarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.onSurface.withOpacity(0.85);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建网格视图
  Widget _buildGridPageView(VideoListState videoState) {
    return PosterGridView(scrollController: _gridScrollController);
  }

  // 构建视频流 PageView：支持相邻条目预加载、自动连播、resume 模式
  // 起始播放项由 build 中读取 widget.initialItemId 决定（路由透传）
  Widget _buildVideoPageView(VideoListState videoState) {
    final errorMsg = videoState.error;
    if (videoState.items.isEmpty && videoState.isLoading) {
      return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
    }
    if (videoState.items.isEmpty && errorMsg != null) {
      return ErrorStateCard(
        title: errorMsg,
        actionLabel: '重试',
        onAction: () {
          ref.read(videoListProvider.notifier).refresh();
        },
      );
    }
    // 追加失败时用 SnackBar 提示，不清除已有数据
    if (videoState.items.isNotEmpty && errorMsg != null) {
      final msg = errorMsg;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
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

    // =======================================================
    // 路由透传 initialId 跳转（最高优先级）
    // - 网格点击/搜索/演员详情：context.go('/?initialId=$id')
    // - 这里只读 widget.initialItemId，不依赖任何全局 provider
    // =======================================================
    final initialId = widget.initialItemId;
    if (initialId != null && initialId.isNotEmpty && _processedInitialItemId != initialId) {
      _processedInitialItemId = initialId;
      AppLogger.debug('路由透传：启动等待跳转', data: {'itemId': initialId});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _waitForInitialItemToLoad(initialId);
        }
      });
    }

    final auth = ref.read(authProvider);
    final embyServerUrl = auth.embyServerUrl;
    final token = auth.token;

    // 首次加载：items 可用但 currentPlayingId 尚未初始化时，设置第一个 item 为当前播放项
    // 避免 PageView 首次构建时相邻页面的 VideoPlayerWidget 先初始化导致的竞态（从第二个视频开始播放）
    // 使用 addPostFrameCallback 避免 build 期间修改 provider 状态
    if (videoState.items.isNotEmpty && ref.read(currentPlayingIdProvider) == null) {
      final firstItem = videoState.items[0];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(currentPlayingIdProvider) == null) {
          ref.read(currentPlayingIdProvider.notifier).state = firstItem.id;
          ref.read(currentPlayingItemProvider.notifier).state = firstItem;
        }
      });
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: videoState.items.length + (videoState.hasMore ? 1 : 0),
      onPageChanged: (index) {
        _currentIndex = index;
        _currentIndexNotifier.value = index;
        // 通过协调器同步当前播放 ID（全局 store，供网格/收藏/历史高亮使用）
        // onPageChanged 是 PageView 真正切换完成时，比 onControllerReady 更可靠。
        _playbackCoordinator.syncCurrentPlaying(
          index: index,
          items: videoState.items,
        );
        // 分页加载：接近末尾时立即触发，不防抖（数据加载需要及时）
        if (videoState.hasMore && index >= videoState.items.length - 2) {
          final latestState = ref.read(videoListProvider);
          if (!latestState.isLoading) {
            ref.read(videoListProvider.notifier).loadMore();
          }
        }
        // 预加载和清理：防抖 100ms，快速滑动时避免“创建-销毁-重建”的资源浪费
        _pageChangeDebounce?.cancel();
        _pageChangeDebounce = Timer(const Duration(milliseconds: 100), () {
          _playbackCoordinator.preloadNeighbors(
            index: index,
            items: videoState.items,
          );
          _playbackCoordinator.evictFarPreloads(
            currentIndex: index,
            items: videoState.items,
          );
        });
      },
      itemBuilder: (context, index) {
        if (index >= videoState.items.length) {
          return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
        }
        final item = videoState.items[index];
        // 从协调器取出预加载的会话（如存在）
        // 守卫：仅当会话仍有效（未因 Token 切换/清理被 dispose）时才使用，
        // 否则回退到 VideoPlayerWidget 动态创建，避免持有已释放的 controller 导致崩溃
        final rawSession = _playbackCoordinator.takePreloadedSession(item.id);
        final preloadedSession =
            (rawSession != null && rawSession.isInitialized) ? rawSession : null;
        // 首次构建：当前视频由 VideoPlayerWidget 直接初始化，只预加载下一条
        // 避免重复为 index=0 创建 controller（VideoPlayerWidget 已在动态创建路径中创建）
        if (index == 0 && preloadedSession == null && ref.read(videoPoolProvider).size == 0) {
          if (1 < videoState.items.length && embyServerUrl != null && token != null) {
            final nextItem = videoState.items[1];
            final pool = ref.read(videoPoolProvider);
            unawaited(pool.preload(item: nextItem, serverUrl: embyServerUrl, token: token));
          }
        }
        // RepaintBoundary：隔离每页的绘制层，滑动时避免相邻页重绘
        // VideoPageItem 含视频画面+按钮栏+信息栏，重绘成本高
        return RepaintBoundary(
          child: VideoPageItem(
            item: item,
            isCurrentPage: index == _currentIndex,
            preloadedSession: preloadedSession,
            onVideoEnded: _goToNextVideo,
            startFromResumePosition: item.hasProgress,
            source:
                videoState.feedType == FeedType.resume ? 'resume' : 'feed',
            // 下一集：在 items 中查找同系列的下一集（更大的 indexNumber 或同一 series 的后续条目）
            onNextEpisode: item.seriesName != null
                ? () {
                    _jumpToNextEpisode(videoState.items, index);
                  }
                : null,
          ),
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
