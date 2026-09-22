// 从 video_page_item.dart 拆分（part 文件，无行为变化）

part of 'video_page_item.dart';

// ==================== 播放页辅助组件 ====================

class _RightActionButtons extends ConsumerWidget {
  const _RightActionButtons({
    required this.item,
    required this.controller,
    required this.discRotation,
    required this.posterUrl,
    required this.posterHeaders,
    required this.toolbarVisible,
    required this.bottomPadding,
    required this.onToggleFullscreen,
    required this.onInfoTap,
    required this.onDeleteTap,
    required this.onShareTap,
    required this.onCommentTap,
    this.onSpeedTap,
    this.onSubtitleTap,
  });
  final MediaItem item;
  final VideoPlayerController? controller;
  final Animation<double> discRotation;
  final String posterUrl;
  final Map<String, String>? posterHeaders;
  final bool toolbarVisible;
  final double bottomPadding;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onInfoTap;
  final VoidCallback onDeleteTap;
  final VoidCallback onShareTap;
  final VoidCallback onCommentTap;
  final VoidCallback? onSpeedTap;
  final VoidCallback? onSubtitleTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    double rs(double base, [double maxScale = 1.7]) =>
        responsiveSize(context, base, maxScale);
    // 用 select 仅监听当前 item 的收藏状态，避免 favoritesProvider 任意变化触发重建
    final favorited = ref.watch(
      favoritesProvider.select((s) => s.favoriteIds.contains(item.id)),
    );
    // 本地评论数（select 精确监听当前 item，避免其他 item 评论变化触发重建）
    final commentCount = ref.watch(
      videoCommentsProvider.select((s) => s[item.id]?.length ?? 0),
    );

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: rs(_kRightActionWidth, 2.0),
      child: RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                scheme.surface.withValues(alpha: 0.36),
                Colors.transparent
              ],
            ),
          ),
          // 全屏按钮固定顶部（不随列表滚动）：避免 11 个按钮总高超出视口时，
          // reverse:true 的滚动把顶部全屏按钮滚出视口导致被遮挡 / 无法点击。
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  0,
                  // 右侧操作栏顶部需避开刘海：沉浸式下 padding 归零，用 SafeInsets 取真实物理高度
                  toolbarVisible
                      ? SafeInsets.topOf(context) + _kRightActionTopWithToolbar
                      : _kRightActionTopNoToolbar,
                  _kRightActionRightPadding,
                  rs(16, 1.5),
                ),
                child: PressableActionButton(
                  icon: Icons.fullscreen,
                  label: '全屏',
                  color: scheme.onSurface,
                  onTap: onToggleFullscreen,
                ),
              ),
              // 小屏防溢出：reverse:true 保持其余按钮贴底，内容超出时从顶部滚动
              // （新增分享/评论按钮后元素较多，低矮屏必须可滚动而非 RenderFlex 溢出）
              Expanded(
                child: SingleChildScrollView(
                  reverse: true,
                  padding: EdgeInsets.fromLTRB(
                    0,
                    0,
                    _kRightActionRightPadding,
                    // 全面屏适配：底部叠加导航栏高度 kBottomNavHeight，避免最下方 2 个按钮
                    // （字幕按钮 / DiscMute 唱片+头像）被 HomeScaffold 的底部导航栏吃掉一半。
                    toolbarVisible
                        ? bottomPadding +
                            _kBottomControlBarHeight +
                            _kBottomInfoGradientHeight +
                            kBottomNavHeight
                        : bottomPadding +
                            _kBottomControlBarHeight +
                            kBottomNavHeight,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AutoPlayButton(),
                      SizedBox(height: rs(16, 1.5)),
                      PosterAvatar(item: item),
                      SizedBox(height: rs(16, 1.5)),
                      PressableActionButton(
                        icon:
                            favorited ? Icons.favorite : Icons.favorite_border,
                        label: '点赞',
                        color: favorited ? scheme.primary : scheme.onSurface,
                        onTap: () => ref
                            .read(favoritesProvider.notifier)
                            .toggleFavorite(item),
                      ),
                      SizedBox(height: rs(16, 1.5)),
                      PressableActionButton(
                        icon: Icons.share_outlined,
                        label: '分享',
                        color: scheme.onSurface,
                        onTap: onShareTap,
                      ),
                      SizedBox(height: rs(16, 1.5)),
                      PressableActionButton(
                        icon: Icons.chat_bubble_outline,
                        label: '评论',
                        color: scheme.onSurface,
                        badgeCount: commentCount,
                        onTap: onCommentTap,
                      ),
                      SizedBox(height: rs(16, 1.5)),
                      PressableActionButton(
                        icon: Icons.info_outline,
                        label: '信息',
                        color: scheme.onSurface,
                        onTap: onInfoTap,
                      ),
                      SizedBox(height: rs(16, 1.5)),
                      PressableActionButton(
                        icon: Icons.delete_outline,
                        label: '删除',
                        color: scheme.error,
                        onTap: onDeleteTap,
                      ),
                      SizedBox(height: rs(16, 1.5)),
                      SpeedControlButton(
                        controller: controller,
                        onTap: onSpeedTap ?? () {},
                      ),
                      SizedBox(height: rs(16, 1.5)),
                      SubtitleButton(
                        hasSubtitles: item.subtitleTracks.isNotEmpty,
                        onTap: onSubtitleTap,
                      ),
                      SizedBox(height: rs(16, 1.5)),
                      DiscMuteButton(
                        discRotation: discRotation,
                        controller: controller,
                        posterUrl: posterUrl,
                        httpHeaders: posterHeaders,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 播放页面外壳：支持滑动切换视频列表
///
/// 使用 PageView 展示视频列表，支持上下滑动切换视频

class _BottomInfoBar extends StatelessWidget {
  const _BottomInfoBar({
    required this.item,
    required this.controller,
    required this.isVisible,
    required this.toolbarVisible,
    required this.bottomPadding,
    required this.onToggleFullscreen,
    required this.onInfoTap,
    required this.formatDuration,
  });
  final MediaItem item;
  final VideoPlayerController? controller;
  final bool isVisible;
  final bool toolbarVisible;
  final double bottomPadding;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onInfoTap;
  final String Function(Duration) formatDuration;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    double rs(double base, [double maxScale = 1.7]) =>
        responsiveSize(context, base, maxScale);

    final hasController = controller != null && controller!.value.isInitialized;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      // RepaintBoundary 放在 Positioned 内部，避免定位失效
      // 控制层与视频渲染层隔离，减少不必要的重绘
      child: RepaintBoundary(
        child: AnimatedOpacity(
          opacity: isVisible ? 1.0 : 0.0,
          duration: Duration(milliseconds: isVisible ? 300 : 500),
          curve: Curves.easeOut,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              _kHorizontalPadding,
              _kBottomInfoGradientHeight,
              rs(_kRightActionWidth, 2.0) + _kHorizontalPadding,
              // 全面屏适配：底部叠加导航栏高度，避免进度条 / 时间文字
              // 与 HomeScaffold 底部导航栏发生视觉重叠。
              toolbarVisible
                  ? bottomPadding +
                      _kBottomControlBarHeight +
                      _kBottomInfoGradientHeight +
                      kBottomNavHeight
                  : bottomPadding + _kBottomControlBarHeight + kBottomNavHeight,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  scheme.surface.withValues(alpha: 0.8),
                  scheme.surface.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onInfoTap,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 类型标签（前2个genre，回退到 type）
                      Builder(
                        builder: (_) {
                          final tags =
                              (item.genres != null && item.genres!.isNotEmpty)
                                  ? item.genres!.take(2).toList()
                                  : [item.type];
                          return Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: tags
                                .map((t) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: _kTagPaddingHorizontal,
                                          vertical: _kTagPaddingVertical),
                                      decoration: BoxDecoration(
                                        color: scheme.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        t,
                                        style: TextStyle(
                                          color: scheme.onPrimary,
                                          fontSize: _kFontSizeSmall,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          );
                        },
                      ),
                      const SizedBox(height: _kSpacingMedium),
                      // 标题 + 评分 + 时长
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              _buildTitle(item),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: _kFontSizeLarge,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: _kSpacingLarge),
                          if (item.displayRating != null &&
                              item.displayRating! > 0)
                            Text(
                              '★ ${item.displayRating!.toStringAsFixed(1)}',
                              style: TextStyle(
                                color: scheme.primary,
                                fontSize: _kFontSizeMedium,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          // 用户评分（如有）
                          if (item.userRating != null &&
                              item.userRating! > 0) ...[
                            const SizedBox(width: _kSpacingSmall),
                            Text(
                              '你 ★ ${item.userRating!.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: scheme.tertiary,
                                fontSize: _kFontSizeMedium,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(width: _kSpacingSmall),
                          if (item.durationSeconds != null &&
                              item.durationSeconds! > 0)
                            Text(
                              _formatDurationFromSeconds(
                                  item.durationSeconds!.toInt()),
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: _kFontSizeMedium,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: _kSpacingSmall),
                      // 简介（2行）
                      if (item.overview != null && item.overview!.isNotEmpty)
                        Text(
                          item.overview!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: _kFontSizeMedium,
                          ),
                        ),
                      // 导演/主演
                      if (item.people != null && item.people!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: _kSpacingSmall),
                          child: Text(
                            _buildPeopleSummary(item.people!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.8),
                              fontSize: _kFontSizeSmall,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 进度条（不包在 GestureDetector 里，避免点击进度条弹出详情）
                if (hasController)
                  Padding(
                    padding: const EdgeInsets.only(top: _kSpacingLarge),
                    child: SeekableProgressBar(
                      controller: controller!,
                      formatDuration: formatDuration,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 右侧操作按钮组（非纯净模式）
///
/// 从 [VideoPageItem] 提取为独立 ConsumerWidget，
/// 收藏状态等局部变化只重建本组件，不触发父组件重建。

class _CenterPlayButtonWrapper extends ConsumerWidget {
  const _CenterPlayButtonWrapper({
    required this.controller,
    required this.onPlay,
    required this.visible,
    required this.isAutoPlay,
  });
  final VideoPlayerController? controller;
  final VoidCallback onPlay;
  // 由父组件控制显示状态（非纯净模式下的自动隐藏）
  final bool visible;
  final bool isAutoPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 纯净模式不显示中央按钮（由 VideoControls 控制条操作）
    if (isAutoPlay) return const SizedBox.shrink();
    // 非纯净模式：由 visible 状态控制显示
    if (!visible) return const SizedBox.shrink();
    if (controller == null || !controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final isPlaying = ref.watch(isPlayingProvider);
    return CenterPlayButton(onPlay: onPlay, isPlaying: isPlaying);
  }
}

/// 底部信息条：标题/简介/类型标签/进度条（非纯净模式）
///
/// 从 [VideoPageItem] 提取为独立 Widget，减少父组件 build 复杂度。
/// 内部大部分子组件不随父组件状态变化而重建，提升 PageView 滑动性能。

String _buildTitle(MediaItem item) {
  // 剧集：显示 S01E05 集名
  if (item.type == 'Episode' && item.parentIndexNumber != null) {
    final s = item.parentIndexNumber.toString().padLeft(2, '0');
    final e = (item.indexNumber ?? 0).toString().padLeft(2, '0');
    final series = item.seriesName != null ? '${item.seriesName} ' : '';
    return '$series[S$s E$e] ${item.title}';
  }
  // 电影：标题 (年份)
  if (item.year != null) return '${item.title} (${item.year})';
  return item.title;
}

String _formatDurationFromSeconds(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

String _buildPeopleSummary(List<Person> people) {
  final directors = people
      .where((p) => p.type == 'Director')
      .map((p) => p.name)
      .take(2)
      .join('、');
  final actors = people
      .where((p) => p.type == 'Actor')
      .map((p) => p.name)
      .take(3)
      .join('、');
  final parts = <String>[];
  if (directors.isNotEmpty) parts.add('导演：$directors');
  if (actors.isNotEmpty) parts.add('主演：$actors');
  return parts.join('  |  ');
}
