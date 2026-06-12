// 视频列表分页加载：支持按媒体库筛选、下拉刷新与无限滚动

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/constants.dart';
import 'auth_provider.dart';
import 'library_provider.dart';

// 视频列表状态
class VideoListState {
  final List<MediaItem> items;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int offset;
  final int limit;

  const VideoListState({
    this.items = const <MediaItem>[],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.offset = 0,
    this.limit = kDefaultPageLimit,
  });

  VideoListState copyWith({
    List<MediaItem>? items,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? offset,
    int? limit,
  }) {
    return VideoListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
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

  // 读取认证信息
  AuthState get _auth => _ref.read(authProvider);

  // 刷新：重置偏移并加载第一页
  Future<void> refresh({String? libraryId}) async {
    state = VideoListState(
      items: const <MediaItem>[],
      isLoading: true,
      hasMore: true,
      error: null,
      offset: 0,
      limit: state.limit,
    );

    final auth = _auth;
    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
      state = state.copyWith(
        isLoading: false,
        error: '尚未登录',
      );
      return;
    }

    try {
      final targetLibraryId = libraryId ?? _ref.read(selectedLibraryIdProvider);
      if (targetLibraryId == null || targetLibraryId.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final resp = await _service.getLibraryItems(
        targetLibraryId,
        limit: state.limit,
        offset: 0,
        serverUrl: auth.embyServerUrl!,
        token: auth.token!,
      );

      final hasMore = resp.offset + resp.items.length < resp.total;
      state = VideoListState(
        items: resp.items,
        isLoading: false,
        hasMore: hasMore,
        error: null,
        offset: resp.items.length,
        limit: state.limit,
      );
    } catch (e) {
      final message = e is String ? e : '加载视频失败：$e';
      state = state.copyWith(isLoading: false, error: message);
    }
  }

  // 加载更多：在当前列表末尾追加
  Future<void> loadMore({String? libraryId}) async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);

    final auth = _auth;
    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
      state = state.copyWith(isLoading: false, error: '尚未登录');
      return;
    }

    try {
      final targetLibraryId = libraryId ?? _ref.read(selectedLibraryIdProvider);
      if (targetLibraryId == null || targetLibraryId.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final resp = await _service.getLibraryItems(
        targetLibraryId,
        limit: state.limit,
        offset: state.offset,
        serverUrl: auth.embyServerUrl!,
        token: auth.token!,
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
