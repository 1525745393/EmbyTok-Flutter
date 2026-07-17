// 视频网格视图页面：GridView.builder 实现自适应网格布局
// - 竖屏：2列 / 横屏：4列
// - 点击卡片跳转到视频流对应位置

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/app_preferences.dart' show ViewMode;
import '../utils/constants.dart';
import '../widgets/library_selector.dart';
import '../widgets/video_grid_card.dart';

// 视频网格视图
class VideoGridView extends ConsumerStatefulWidget {
  const VideoGridView({super.key});

  @override
  ConsumerState<VideoGridView> createState() => _VideoGridViewState();
}

class _VideoGridViewState extends ConsumerState<VideoGridView> {
  @override
  void initState() {
    super.initState();
    // 初始化时加载视频列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVideos();
    });
  }

  // 加载视频列表
  Future<void> _loadVideos() async {
    final selectedIds = ref.read(selectedLibraryIdsProvider);
    if (selectedIds.isNotEmpty) {
      await ref.read(videoListProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 视频列表状态（原始列表）
    final scheme = Theme.of(context).colorScheme;
    final videoState = ref.watch(videoListProvider);
    // 过滤后的视频列表（用于显示）
    final displayItems = ref.watch(filteredVideoListProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Text(
          '视频列表',
          style: TextStyle(color: scheme.onSurface),
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(Icons.library_books, color: scheme.onSurface),
            onPressed: () => LibrarySelector.show(context),
            tooltip: '媒体库',
          ),
        ],
      ),
      body: _buildBody(videoState, displayItems),
    );
  }

  // 根据状态构建内容
  Widget _buildBody(VideoListState videoState, List<MediaItem> displayItems) {
    final scheme = Theme.of(context).colorScheme;
    // 加载中（首次加载且无数据）
    if (displayItems.isEmpty && videoState.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: scheme.primary),
      );
    }

    // 错误状态
    final error = videoState.error;
    if (displayItems.isEmpty && error != null) {
      return _buildErrorState(error.message);
    }

    // 空状态（无过滤结果）
    if (displayItems.isEmpty) {
      return Center(
        child: Text(
          videoState.items.isEmpty
              ? '暂无视频，请选择其他媒体库'
              : '没有符合筛选条件的视频',
          style: TextStyle(
              color: scheme.onSurface.withOpacity(0.6), fontSize: 16),
        ),
      );
    }

    // 正常：网格视图
    return _buildGridView(videoState, displayItems);
  }

  // 构建网格视图
  Widget _buildGridView(VideoListState videoState, List<MediaItem> displayItems) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据屏幕方向计算列数：竖屏2列，横屏4列
        final isPortrait = constraints.maxHeight > constraints.maxWidth;
        final crossAxisCount = isPortrait ? 2 : 4;

        // 计算卡片宽高比（竖屏接近 9:16，横屏接近 16:9）
        final childAspectRatio = isPortrait ? 9 / 16 : 16 / 9;

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // 滚动到底部时加载更多（仍基于原始列表）
            if (notification is ScrollEndNotification &&
                notification.metrics.extentAfter < 200 &&
                videoState.hasMore &&
                !videoState.isLoading) {
              ref.read(videoListProvider.notifier).loadMore();
            }
            return false;
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: displayItems.length + (videoState.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              // 末尾加载指示器
              if (index >= displayItems.length) {
                final scheme = Theme.of(context).colorScheme;
                return Center(
                  child: CircularProgressIndicator(color: scheme.primary),
                );
              }

              final item = displayItems[index];
              return VideoGridCard(
                key: Key(item.id),
                item: item,
                onTap: () => _navigateToVideo(item, index),
              );
            },
          ),
        );
      },
    );
  }

  // 错误状态 UI
  Widget _buildErrorState(String error) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: scheme.error, size: 48),
            const SizedBox(height: 12),
            Text(
              error,
              style: TextStyle(
                  color: scheme.onSurface.withOpacity(0.7), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(videoListProvider.notifier).refresh();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  // 导航到视频流中的对应位置
  // 路由 + initialId 透传：跳转由路由层处理，feed_view 通过 widget.initialItemId 接收
  void _navigateToVideo(MediaItem item, int index) {
    // 切换到视频流模式
    ref.read(viewModeProvider.notifier).setMode(ViewMode.feed);
    // 路由透传：把目标 itemId 编码到 query string
    context.go('/?initialId=${Uri.encodeComponent(item.id)}');
  }
}
