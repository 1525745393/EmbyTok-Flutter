// 观看历史页面：从 Emby 服务器获取最近观看的条目

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/error_state_card.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(watchHistoryProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: Row(
          children: [
            Icon(Icons.history, color: scheme.primary, size: 24),
            const SizedBox(width: 8),
            const Text('观看历史'),
          ],
        ),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(WatchHistoryState state) {
    if (state.isLoading && state.items.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: CircularProgressIndicator(color: scheme.primary),
      );
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorStateCard(
        title: state.error!,
        actionLabel: '重试',
        onAction: () {
          ref.read(watchHistoryProvider.notifier).load();
        },
      );
    }
    if (state.items.isEmpty) {
      return EmptyStateCard.noHistory();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = state.items[index];
        return _HistoryTile(key: Key(item.id), item: item);
      },
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  final MediaItem item;
  const _HistoryTile({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
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
        context.push('/play/${item.id}', extra: item);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.onSurface.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      width: 120,
                      height: 72,
                      fit: BoxFit.cover,
                      httpHeaders: headers.isNotEmpty ? headers : null,
                      memCacheWidth: 240,
                      placeholder: (_, __) => _thumbPlaceholder(scheme),
                      errorWidget: (_, __, ___) => _thumbPlaceholder(scheme),
                    )
                  : _thumbPlaceholder(scheme),
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
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.type,
                    style: TextStyle(
                      color: scheme.primary,
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
                              backgroundColor: scheme.onSurface.withOpacity(0.08),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                scheme.primary,
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(progressPct * 100).toInt()}%',
                          style: TextStyle(
                              color: scheme.onSurface.withOpacity(0.5), fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (item.userData?.lastPlayedDate != null)
                    Text(
                      '上次观看：${item.userData!.lastPlayedDate!.split('T').first}',
                      style: TextStyle(
                          color: scheme.onSurface.withOpacity(0.4), fontSize: 11),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder(ColorScheme scheme) => Container(
        width: 120,
        height: 72,
        color: scheme.surface.withOpacity(0.3),
        child: Icon(Icons.movie_outlined, color: scheme.onSurface.withOpacity(0.5)),
      );
}

class _HistoryPlayPage extends StatelessWidget {
  final MediaItem item;
  const _HistoryPlayPage({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: Text(item.title, style: const TextStyle(fontSize: 16)),
      ),
      body: VideoPageItem(item: item),
    );
  }
}
