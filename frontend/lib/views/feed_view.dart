// 视频流页面：竖向全屏滑动 + 顶部媒体库切换 + 分页加载 + 键盘快捷键 + 视图切换
// 新增：跨设备续播（通过 Emby DisplayPreferences 接口与其它设备/EmbyX 共享续播书签）
//
// 路由 + 起始 itemId 透传模式：
// - 路由 `/` 支持 `?initialId=<itemId>`，FeedView 接收后等待目标在 items 中出现，jumpToPage
// - onPageChanged 同步写入 currentPlayingIdProvider（全局"当前在播"信号源）
// - 网格等其他视图只读 currentPlayingIdProvider 用于高亮回显
//
// 架构说明（阶段 3 ViewModel 重构）：
// - FeedView：纯 UI 层，负责 Widget 构建、PageController 管理、系统栏控制
// - FeedViewModel：业务逻辑层，处理键盘快捷键、云同步、滚动持久化、视频切换等
// - PlaybackCoordinator：播放协调层，处理预加载、播放ID同步、视图切换播放控制

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../coordinators/playback_coordinator.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/app_preferences.dart' show ViewMode, FeedType;
import '../utils/constants.dart';
import '../utils/fullscreen_navigator.dart';
import '../utils/keyboard_shortcuts.dart';
import '../viewmodels/feed_view_model.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/error_state_card.dart';
import '../widgets/library_selector.dart';
import '../widgets/poster_grid_view.dart';
import '../widgets/video_page_item.dart';

class FeedView extends ConsumerStatefulWidget {
  // 路由透传的初始播放视频 ID：来自 GoRouter `/?initialId=`
  // - 网格点击 → 跳转前 context.go('/?initialId=$id')
  // - 搜索/收藏/演员详情 → 跳转前 context.go('/?initialId=$id')
  // - 跨进程清空：每次新路由都是一次新的"起点"
  final String? initialItemId;

  const FeedView({super.key, this.initialItemId});

  @override
  ConsumerState<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends ConsumerState<FeedView>
    with AutomaticKeepAliveClientMixin<FeedView> {
  late PageController _pageController;
  int _currentIndex = 0;
  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier<int>(0);

  // 滚动位置持久化相关（仅网格视图，视频流不持久化）
  final ScrollController _gridScrollController = ScrollController();

  // 页面切换防抖：快速滑动时只在静止后执行预加载和清理
  Timer? _pageChangeDebounce;

  // 播放协调器：抽离自原 feed_view.dart 的播放协调逻辑
  late final PlaybackCoordinator _playbackCoordinator;

  // 视图模型：业务逻辑层
  late final FeedViewModel _viewModel;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0, viewportFraction: 1.0);
    // 创建播放协调器
    _playbackCoordinator = PlaybackCoordinator(ref, onPageIndexReady: _jumpToPageByIndex);
    // 创建视图模型
    _viewModel = FeedViewModel(
      ref,
      _playbackCoordinator,
      onJumpToPage: _animateToPage,
      onJumpToPageInstant: _jumpToPageWhenReady,
      onShowSnackBar: _showSnackBar,
      onOpenFullscreen: _openFullscreenPage,
      onShowLibrarySelector: () => LibrarySelector.show(context, scope: LibraryScope.feed),
      onUpdateHelpVisibility: (visible) {
        if (mounted) setState(() {});
      },
    );
    _viewModel.init();

    // 注册全局键盘监听
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    // 监听视图模式变化：系统栏显隐是 UI 行为，由本视图处理
    // 播放暂停/恢复已委托给 ViewModel → PlaybackCoordinator
    ref.listen<ViewMode>(viewModeProvider, (prev, next) {
      if (prev == null) return;
      if (prev == ViewMode.feed && next == ViewMode.grid) {
        _restoreSystemBars();
      } else if (prev == ViewMode.grid && next == ViewMode.feed) {
        _hideSystemBars();
      }
    });

    // 跨设备续播：进入页面时检查其它设备是否存在续播信息
    unawaited(_viewModel.checkCloudSyncOnStartup());

    // 监听网格滚动位置，防抖保存
    _gridScrollController.addListener(_onGridScrollChanged);

