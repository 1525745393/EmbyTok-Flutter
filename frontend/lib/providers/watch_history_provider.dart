// 观看历史：从 Emby 服务器获取最近观看的条目

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';
import 'cache_providers.dart';
import 'media_server_api_provider.dart';

/// 观看历史状态：从 Emby 获取最近播放（Resume）的视频列表
class WatchHistoryState {

  const WatchHistoryState({
    this.items = const <MediaItem>[],
    this.isLoading = false,
    this.error,
  });
  final List<MediaItem> items;
  final bool isLoading;
  final String? error;

  WatchHistoryState copyWith({
    List<MediaItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return WatchHistoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// 观看历史 Notifier
class WatchHistoryNotifier extends StateNotifier<WatchHistoryState> {

  WatchHistoryNotifier(this._ref) : super(const WatchHistoryState());
  final Ref _ref;

  // 从 Emby 服务器加载（走缓存仓库，短 TTL）
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    final auth = _ref.read(authProvider);

    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
      state = state.copyWith(isLoading: false, error: '尚未登录');
      return;
    }

    try {
      final items =
          await _ref.read(cachedMediaRepositoryProvider).getWatchHistory(
                limit: 50,
                userId: auth.user?.id,
                serverUrl: auth.embyServerUrl!,
                token: auth.token!,
              );
      state = WatchHistoryState(items: items);
      AppLogger.info('观看历史加载成功', data: {'count': items.length});
    } catch (e) {
      final message = e is String ? e : '加载观看历史失败：$e';
      state = state.copyWith(isLoading: false, error: message);
      AppLogger.error('加载观看历史失败', error: e);
    }
  }

  // 刷新观看历史
  Future<void> refresh() async {
    await load();
  }

  /// 删除单条历史记录（调用 Emby API 清除播放进度）
  Future<void> removeItem(String itemId) async {
    final auth = _ref.read(authProvider);
    if (auth.user?.id == null) return;
    try {
      await _ref.read(mediaServerApiProvider).markAsUnplayed(
            itemId,
            serverUrl: auth.embyServerUrl!,
            token: auth.token!,
          );
      state = state.copyWith(
        items: state.items.where((i) => i.id != itemId).toList(),
      );
      AppLogger.info('已删除历史记录', data: {'itemId': itemId});
    } catch (e) {
      AppLogger.error('删除历史记录失败', error: e);
    }
  }

  /// 一键清空全部历史（分批并发删除，每批 5 个）
  Future<void> clearAll() async {
    final items = List.of(state.items);
    for (var i = 0; i < items.length; i += 5) {
      final batch = items.sublist(
          i, i + 5 > items.length ? items.length : i + 5);
      await Future.wait(batch.map((item) => removeItem(item.id)));
    }
    state = state.copyWith(items: []);
  }
}

/// 顶层观看历史 Provider：从 Emby 获取最近播放的视频列表
///
/// UI 通过 `ref.watch(watchHistoryProvider)` 读取列表，
/// 通过 `ref.read(watchHistoryProvider.notifier).load()` 触发重新加载。
final watchHistoryProvider =
    StateNotifierProvider<WatchHistoryNotifier, WatchHistoryState>((ref) {
  return WatchHistoryNotifier(ref);
});
