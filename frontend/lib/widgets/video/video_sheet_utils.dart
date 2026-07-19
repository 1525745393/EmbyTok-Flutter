// 视频播放相关的底部弹出面板和对话框
// 包含：倍速调节面板、字幕选择器、删除确认对话框、视频信息面板

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';

// ===== 倍速调节面板（BottomSheet + 滑块）=====
Future<void> showSpeedControlPanel(
  BuildContext context,
  VideoPlayerController? controller,
) async {
  double currentSpeed = controller?.value.playbackSpeed ?? 1.0;
  double selectedSpeed = currentSpeed;
  final scheme = Theme.of(context).colorScheme;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: scheme.surface.withOpacity(0.9),
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
                  inactiveColor: scheme.onSurface.withOpacity(0.2),
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
                              : scheme.onSurface.withOpacity(0.1),
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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

// ===== 画质选择面板 =====
Future<void> showQualitySelector(BuildContext context) async {
  final scheme = Theme.of(context).colorScheme;
  final container = ProviderScope.containerOf(context, listen: false);
  final currentLevel = container.read(playbackLevelProvider);

  // 等级对应的显示名称
  const qualityOptions = <(int level, String label, String desc)>[
    (0, '原画', 'Direct Play，无损画质'),
    (1, '高清 Remux', 'Direct Stream，仅重封装'),
    (2, '流畅转码', 'HLS 转码，低带宽适配'),
  ];

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: scheme.surface.withOpacity(0.9),
    builder: (context) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '画质选择',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...qualityOptions.map((opt) {
              final selected = opt.$1 == currentLevel;
              return ListTile(
                title: Text(
                  opt.$2,
                  style: TextStyle(
                    color: selected ? scheme.primary : scheme.onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  opt.$3,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                trailing: selected
                    ? Icon(Icons.check, color: scheme.primary)
                    : null,
                onTap: () {
                  if (!selected) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        ProviderScope.containerOf(context, listen: false)
                            .read(playbackLevelProvider.notifier)
                            .setLevel(opt.$1);
                      }
                    });
                  }
                  Navigator.of(context).pop();
                },
              );
            }),
          ],
        ),
      );
    },
  );
}

// ===== 字幕选择器 =====
Future<void> showSubtitleSelector(
  BuildContext context,
  List<SubtitleTrack> tracks,
) async {
  final scheme = Theme.of(context).colorScheme;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: scheme.surface.withOpacity(0.9),
    builder: (context) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('字幕选择',
                style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              title: Text('关闭字幕', style: TextStyle(color: scheme.onSurface)),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    ProviderScope.containerOf(context, listen: false)
                        .read(selectedSubtitleProvider.notifier)
                        .state = null;
                  }
                });
                Navigator.of(context).pop();
              },
            ),
            ...tracks.asMap().entries.map((entry) {
              final track = entry.value;
              return ListTile(
                title: Text('${track.displayName} (${entry.key + 1})',
                    style: TextStyle(color: scheme.onSurface)),
                onTap: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      ProviderScope.containerOf(context, listen: false)
                          .read(selectedSubtitleProvider.notifier)
                          .state = track.id;
                    }
                  });
                  Navigator.of(context).pop();
                },
              );
            }),
          ],
        ),
      );
    },
  );
}

// ===== 删除确认对话框 =====
Future<bool> showDeleteConfirmDialog(BuildContext context, String itemTitle) async {
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: scheme.surface.withOpacity(0.9),
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
  final isEpisode = type == 'Episode' ||
      (seriesName != null && seriesName.isNotEmpty);

  List<Person>? actors;
  List<Person>? directors;
  if (people != null && people.isNotEmpty) {
    actors = people.where((p) => p.type.toLowerCase() == 'actor').take(5).toList();
    directors = people
        .where((p) => p.type.toLowerCase().contains('director'))
        .take(3)
        .toList();
  }

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: scheme.surface.withOpacity(0.9),
    isScrollControlled: true,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(item.title,
                    style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
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
                  duration: duration,
                  rating: rating,
                  genres: genres,
                  studios: studios,
                ),
                const SizedBox(height: 24),
                if (overview != null && overview.isNotEmpty) ...[
                  _VideoInfoSectionLabel('简介'),
                  const SizedBox(height: 8),
                  Text(overview,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 14,
                          height: 1.5)),
                  const SizedBox(height: 24),
                ],
                if (actors != null && actors.isNotEmpty) ...[
                  _VideoInfoSectionLabel('主演'),
                  const SizedBox(height: 8),
                  _PersonChipList(people: actors),
                  const SizedBox(height: 24),
                ],
                if (directors != null && directors.isNotEmpty) ...[
                  _VideoInfoSectionLabel('导演'),
                  const SizedBox(height: 8),
                  _PersonChipList(people: directors),
                  const SizedBox(height: 24),
                ],
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    },
  );
}

// ===== 信息面板副标题行 =====
class _VideoInfoSubtitle extends StatelessWidget {
  final String type;
  final int? year;
  final bool isEpisode;
  final String? seriesName;
  final int? season;
  final int? episode;

  const _VideoInfoSubtitle({
    required this.type,
    required this.year,
    required this.isEpisode,
    required this.seriesName,
    required this.season,
    required this.episode,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[];

    children.add(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.primary.withOpacity(0.18),
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

    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: children);
  }
}

// ===== 信息面板基本信息行 =====
class _VideoInfoRowItems extends StatelessWidget {
  final String duration;
  final double? rating;
  final List<String> genres;
  final List<String>? studios;

  const _VideoInfoRowItems({
    required this.duration,
    required this.rating,
    required this.genres,
    required this.studios,
  });

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    if (duration.isNotEmpty) {
      widgets.add(_VideoInfoChip(label: '时长', value: duration));
    }
    final r = rating;
    if (r != null && r > 0) {
      widgets.add(_VideoInfoChip(
          label: '评分', value: '★ ${r.toStringAsFixed(1)}', highlight: true));
    }
    if (genres.isNotEmpty) {
      widgets.add(_VideoInfoChip(label: '类型', value: genres.take(3).join(' / ')));
    }
    final s = studios;
    if (s != null && s.isNotEmpty) {
      widgets.add(_VideoInfoChip(label: '出品', value: s.first));
    }
    if (widgets.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 12, runSpacing: 10, children: widgets);
  }
}

// ===== 信息面板中的小卡片 =====
class _VideoInfoChip extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _VideoInfoChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.onSurface.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: highlight
            ? Border.all(color: scheme.primary.withOpacity(0.45))
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
  }
}

// ===== 信息面板中的小节标题 =====
class _VideoInfoSectionLabel extends StatelessWidget {
  final String text;
  const _VideoInfoSectionLabel(this.text);

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
class _PersonChipList extends StatelessWidget {
  final List<Person> people;
  const _PersonChipList({required this.people});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: people.map((p) {
        final role = p.role;
        final display =
            role != null && role.isNotEmpty && role != p.name
                ? '${p.name} ($role)'
                : p.name;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surface.withOpacity(0.25),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(display,
              style: TextStyle(color: scheme.onSurface, fontSize: 13)),
        );
      }).toList(),
    );
  }
}