    // 沉浸式：进入 feed view 时，若当前是视频流模式则隐藏系统栏
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(viewModeProvider) == ViewMode.feed) {
        _hideSystemBars();
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _pageChangeDebounce?.cancel();
    _currentIndexNotifier.dispose();
    _pageController.dispose();
    _gridScrollController.removeListener(_onGridScrollChanged);
    _gridScrollController.dispose();
    _viewModel.dispose();
    unawaited(_playbackCoordinator.disposeAllPreloads());
    _playbackCoordinator.detach();
    _restoreSystemBars();
    super.dispose();
  }

  // ==================== 跳页辅助（UI 层职责，依赖 PageController.hasClients） ====================

  /// 帧轮询：等到 PageController 已 attach 后执行 jumpToPage
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
  bool _jumpToPageByIndex(int targetIndex) {
    if (!mounted || !_pageController.hasClients) return false;
    _currentIndex = targetIndex;
    _currentIndexNotifier.value = targetIndex;
    _pageController.jumpToPage(targetIndex);
    return true;
  }

  /// 带动画跳页（键盘快捷键、浏览模式切换等场景使用）
  void _animateToPage(int targetIndex) {
    if (!mounted || !_pageController.hasClients) return;
    if (targetIndex < 0) return;
    final items = ref.read(videoListProvider).items;
    if (targetIndex >= items.length) return;
    _pageController.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ==================== 沉浸式系统栏控制（纯 UI 行为） ====================

  void _hideSystemBars() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _restoreSystemBars() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // ==================== 滚动位置持久化 ====================

  void _onGridScrollChanged() {
    _viewModel.saveGridScrollOffset(() => _gridScrollController.offset);
  }

  // ==================== 键盘快捷键（委托给 ViewModel） ====================

  bool _handleKeyEvent(KeyEvent event) => _viewModel.handleKeyEvent(event);

  // ==================== SnackBar（UI 层职责） ====================

  void _showSnackBar(String message, {String? actionLabel, void Function()? onAction}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: actionLabel != null ? const Duration(seconds: 6) : const Duration(seconds: 1),
        backgroundColor: actionLabel != null ? null : scheme.surface.withOpacity(0.9),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
  }

  // ==================== 全屏页（UI 层职责，依赖 Navigator） ====================

  Future<void> _openFullscreenPage() async {
    await FullscreenNavigator.open(
      ref: ref,
      context: context,
      onExit: () {
        if (mounted) {
          ref.read(toolbarVisibilityProvider.notifier).show();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final videoState = ref.watch(videoListProvider);
    final authState = ref.watch(authProvider);
    final viewMode = ref.watch(viewModeProvider);
    final toolbarVisible = ref.watch(toolbarVisibilityProvider);
    final helpVisible = ref.watch(feedHelpVisibleProvider);
    final scheme = Theme.of(context).colorScheme;

    final isNotAuthenticated = !authState.isAuthenticated ||
        authState.embyServerUrl == null ||
        authState.token == null;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
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

          // 顶部工具栏
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

          // 当前位置指示
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
          if (helpVisible)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => ref.read(feedHelpVisibleProvider.notifier).state = false,
                child: Container(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.54),
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: () {},
                    behavior: HitTestBehavior.opaque,
                    child: const KeyboardHelpPanel(),
                  ),
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

  // 视频流模式顶部栏
  Widget _buildFeedTopBar(ColorScheme scheme, ViewMode viewMode) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTopBarButton(
            icon: Icons.search,
            label: '搜索',
            onTap: () => ref.read(pageNavigationNotifierProvider).goToSearch(),
          ),
          _buildTopBarButton(
            icon: Icons.history,
            label: '历史',
            onTap: () => ref.read(pageNavigationNotifierProvider).goToHistory(),
          ),
          _buildTopBarButton(
            icon: Icons.auto_awesome,
            label: '推荐',
            onTap: () => context.push('/recommend'),
          ),
          _buildTopBarButton(
            icon: Icons.play_circle_outline,
            label: '视频流',
            onTap: () {
              if (viewMode != ViewMode.feed) {
                ref.read(viewModeProvider.notifier).setMode(ViewMode.feed);
              }
            },
          ),
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

  // 顶部栏统一按钮
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

  // 构建视频流 PageView
  Widget _buildVideoPageView(VideoListState videoState) {
    final error = videoState.error;
    final errorMsg = error?.message;
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
          ref.read(videoListProvider.notifier).clearError();
        }
      });
    }
    if (videoState.items.isEmpty) {
      return EmptyStateCard.noVideos();
    }

    // 路由透传 initialId 跳转
    final initialId = widget.initialItemId;
    if (initialId != null && initialId.isNotEmpty) {
      _viewModel.waitForInitialItem(initialId);
    }

    final auth = ref.read(authProvider);
    final embyServerUrl = auth.embyServerUrl;
    final token = auth.token;

    // 首次加载：items 可用但 currentPlayingId 尚未初始化时，设置第一个 item 为当前播放项
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
        // 委托 ViewModel 处理业务逻辑
        final needLoadMore = _viewModel.onPageChanged(
          index,
          videoState.items,
          videoState.hasMore,
          videoState.isLoading,
        );
        if (needLoadMore) {
          ref.read(videoListProvider.notifier).loadMore();
        }
        // 防抖：页面静止后执行预加载和清理
        _pageChangeDebounce?.cancel();
        _pageChangeDebounce = Timer(const Duration(milliseconds: 200), () {
          _viewModel.onPageChangeSettled(index, videoState.items);
        });
      },
      itemBuilder: (context, index) {
        if (index >= videoState.items.length) {
          return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
        }
        final item = videoState.items[index];
        // 从协调器取出预加载的会话
        final rawSession = _playbackCoordinator.takePreloadedSession(item.id);
        final preloadedSession =
            (rawSession != null && rawSession.isInitialized) ? rawSession : null;
        // 首次构建：当前视频由 VideoPlayerWidget 直接初始化，只预加载下一条
        if (index == 0 && preloadedSession == null && ref.read(videoPoolProvider).size == 0) {
          if (1 < videoState.items.length && embyServerUrl != null && token != null) {
            final nextItem = videoState.items[1];
            final pool = ref.read(videoPoolProvider);
            unawaited(pool.preload(item: nextItem, serverUrl: embyServerUrl, token: token));
          }
        }
        return RepaintBoundary(
          // 设置 ValueKey(item.id)：items 列表变化时让 PageView 按 id 复用 widget，
          // 避免出现「画面还在播旧视频，元信息是新视频」的鬼影过渡态。
          // 对齐 PlaybackShell（video_page_item.dart 第 1205 行）的实现。
          child: VideoPageItem(
            key: ValueKey(item.id),
            item: item,
            isCurrentPage: index == _currentIndex,
            preloadedSession: preloadedSession,
            onVideoEnded: _viewModel.onVideoEnded,
            startFromResumePosition: item.hasProgress,
            source: videoState.feedType == FeedType.resume ? 'resume' : 'feed',
          ),
        );
      },
    );
  }
}
