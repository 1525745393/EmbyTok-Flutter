// 视频播放相关的底部弹出面板和对话框
// 包含：倍速调节面板、字幕选择器、删除确认对话框、视频信息面板

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  // 从 Emby 服务器获取真正的海报/背景图 URL
  final container = ProviderScope.containerOf(context);
  final auth = container.read(authProvider);
  final posterUrl = item.primaryUrl(
    embyServerUrl: auth.embyServerUrl,
    apiKey: auth.token,
    maxWidth: 500,
  );
  final backdropUrl = item.backdropUrl(
    embyServerUrl: auth.embyServerUrl,
    apiKey: auth.token,
    maxWidth: 1280,
  );

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
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          color: scheme.surface.withValues(alpha: 0.3),
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
                        // 封面海报（用 Emby primary poster）
                        if (posterUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              posterUrl,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 200,
                                color: scheme.onSurface.withValues(alpha: 0.1),
                                child: Icon(Icons.movie,
                                    size: 48, color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        // 标题 + 收藏按钮
                        Row(
                          children: [
                            Expanded(
                              child: Text(item.title,
                                  style: TextStyle(
                                      color: scheme.onSurface,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700)),
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
    final r = rating;
    if (r != null && r > 0) {
      widgets.add(_VideoInfoChip(
          label: '评分', value: '★ ${r.toStringAsFixed(1)}', highlight: true));
    }
    if (genres.isNotEmpty) {
      // 类型：拆成单独 chip，可点击
      for (final g in genres.take(3)) {
        widgets.add(_VideoInfoChip(
          label: '类型',
          value: g,
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('筛选类型：$g')),
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
          Text(label,
              style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
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
class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isFavorite = item.userData?.isFavorite ?? item.isFavorite ?? false;
    return IconButton(
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: isFavorite ? scheme.primary : scheme.onSurfaceVariant,
      ),
      onPressed: () {
        // TODO: 调用 Emby API 切换收藏
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isFavorite ? '已取消收藏' : '已收藏')),
        );
      },
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
        final imageUrl = p.imageUrl;
        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('查看演员：${p.name}')),
            );
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
