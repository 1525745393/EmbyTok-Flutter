// 观看历史页面：显示用户已播放过的内容，支持清空和继续播放

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/formatters.dart';
import '../widgets/video_page_item.dart';

class HistoryView extends ConsumerStatefulWidget {
  const HistoryView({super.key});

  @override
  ConsumerState<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends ConsumerState<HistoryView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(watchHistoryProvider.notifier).load();
    });
  }

  void _confirmClear() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('清空历史', style: TextStyle(color: Colors.white)),
        content: const Text('确定要清空所有观看历史吗？此操作不可恢复。',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(watchHistoryProvider.notifier).clear();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('清空', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(watchHistoryProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          children: const [
            Icon(Icons.history, color: Color(0xFFFF5983), size: 24),
            SizedBox(width: 8),
            Text('观看历史'),
          ],
        ),
        actions: [
          if (state.items.isNotEmpty)
            TextButton(
              onPressed: _confirmClear,
              child: const Text('清空', style: TextStyle(color: Color(0xFFFF5983))),
            ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(WatchHistoryState state) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE91E63)),
      );
    }
    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(state.error!, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }
    if (state.items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.movie_outlined, size: 80, color: Colors.white30),
            SizedBox(height: 16),
            Text('暂无观看历史',
                style: TextStyle(color: Colors.white70, fontSize: 18)),
            SizedBox(height: 8),
            Text('开始观看后将自动记录',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = state.items[index];
        return _HistoryTile(item: item);
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final WatchHistoryItem item;
  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final progressPct = item.totalSeconds > 0
        ? (item.progressSeconds / item.totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    return InkWell(
      onTap: () {
        final media = MediaItem(
          id: item.itemId,
          title: item.itemTitle,
          type: '电影',
          thumbnailUrl: item.thumbnailUrl,
        );
        Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => _HistoryPlayPage(item: media)),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty
                  ? Image.network(
                      item.thumbnailUrl!,
                      width: 120,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                    )
                  : _thumbPlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 进度条
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressPct,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFE91E63),
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progressPct * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_formatSeconds(item.progressSeconds)} / ${_formatSeconds(item.totalSeconds)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDateTime(item.watchedAt),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
        width: 120,
        height: 72,
        color: Colors.grey[800],
        child: const Icon(Icons.movie_outlined, color: Colors.white30),
      );

  static String _formatSeconds(int seconds) {
    if (seconds <= 0) return '0:00';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  static String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '今天 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '昨天 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} 天前';
    }
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _HistoryPlayPage extends StatelessWidget {
  final MediaItem item;
  const _HistoryPlayPage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(item.title, style: const TextStyle(fontSize: 16)),
      ),
      body: VideoPageItem(item: item),
    );
  }
}
