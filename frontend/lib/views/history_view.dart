// 观看历史页面：从 Emby 服务器获取最近观看的条目

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(watchHistoryProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.history, color: Color(0xFFFF5983), size: 24),
            SizedBox(width: 8),
            Text('观看历史'),
          ],
        ),
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
            const Icon(Icons.error_outline,
                color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(state.error!,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(watchHistoryProvider.notifier).load();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (state.items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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

class _HistoryTile extends ConsumerWidget {
  final MediaItem item;
  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final thumbnailUrl = item.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
    );
    final headers = item.authHeaders(authState.token);

    // 计算播放进度
    final durationSec = item.durationSeconds ?? 0.0;
    final progressTicks = item.userData?.playbackPositionTicks ?? 0.0;
    final progressSec = progressTicks / 10000000.0;
    final progressPct = durationSec > 0
        ? (progressSec / durationSec).clamp(0.0, 1.0)
        : 0.0;

    return InkWell(
      onTap: () {
        Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => _HistoryPlayPage(item: item)),
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
              child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                  ? Image.network(
                      thumbnailUrl,
                      width: 120,
                      height: 72,
                      fit: BoxFit.cover,
                      headers: headers.isNotEmpty ? headers : null,
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
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.type,
                    style: const TextStyle(
                      color: Color(0xFFE91E63),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 进度条
                  if (progressPct > 0) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progressPct,
                              backgroundColor: Colors.white12,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                Color(0xFFE91E63),
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(progressPct * 100).toInt()}%',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (item.userData?.lastPlayedDate != null)
                    Text(
                      '上次观看：${item.userData!.lastPlayedDate!.split('T').first}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
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
