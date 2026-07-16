// 搜索状态：关键词、结果分页、加载状态、分组搜索

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';

/// 搜索分组类型
enum SearchCategory {
  all,
  movies,
  videos,
  persons,
  genres,
  tags,
}

/// 搜索分组配置
const searchCategories = [
  {'category': SearchCategory.all, 'label': '热门结果'},
  {'category': SearchCategory.movies, 'label': '影片'},
  {'category': SearchCategory.videos, 'label': '视频'},
  {'category': SearchCategory.persons, 'label': '人物'},
  {'category': SearchCategory.genres, 'label': '类型'},
  {'category': SearchCategory.tags, 'label': '标签'},
];

/// 搜索人物结果
class SearchPerson {
  final String id;
  final String name;
  final String? imageUrl;
  final String? overview;

  const SearchPerson({
    required this.id,
    required this.name,
    this.imageUrl,
    this.overview,
  });

  factory SearchPerson.fromJson(Map<String, dynamic> json, String serverUrl, String? token) {
    final id = (json['Id'] as String?) ?? '';
    final imageTags = json['ImageTags'] as Map<String, dynamic>?;
    String? imageUrl;
    if (imageTags != null && imageTags.containsKey('Primary')) {
      final tag = imageTags['Primary'] as String?;
      if (tag != null && tag.isNotEmpty) {
        final authParam = token != null && token.isNotEmpty ? '&api_key=$token' : '';
        imageUrl = '$serverUrl/Items/$id/Images/Primary?MaxWidth=300&Format=jpg$authParam';
      }
    }
    return SearchPerson(
      id: id,
      name: (json['Name'] as String?) ?? '',
      imageUrl: imageUrl,
      overview: json['Overview'] as String?,
    );
  }
}

/// 搜索状态：关键字、结果列表、加载状态
class SearchState {
  final List<MediaItem> results;
  final String query;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int offset;
  final int limit;
  final int total;
  final List<String> includeTypes;
  final SearchCategory category;
  final List<SearchPerson> persons;
  final bool isLoadingPersons;

  const SearchState({
    this.results = const <MediaItem>[],
    this.query = '',
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.offset = 0,
    this.limit = kDefaultPageLimit,
    this.total = 0,
    this.includeTypes = const [],
    this.category = SearchCategory.all,
    this.persons = const [],
    this.isLoadingPersons = false,
  });

  SearchState copyWith({
    List<MediaItem>? results,
    String? query,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? offset,
    int? limit,
    int? total,
    List<String>? includeTypes,
    SearchCategory? category,
    List<SearchPerson>? persons,
    bool? isLoadingPersons,
  }) {
    return SearchState(
      results: results ?? this.results,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
      total: total ?? this.total,
      includeTypes: includeTypes ?? this.includeTypes,
      category: category ?? this.category,
      persons: persons ?? this.persons,
      isLoadingPersons: isLoadingPersons ?? this.isLoadingPersons,
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

  // 根据分组获取媒体类型列表
  List<String>? _typesFromCategory(SearchCategory category) {
    switch (category) {
      case SearchCategory.movies:
        return ['Movie'];
      case SearchCategory.videos:
        return ['Video', 'Episode'];
      case SearchCategory.genres:
        return null;
      case SearchCategory.tags:
        return null;
      case SearchCategory.persons:
        return null;
      case SearchCategory.all:
      default:
        return null;
    }
  }

  // 发起一次新搜索（重置状态）
  Future<void> search(String query, {SearchCategory? category}) async {
    final searchCategory = category ?? SearchCategory.all;

    if (query.isEmpty) {
      state = const SearchState();
      return;
    }

    AppLogger.info('开始搜索', data: {'query': query, 'category': searchCategory.name});

    state = SearchState(
      results: const <MediaItem>[],
      query: query,
      isLoading: searchCategory != SearchCategory.persons,
      hasMore: true,
      error: null,
      offset: 0,
      limit: state.limit,
      includeTypes: _typesFromCategory(searchCategory) ?? const [],
      category: searchCategory,
      persons: const [],
      isLoadingPersons: searchCategory == SearchCategory.persons,
    );

    final auth = _auth;
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    final userId = auth.user?.id;
    if (!auth.isAuthenticated || serverUrl == null || token == null) {
      state = state.copyWith(isLoading: false, isLoadingPersons: false, error: '尚未登录');
      return;
    }

    try {
      if (searchCategory == SearchCategory.persons) {
        await _searchPersons(query, serverUrl, token);
      } else {
        await _searchMedia(query, serverUrl, token, userId, searchCategory);
      }
    } catch (e) {
      final message = e is String ? e : '搜索失败：$e';
      state = state.copyWith(isLoading: false, isLoadingPersons: false, error: message);
      AppLogger.error('搜索失败', error: e);
    }
  }

  // 搜索媒体项
  Future<void> _searchMedia(String query, String serverUrl, String token, String? userId, SearchCategory category) async {
    final includeTypes = _typesFromCategory(category);
    final resp = await _service.searchItems(
      query,
      limit: state.limit,
      offset: 0,
      includeTypes: includeTypes,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
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
      total: resp.total,
      includeTypes: includeTypes ?? const [],
      category: category,
      persons: const [],
      isLoadingPersons: false,
    );
    AppLogger.debug('搜索完成', data: {'results': resp.items.length, 'total': resp.total});
  }

  // 搜索人物
  Future<void> _searchPersons(String query, String serverUrl, String token) async {
    final items = await _service.searchPersons(
      query,
      limit: 20,
      serverUrl: serverUrl,
      token: token,
    );
    final persons = items
        .map((e) => SearchPerson.fromJson(e, serverUrl, token))
        .toList();
    state = SearchState(
      results: const [],
      query: query,
      isLoading: false,
      hasMore: false,
      error: null,
      offset: 0,
      limit: state.limit,
      total: persons.length,
      includeTypes: const [],
      category: SearchCategory.persons,
      persons: persons,
      isLoadingPersons: false,
    );
    AppLogger.debug('人物搜索完成', data: {'results': persons.length});
  }

  // 加载更多搜索结果
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.query.isEmpty) return;

    AppLogger.debug('加载更多搜索结果', data: {'offset': state.offset});

    state = state.copyWith(isLoading: true, error: null);

    final auth = _auth;
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    final userId = auth.user?.id;
    if (!auth.isAuthenticated || serverUrl == null || token == null) {
      state = state.copyWith(isLoading: false, error: '尚未登录');
      return;
    }

    try {
      final resp = await _service.searchItems(
        state.query,
        limit: state.limit,
        offset: state.offset,
        includeTypes: state.includeTypes.isNotEmpty ? state.includeTypes : null,
        serverUrl: serverUrl,
        token: token,
        userId: userId,
      );
      final newItems = <MediaItem>[...state.results, ...resp.items];
      final hasMore = state.offset + resp.items.length < resp.total;
      state = state.copyWith(
        results: newItems,
        isLoading: false,
        hasMore: hasMore,
        offset: state.offset + resp.items.length,
        total: resp.total,
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
