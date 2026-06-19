// 搜索状态：关键词、结果分页、加载状态

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';

/// 搜索状态：关键字、结果列表、加载状态
class SearchState {
  final List<MediaItem> results;
  final String query;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int offset;
  final int limit;

  const SearchState({
    this.results = const <MediaItem>[],
    this.query = '',
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.offset = 0,
    this.limit = kDefaultPageLimit,
  });

  SearchState copyWith({
    List<MediaItem>? results,
    String? query,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? offset,
    int? limit,
  }) {
    return SearchState(
      results: results ?? this.results,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
    );
  }
}

// 搜索 Notifier
class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;
  final EmbytokService _service;

  SearchNotifier(this._ref, {EmbytokService? service})
      : _service = service ?? EmbytokService(),
        super(const SearchState());

  AuthState get _auth => _ref.read(authProvider);

  // 发起一次新搜索（重置状态）
  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = const SearchState();
      return;
    }

    AppLogger.info('开始搜索', data: {'query': query});

    state = SearchState(
      results: const <MediaItem>[],
      query: query,
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
      state = state.copyWith(isLoading: false, error: '尚未登录');
      return;
    }

    try {
      final resp = await _service.searchItems(
        query,
        limit: state.limit,
        offset: 0,
        serverUrl: auth.embyServerUrl!,
        token: auth.token!,
        userId: auth.user?.id,
      );
      final hasMore = resp.offset + resp.items.length < resp.total;
      state = SearchState(
        results: resp.items,
        query: query,
        isLoading: false,
        hasMore: hasMore,
        error: null,
        offset: resp.items.length,
        limit: state.limit,
      );
      AppLogger.debug('搜索完成', data: {'results': resp.items.length, 'total': resp.total});
    } catch (e) {
      final message = e is String ? e : '搜索失败：$e';
      state = state.copyWith(isLoading: false, error: message);
      AppLogger.error('搜索失败', error: e);
    }
  }

  // 加载更多搜索结果
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.query.isEmpty) return;

    AppLogger.debug('加载更多搜索结果', data: {'offset': state.offset});

    state = state.copyWith(isLoading: true, error: null);

    final auth = _auth;
    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
      state = state.copyWith(isLoading: false, error: '尚未登录');
      return;
    }

    try {
      final resp = await _service.searchItems(
        state.query,
        limit: state.limit,
        offset: state.offset,
        serverUrl: auth.embyServerUrl!,
        token: auth.token!,
        userId: auth.user?.id,
      );
      final newItems = <MediaItem>[...state.results, ...resp.items];
      final hasMore = state.offset + resp.items.length < resp.total;
      state = SearchState(
        results: newItems,
        query: state.query,
        isLoading: false,
        hasMore: hasMore,
        error: null,
        offset: state.offset + resp.items.length,
        limit: state.limit,
      );
      AppLogger.debug('加载更多成功', data: {'newCount': resp.items.length});
    } catch (e) {
      final message = e is String ? e : '加载更多失败：$e';
      state = state.copyWith(isLoading: false, error: message);
      AppLogger.error('加载更多搜索结果失败', error: e);
    }
  }
}

/// 顶层搜索 Provider：提供搜索结果、分页加载、错误提示
///
/// UI 通过 `ref.watch(searchProvider)` 读取搜索状态，
/// 通过 `ref.read(searchProvider.notifier).search('keyword')` 触发搜索。
final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});
