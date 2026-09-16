// 视频网格视图页面：GridView.builder 实现自适应网格布局
// - 竖屏：2列 / 横屏：4列
// - 点击卡片跳转到视频流对应位置

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/app_preferences.dart' show ViewMode;
import '../utils/playback_position_memory.dart';
import '../widgets/resume_play_banner.dart';
import '../widgets/video/video_grid_card.dart';

// 视频网格视图
class VideoGridView extends ConsumerStatefulWidget {
  const VideoGridView({super.key});

  @override
  ConsumerState<VideoGridView> createState() => _VideoGridViewState();
}

class _VideoGridViewState extends ConsumerState<VideoGridView> {
  /// 本列表上次观看的视频 id（播放页位置记忆标记，feed 源）
  String? _lastWatchedId;

  /// 网格滚动控制器（用于定位到上次观看的视频）
  final ScrollController _gridController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 初始化时加载视频列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVideos();
    });
  }

  @override
  void dispose() {
    _gridController.dispose();
    super.dispose();
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

    // 异步读取「上次看到」标记：从视频流返回网格时标记刚看的视频
    if (videoState.items.isNotEmpty) {
      _scheduleLoadLastWatched(videoState.items, displayItems);
    }

    // 监听媒体库选择变化：用户切换媒体库后自动刷新视频列表
    ref.listen(selectedLibraryIdsProvider, (prev, next) {
      if (prev != next && next.isNotEmpty) {
        _loadVideos();
      }
    });

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Text(
          '视频列表',
          style: TextStyle(color: scheme.onSurface),
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      body: _buildBody(videoState, displayItems),
    );
  }

  void _scheduleLoadLastWatched(
      List<MediaItem> allItems, List<MediaItem> displayItems) {
    // 位置记忆签名 = 播放页列表首 item id（feed 视频流为全量列表）
    final firstId = allItems.first.id;
    Future.microtask(() async {
      final id = await PlaybackPositionMemory.lastWatchedItemId(
        source: 'feed',
        listSignature: firstId,
      );
      if (!mounted) return;
      if (id != _lastWatchedId) {
        setState(() => _lastWatchedId = id);
      }
      // 定位到上次观看的视频（仅在显示列表中可见时）
      if (id != null && displayItems.any((i) => i.id == id)) {
        _scrollToLastWatched(displayItems, id);
      }
    });
  }

  /// 网格滚动定位：把上次观看的视频滚动到视口内（估算偏移粗定位），
  /// 便于用户一眼看到角标。若目标已在视口内则不打扰。
  void _scrollToLastWatched(List<MediaItem> displayItems, String id) {
    final index = displayItems.indexWhere((i) => i.id == id);
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_gridController.hasClients) return;
      final position = _gridController.position;
      // 与 _buildGridView 的列数/比例逻辑保持一致
      final width = position.viewportDimension;
      final crossAxisCount =
          width < 400 ? 2 : (width < 700 ? 3 : (width < 1000 ? 4 : 5));
      final aspectRatio = crossAxisCount <= 2
          ? 9 / 16
          : (crossAxisCount <= 4 ? 3 / 4 : 16 / 9);
      const spacing = 8.0;
      final cellWidth =
          (width - spacing * 2 - spacing * (crossAxisCount - 1)) /
              crossAxisCount;
      final cellHeight = cellWidth / aspectRatio;
      final row = index ~/ crossAxisCount;
      // 顶部 padding 8，首行起点即 offset 8
      final target = row * (cellHeight + spacing) + 8;

      final viewport = position.viewportDimension;
      final current = position.pixels;
      final needsScroll =
          target < current || target > current + viewport - cellHeight;
      if (needsScroll) {
        _gridController.animateTo(
          target.clamp(0.0, position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
      // 区分两种空状态：
      // 1. 未配置媒体库（items 为空）→ 显示"选择媒体库"按钮引导
      // 2. 筛选无结果（items 非空但 displayItems 为空）→ 仅文字提示
      final isLibraryEmpty = videoState.items.isEmpty;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isLibraryEmpty ? '暂无视频，请在设置中选择媒体库' : '没有符合筛选条件的视频',
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.6), fontSize: 16),
            ),
          ],
        ),
      );
    }

    // 正常：网格视图
    return _buildGridView(videoState, displayItems);
  }

  // 构建网格视图
  Widget _buildGridView(
      VideoListState videoState, List<MediaItem> displayItems) {
    // 顶部「上次看到」续播横幅
    final lastWatchedItem = _lastWatchedItemOf(displayItems);
    return Column(
      children: [
        if (lastWatchedItem != null)
          ResumePlayBanner(
            title: lastWatchedItem.title,
            onTap: () => _navigateToVideo(
                lastWatchedItem,
                displayItems.indexWhere((i) => i.id == lastWatchedItem.id)),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 根据屏幕宽度动态计算列数（适配手机/平板/横屏）
              // - <400px：手机竖屏，2列
              // - 400-700px：大屏手机/小平板竖屏，3列
              // - 700-1000px：平板竖屏/手机横屏，4列
              // - >=1000px：平板横屏/桌面，5列
              final width = constraints.maxWidth;
              final crossAxisCount = width < 400
                  ? 2
                  : (width < 700
                      ? 3
                      : (width < 1000 ? 4 : 5));

              // 根据列数计算卡片宽高比：列数越少卡片越宽越高，列数越多卡片越扁
              final childAspectRatio = crossAxisCount <= 2
                  ? 9 / 16
                  : (crossAxisCount <= 4 ? 3 / 4 : 16 / 9);

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
                  controller: _gridController,
                  padding: EdgeInsets.fromLTRB(
                      8, 8, 8, 8 + MediaQuery.paddingOf(context).bottom),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: childAspectRatio,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount:
                      displayItems.length + (videoState.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // 末尾加载指示器
                    if (index >= displayItems.length) {
                      final scheme = Theme.of(context).colorScheme;
                      return Center(
                        child:
                            CircularProgressIndicator(color: scheme.primary),
                      );
                    }

                    final item = displayItems[index];
                    return VideoGridCard(
                      key: Key(item.id),
                      item: item,
                      isLastWatched: item.id == _lastWatchedId,
                      onTap: () => _navigateToVideo(item, index),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 从当前显示列表中找到上次观看的视频（横幅续播用）
  MediaItem? _lastWatchedItemOf(List<MediaItem> displayItems) {
    final id = _lastWatchedId;
    if (id == null) return null;
    for (final item in displayItems) {
      if (item.id == id) return item;
    }
    return null;
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
                  color: scheme.onSurface.withValues(alpha: 0.7), fontSize: 16),
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
