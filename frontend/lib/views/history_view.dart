// 观看历史页面：从 Emby 服务器获取最近观看的条目

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/colors.dart';
import '../widgets/video_page_item.dart';

class HistoryView extends ConsumerStatefulWidget {
  const HistoryView({super.key});

  @override
  ConsumerState<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends ConsumerState<HistoryView>
    with AutomaticKeepAliveClientMixin<HistoryView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(watchHistoryProvider.notifier).load();
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(watchHistoryProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        title: const Row(
          children: [
            Icon(Icons.history, color: historyPink, size: 24),
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
        child: CircularProgressIndicator(color: primaryPink),
      );
    }
    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: errorColor, size: 48),
            const SizedBox(height: 12),
            Text(state.error!,
                style: const TextStyle(color: textSecondary)),
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
            Icon(Icons.movie_outlined, size: 80, color: textPlaceholder),
            SizedBox(height: 16),
            Text('暂无观看历史',
                style: TextStyle(color: textSecondary, fontSize: 18)),
            SizedBox(height: 8),
            Text('开始观看后将自动记录',
                style: TextStyle(color: textTertiary, fontSize: 14)),
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
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dividerColor),
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
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.type,
                    style: const TextStyle(
                      color: primaryPink,
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
                              backgroundColor: dividerColor,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                primaryPink,
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(progressPct * 100).toInt()}%',
                          style: const TextStyle(
                              color: textTertiary, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (item.userData?.lastPlayedDate != null)
                    Text(
                      '上次观看：${item.userData!.lastPlayedDate!.split('T').first}',
                      style: const TextStyle(
                          color: textQuaternary, fontSize: 11),
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
        color: surfaceColorL3,
        child: Icon(Icons.movie_outlined, color: textPlaceholder),
      );
}

class _HistoryPlayPage extends StatelessWidget {
  final MediaItem item;
  const _HistoryPlayPage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        title: Text(item.title, style: const TextStyle(fontSize: 16)),
      ),
      body: VideoPageItem(item: item),
    );
  }
}
