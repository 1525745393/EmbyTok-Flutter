// 观看历史：从 Emby 服务器获取最近观看的条目

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';

// 观看历史状态
class WatchHistoryState {
  final List<MediaItem> items;
  final bool isLoading;
  final String? error;

  const WatchHistoryState({
    this.items = const <MediaItem>[],
    this.isLoading = false,
    this.error,
  });

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
  final Ref _ref;
  final EmbytokService _service;

  WatchHistoryNotifier(this._ref)
      : _service = EmbytokService(),
        super(const WatchHistoryState()) {
    load();
  }

  // 从 Emby 服务器加载
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
      final items = await _service.getWatchHistory(
        limit: 50,
        serverUrl: auth.embyServerUrl,
        token: auth.token,
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
}

// 顶层 Provider
final watchHistoryProvider =
    StateNotifierProvider<WatchHistoryNotifier, WatchHistoryState>((ref) {
  return WatchHistoryNotifier(ref);
});
