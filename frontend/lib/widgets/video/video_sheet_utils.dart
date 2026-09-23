// 视频播放相关的底部弹出面板和对话框
// 包含：倍速调节面板、字幕选择器、删除确认对话框、视频信息面板

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../models/models.dart';
import '../../providers/disliked_items_provider.dart';
import '../../providers/providers.dart';
import '../../utils/constants.dart';
import '../person_avatar_image.dart';
import 'subtitle_selector.dart';

// ===== 倍速调节面板（BottomSheet + 滑块）=====
Future<void> showSpeedControlPanel(
  BuildContext context,
  VideoPlayerController? controller,
) async {
  final double currentSpeed = controller?.value.playbackSpeed ?? 1.0;
  double selectedSpeed = currentSpeed;
  final scheme = Theme.of(context).colorScheme;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: scheme.surface.withValues(alpha: 0.9),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('播放速度',
                    style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                Text('${selectedSpeed.toStringAsFixed(1)}x',
                    style: TextStyle(
                        color: scheme.tertiary,
                        fontSize: 48,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Slider(
                  value: selectedSpeed,
                  min: 1.0,
                  max: 10.0,
                  divisions: 18,
                  activeColor: scheme.tertiary,
                  inactiveColor: scheme.onSurface.withValues(alpha: 0.2),
                  onChanged: (value) {
                    setSheetState(() {
                      selectedSpeed = double.parse(value.toStringAsFixed(1));
                    });
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1x',
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 12)),
                    Text('10x',
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [1.0, 1.5, 2.0, 3.0].map((speed) {
                    final isSelected = selectedSpeed == speed;
                    return GestureDetector(
                      onTap: () {
                        setSheetState(() {
                          selectedSpeed = speed;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? scheme.tertiary
                              : scheme.onSurface.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${speed}x',
                          style: TextStyle(
                            color: isSelected
                                ? scheme.onTertiary
                                : scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      controller?.setPlaybackSpeed(selectedSpeed);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) {
                          ProviderScope.containerOf(context, listen: false)
                              .read(playbackRateProvider.notifier)
                              .state = selectedSpeed;
                        }
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('确定',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// ===== 字幕选择器 =====
/// 显示字幕选择器底部弹窗（委托给 SubtitleSelector 组件）
Future<void> showSubtitleSelector(
  BuildContext context,
  List<SubtitleTrack> tracks,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final selectedTrackId = container.read(selectedSubtitleProvider);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => SubtitleSelector(
      tracks: tracks,
      selectedTrackId: selectedTrackId,
      onSelected: (track) {
        // 先更新 provider，再关闭弹窗
        // 注意：不能用 addPostFrameCallback + Navigator.pop 顺序，
        // 因为 pop 后 context 会 unmount，postFrameCallback 中的更新会被跳过
        if (track == null) {
          container.read(selectedSubtitleProvider.notifier).state = null;
        } else {
          container.read(selectedSubtitleProvider.notifier).state = track.id;
        }
      },
      onClose: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

// ===== 删除确认对话框 =====
Future<bool> showDeleteConfirmDialog(
    BuildContext context, String itemTitle) async {
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: scheme.surface.withValues(alpha: 0.9),
      title: Text('确认删除', style: TextStyle(color: scheme.onSurface)),
      content: Text('确定要从媒体库中删除 "$itemTitle" 吗？',
          style: TextStyle(color: scheme.onSurfaceVariant)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('取消', style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('删除', style: TextStyle(color: scheme.error)),
        ),
      ],
    ),
  );
  return confirmed == true;
}

// ===== 视频信息底部面板 =====
void showVideoInfoSheet(BuildContext context, MediaItem item) {
  final type = item.type;
  final year = item.displayYear;
  final duration = item.formattedDuration;
  final rating = item.displayRating;
  final genres = item.displayGenres;
  final studios = item.studioNames;
  final overview = item.overview;
  final people = item.people;
  final scheme = Theme.of(context).colorScheme;
  final seriesName = item.seriesName;
  final isEpisode =
      type == 'Episode' || (seriesName != null && seriesName.isNotEmpty);

  // 用 Emby Primary 海报（带认证 token），构造完整图片 URL
  final container = ProviderScope.containerOf(context);
  final auth = container.read(authProvider);
  final posterUrl = item.thumbnailUrlWithAuth(
    auth.embyServerUrl,
    auth.token,
    maxWidth: 500,
  );
  // 高清版 Primary 海报（用于全屏查看）
  final posterUrlHiRes = item.thumbnailUrlWithAuth(
    auth.embyServerUrl,
    auth.token,
    maxWidth: 1280,
  );
  final backdropUrl = item.backdropUrl(
    embyServerUrl: auth.embyServerUrl,
    apiKey: auth.token,
    maxWidth: 1280,
  );
  // Emby Thumb 横版缩略图（用于详情页右侧展示）
  final thumbUrl = item.imageUrl(
    'Thumb',
    embyServerUrl: auth.embyServerUrl,
    apiKey: auth.token,
    maxWidth: 600,
  );
  // 高清版 Thumb（用于全屏查看）
  final thumbUrlHiRes = item.imageUrl(
    'Thumb',
    embyServerUrl: auth.embyServerUrl,
    apiKey: auth.token,
    maxWidth: 1280,
  );
  final httpHeaders = auth.token != null && auth.token!.isNotEmpty
      ? embyAuthHeaders(auth.token!)
      : <String, String>{};

  List<Person>? actors;
  List<Person>? directors;
  if (people != null && people.isNotEmpty) {
    actors =
        people.where((p) => p.type.toLowerCase() == 'actor').take(5).toList();
    directors = people
        .where((p) => p.type.toLowerCase().contains('director'))
        .take(3)
        .toList();
  }

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.95),
              ),
              child: Stack(
                children: [
                  // 背景模糊海报（用 Emby backdrop + BackdropFilter 真正模糊）
                  if (backdropUrl != null)
                    Positioned.fill(
                      child: Image.network(
                        backdropUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  // 真正模糊
                  if (backdropUrl != null)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            color: scheme.surface.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  // 深色遮罩
                  Positioned.fill(
                    child: Container(
                      color: scheme.surface.withValues(alpha: 0.7),
                    ),
                  ),
                  // 内容
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    child: ListView(
                      controller: scrollController,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: scheme.onSurface.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 封面海报 + 视频缩略图（Emby Primary 竖版 + Thumb 横版）
                        if (posterUrl != null || thumbUrl != null)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 左侧：Primary 竖版海报（2:3）
                              if (posterUrl != null)
                                GestureDetector(
                                  onTap: () => showFullScreenImageViewer(
                                    context,
                                    posterUrlHiRes ?? posterUrl,
                                    headers: httpHeaders.isNotEmpty
                                        ? httpHeaders
                                        : null,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: posterUrl,
                                      httpHeaders: httpHeaders.isNotEmpty
                                          ? httpHeaders
                                          : null,
                                      width: 110,
                                      height: 165,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        width: 110,
                                        height: 165,
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.1),
                                        child: const Center(
                                            child: CircularProgressIndicator()),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        width: 110,
                                        height: 165,
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.1),
                                        child: Icon(Icons.movie,
                                            size: 40,
                                            color: scheme.onSurfaceVariant),
                                      ),
                                    ),
                                  ),
                                ),
                              if (posterUrl != null && thumbUrl != null)
                                const SizedBox(width: 12),
                              // 右侧：Thumb 横版视频缩略图
                              if (thumbUrl != null)
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => showFullScreenImageViewer(
                                      context,
                                      thumbUrlHiRes ?? thumbUrl,
                                      headers: httpHeaders.isNotEmpty
                                          ? httpHeaders
                                          : null,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: thumbUrl,
                                        httpHeaders: httpHeaders.isNotEmpty
                                            ? httpHeaders
                                            : null,
                                        height: 165,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                          height: 165,
                                          color: scheme.onSurface
                                              .withValues(alpha: 0.1),
                                          child: const Center(
                                              child:
                                                  CircularProgressIndicator()),
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          height: 165,
                                          color: scheme.onSurface
                                              .withValues(alpha: 0.1),
                                          child: Icon(Icons.image,
                                              size: 40,
                                              color: scheme.onSurfaceVariant),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        // 标题 + 收藏 + 分享
                        Row(
                          children: [
                            Expanded(
                              child: Text(item.title,
                                  style: TextStyle(
                                      color: scheme.onSurface,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700)),
                            ),
                            IconButton(
                              icon: Icon(Icons.share,
                                  color: scheme.onSurfaceVariant, size: 20),
                              onPressed: () {
                                final url =
                                    '${auth.embyServerUrl}/web/index.html#!/details?id=${item.id}';
                                Clipboard.setData(ClipboardData(text: url));
                                final messenger = ScaffoldMessenger.of(context);
                                Navigator.pop(context);
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('分享链接已复制到剪贴板')),
                                );
                              },
                            ),
                            _FavoriteButton(item: item),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _InfoActionRow(item: item),
                        const SizedBox(height: 8),
                        _VideoInfoSubtitle(
                          type: type,
                          year: year,
                          isEpisode: isEpisode,
                          seriesName: item.seriesName,
                          season: item.parentIndexNumber,
                          episode: item.indexNumber,
                        ),
                        const SizedBox(height: 20),
                        _VideoInfoRowItems(
                          item: item,
                          duration: duration,
                          rating: rating,
                          genres: genres,
                          studios: studios,
                        ),
                        const SizedBox(height: 24),
                        if (overview != null && overview.isNotEmpty) ...[
                          const _VideoInfoSectionLabel('简介'),
                          const SizedBox(height: 8),
                          _OverviewExpandable(text: overview),
                          const SizedBox(height: 24),
                        ],
                        if (actors != null && actors.isNotEmpty) ...[
                          const _VideoInfoSectionLabel('主演'),
                          const SizedBox(height: 8),
                          _PersonChipList(people: actors),
                          const SizedBox(height: 24),
                        ],
                        if (directors != null && directors.isNotEmpty) ...[
                          const _VideoInfoSectionLabel('导演'),
                          const SizedBox(height: 8),
                          _PersonChipList(people: directors),
                          const SizedBox(height: 24),
                        ],
                        // 剧集导航：上一集 / 下一集
                        if (isEpisode && item.seriesId != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  final c = ProviderScope.containerOf(context);
                                  _navigateToEpisode(context, c, item, -1);
                                },
                                icon: const Icon(Icons.skip_previous),
                                label: const Text('上一集'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  final c = ProviderScope.containerOf(context);
                                  _navigateToEpisode(context, c, item, 1);
                                },
                                icon: const Icon(Icons.skip_next),
                                label: const Text('下一集'),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        // 相似推荐
                        _SimilarSection(itemId: item.id),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// 剧集导航：跳转到上一集/下一集
Future<void> _navigateToEpisode(
  BuildContext context,
  ProviderContainer container,
  MediaItem item,
  int offset,
) async {
  final messenger = ScaffoldMessenger.of(context);
  Navigator.pop(context);
  try {
    final api = container.read(mediaServerApiProvider);
    final episodes = await api.getEpisodes(item.seriesId!, limit: 100);
    final items = episodes.items;
    final currentIndex = items.indexWhere((e) => e.id == item.id);
    if (currentIndex < 0) {
      messenger.showSnackBar(const SnackBar(content: Text('未找到当前剧集')));
      return;
    }
    final targetIndex = currentIndex + offset;
    if (targetIndex < 0 || targetIndex >= items.length) {
      messenger.showSnackBar(
        SnackBar(content: Text(offset < 0 ? '已经是第一集' : '已经是最后一集')),
      );
      return;
    }
    final targetItem = items[targetIndex];
    if (context.mounted) {
      context.push('/play/${targetItem.id}');
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('加载失败：$e')));
  }
}

// ===== 信息面板副标题行 =====
class _VideoInfoSubtitle extends StatelessWidget {
  const _VideoInfoSubtitle({
    required this.type,
    required this.year,
    required this.isEpisode,
    required this.seriesName,
    required this.season,
    required this.episode,
  });
  final String type;
  final int? year;
  final bool isEpisode;
  final String? seriesName;
  final int? season;
  final int? episode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[];

    children.add(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(type,
            style: TextStyle(
                color: scheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );

    if (year != null) {
      children.addAll([
        const SizedBox(width: 8),
        Text(year.toString(),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
      ]);
    }

    if (isEpisode) {
      final name = seriesName;
      if (name != null && name.isNotEmpty) {
        children.addAll([
          const SizedBox(width: 8),
          Text('·',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ]);
      }
      if (season != null || episode != null) {
        final s = season != null ? 'S$season' : '';
        final e = episode != null ? 'E$episode' : '';
        children.addAll([
          if (children.length > 1) const SizedBox(width: 8),
          Text('$s$e',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
        ]);
      }
    }

    return Row(
        crossAxisAlignment: CrossAxisAlignment.center, children: children);
  }
}

// ===== 信息面板基本信息行 =====
class _VideoInfoRowItems extends StatelessWidget {
  const _VideoInfoRowItems({
    required this.item,
    required this.duration,
    required this.rating,
    required this.genres,
    required this.studios,
  });
  final MediaItem item;
  final String duration;
  final double? rating;
  final List<String> genres;
  final List<String>? studios;

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    if (duration.isNotEmpty) {
      widgets.add(_VideoInfoChip(label: '时长', value: duration));
    }
    // 播放进度
    if (item.hasProgress) {
      final progress = (item.progressPercent * 100).toStringAsFixed(0);
      widgets.add(
          _VideoInfoChip(label: '已看', value: '$progress%', highlight: true));
    }
    // 播放次数
    final playCount = item.userData?.playCount;
    if (playCount != null && playCount > 0) {
      widgets.add(_VideoInfoChip(label: '播放', value: '$playCount次'));
    }
    // 用户评分
    final userRating = item.userData?.rating;
    if (userRating != null && userRating > 0) {
      widgets.add(_VideoInfoChip(
          label: '我的评分', value: '★ ${userRating.toStringAsFixed(1)}'));
    }
    final r = rating;
    if (r != null && r > 0) {
      widgets.add(_VideoInfoChip(
          label: '评分', value: '★ ${r.toStringAsFixed(1)}', highlight: true));
    }
    if (genres.isNotEmpty) {
      // 类型：拆成单独 chip，点击后追加到发现页筛选条件（去重）
      final container = ProviderScope.containerOf(context);
      void addGenreToDiscover(String g) {
        final current = container.read(discoverProvider).selectedGenreIds;
        if (current.contains(g)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('「$g」已在发现页筛选中')),
          );
          return;
        }
        container
            .read(discoverProvider.notifier)
            .saveSelection([...current, g]);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加「$g」到发现页筛选')),
        );
      }

      final displayGenres = genres.take(3).toList();
      for (final g in displayGenres) {
        widgets.add(_VideoInfoChip(
          label: '',
          value: g,
          onTap: () => addGenreToDiscover(g),
        ));
      }
      if (genres.length > 3) {
        widgets.add(_VideoInfoChip(
          label: '',
          value: '+${genres.length - 3}',
          onTap: () {
            showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('全部类型'),
                content: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: genres
                      .map((g) => ActionChip(
                            label: Text(g),
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              addGenreToDiscover(g);
                            },
                          ))
                      .toList(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            );
          },
        ));
      }
    }
    final s = studios;
    if (s != null && s.isNotEmpty) {
      widgets.add(_VideoInfoChip(label: '出品', value: s.first));
    }
    if (widgets.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 12, runSpacing: 10, children: widgets);
  }
}

// ===== 简介展开/收起 =====
class _OverviewExpandable extends StatefulWidget {
  const _OverviewExpandable({required this.text});
  final String text;

  @override
  State<_OverviewExpandable> createState() => _OverviewExpandableState();
}

class _OverviewExpandableState extends State<_OverviewExpandable> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLong = widget.text.length > 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded || !isLong ? null : 3,
          overflow: _expanded || !isLong
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: TextStyle(
              color: scheme.onSurfaceVariant, fontSize: 14, height: 1.5),
        ),
        if (isLong)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _expanded ? '收起' : '展开全部',
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ===== 信息面板中的小卡片 =====
class _VideoInfoChip extends StatelessWidget {
  const _VideoInfoChip({
    required this.label,
    required this.value,
    this.highlight = false,
    this.onTap,
  });
  final String label;
  final String value;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: highlight
            ? Border.all(color: scheme.primary.withValues(alpha: 0.45))
            : null,
      ),
      constraints: const BoxConstraints(minWidth: 80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            Text(label,
                style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
          ],
          Text(value,
              style: TextStyle(
                  color: highlight ? scheme.primary : scheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
    return onTap != null ? GestureDetector(onTap: onTap, child: chip) : chip;
  }
}

// ===== 收藏按钮 =====
class _FavoriteButton extends ConsumerStatefulWidget {
  const _FavoriteButton({required this.item});
  final MediaItem item;

  @override
  ConsumerState<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<_FavoriteButton> {
  late bool _isFavorite;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _isFavorite =
        widget.item.userData?.isFavorite ?? widget.item.isFavorite ?? false;
  }

  Future<void> _toggle() async {
    if (_loading) return;
    setState(() => _loading = true);
    final newVal = !_isFavorite;
    try {
      final api = ref.read(mediaServerApiProvider);
      await api.toggleFavorite(
        itemId: widget.item.id,
        isFavorite: newVal,
      );
      setState(() => _isFavorite = newVal);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newVal ? '已收藏' : '已取消收藏')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败：$e'),
            action: SnackBarAction(
              label: '重试',
              onPressed: _toggle,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? scheme.primary : scheme.onSurfaceVariant,
            ),
      onPressed: _loading ? null : _toggle,
    );
  }
}

// ===== 相似推荐 =====
class _SimilarSection extends ConsumerStatefulWidget {
  const _SimilarSection({required this.itemId});
  final String itemId;

  @override
  ConsumerState<_SimilarSection> createState() => _SimilarSectionState();
}

class _SimilarSectionState extends ConsumerState<_SimilarSection> {
  Future<List<MediaItem>>? _future;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    _future = ref.read(cachedMediaRepositoryProvider).getSimilarItems(
          widget.itemId,
          limit: 10,
          serverUrl: auth.embyServerUrl ?? '',
          token: auth.token ?? '',
          userId: auth.user?.id,
        );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final httpHeaders = auth.token != null && auth.token!.isNotEmpty
        ? embyAuthHeaders(auth.token!)
        : <String, String>{};
    return FutureBuilder<List<MediaItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton(scheme);
        }
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }
        // 过滤掉当前项本身
        final items =
            (snapshot.data ?? []).where((e) => e.id != widget.itemId).toList();
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _VideoInfoSectionLabel('相似推荐'),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final item = items[i];
                  final posterUrl = item.primaryUrl(
                    embyServerUrl: auth.embyServerUrl,
                    apiKey: auth.token,
                    maxWidth: 200,
                  );
                  return GestureDetector(
                    onTap: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      if (item.id.isNotEmpty) {
                        context.push('/play/${item.id}', extra: {
                          'item': item,
                          'items': items,
                          'source': 'similar',
                        });
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 80,
                        child: posterUrl != null
                            ? CachedNetworkImage(
                                imageUrl: posterUrl,
                                httpHeaders:
                                    httpHeaders.isNotEmpty ? httpHeaders : null,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.1),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.1),
                                  child: const Icon(Icons.movie),
                                ),
                              )
                            : Container(
                                color: scheme.onSurface.withValues(alpha: 0.1),
                                child: const Icon(Icons.movie),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeleton(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _VideoInfoSectionLabel('相似推荐'),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 80,
                color: scheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ===== 信息面板中的小节标题 =====
class _VideoInfoSectionLabel extends StatelessWidget {
  const _VideoInfoSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ===== 人员 chips 列表 =====
class _PersonChipList extends ConsumerWidget {
  const _PersonChipList({required this.people});
  final List<Person> people;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final token = authState.token;
    final serverUrl = authState.embyServerUrl;
    final httpHeaders = token != null && token.isNotEmpty
        ? embyAuthHeaders(token)
        : <String, String>{};
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: people.map((p) {
        final role = p.role;
        final display = role != null && role.isNotEmpty && role != p.name
            ? '${p.name} ($role)'
            : p.name;
        // 构造演员头像 URL：优先用 imageUrl，否则用 serverUrl + personId
        final imageUrl = p.imageUrl ??
            (p.id != null &&
                    p.id!.isNotEmpty &&
                    serverUrl != null &&
                    serverUrl.isNotEmpty
                ? '$serverUrl/Items/${p.id}/Images/Primary?maxWidth=200'
                : null);
        return GestureDetector(
          onTap: () {
            final messenger = ScaffoldMessenger.of(context);
            Navigator.pop(context);
            if (p.id != null && p.id!.isNotEmpty) {
              context.push('/person/${p.id}');
            } else {
              messenger.showSnackBar(
                SnackBar(content: Text('查看演员：${p.name}')),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: PersonAvatarImage(
                      imageUrl: imageUrl,
                      httpHeaders: httpHeaders.isNotEmpty ? httpHeaders : null,
                      size: 24,
                      memCacheWidth: 48,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(display,
                    style: TextStyle(color: scheme.onSurface, fontSize: 13)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ===== 信息面板操作行：不感兴趣 =====
/// 用户显式负反馈入口（抖音"不感兴趣"的等价物）
///
/// - 标记后写入 dislikedItemsProvider（本地持久化），并立即从当前 feed 列表移除
/// - 推荐过滤（_shouldSkipItem）在下次加载时生效，收藏项豁免
/// - 已标记状态下可点击撤销，恢复推荐
class _InfoActionRow extends ConsumerWidget {
  const _InfoActionRow({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final disliked = ref.watch(
      dislikedItemsProvider.select((s) => s.contains(item.id)),
    );

    Future<void> onToggle() async {
      final notifier = ref.read(dislikedItemsProvider.notifier);
      final messenger = ScaffoldMessenger.of(context);
      if (disliked) {
        await notifier.removeDislike(item.id);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('已恢复推荐'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        await notifier.dislike(item.id);
        // 立即从当前 feed 列表移除，避免用户反向滑回已标记的视频
        ref.read(videoListProvider.notifier).removeItem(item.id);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('已减少此类推荐'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onToggle,
        icon: Icon(
          disliked ? Icons.thumb_down : Icons.thumb_down_alt_outlined,
          size: 16,
          color: disliked ? scheme.primary : scheme.onSurfaceVariant,
        ),
        label: Text(
          disliked ? '已不感兴趣（点击恢复）' : '不感兴趣',
          style: TextStyle(
            fontSize: 12,
            color: disliked ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

/// 全屏图片查看器（支持双指缩放、双击缩放、关闭按钮）
void showFullScreenImageViewer(
  BuildContext context,
  String imageUrl, {
  Map<String, String>? headers,
}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: _FullScreenImageViewer(
        imageUrl: imageUrl,
        headers: headers,
      ),
    ),
  );
}

class _FullScreenImageViewer extends StatefulWidget {
  const _FullScreenImageViewer({
    required this.imageUrl,
    this.headers,
  });

  final String imageUrl;
  final Map<String, String>? headers;

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  final _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails!.localPosition;
      _transformationController.value = Matrix4.identity()
        ..translateByDouble(-position.dx * 2, -position.dy * 2, 0, 0)
        ..scaleByDouble(2.0, 2.0, 1.0, 1.0);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: GestureDetector(
            onDoubleTapDown: _handleDoubleTapDown,
            onDoubleTap: _handleDoubleTap,
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl,
                httpHeaders: widget.headers,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child:
                      Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}
