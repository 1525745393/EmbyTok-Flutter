// 搜索建议 Provider：管理搜索建议列表
//
// 特性：
// 1. 防抖：300ms 内的连续输入只发起最后一次请求，减少 API 调用
// 2. 缓存：相同查询 30 秒内命中缓存，避免重复请求
// 3. 空查询：立即清空状态，不发起 API 请求

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/logger.dart';
import '../utils/memory_cache.dart';
import 'auth_provider.dart';

/// 搜索建议防抖时间
const Duration _kSearchHintsDebounce = Duration(milliseconds: 300);

/// 搜索建议缓存 TTL（短时间内重复搜索同一关键词时命中缓存）
const Duration _kSearchHintsCacheTtl = Duration(seconds: 30);

/// 搜索建议缓存最大条目数
const int _kSearchHintsCacheMaxSize = 20;

/// 搜索建议状态
class SearchHintsState {
  final List<SearchHint> hints;
  final String query;
  final bool isLoading;
  final String? error;

  const SearchHintsState({
    this.hints = const [],
    this.query = '',
    this.isLoading = false,
    this.error,
  });

  SearchHintsState copyWith({
    List<SearchHint>? hints,
    String? query,
    bool? isLoading,
    String? error,
  }) {
    return SearchHintsState(
      hints: hints ?? this.hints,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// 搜索建议 Notifier
class SearchHintsNotifier extends StateNotifier<SearchHintsState> {
  final Ref _ref;
  final EmbytokService _service;

  /// 防抖 Timer：连续输入时只保留最后一次
  Timer? _debounceTimer;

  /// 搜索结果缓存（短 TTL，避免短时间内重复搜索同一关键词）
  final MemoryCache<List<SearchHint>> _cache =
      MemoryCache<List<SearchHint>>(maxSize: _kSearchHintsCacheMaxSize);

  SearchHintsNotifier(this._ref, {EmbytokService? service})
      : _service = service ?? EmbytokService(),
        super(const SearchHintsState());

  AuthState get _auth => _ref.read(authProvider);

  /// 获取搜索建议（带防抖和缓存）
  ///
  /// 300ms 内的连续调用只发起最后一次请求。
  /// 相同查询 30 秒内命中缓存。
  void fetchHints(String query) {
    // 空查询：立即清空，取消 pending 请求
    if (query.isEmpty) {
      _debounceTimer?.cancel();
      state = const SearchHintsState();
      return;
    }

    // 防抖：取消上一次 pending 请求，300ms 后再执行
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_kSearchHintsDebounce, () {
      _doFetchHints(query);
    });
  }

  /// 实际执行搜索建议查询
  Future<void> _doFetchHints(String query) async {
    // 先检查缓存
    final cacheKey = '$query:${_auth.embyServerUrl}:${_auth.token}';
    final cached = _cache.get(cacheKey);
    if (cached != null) {
      state = SearchHintsState(
        hints: cached,
        query: query,
        isLoading: false,
        error: null,
      );
      return;
    }

    // 显示加载状态
    state = SearchHintsState(
      hints: const [],
      query: query,
      isLoading: true,
      error: null,
    );

    final auth = _auth;
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    if (!auth.isAuthenticated || serverUrl == null || token == null) {
      state = state.copyWith(isLoading: false, error: '尚未登录');
      return;
    }

    try {
      final hints = await _service.searchHints(
        query,
        limit: 10,
        serverUrl: serverUrl,
        token: token,
      );
      // 写入缓存
      _cache.set(cacheKey, hints, ttl: _kSearchHintsCacheTtl);
      state = SearchHintsState(
        hints: hints,
        query: query,
        isLoading: false,
        error: null,
      );
      AppLogger.debug('搜索建议获取成功', data: {'count': hints.length});
    } catch (e) {
      final message = e is String ? e : '获取搜索建议失败：$e';
      state = state.copyWith(isLoading: false, error: message);
      AppLogger.error('搜索建议获取失败', error: e);
    }
  }

  // 清空建议和缓存
  void clear() {
    _debounceTimer?.cancel();
    _cache.clear();
    state = const SearchHintsState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// 顶层搜索建议 Provider（状态管理版）
/// 
/// 注意：与 item_detail_provider.dart 中的 searchHintsProvider（FutureProvider版）区分
final searchHintsStateProvider =
    StateNotifierProvider<SearchHintsNotifier, SearchHintsState>((ref) {
  return SearchHintsNotifier(ref);
});
