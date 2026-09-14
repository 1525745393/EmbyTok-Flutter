// 播放数据统计页（PRD #28）
//
// 基于本地 PlayEvent 聚合：总时长/总次数/收藏数、近7天柱状图、
// 热门歌曲/艺术家/专辑 Top10。时间范围：本周/本月/全部。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/play_events_provider.dart';
import '../providers/synology_music_provider.dart';
import '../providers/synology_playback_provider.dart';
import '../providers/recent_playbacks_provider.dart';
import '../models/audio_models.dart';

enum _Range { week, month, all }

class PlayStatsView extends ConsumerStatefulWidget {
  const PlayStatsView({super.key});

  @override
  ConsumerState<PlayStatsView> createState() => _PlayStatsViewState();
}

class _PlayStatsViewState extends ConsumerState<PlayStatsView> {
  _Range _range = _Range.week;

  DateTime get _rangeStart {
    final now = DateTime.now();
    switch (_range) {
      case _Range.week:
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
      case _Range.month:
        return DateTime(now.year, now.month, 1);
      case _Range.all:
        return DateTime(2000);
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(playEventsProvider);
    final startMs = _rangeStart.millisecondsSinceEpoch;
    final scoped = events.where((e) => e.playedAtMs >= startMs).toList();

    // 总览
    final totalSecs = scoped.fold<int>(0, (s, e) => s + e.durationSeconds);
    final totalPlays = scoped.length;
    final favCount = ref.watch(synologyMusicProvider).pins.length;

    // 近7天柱状图
    final now = DateTime.now();
    final weekDays = List.generate(7, (i) {
      final d = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - i));
      final dayStart = d.millisecondsSinceEpoch;
      final dayEnd = d.add(const Duration(days: 1)).millisecondsSinceEpoch;
      final secs = events
          .where((e) => e.playedAtMs >= dayStart && e.playedAtMs < dayEnd)
          .fold<int>(0, (s, e) => s + e.durationSeconds);
      return _DayBars(d, secs);
    });

    // Top 聚合
    final songs = <String, _Counter>{};
    final artists = <String, _Counter>{};
    final albums = <String, _Counter>{};
    for (final e in scoped) {
      (songs[e.songId] ??= _Counter(e.title, e.artist)).inc();
      if (e.artist.isNotEmpty) {
        (artists[e.artist] ??= _Counter(e.artist, '')).inc();
      }
      if (e.album.isNotEmpty) {
        (albums[e.album] ??= _Counter(e.album, e.artist)).inc();
      }
    }
    final topSongs = songs.values.toList()
      ..sort((a, b) => b.count - a.count);
    final topArtists = artists.values.toList()
      ..sort((a, b) => b.count - a.count);
    final topAlbums = albums.values.toList()
      ..sort((a, b) => b.count - a.count);

    return Scaffold(
      appBar: AppBar(
        title: const Text('播放统计'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ToggleButtons(
              isSelected: [
                _range == _Range.week,
                _range == _Range.month,
                _range == _Range.all,
              ],
              onPressed: (i) => setState(() => _range = _Range.values[i]),
              borderRadius: BorderRadius.circular(8),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('本周', style: TextStyle(fontSize: 12)),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('本月', style: TextStyle(fontSize: 12)),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('全部', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 总览卡片
          Row(
            children: [
              _OverviewCard(
                  label: '总听歌时长',
                  value: '${(totalSecs / 3600).toStringAsFixed(1)}',
                  unit: '小时'),
              const SizedBox(width: 12),
              _OverviewCard(
                  label: '总播放次数', value: '$totalPlays', unit: '次'),
              const SizedBox(width: 12),
              _OverviewCard(label: '收藏歌曲', value: '$favCount', unit: '首'),
            ],
          ),
          const SizedBox(height: 20),
          const Text('近7天听歌时长',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: _WeekBarChart(days: weekDays),
          ),
          const SizedBox(height: 20),
          _TopSection(
            title: '热门歌曲',
            items: topSongs.take(10).toList(),
            onTap: (c) {
              // 点击播放：从事件里找这首歌
              final ev = scoped.firstWhere(
                (e) => e.title == c.name,
                orElse: () => PlayEvent(songId: '', title: c.name, playedAtMs: 0),
              );
              if (ev.songId.isEmpty) return;
              ref
                  .read(synologyPlaybackProvider.notifier)
                  .playQueue([
                    AudioSong(
                        id: ev.songId,
                        title: ev.title,
                        tag: AudioSongTag(artist: ev.artist)),
                  ], 0);
            },
          ),
          _TopSection(
            title: '热门艺术家',
            items: topArtists.take(10).toList(),
            onTap: (_) {},
          ),
          _TopSection(
            title: '热门专辑',
            items: topAlbums.take(10).toList(),
            onTap: (_) {},
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Counter {
  _Counter(this.name, this.sub);
  final String name;
  final String sub;
  int count = 0;
  void inc() => count++;
}

class _DayBars {
  _DayBars(this.date, this.seconds);
  final DateTime date;
  final int seconds;
}

String _fmtDur(int secs) {
  if (secs < 60) return '${secs}s';
  if (secs < 3600) return '${(secs / 60).toStringAsFixed(0)}m';
  return '${(secs / 3600).toStringAsFixed(1)}h';
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.label, required this.value, required this.unit});
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            Text(unit,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _WeekBarChart extends StatelessWidget {
  const _WeekBarChart({required this.days});
  final List<_DayBars> days;

  @override
  Widget build(BuildContext context) {
    final maxSecs = days.map((d) => d.seconds).fold<int>(0, (a, b) => a > b ? a : b);
    final weekLabels = const ['一', '二', '三', '四', '五', '六', '日'];
    final today = DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: days.asMap().entries.map((e) {
        final i = e.key;
        final d = e.value;
        final isToday = d.date.year == today.year &&
            d.date.month == today.month &&
            d.date.day == today.day;
        final h = maxSecs > 0 ? (d.seconds / maxSecs) : 0.0;
        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(_fmtDur(d.seconds),
                  style: const TextStyle(fontSize: 9, color: Colors.grey)),
              const SizedBox(height: 2),
              Container(
                width: 16,
                height: 60 * (h <= 0 ? 0.05 : h),
                decoration: BoxDecoration(
                  color: isToday
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 4),
              Text(weekLabels[d.date.weekday - 1],
                  style: TextStyle(
                      fontSize: 10,
                      color: isToday ? Theme.of(context).colorScheme.primary : Colors.grey)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TopSection extends StatelessWidget {
  const _TopSection({
    required this.title,
    required this.items,
    required this.onTap,
  });
  final String title;
  final List<_Counter> items;
  final void Function(_Counter c) onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...items.asMap().entries.map((e) {
          final rank = e.key + 1;
          final c = e.value;
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
                  color: rank == 1
                      ? Colors.amber
                      : rank == 2
                          ? Colors.grey
                          : rank == 3
                              ? Colors.brown
                              : Colors.grey,
                ),
              ),
            ),
            title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: c.sub.isEmpty
                ? null
                : Text(c.sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
            trailing: Text('${c.count}次',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            onTap: () => onTap(c),
          );
        }),
      ],
    );
  }
}
