// 稍后观看（Watchlist）Provider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_item.dart';
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
///
/// 维护本次会话内用户对 watchlist 状态的本地覆盖：
/// - 按钮初始状态以服务端 UserData.IsWatchlisted 为准
/// - 用户点击后，本地记录新状态，避免服务端返回旧值导致按钮闪烁
/// - 成功后失效 watchlistProvider 让列表页刷新
class WatchlistNotifier extends StateNotifier<Map<String, bool>> {
  WatchlistNotifier(this._ref) : super(<String, bool>{});
  final Ref _ref;

  /// 本地是否覆盖了该 item 的 watchlist 状态
  bool? localOverride(String itemId) => state[itemId];

  Future<void> toggle(MediaItem item, bool currentlyWatchlisted) async {
    final auth = _ref.read(authProvider);
    final svr = auth.embyServerUrl;
    final tkn = auth.token;
    if (svr == null || tkn == null) return;
    final newState = !currentlyWatchlisted;
    // 乐观更新：立即反映 UI
    state = {...state, item.id: newState};
    try {
      final service = _ref.read(embytokServiceProvider);
      await service.toggleWatchlist(
        itemId: item.id,
        isWatchlisted: newState,
        serverUrl: svr,
        token: tkn,
      );
      // 失效列表缓存
      _ref.invalidate(watchlistProvider);
    } catch (e) {
      // 失败回滚
      state = {...state, item.id: currentlyWatchlisted};
      // 重新抛出，让 UI 层显示错误提示
      rethrow;
    }
  }
}

final watchlistNotifierProvider =
    StateNotifierProvider<WatchlistNotifier, Map<String, bool>>(
  (ref) => WatchlistNotifier(ref),
);
