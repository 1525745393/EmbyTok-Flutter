// 视频流页面：竖向全屏滑动 + 顶部工具栏 + 视图切换 + 分页加载

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/app_preferences.dart' show ViewMode;
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
    super.dispose();
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
      backgroundColor: Colors.black,
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

  // 构建视频流 PageView
  Widget _buildVideoPageView(VideoListState videoState, List<MediaItem> displayItems) {
    // 加载中（首次加载）
    if (displayItems.isEmpty && videoState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE91E63)),
      );
    }

    // 错误状态
    if (displayItems.isEmpty && videoState.error != null) {
      return _buildErrorState(videoState.error!);
    }

    // 空状态（无过滤结果）
    if (displayItems.isEmpty) {
      return Center(
        child: Text(
          videoState.items.isEmpty
              ? '暂无视频，请选择其他媒体库'
              : '没有符合筛选条件的视频',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    // 正常：竖向 PageView
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: displayItems.length + (videoState.hasMore ? 1 : 0),
      onPageChanged: (index) {
        // 滚动到倒数第 2 项时触发分页加载
        // 注意：这里仍使用原始列表长度判断，因为分页加载的是原始列表
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
            child: CircularProgressIndicator(color: Color(0xFFE91E63)),
          );
        }
        final item = displayItems[index];
        return VideoPageItem(item: item);
      },
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
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              error,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final libId = ref.read(selectedLibraryIdProvider);
                ref.read(videoListProvider.notifier).refresh(libraryId: libId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

}
