// 视频列表分页加载：支持按媒体库筛选、下拉刷新与无限滚动

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import 'auth_provider.dart';

// 视频列表状态
class VideoListState {
  final List<MediaItem> items;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int offset;
  final int limit;
  final String? currentLibraryId;
  final String? currentLibraryType; // 新增：当前库类型

  const VideoListState({
    this.items = const <MediaItem>[],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.offset = 0,
    this.limit = 20,
    this.currentLibraryId,
    this.currentLibraryType,
  });

  VideoListState copyWith({
    List<MediaItem>? items,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? offset,
    int? limit,
    String? currentLibraryId,
    String? currentLibraryType,
  }) {
    return VideoListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
      currentLibraryId: currentLibraryId ?? this.currentLibraryId,
      currentLibraryType: currentLibraryType ?? this.currentLibraryType,
    );
  }
}

// 视频列表 Notifier
class VideoListNotifier extends StateNotifier<VideoListState> {
  final Ref _ref;
  final EmbytokService _service;

  VideoListNotifier(this._ref, {EmbytokService? service})
      : _service = service ?? EmbytokService(),
        super(const VideoListState());

  // ——— 辅助方法 ———
  void _setupServiceAuth() {
    final auth = _ref.read(authProvider);
    final embyServerUrl = auth.embyServerUrl;
    final userId = auth.user?.id;
    final token = auth.token;
    if (embyServerUrl != null && userId != null && token != null) {
      _service.setupAuth(
        embyServerUrl: embyServerUrl,
        userId: userId,
        apiKey: token,
      );
    }
  }

  bool get _hasAuth {
    final auth = _ref.read(authProvider);
    return auth.isAuthenticated &&
        auth.embyServerUrl != null &&
        auth.user?.id != null &&
        auth.token != null;
  }

  // ——— 刷新：重置偏移并加载第一页 ———
  Future<void> refresh({
    String? libraryId,
    String? libraryType,
  }) async {
    state = VideoListState(
      items: const <MediaItem>[],
      isLoading: true,
      hasMore: true,
      error: null,
      offset: 0,
      limit: state.limit,
      currentLibraryId: libraryId,
      currentLibraryType: libraryType,
    );

    if (!_hasAuth) {
      state = state.copyWith(isLoading: false, error: '尚未登录');
      return;
    }

    try {
      final targetLibraryId = libraryId ?? state.currentLibraryId;
      final targetLibraryType = libraryType ?? state.currentLibraryType;

      if (targetLibraryId == null || targetLibraryId.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      _setupServiceAuth();
      final resp = await _service.getItems(
        libraryId: targetLibraryId,
        libraryType: targetLibraryType,
        limit: state.limit,
        offset: 0,
      );

      final hasMore = resp.offset + resp.items.length < resp.total;
      state = VideoListState(
        items: resp.items,
        isLoading: false,
        hasMore: hasMore,
        error: null,
        offset: resp.items.length,
        limit: state.limit,
        currentLibraryId: targetLibraryId,
        currentLibraryType: targetLibraryType,
      );
    } catch (e) {
      final message = e is String ? e : '加载视频失败：$e';
      state = state.copyWith(isLoading: false, error: message);
    }
  }

  // ——— 加载更多：在当前列表末尾追加 ———
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);

    if (!_hasAuth) {
      state = state.copyWith(isLoading: false, error: '尚未登录');
      return;
    }

    try {
      _setupServiceAuth();
      final resp = await _service.getItems(
        libraryId: state.currentLibraryId,
        libraryType: state.currentLibraryType,
        limit: state.limit,
        offset: state.offset,
      );

      final newItems = <MediaItem>[...state.items, ...resp.items];
      final hasMore = state.offset + resp.items.length < resp.total;

      state = VideoListState(
        items: newItems,
        isLoading: false,
        hasMore: hasMore,
        error: null,
        offset: state.offset + resp.items.length,
        limit: state.limit,
        currentLibraryId: state.currentLibraryId,
        currentLibraryType: state.currentLibraryType,
      );
    } catch (e) {
      final message = e is String ? e : '加载更多失败：$e';
      state = state.copyWith(isLoading: false, error: message);
    }
  }
}

// 顶层 Provider
final videoListProvider =
    StateNotifierProvider<VideoListNotifier, VideoListState>((ref) {
  return VideoListNotifier(ref);
});
