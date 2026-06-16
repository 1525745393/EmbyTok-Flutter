// 视频流页面：竖向全屏滑动 + 顶部工具栏 + 视图切换 + 分页加载
// 新增：视频切换渐入动画、智能预加载、首次滑动引导

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/app_preferences.dart' show ViewMode;
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../widgets/top_tool_bar.dart';
import '../widgets/video_page_item.dart';
import 'video_grid_view.dart';

// 视频流页面：ConsumerStatefulWidget 用于分页加载 & 状态保持
class FeedView extends ConsumerStatefulWidget {
  const FeedView({super.key});

  @override
  ConsumerState<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends ConsumerState<FeedView>
    with AutomaticKeepAliveClientMixin<FeedView> {
  late PageController _pageController;
  int _swipeCount = 0;
  bool _guideShown = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 1.0,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    ref.read(preloadProvider.notifier).clear();
    super.dispose();
  }

  /// 切换到新页面时：更新索引、触发下一条预取、更新引导状态
  void _onPageSwitched(int index, List<MediaItem> items) {
    setState(() {
      _swipeCount++;
    });
    ref.read(currentPlayingIndexProvider.notifier).state = index;
    // 触发下一条视频预加载（异步，不需要 await）
    ref.read(preloadProvider.notifier).preloadNext(
      items,
      index,
      embyServerUrl: ref.read(authProvider).embyServerUrl,
      token: ref.read(authProvider).token,
    );
    // 计数达到引导阈值时，淡出引导层
    if (!_guideShown && _swipeCount >= kGuideSwipeThreshold) {
      setState(() => _guideShown = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 监听视图模式
    final viewMode = ref.watch(viewModeProvider);

    // 监听 currentIndexProvider 变化（从网格视图跳转时触发）
    ref.listen<int>(currentIndexProvider, (previous, next) {
      // 只有在视频流模式下才滚动
      if (viewMode == ViewMode.feed && _pageController.hasClients) {
        _pageController.jumpToPage(next);
      }
    });

    // 视频列表状态（原始列表，用于分页和加载状态）
    final videoState = ref.watch(videoListProvider);

    // 过滤后的视频列表（用于显示）
    final filteredItems = ref.watch(filteredVideoListProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // 根据视图模式切换显示
          if (viewMode == ViewMode.grid)
            // 网格视图
            const VideoGridView()
          else
            // 视频流视图
            _buildVideoPageView(videoState, filteredItems),

          // 顶部工具栏
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: TopToolBar(
                onFullscreenPressed: (_) => _toggleFullscreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 全屏切换
  void _toggleFullscreen() {
    // 获取当前全屏状态
    final isFullscreen = ref.read(isFullscreenProvider);
    if (isFullscreen) {
      // 退出全屏
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      ref.read(isFullscreenProvider.notifier).state = false;
    } else {
      // 进入全屏
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      ref.read(isFullscreenProvider.notifier).state = true;
    }
  }

  // 构建视频流 PageView：接入预加载缓存、滑动引导、切换渐入
  Widget _buildVideoPageView(VideoListState videoState, List<MediaItem> displayItems) {
    // 加载中（首次加载）
    if (displayItems.isEmpty && videoState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryPink),
      );
    }

    // 错误状态
    if (displayItems.isEmpty && videoState.error != null) {
      return _buildErrorState(videoState.error!);
    }

    // 空状态（无过滤结果）
    if (displayItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_outlined, size: 80, color: textPlaceholder),
            const SizedBox(height: 16),
            Text(
              videoState.items.isEmpty ? '暂无视频，请选择其他媒体库' : '没有符合筛选条件的视频',
              style: const TextStyle(color: textSecondary, fontSize: 16),
            ),
            if (videoState.items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ElevatedButton(
                  onPressed: () {
                    final libId = ref.read(selectedLibraryIdProvider);
                    ref.read(videoListProvider.notifier).refresh(libraryId: libId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    foregroundColor: textPrimary,
                  ),
                  child: const Text('刷新'),
                ),
              ),
          ],
        ),
      );
    }

    // 正常：竖向 PageView + 滑动引导
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: displayItems.length + (videoState.hasMore ? 1 : 0),
          onPageChanged: (index) {
            if (index < displayItems.length) {
              _onPageSwitched(index, displayItems);
            }
            // 滚动到倒数第 2 项时触发分页加载
            if (videoState.hasMore &&
                index >= displayItems.length - 2 &&
                !videoState.isLoading) {
              ref.read(videoListProvider.notifier).loadMore();
            }
          },
          itemBuilder: (context, index) {
            // 末尾加载指示器
            if (index >= displayItems.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: primaryPink),
                ),
              );
            }
            final item = displayItems[index];
            // 尝试从预加载缓存中取出已初始化的 controller
            final preloaded = ref.read(preloadProvider.notifier).consume(item.id);
            return VideoPageItem(
              item: item,
              preloadedController: preloaded,
              key: ValueKey('feed-${item.id}'),
            );
          },
        ),
        // 首次使用引导：向上滑动箭头
        if (!_guideShown && _swipeCount < kGuideSwipeThreshold)
          Positioned(
            left: 0,
            right: 0,
            bottom: 80,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: kGuideFadeMs),
              opacity: _swipeCount == 0 ? 1.0 : 0.4,
              child: const Column(
                children: [
                  Icon(Icons.keyboard_arrow_up, color: textPrimary, size: 40),
                  SizedBox(height: 4),
                  Text(
                    '上滑看下一条',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // 错误提示 UI
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: errorColor, size: 48),
            const SizedBox(height: 12),
            Text(
              error,
              style: const TextStyle(color: textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final libId = ref.read(selectedLibraryIdProvider);
                ref.read(videoListProvider.notifier).refresh(libraryId: libId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPink,
                foregroundColor: textPrimary,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

}
