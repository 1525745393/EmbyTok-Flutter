// 搜索建议 Provider：管理搜索建议列表

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';

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

  SearchHintsNotifier(this._ref, {EmbytokService? service})
      : _service = service ?? EmbytokService(),
        super(const SearchHintsState());

  AuthState get _auth => _ref.read(authProvider);

  // 获取搜索建议
  Future<void> fetchHints(String query) async {
    if (query.isEmpty) {
      state = const SearchHintsState();
      return;
    }

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

  // 清空建议
  void clear() {
    state = const SearchHintsState();
  }
}

/// 顶层搜索建议 Provider（状态管理版）
/// 
/// 注意：与 item_detail_provider.dart 中的 searchHintsProvider（FutureProvider版）区分
final searchHintsStateProvider =
    StateNotifierProvider<SearchHintsNotifier, SearchHintsState>((ref) {
  return SearchHintsNotifier(ref);
});
