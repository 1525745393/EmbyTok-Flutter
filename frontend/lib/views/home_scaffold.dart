// 主骨架页：底部导航栏 + 页面切换
// 底部导航栏4个标签：首页、收藏、演员、设置
// 搜索和历史通过 FeedView 顶部操作栏的图标按钮访问（覆盖层页面）
//
// 系统返回键拦截：HomeScaffold 的 PopScope 拦截系统返回键。
// - 在覆盖层页面（搜索/历史）上按返回键 → 回到 Feed
// - 在非 Feed Tab 上按返回键 → 回到 Feed Tab
// - 在 Feed Tab 上按返回键 → 弹出退出确认对话框
//
// 路由透传：HomeScaffold 接受 initialItemId（来自 GoRouter `?initialId=` 参数），
// 透传给 FeedView 作为"目标播放项"。
//
// App 生命周期处理：HomeScaffold 混入 WidgetsBindingObserver，
// 当 App 切到后台时（resumed → inactive/paused/hidden）暂停 Feed 中的视频，
// 回到前台时（paused/inactive → resumed）仅当 Feed 可见 + 用户原本想播放
// 才自动恢复。避免后台继续消耗流量 / 电池 / 发热，同时尊重用户主动暂停意图。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../providers/providers.dart';
import '../services/video_pool_service.dart';
import '../utils/constants.dart';
import 'feed_view.dart';
import 'search_view.dart';
import 'favorites_view.dart';
import 'history_view.dart';
import 'settings_view.dart';
import 'actors_view.dart';

// 主骨架：包含底部导航的入口页
class HomeScaffold extends ConsumerStatefulWidget {
  // 从路由 ?initialId= 透传过来的初始播放视频 ID
  // HomeScaffold 不消费此参数，仅透传给 FeedView
  final String? initialItemId;

  const HomeScaffold({super.key, this.initialItemId});

