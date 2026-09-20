// 视频流页面：竖向全屏滑动 + 顶部媒体库切换 + 分页加载 + 键盘快捷键 + 视图切换
// 新增：跨设备续播（通过 Emby DisplayPreferences 接口与其它设备/EmbyX 共享续播书签）
//
// 路由 + 起始 itemId 透传模式：
// - 路由 `/` 支持 `?initialId=<itemId>`，FeedView 接收后等待目标在 items 中出现，jumpToPage
// - onPageChanged 同步写入 playbackStateProvider（全局"当前在播"信号源）
// - 网格等其他视图只读 playbackStateProvider.id 用于高亮回显
//
// 架构说明（阶段 3 ViewModel 重构）：
// - FeedView：纯 UI 层，负责 Widget 构建、PageController 管理、系统栏控制
// - FeedViewModel：业务逻辑层，处理键盘快捷键、云同步、滚动持久化、视频切换等
// - PlaybackCoordinator：播放协调层，处理预加载、播放ID同步、视图切换播放控制

import 'dart:async';

import '../utils/safe_unawaited.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import '../coordinators/playback_coordinator.dart';
import '../providers/providers.dart';
import '../utils/app_preferences.dart' show ViewMode, FeedType;
import '../utils/constants.dart';
import '../utils/fullscreen_navigator.dart';
import '../utils/safe_insets.dart';
import '../utils/keyboard_shortcuts.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/error_state_card.dart';
import '../widgets/library_selector.dart';
import '../widgets/poster_grid_view.dart';
import '../widgets/video/video_page_item.dart';
part 'feed_parts/feed_actions.dart';
part 'feed_parts/feed_builders.dart';

class FeedView extends ConsumerStatefulWidget {
  const FeedView({super.key, this.initialItemId});
  // 路由透传的初始播放视频 ID：来自 GoRouter `/?initialId=`
  // - 网格点击 → 跳转前 context.go('/?initialId=$id')
  // - 搜索/收藏/演员详情 → 跳转前 context.go('/?initialId=$id')
  // - 跨进程清空：每次新路由都是一次新的"起点"
  final String? initialItemId;

  @override
  ConsumerState<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends ConsumerState<FeedView>
    with AutomaticKeepAliveClientMixin<FeedView> {
  late PageController _pageController;
  int _currentIndex = 0;
  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier<int>(0);

  // 位置计数指示器临时显示：切视频后显示 3 秒自动隐藏（仅非纯净模式）
  Timer? _positionBadgeTimer;
  final ValueNotifier<bool> _positionBadgeVisible = ValueNotifier<bool>(false);

  AppLifecycleListener? _lifecycleListener;

  // 位置就绪标记：只有「恢复跳转完成」或「用户主动翻过页」后才允许
  // 生命周期兜底写盘。防止启动恢复完成前退后台，用默认 index 0
  // 覆盖已持久化的上次位置（P2 修复）。
  bool _feedPositionReady = false;

  // 滚动位置持久化相关（仅网格视图，视频流不持久化）
  final ScrollController _gridScrollController = ScrollController();

  // 页面切换防抖：快速滑动时只在静止后执行预加载和清理
  Timer? _pageChangeDebounce;

  // 播放协调器：抽离自原 feed_view.dart 的播放协调逻辑
  late final PlaybackCoordinator _playbackCoordinator;

  // 视图模型：业务逻辑层
  late final FeedViewModel _viewModel;

  // 保存 listenManual 订阅引用，dispose 时显式 close 避免内存泄漏
  // 修复：ref.listen 只能在 build 中调用，initState 中必须用 ref.listenManual
  ProviderSubscription<ViewMode>? _viewModeSubscription;

  // 防止多次 rebuild 重复触发 initialItemId 处理
  bool _initialItemProcessed = false;

  // 防止多次 rebuild 重复触发首 item 播放初始化
  bool _firstItemInitProcessed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0, viewportFraction: 1.0);
    // 创建播放协调器
    _playbackCoordinator =
        PlaybackCoordinator(ref, onPageIndexReady: _jumpToPageByIndex);
    // 创建视图模型
    _viewModel = FeedViewModel(
      ref,
      _playbackCoordinator,
      onJumpToPage: _animateToPage,
      onJumpToPageInstant: _jumpToPageWhenReady,
      onShowSnackBar: _showSnackBar,
      onOpenFullscreen: _openFullscreenPage,
      onShowLibrarySelector: () =>
          LibrarySelector.show(context, scope: LibraryScope.feed),
      onUpdateHelpVisibility: () {
        if (mounted) setState(() {});
      },
    );
    _viewModel.init();

