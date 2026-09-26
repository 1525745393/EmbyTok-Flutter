// 观看年度报告：汇总播放数据，生成可分享的年度总结
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/play_events_provider.dart';

class YearReportPage extends ConsumerWidget {
  const YearReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(playEventsProvider);
    final now = DateTime.now();
    final yearStart = DateTime(now.year, 1, 1);
    final yearEvents = events
        .where((e) => DateTime.fromMillisecondsSinceEpoch(e.playedAtMs)
            .isAfter(yearStart))
        .toList();

    final totalSecs =
        yearEvents.fold<int>(0, (s, e) => s + e.durationSeconds);
    final totalHours = (totalSecs / 3600).toStringAsFixed(1);
    final totalPlays = yearEvents.length;
    final uniqueDays = yearEvents
        .map((e) => DateTime.fromMillisecondsSinceEpoch(e.playedAtMs))
        .map((d) => '${d.year}-${d.month}-${d.day}')
        .toSet()
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text('${now.year} 年度报告'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.share(
              '我在 EmbyTok ${now.year} 年观看了 $totalHours 小时内容，'
              '共 $totalPlays 次播放，活跃 $uniqueDays 天！',
              subject: 'EmbyTok 年度报告',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text(
                  '${now.year}',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Text('我的观影报告', style: TextStyle(fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _StatCard(
            icon: Icons.timer,
            label: '总观看时长',
            value: '$totalHours 小时',
            color: Colors.blue,
          ),
          _StatCard(
            icon: Icons.play_circle_fill,
            label: '播放次数',
            value: '$totalPlays 次',
            color: Colors.green,
          ),
          _StatCard(
            icon: Icons.calendar_today,
            label: '活跃天数',
            value: '$uniqueDays 天',
            color: Colors.orange,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                yearEvents.isEmpty
                    ? '今年还没有播放记录，开始观看吧！'
                    : '这一年，EmbyTok 陪你度过了 $totalHours 小时。'
                        '继续探索更多精彩内容！',
                style: const TextStyle(fontSize: 14, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
