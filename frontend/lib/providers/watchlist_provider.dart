// 稍后观看（Watchlist）Provider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_item.dart';
import '../services/media_server_api.dart';
import 'providers.dart';

/// 稍后观看列表
final watchlistProvider =
    FutureProvider.autoDispose.family<List<MediaItem>, int>((ref, limit) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return <MediaItem>[];
  final svr = auth.embyServerUrl;
  final tkn = auth.token;
  if (svr == null || tkn == null) return <MediaItem>[];
  final service = ref.watch(embytokServiceProvider);
  final result = await service.getWatchlist(
    limit: limit,
    serverUrl: svr,
    token: tkn,
  );
  return result.items;
});

/// 稍后观看操作 Notifier
class WatchlistNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;
  WatchlistNotifier(this._ref) : super(<String>{});

  Future<void> toggle(MediaItem item, bool currentlyWatchlisted) async {
    final auth = _ref.read(authProvider);
    final svr = auth.embyServerUrl;
    final tkn = auth.token;
    if (svr == null || tkn == null) return;
    final service = _ref.read(embytokServiceProvider);
    await service.toggleWatchlist(
      itemId: item.id,
      isWatchlisted: !currentlyWatchlisted,
      serverUrl: svr,
      token: tkn,
    );
    // 失效缓存
    _ref.invalidate(watchlistProvider);
  }
}

final watchlistNotifierProvider =
    StateNotifierProvider<WatchlistNotifier, Set<String>>(
  (ref) => WatchlistNotifier(ref),
);
