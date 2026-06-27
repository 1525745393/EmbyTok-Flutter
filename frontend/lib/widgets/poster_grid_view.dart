import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/app_preferences.dart' show FeedType, ViewMode;
import '../utils/image_cache_manager.dart';
import '../utils/logger.dart';
import '../widgets/tv_focusable.dart';

/// 海报墙视图：网格布局展示视频缩略图
/// 参考 EmbyX 实现：
/// - 3列网格布局
/// - 顶部 Header 显示媒体库名、总数、换一批按钮、分页控件
/// - 支持分页导航（上一页/下一页）
class PosterGridView extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const PosterGridView({super.key, this.scrollController});

  @override
  ConsumerState<PosterGridView> createState() => _PosterGridViewState();
}

class _PosterGridViewState extends ConsumerState<PosterGridView> {
  // 已滚动的目标 ID（避免重复滚动到同一位置）
  String? _lastScrolledPlayingId;
  // 上次滚动时的 gridItems 引用（用于检测 gridItems 是否被换了一批）
  List<MediaItem>? _lastScrolledGridItems;

  // 滚动到当前正在播放的视频位置
  // 设计：feed 切回 grid 时，gridItems 已包含 currentPlayingIdProvider 指示的当前在播视频。
  // 这里只需在 gridItems 中找到它并滚动到对应位置。
  // 路径：feed.onPageChanged → currentPlayingIdProvider → 本视图 watch → 滚动。
  void _scrollToPlayingId(String playingId) {
    final controller = widget.scrollController;
    if (controller == null) return;

    // 帧轮询：等待 controller attach
    if (!controller.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToPlayingId(playingId);
      });
      return;
    }

    // ★ 关键：gridItems 引用变化时，重置去重状态
    // 场景：用户在 grid 点了"换一批"(shuffleRandom) → gridItems 引用变了
    // 此时 _lastScrolledPlayingId 跟 playingId 相同（都是当前在播视频 id），
    // 但 gridItems 内容已变，必须允许重新滚动
    final gridItems = ref.read(videoListProvider).gridItems;
    if (!identical(_lastScrolledGridItems, gridItems)) {
      _lastScrolledGridItems = gridItems;
      _lastScrolledPlayingId = null;
    }

    if (_lastScrolledPlayingId == playingId) return; // 已经处理过

    final targetIndex = gridItems.indexWhere((item) => item.id == playingId);
    if (targetIndex < 0) {
      // gridItems 中暂无目标
      AppLogger.debug('网格定位：目标不在 gridItems，等待更新', data: {'itemId': playingId});
      return;
    }

    _lastScrolledPlayingId = playingId;
    _scrollToGridIndex(targetIndex);
  }

  // 滚动到网格中指定索引位置（3列布局，居中对齐）
  // 使用帧轮询等待 controller attach，确保 GridView 构建完成后再执行滚动
  void _scrollToGridIndex(int indexInGrid, {int retryCount = 0}) {
    final controller = widget.scrollController;
    if (controller == null) return;

    if (retryCount > 30) return; // 最多等待约1.5秒

    if (!controller.hasClients) {
      // GridView 还未构建完成，等待下一帧重试
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToGridIndex(indexInGrid, retryCount: retryCount + 1);
        }
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) return;

      final viewportWidth = MediaQuery.of(context).size.width;
      final viewportHeight = controller.position.viewportDimension;
      const padding = 8.0;
      const crossAxisSpacing = 8.0;
      const mainAxisSpacing = 8.0;
      const crossAxisCount = 3;
      const childAspectRatio = 0.65;

      final availableWidth = viewportWidth - padding * 2 - (crossAxisCount - 1) * crossAxisSpacing;
      final itemWidth = availableWidth / crossAxisCount;
      final itemHeight = itemWidth / childAspectRatio;
      final rowHeight = itemHeight + mainAxisSpacing;
      final row = indexInGrid ~/ 3;

      final targetTop = padding + row * rowHeight;
      final scrollOffset = targetTop - (viewportHeight / 2) + (itemHeight / 2);

      final maxScroll = controller.position.maxScrollExtent;
      final safeOffset = scrollOffset.clamp(0.0, maxScroll);

      controller.animateTo(
        safeOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // 随机播放：从当前 gridItems 中随机选一个视频，跳转到 feed 从该视频开始
  // 路由透传 itemId，复用 grid→feed 的标准流程（PR #50 三层架构）
  void _playRandom() {
    final gridItems = ref.read(videoListProvider).gridItems;
    if (gridItems.isEmpty) {
      AppLogger.warn('随机播放失败：gridItems 为空');
      return;
    }
    // 随机选取（包含当前在播视频，避免每次都"原地不动"）
    final randomIndex = Random().nextInt(gridItems.length);
    final randomItem = gridItems[randomIndex];
    AppLogger.info('随机播放：选中视频', data: {
      'id': randomItem.id,
      'title': randomItem.title,
      'index': randomIndex,
      'total': gridItems.length,
    });
    // 切到 feed 模式 + 路由透传 initialId
    ref.read(viewModeProvider.notifier).setMode(ViewMode.feed);
    context.go('/?initialId=${Uri.encodeComponent(randomItem.id)}');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final videoState = ref.watch(videoListProvider);
    final gridItems = videoState.gridItems;
    final selectedLibraries = ref.watch(selectedLibrariesProvider);
    // 全局"当前在播"信号源：用于定位 + 高亮回显
    final playingId = ref.watch(currentPlayingIdProvider);

    if (gridItems.isEmpty && videoState.isLoading) {
      return Center(child: CircularProgressIndicator(color: scheme.primary));
    }
    if (gridItems.isEmpty) {
      return Center(
        child: Text('暂无视频', style: TextStyle(color: scheme.onSurface.withOpacity(0.7), fontSize: 16)),
      );
    }

    // 定位到当前正在播放的视频（feed 切回 grid 时由 video_list_provider 已加载对应页）
    if (playingId != null && playingId.isNotEmpty) {
      _scrollToPlayingId(playingId);
    }

    final totalCount = videoState.totalCount;
    final countStr = totalCount > 999 ? '999+' : '$totalCount';

    // 计算分页信息（直接从 state 计算，确保 UI 响应式更新）
    const gridPageSize = 150;
    final gridStartIndex = videoState.gridStartIndex;
    final currentPage = totalCount > 0
        ? (gridStartIndex ~/ gridPageSize) + 1
        : 1;
    final totalPages = totalCount > 0
        ? (totalCount / gridPageSize).ceil()
        : 1;
    final hasPrevPage = currentPage > 1;
    final hasNextPage = currentPage < totalPages;

    // 获取媒体库名称
    String libraryName = '全部视频';
    if (videoState.feedType == FeedType.favorites) {
      libraryName = '收藏夹';
    } else if (selectedLibraries.isNotEmpty) {
      final firstLib = selectedLibraries.first;
      libraryName = firstLib.name;
    }

    // 判断是否显示分页控件（仅单库模式且多页时显示）
    final showPager = selectedLibraries.length == 1 && totalPages > 1;

    return Column(
      children: [
        // 顶部 Header：媒体库名 + 总数 + 换一批 + 分页控件
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surface.withOpacity(0.5),
            border: Border(
              bottom: BorderSide(color: scheme.onSurface.withOpacity(0.1)),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                // 媒体库名称
                Text(
                  libraryName,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                // 总数 + 换一批按钮
                GestureDetector(
                  onTap: () {
                    // 换一批：随机获取 150 条
                    ref.read(videoListProvider.notifier).shuffleRandom();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          countStr,
                          style: TextStyle(
                            color: scheme.primary.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: scheme.onSurface.withOpacity(0.7),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // 视图切换按钮
                IconButton(
                  onPressed: () {
                    ref.read(viewModeProvider.notifier).setMode(ViewMode.feed);
                  },
                  icon: Icon(
                    Icons.phone_android,
                    color: scheme.onSurface.withOpacity(0.7),
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: '切换到视频流',
                ),
                // 分页控件：仅在单库模式且多页时显示
                if (showPager) ...[
                  // 上一页按钮
                  IconButton(
                    onPressed: hasPrevPage
                        ? () => ref.read(videoListProvider.notifier).prevPage()
                        : null,
                    icon: Icon(
                      Icons.chevron_left,
                      color: hasPrevPage
                          ? scheme.onSurface.withOpacity(0.7)
                          : scheme.onSurface.withOpacity(0.3),
                    ),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: '上一页',
                  ),
                  // 页码显示
                  Text(
                    '$currentPage/$totalPages',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // 下一页按钮
                  IconButton(
                    onPressed: hasNextPage
                        ? () => ref.read(videoListProvider.notifier).nextPage()
                        : null,
                    icon: Icon(
                      Icons.chevron_right,
                      color: hasNextPage
                          ? scheme.onSurface.withOpacity(0.7)
                          : scheme.onSurface.withOpacity(0.3),
                    ),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: '下一页',
                  ),
                ],
              ],
            ),
          ),
        ),
        // 网格内容
        Expanded(
          child: GridView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.65,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: gridItems.length + (videoState.hasMore && !showPager ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= gridItems.length) {
                return Center(child: CircularProgressIndicator(color: scheme.primary));
              }
              final item = gridItems[index];
              return _PosterCard(
                key: Key(item.id),
                item: item,
                isPlaying: item.id == playingId, // 标记"当前正在播"高亮
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 单个海报卡片
class _PosterCard extends ConsumerWidget {
  final MediaItem item;
  // 是否为当前正在播放的视频（用于回显高亮）
  final bool isPlaying;

  const _PosterCard({
    super.key,
    required this.item,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final thumbnailUrl = item.thumbnailUrlWithAuth(authState.embyServerUrl, authState.token);

    return TvFocusable(
      onTap: () {
        // 点击海报：通过路由透传 initialId 跳转到目标视频
        // - 路由：context.go('/?initialId=$id') 会触发路由重建
        // - HomeScaffold 把 initialItemId 透传给 FeedView
        // - FeedView 接收后调用 _waitForInitialItemToLoad → _jumpToPageWhenReady
        ref.read(viewModeProvider.notifier).setMode(ViewMode.feed);
        context.go('/?initialId=${Uri.encodeComponent(item.id)}');
      },
      borderRadius: 8,
      borderWidth: isPlaying ? 3 : 2,
      // isPlaying 时显示醒目边框
      borderColor: isPlaying ? scheme.primary : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                cacheManager: AppImageCacheManager.thumbnail,
                fit: BoxFit.cover,
                httpHeaders: item.authHeaders(authState.token),
                memCacheWidth: 400,
                placeholder: (_, __) => Container(
                  color: scheme.surface.withOpacity(0.3),
                  child: Center(
                    child: CircularProgressIndicator(color: scheme.primary, strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: scheme.surface.withOpacity(0.3),
                  child: Icon(Icons.broken_image, color: scheme.onSurface.withOpacity(0.4)),
                ),
              )
            else
              Container(
                color: scheme.surface.withOpacity(0.3),
                child: Icon(Icons.movie, color: scheme.onSurface.withOpacity(0.4)),
              ),
            // "正在播放"角标：左上角小播放图标
            if (isPlaying)
              Positioned(
                left: 6, top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow, size: 10, color: scheme.onPrimary),
                      const SizedBox(width: 2),
                      Text(
                        '播放中',
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // 底部渐变 + 标题
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      scheme.surface.withOpacity(0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            // 继续观看进度条：当有播放位置时在底部显示细粉色条
            if (item.hasProgress)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: LinearProgressIndicator(
                  value: item.progressPercent,
                  minHeight: 3,
                  backgroundColor: scheme.onSurface.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