    // 注册全局键盘监听
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    // 监听视图模式变化：系统栏显隐是 UI 行为，由本视图处理
    // 播放暂停/恢复已委托给 ViewModel → PlaybackCoordinator
    // 修复：使用 listenManual 替代 listen，避免在 initState 中调用 ref.listen 触发断言
    _viewModeSubscription =
        ref.listenManual<ViewMode>(viewModeProvider, (prev, next) {
      if (prev == null) return;
      if (prev == ViewMode.feed && next == ViewMode.grid) {
        _restoreSystemBars();
      } else if (prev == ViewMode.grid && next == ViewMode.feed) {
        _hideSystemBars();
        // 网格 → 视频流：把视频流定位到网格滚动中心的同一个视频
        _jumpToGridAnchorInFeed();
      }
    });

    // 跨设备续播：进入页面时检查其它设备是否存在续播信息
    safeUnawaited(
      _viewModel.checkCloudSyncOnStartup(),
      context: 'FeedView.initState.checkCloudSyncOnStartup',
    );

    // 生命周期兜底：退后台/异常退出前立即保存视频流位置，
    // 避免 onPageChanged 的异步保存未落盘时被强杀导致位置丢失
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive ||
            state == AppLifecycleState.detached) {
          _saveFeedPositionOnBackground();
        }
      },
    );

    // 恢复视频流上次位置：由 postFrame 副作用统一驱动（见 146 行附近），
    // 与「首 item 播放初始化」协调执行，避免先播第一个视频再跳转的竞态（F1）。
    // 不再在 initState 中独立调用，防止与 initialId 跳转/自动播放抢占。

    // 监听网格滚动位置，防抖保存
    _gridScrollController.addListener(_onGridScrollChanged);

    // 沉浸式：进入 feed view 时，若当前是视频流模式则立即隐藏系统栏
    // 不等待首帧后再设置，避免启动时短暂显示状态栏
    if (ref.read(viewModeProvider) == ViewMode.feed) {
      _hideSystemBars();
    }

    // 监听 PageView 滚动状态，用于快速滑动时立即释放非当前页 controller
    // 延迟到首帧后注册：initState 时 PageView 尚未 build，hasClients 必为 false
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.position.isScrollingNotifier
            .addListener(_onScrollingChanged);
      }
    });

    // 从 build 树移出的副作用：initialItemId 跳转 + 位置恢复 + 首 item 播放初始化
    // F1 修复：三者协调执行，先等位置恢复完成，再决定是否初始化首个视频播放，
    // 避免「先播 index 0 再跳到上次位置」的竞态与完播率统计污染。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // 1. 路由透传 initialId 跳转（深层链接优先）
      final initialId = widget.initialItemId;
      if (initialId != null && initialId.isNotEmpty && !_initialItemProcessed) {
        _initialItemProcessed = true;
        _viewModel.waitForInitialItem(initialId);
      }

      // 2. 恢复上次播放位置（内部等待列表加载；grid 模式/深层链接直接跳过）
      await Future<void>.delayed(Duration.zero);
      if (!mounted || _firstItemInitProcessed) return;
      final restored = await _restoreFeedVideoIndex();
      if (!mounted || _firstItemInitProcessed) return;

      // 2.5 grid 模式：恢复网格滚动位置（不设置 playbackState，
      //     避免在 offstage PageView 上激活播放器，F4）
      if (ref.read(viewModeProvider) == ViewMode.grid) {
        safeUnawaited(
          _restoreGridPosition(),
          context: 'FeedView._restoreGridPosition',
        );
        return;
      }

      // 3. 首 item 播放初始化：仅当未恢复位置时才播放列表第一个视频
      //    - 已恢复：jumpToPage 触发 onPageChanged → syncCurrentPlaying 完成播放
      //    - grid 模式：不自动播放（避免后台激活播放器，F4）
      if (ref.read(viewModeProvider) != ViewMode.feed) return;
      final videoState = ref.read(videoListProvider);
      final playbackState = ref.read(playbackStateProvider);
      if (!restored &&
          videoState.items.isNotEmpty &&
          playbackState.id == null) {
        _firstItemInitProcessed = true;
        final firstItem = videoState.items.first;
        ref
            .read(playbackStateProvider.notifier)
            .setPlaying(firstItem.id, firstItem);
      }
    });
  }

  /// 切视频后临时显示位置计数 3 秒，随后自动隐藏（仅非纯净模式）。
  /// 纯净模式（沉浸式播放）不显示位置计数，避免遮挡画面。
  void _showPositionBadgeTemporarily() {
    if (!mounted) return;
    if (ref.read(isAutoPlayProvider)) return;
    _positionBadgeVisible.value = true;
    _positionBadgeTimer?.cancel();
    _positionBadgeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _positionBadgeVisible.value = false;
    });
  }

  @override
  void dispose() {
    try {
      if (_pageController.hasClients) {
        _pageController.position.isScrollingNotifier
            .removeListener(_onScrollingChanged);
      }
    } catch (_) {
      // dispose 时 position 可能已被 Flutter 清理，忽略错误
    }
    _positionBadgeTimer?.cancel();
    _positionBadgeVisible.dispose();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _lifecycleListener?.dispose();
    _pageChangeDebounce?.cancel();
    _gridLoadMoreDebounce?.cancel();
    _currentIndexNotifier.dispose();
    _pageController.dispose();
    _gridScrollController.removeListener(_onGridScrollChanged);
    _gridScrollController.dispose();
    _viewModel.dispose();
    // 显式取消 listenManual 订阅，避免内存泄漏
    _viewModeSubscription?.close();
    safeUnawaited(
      _playbackCoordinator.disposeAllPreloads(),
      context: 'FeedView.dispose.disposeAllPreloads',
    );
    _playbackCoordinator.detach();
    _restoreSystemBars();
    super.dispose();
  }

  // ==================== 跳页辅助（UI 层职责，依赖 PageController.hasClients） ====================

  /// 帧轮询：等到 PageController 已 attach 后执行 jumpToPage

  /// 异步版跳页：等待 PageController attach 后 jumpToPage，返回真实跳转结果。
  /// 位置恢复等需要「确认跳转生效」的场景使用——跳转失败返回 false，
  /// 调用方可回退到默认行为（如播放列表第一个视频），避免假成功导致黑屏。

  /// 协调器跳页回调：返回 true 表示已成功跳页

  /// 带动画跳页（键盘快捷键、浏览模式切换等场景使用）

  // 恢复视频流上次位置
  //
  // 返回 true 表示已恢复（或已请求跳转）；false 表示无需/无法恢复，
  // 调用方据此决定是否回退到「播放列表第一个视频」。
  //
  // F2：带 initialId 深层链接进入时跳过（避免与 waitForInitialItem 抢跳）。
  // F3：优先用保存的视频 id 精确定位，换库/重排后找不到则不恢复。
  // F4：grid 模式下跳过（IndexedStack 中 PageView 仍在树，跳转会后台激活播放器）。
  // F5：跳转复用 _jumpToPageWhenReady（hasClients 重试），不裸调 jumpToPage。

  // PageView 滚动状态变化回调：快速滑动时立即释放非当前页 controller

  // ==================== 沉浸式系统栏控制（纯 UI 行为） ====================

  /// 隐藏系统栏，进入全屏沉浸式模式
  /// - 使用 immersiveSticky：用户从边缘滑入时临时显示，几秒后自动隐藏
  /// - 配合 Scaffold.extendBody 确保视频内容延伸到系统栏区域

  /// 恢复系统栏显示（切换到网格模式或离开页面时）

  // ==================== 滚动位置持久化 ====================

  /// 退后台兜底：立即保存当前位置（不等待异步写盘）
  ///
  /// - feed 模式：保存视频流 index+itemId（受 _feedPositionReady 保护，
  ///   恢复完成/主动翻页前不写，避免覆盖上次位置——P2 修复）
  /// - grid 模式：保存网格滚动 offset（0 写入无害，恢复端 >0 才生效）

  /// 恢复网格滚动位置（仅 grid 模式启动时调用）
  ///
  /// 分两阶段：
  /// 1. 等网格 attach 且首屏渲染完成（maxScrollExtent>0）
  /// 2. 目标 offset 超出当前已加载高度时逐级 loadMore，
  ///    直到 maxScrollExtent 达到目标或没有更多数据
  /// 3. 最终按 clamp 后的 offset jumpTo

  /// 立即把当前网格滚动 offset 写入持久化（退后台兜底）

  // 计算网格滚动中心对应的视频 id，供 grid → feed 切换时定位

  // grid → feed 切换：若网格中心视频在视频流列表中，则跳转到该视频
  //
  // 同源设计：网格与视频流是同一数据源（网格仅是不同的展示形态），
  // 网格分页/搜索后 gridItems 会与 feed items 暂时不同集合——此时先把
  // items 同步为 gridItems（复用 setItemsFromGrid），保证切换后视频流
  // 显示的就是网格里看到的那批视频，且定位到网格中心的同一个视频。

  // 网格分页：滚动接近底部（剩余不足 3 屏）时自动加载更多
  // 修复：此前网格只保存滚动位置、从不触发 loadMore，多库模式网格永远只有
  //       首屏数据（与视频流同源同量），海报墙无法滚到更多内容。
  Timer? _gridLoadMoreDebounce;

  // ==================== 键盘快捷键（委托给 ViewModel） ====================

  // ==================== SnackBar（UI 层职责） ====================

  // ==================== 全屏页（UI 层职责，依赖 Navigator） ====================

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
      extendBody: true,
      extendBodyBehindAppBar: true,
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
              left: 0,
              right: 0,
              top: 0,
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

          // 当前位置指示：放在顶部工具栏下沿右侧，避免与底部导航栏重叠。
          // 跟随顶部工具栏一起自动隐藏：单击屏幕切换控制条时同步显隐，
          // 避免位置计数常驻遮挡视频画面。
          // 非纯净模式下切视频后临时显示 3 秒自动隐藏（见 _showPositionBadgeTemporarily）。
          if (viewMode == ViewMode.feed && videoState.items.isNotEmpty)
            Positioned(
              right: 12,
              top: SafeInsets.topOf(context) + kAppToolbarHeight + 8,
              child: ValueListenableBuilder<bool>(
                valueListenable: _positionBadgeVisible,
                builder: (context, badgeVisible, _) {
                  final show = toolbarVisible || badgeVisible;
                  return IgnorePointer(
                    ignoring: !show,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: kToolbarAnimMs),
                      curve: Curves.easeOut,
                      opacity: show ? 1.0 : 0.0,
                      child: ValueListenableBuilder<int>(
                        valueListenable: _currentIndexNotifier,
                        builder: (context, idx, _) {
                          final total = videoState.items.length;
                          final pos = (idx + 1).clamp(1, total);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: scheme.surface.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '$pos / $total',
                              style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
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
                onTap: () =>
                    ref.read(feedHelpVisibleProvider.notifier).state = false,
                child: Container(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.54),
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

  // 视频流模式顶部栏

  // 顶部栏统一按钮

  // 构建网格视图

  // 构建视频流 PageView
}