  @override
  ConsumerState<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends ConsumerState<HomeScaffold>
    with WidgetsBindingObserver {
  // Feed Tab 当前是否处于"用户可见 + 未被覆盖层遮挡"状态
  //
  // 背景：HomeScaffold 用 IndexedStack 同时保持 Feed / Favorites / Actors / Settings
  // 四个 Tab 视图存活，切换 Tab 时不会触发 deactivate/activate。
  // Feed 中的 VideoPlayerController 一直是同一个实例，即使切到其他 Tab
  // 也会继续后台播放。
  //
  // 修复：在 _HomeScaffoldState 中监听 pageNavigationProvider 变化，
  // 当 Feed 刚被隐藏时主动 controller.pause()，重新可见时如果用户
  // 原本"想播放"（isPlayingProvider=true）则 controller.play()，
  // 既保证切到其他 Tab 时视频不会继续播放/消耗流量/发热，也保留
  // 用户的"主动暂停"意图（切回不会自动恢复）。
  //
  // 同样的逻辑也用在 App 生命周期变化上（WidgetsBindingObserver）：
  // - 切后台（resumed → inactive/paused）→ 暂停（无论 Feed 可见否）
  // - 回前台（paused/inactive → resumed）→ 仅当 Feed 可见 + 想播 才恢复
  // 决策逻辑统一在 [applyLifecyclePlaybackChange] 顶层纯函数中。

  // 上一次的 AppLifecycleState：用于在 didChangeAppLifecycleState
  // 中判断"刚离开前台"或"刚回到前台"
  AppLifecycleState? _lastLifecycleState;

  // 保存 listenManual 返回的订阅引用，dispose 时显式 close 避免内存泄漏
  ProviderSubscription<PageNavigationState>? _pageNavSubscription;

  @override
  void initState() {
    super.initState();
    // 记录初始 lifecycle（通常是 resumed）
    _lastLifecycleState = WidgetsBinding.instance.lifecycleState;
    // 注册 WidgetsBindingObserver 以监听 App 前后台切换
    WidgetsBinding.instance.addObserver(this);
    // 延迟到第一帧后注册 listen，避免在 build 期间触发 state 修改
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pageNavSubscription = ref.listenManual<PageNavigationState>(
        pageNavigationProvider,
        _onPageNavChanged,
      );
    });
  }

  @override
  void dispose() {
    // 显式取消订阅，避免内存泄漏
    _pageNavSubscription?.close();
    // 注销 observer，避免内存泄漏
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;

    final prev = _lastLifecycleState;
    _lastLifecycleState = state;
    if (prev == null) return;

    final wasForeground = prev == AppLifecycleState.resumed;
    final isForeground = state == AppLifecycleState.resumed;

    final controller = ref.read(currentVideoControllerProvider);
    final userWantsToPlay = ref.read(isPlayingProvider);
    // 仅当 Feed 当前可见时才在回前台时恢复播放
    final navState = ref.read(pageNavigationProvider);

    // 切后台时清理预加载池，释放网络和解码资源
    if (wasForeground && !isForeground) {
      try {
        unawaited(ref.read(videoPoolProvider).disposeAll());
      } catch (_) {}
    }

    applyLifecyclePlaybackChange(
      prev: prev,
      next: state,
      isFeedVisible: navState.isFeedVisible,
      controller: controller,
      userWantsToPlay: userWantsToPlay,
    );
  }

  /// 监听页面导航变化，处理 Feed Tab 可见性切换时的视频暂停/恢复
  void _onPageNavChanged(
    PageNavigationState? prev,
    PageNavigationState next,
  ) {
    if (prev == null) return;
    if (!mounted) return;

    final controller = ref.read(currentVideoControllerProvider);
    final userWantsToPlay = ref.read(isPlayingProvider);
    applyFeedVisibilityChange(
      prev: prev,
      next: next,
      controller: controller,
      userWantsToPlay: userWantsToPlay,
    );
  }
  @override
  Widget build(BuildContext context) {
    // 监听页面导航状态
    final pageNavState = ref.watch(pageNavigationProvider);
    // 监听工具栏可见性：用于驱动底部导航栏的折叠动画
    final toolbarVisible = ref.watch(toolbarVisibilityProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final scheme = Theme.of(context).colorScheme;

    // 当前显示的页面索引
    // 覆盖层页面（搜索/历史）使用独立索引，底部导航栏保持原位
    final currentIndex = pageNavState.currentIndex;

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;

        // 如果在覆盖层页面（搜索/历史），返回到 Feed
        if (pageNavState.isOverlayPage) {
          ref.read(pageNavigationNotifierProvider).backToFeed();
          return;
        }

        // 在 Feed 之外的 Tab 上按返回键，先回到 Feed
        if (currentIndex != 0 && currentIndex != PageIndices.search && currentIndex != PageIndices.history) {
          ref.read(pageNavigationNotifierProvider).goToPage(0);
          return;
        }

        // 在 Feed 上按返回键，弹出退出确认
        final result = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: scheme.surface,
            title: const Text('退出应用？'),
            content: const Text('确定要退出吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text('取消', style: TextStyle(color: scheme.onSurface)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                ),
                child: const Text('退出'),
              ),
            ],
          ),
        );

        // 对话框返回后检查context是否仍然有效
        if (!context.mounted) return;

        if (result == true) {
          // 主动释放视频控制器池，避免 SystemNavigator.pop() 回收时序与
          // FeedView.dispose() 中的批量 dispose 叠加导致 OOM
          try {
            await ref.read(videoPoolProvider).disposeAll();
          } catch (_) {}
          // 让出一帧给 GC 和 native texture 回收
          await Future.delayed(Duration.zero);
          if (context.mounted) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: Stack(
          children: [
            // 页面内容
            Positioned.fill(
              child: IndexedStack(
                // 覆盖层页面显示在 Feed 之上，不切换底部导航
                index: pageNavState.isOverlayPage ? 0 : currentIndex,
                children: [
                  // 索引 0: Feed 页面（全屏展示）
                  // 路由透传：把 initialItemId 传给 FeedView 用于 jumpToPage
                  FeedView(initialItemId: widget.initialItemId),
                  // 索引 1: 收藏页面（预留底部导航栏高度）
                  Padding(
                    padding: EdgeInsets.only(bottom: kBottomNavHeight + bottomPadding),
                    child: const FavoritesView(),
                  ),
                  // 索引 2: 演员页面（预留底部导航栏高度）
                  Padding(
                    padding: EdgeInsets.only(bottom: kBottomNavHeight + bottomPadding),
                    child: const ActorsView(),
                  ),
                  // 索引 3: 设置页面（预留底部导航栏高度）
                  Padding(
                    padding: EdgeInsets.only(bottom: kBottomNavHeight + bottomPadding),
                    child: const SettingsView(),
                  ),
                ],
              ),
            ),
            // 覆盖层页面：搜索和历史（全屏覆盖，不预留底部导航栏空间）
// 使用 useScaffold: false 避免 Scaffold 嵌套和 Navigator.pop 冲突
            if (pageNavState.isOverlayPage)
              Positioned.fill(
                child: IndexedStack(
                  // search=4, history=5，映射到覆盖层索引 0/1
                  index: currentIndex == 4 ? 0 : 1,
                  children: const [
                    SearchView(useScaffold: false),
                    HistoryView(useScaffold: false),
                  ],
                ),
              ),
            // 底部导航栏：只在非覆盖层页面时显示
            if (!pageNavState.isOverlayPage)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: kToolbarAnimMs),
                  curve: Curves.easeOut,
                  height: toolbarVisible ? kBottomNavHeight + bottomPadding : 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: kToolbarAnimMs),
                    opacity: toolbarVisible ? 1.0 : 0.0,
                    child: ClipRect(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Container(
                          height: kBottomNavHeight + bottomPadding,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                scheme.surface,
                                scheme.surface.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.only(bottom: bottomPadding),
                          child: NavigationBar(
                              selectedIndex: currentIndex,
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              indicatorColor: scheme.primary.withValues(alpha: 0.15),
                              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                              height: kBottomNavHeight,
                              onDestinationSelected: (index) {
                                ref.read(pageNavigationNotifierProvider).goToPage(index);
                              },
                              destinations: [
                                NavigationDestination(
                                  icon: Icon(Icons.home_outlined, color: scheme.onSurfaceVariant),
                                  selectedIcon: Icon(Icons.home, color: scheme.primary),
                                  label: '首页',
                                ),
                                NavigationDestination(
                                  icon: Icon(Icons.favorite_border, color: scheme.onSurfaceVariant),
                                  selectedIcon: Icon(Icons.favorite, color: scheme.primary),
                                  label: '收藏',
                                ),
                                NavigationDestination(
                                  icon: Icon(Icons.person_outline, color: scheme.onSurfaceVariant),
                                  selectedIcon: Icon(Icons.person, color: scheme.primary),
                                  label: '演员',
                                ),
                                NavigationDestination(
                                  icon: Icon(Icons.settings_outlined, color: scheme.onSurfaceVariant),
                                  selectedIcon: Icon(Icons.settings, color: scheme.primary),
                                  label: '设置',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 底层工具：仅在 controller 正在播放时 pause（防止重复 pause）
void _pauseIfPlaying(VideoPlayerController? controller) {
  if (controller == null) return;
  if (!controller.value.isInitialized) return;
  if (controller.value.isPlaying) {
    controller.pause();
  }
}

/// 底层工具：仅在 userWantsToPlay=true 且 controller 已暂停时 play
///
/// 不覆盖用户的"主动暂停"意图——只有当用户原本就想播放时才恢复。
void _playIfWantedAndPaused(
  VideoPlayerController? controller,
  bool userWantsToPlay,
) {
  if (controller == null) return;
  if (!controller.value.isInitialized) return;
  if (userWantsToPlay && !controller.value.isPlaying) {
    controller.play();
  }
}

/// 处理 Feed Tab 可见性切换时的视频播放控制（纯函数，便于单元测试）
///
/// 设计原则：
/// 1. Feed 刚被隐藏（切到 Favorites/Actors/Settings）→ 主动 pause 防止后台播放
/// 2. Feed 刚重新可见（切回首页）→ 仅当用户"原本想播放"（isPlayingProvider=true）才 play
///    - 避免覆盖用户主动暂停的意图
/// 3. 搜索/历史覆盖层（isOverlayPage=true）→ isFeedVisible 仍为 true，
///    不会触发 pause，让用户在弹层中浏览时视频继续播放
///
/// 入参：
/// - [prev] / [next]：前后两次导航状态
/// - [controller]：当前 VideoPlayerController（可能为 null）
/// - [userWantsToPlay]：用户播放意图（isPlayingProvider），用于切回 Feed 时决定是否恢复
void applyFeedVisibilityChange({
  required PageNavigationState prev,
  required PageNavigationState next,
  required VideoPlayerController? controller,
  required bool userWantsToPlay,
}) {
  // 1. 可见性没有变化 → 不处理
  if (prev.isFeedVisible == next.isFeedVisible) return;

  if (!next.isFeedVisible) {
    // Feed 刚被隐藏（切到其他 Tab）：暂停
    _pauseIfPlaying(controller);
  } else {
    // Feed 刚重新可见：恢复（仅当用户原本"想播放"）
    _playIfWantedAndPaused(controller, userWantsToPlay);
  }
}

/// 处理 App 生命周期变化的视频播放控制（纯函数，便于单元测试）
///
/// 设计原则：
/// 1. App 切到后台（resumed → inactive/paused/hidden）→ 主动 pause
///    - 无论 Feed 是否可见都暂停（节省流量 / 电池 / 发热）
/// 2. App 回到前台（inactive/paused → resumed）→ 仅当
///    - Feed 可见（isFeedVisible=true）
///    - 用户原本想播放（userWantsToPlay=true）
///    才自动恢复播放
/// 3. inactive 内部状态变化（如 resumed → inactive → paused）只在
///    "刚离开前台" / "刚回到前台" 两个边界触发，中间过渡态 noop
///
/// 入参：
/// - [prev] / [next]：前后两次 AppLifecycleState（prev 可能为 null 表示首次）
/// - [isFeedVisible]：回前台时 Feed Tab 是否可见（决定是否恢复播放）
/// - [controller]：当前 VideoPlayerController（可能为 null）
/// - [userWantsToPlay]：用户播放意图
void applyLifecyclePlaybackChange({
  required AppLifecycleState? prev,
  required AppLifecycleState next,
  required bool isFeedVisible,
  required VideoPlayerController? controller,
  required bool userWantsToPlay,
}) {
  // 首次回调（prev 为 null）：不做处理
  if (prev == null) return;

  final wasForeground = prev == AppLifecycleState.resumed;
  final isForeground = next == AppLifecycleState.resumed;

  if (wasForeground && !isForeground) {
    // 刚离开前台：无论 Feed 是否可见都暂停（节省资源）
    _pauseIfPlaying(controller);
  } else if (!wasForeground && isForeground) {
    // 刚回到前台：仅当 Feed 可见 + 用户原本想播放 才恢复
    if (isFeedVisible) {
      _playIfWantedAndPaused(controller, userWantsToPlay);
    }
  }
  // 中间过渡态（resumed → inactive → paused 或反向）由边界触发，
  // 内部 inactive 状态不重复调用 pause/play。
}
