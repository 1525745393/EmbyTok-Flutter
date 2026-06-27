import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/app_preferences.dart' show FeedType, ViewMode;
import '../utils/image_cache_manager.dart';
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
  String? _lastProcessedJumpItemId;

  // 等待目标视频出现在 gridItems 中，然后滚动到对应位置
  void _waitForItemAndScroll(String itemId, {int retryCount = 0}) {
    if (!mounted) return;
    if (retryCount > 60) {
      // 最多等待3秒
      ref.read(feedToGridJumpItemIdProvider.notifier).state = null;
      _lastProcessedJumpItemId = null;
      return;
    }

    // 如果用户切回了视频流模式，放弃
    if (ref.read(viewModeProvider) != ViewMode.grid) {
      ref.read(feedToGridJumpItemIdProvider.notifier).state = null;
      _lastProcessedJumpItemId = null;
      return;
    }

    final gridItems = ref.read(videoListProvider).gridItems;
    final targetIndex = gridItems.indexWhere((item) => item.id == itemId);

    if (targetIndex >= 0) {
      // 找到目标，执行滚动
      _scrollToGridIndex(targetIndex);
      ref.read(feedToGridJumpItemIdProvider.notifier).state = null;
      _lastProcessedJumpItemId = null;
      return;
    }

    // 如果还在加载中或还没找到，等待下一帧重试
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _waitForItemAndScroll(itemId, retryCount: retryCount + 1);
    });
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final videoState = ref.watch(videoListProvider);
    final gridItems = videoState.gridItems;
    final selectedLibraries = ref.watch(selectedLibrariesProvider);
    // 监听从 feed 切回网格时需要定位到的 itemId
    final jumpToItemId = ref.watch(feedToGridJumpItemIdProvider);

    if (gridItems.isEmpty && videoState.isLoading) {
      return Center(child: CircularProgressIndicator(color: scheme.primary));
    }
    if (gridItems.isEmpty) {
      return Center(
        child: Text('暂无视频', style: TextStyle(color: scheme.onSurface.withOpacity(0.7), fontSize: 16)),
      );
    }

    // 处理从视频流切回时的定位：在帧后滚动到目标视频
    // 使用帧轮询：如果目标还没加载到 gridItems 中，等待重试
    if (jumpToItemId != null && jumpToItemId.isNotEmpty && jumpToItemId != _lastProcessedJumpItemId) {
      _lastProcessedJumpItemId = jumpToItemId;
      _waitForItemAndScroll(jumpToItemId);
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

  const _PosterCard({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final thumbnailUrl = item.thumbnailUrlWithAuth(authState.embyServerUrl, authState.token);

    return TvFocusable(
      onTap: () {
        // 点击海报切换到视频流模式并从该视频开始播放
        // 1. 设置选中的视频 ID，由 feed_view 监听并跳转到对应位置
        ref.read(gridSelectedItemIdProvider.notifier).state = item.id;

        // 2. 同步更新全局播放状态
        ref.read(currentPlayingItemProvider.notifier).state = item;

        // 3. 切换到视频流模式
        ref.read(viewModeProvider.notifier).setMode(ViewMode.feed);
      },
      borderRadius: 8,
      borderWidth: 2,
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
