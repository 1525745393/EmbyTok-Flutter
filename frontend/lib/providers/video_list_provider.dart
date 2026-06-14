// 基于 Emby 原生 API 的视频列表分页加载：支持多种浏览模式
// Task 2 改造：支持 feedType(latest/random/favorites)、orientationMode、hiddenLibraryIds

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/app_preferences.dart';
import '../utils/constants.dart';
import 'app_preferences_providers.dart';
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
  final FeedType feedType;
  final OrientationMode orientationMode;
  final Set<String> hiddenLibraryIds;

  const VideoListState({
    this.items = const <MediaItem>[],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.offset = 0,
    this.limit = kDefaultPageLimit,
    this.feedType = FeedType.latest,
    this.orientationMode = OrientationMode.both,
    this.hiddenLibraryIds = const <String>{},
  });

  VideoListState copyWith({
    List<MediaItem>? items,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? offset,
    int? limit,
    FeedType? feedType,
    OrientationMode? orientationMode,
    Set<String>? hiddenLibraryIds,
  }) {
    return VideoListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
      feedType: feedType ?? this.feedType,
      orientationMode: orientationMode ?? this.orientationMode,
      hiddenLibraryIds: hiddenLibraryIds ?? this.hiddenLibraryIds,
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

  // 获取当前活跃的 feedType
  FeedType get _currentFeedType => _ref.read(feedTypeProvider);

  // 获取当前 orientationMode
  OrientationMode get _currentOrientation => _ref.read(orientationModeProvider);

  // 获取隐藏媒体库 ID 集合
  Set<String> get _hiddenLibraries => _ref.read(hiddenLibraryIdsProvider);

  // 根据 libraryId 获取对应 library 的 type
  String? _findLibraryType(String libraryId) {
    final libs = _ref.read(libraryListProvider).value;
    if (libs == null || libs.isEmpty) return null;
    final matched = libs.firstWhere((lib) => lib.id == libraryId,
        orElse: () => libs.first);
    return matched.type;
  }

  // 根据 orientationMode 决定 IncludeItemTypes
  // 竖屏模式：只加载 HomeVideo/Video（更可能是竖屏）
  // 横屏模式：加载 Movie/MusicVideo
  // 全部模式：加载所有
  String _buildIncludeItemTypes(String? libraryType) {
    final orientation = _currentOrientation;
    // 如果是 HomeVideos/Photos 类库，直接用默认逻辑即可
    if (libraryType == 'homevideos' || libraryType == 'photos') {
      return includeItemTypesForLibraryType(libraryType);
    }
    switch (orientation) {
      case OrientationMode.vertical:
        // 竖屏模式：允许 HomeVideo/Video/Photo 等短内容
        return 'HomeVideo,Video,Movie';
      case OrientationMode.horizontal:
        // 横屏模式：优先 Movie/Series/MusicVideo
        return 'Movie,Series,MusicVideo';
      case OrientationMode.both:
        // 全部模式：保留 libraryType 的默认逻辑
        return includeItemTypesForLibraryType(libraryType);
    }
  }

  // 加载指定 libraryId 的视频列表（支持 feedType）
  Future<PaginatedResponse<MediaItem>> _loadItems({
    required String libraryId,
    required String? libraryType,
    required int offset,
    required int limit,
    required FeedType feedType,
    required AuthState auth,
  }) async {
    switch (feedType) {
      case FeedType.latest:
        return _service.getLibraryItems(
          libraryId,
          limit: limit,
          offset: offset,
          libraryType: libraryType,
          sortBy: 'DateCreated,SortName',
          includeItemTypes: _buildIncludeItemTypes(libraryType),
          serverUrl: auth.embyServerUrl!,
          token: auth.token!,
        );
      case FeedType.random:
        return _service.getLibraryItems(
          libraryId,
          limit: limit,
          offset: offset,
          libraryType: libraryType,
          sortBy: 'Random',
          includeItemTypes: _buildIncludeItemTypes(libraryType),
          serverUrl: auth.embyServerUrl!,
          token: auth.token!,
        );
      case FeedType.favorites:
        // 收藏模式：使用 Emby UserData 中的 Favorite 标志
        return _service.getLibraryItems(
          libraryId,
          limit: limit,
          offset: offset,
          libraryType: libraryType,
          sortBy: 'DateCreated,SortName',
          includeItemTypes: _buildIncludeItemTypes(libraryType),
          serverUrl: auth.embyServerUrl!,
          token: auth.token!,
        );
    }
  }

  // 过滤收藏项：仅保留 isFavorite=true 的
  List<MediaItem> _filterFavorites(List<MediaItem> items) {
    return items.where((item) {
      return item.userData?.isFavorite == true || item.isFavorite == true;
    }).toList();
  }

  // 刷新：重置偏移并加载第一页
  Future<void> refresh({String? libraryId}) async {
    final feedType = _currentFeedType;
    final orientation = _currentOrientation;
    final hiddenIds = _hiddenLibraries;

    state = VideoListState(
      items: const <MediaItem>[],
      isLoading: true,
      hasMore: true,
      error: null,
      offset: 0,
      limit: state.limit,
      feedType: feedType,
      orientationMode: orientation,
      hiddenLibraryIds: hiddenIds,
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

      final libraryType = _findLibraryType(targetLibraryId);
      final resp = await _loadItems(
        libraryId: targetLibraryId,
        libraryType: libraryType,
        offset: 0,
        limit: state.limit,
        feedType: feedType,
        auth: auth,
      );

      final filtered =
          feedType == FeedType.favorites ? _filterFavorites(resp.items) : resp.items;
      final hasMore = resp.offset + filtered.length < resp.total;

      state = VideoListState(
        items: filtered,
        isLoading: false,
        hasMore: hasMore,
        error: null,
        offset: filtered.length,
        limit: state.limit,
        feedType: feedType,
        orientationMode: orientation,
        hiddenLibraryIds: hiddenIds,
      );
    } catch (e) {
      final message = e is String ? e : '加载视频失败：$e';
      state = state.copyWith(isLoading: false, error: message);
    }
  }

  // 加载更多：在当前列表末尾追加
  Future<void> loadMore({String? libraryId}) async {
    if (state.isLoading || !state.hasMore) return;

    final feedType = _currentFeedType;
    final orientation = _currentOrientation;

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

      final libraryType = _findLibraryType(targetLibraryId);
      final resp = await _loadItems(
        libraryId: targetLibraryId,
        libraryType: libraryType,
        offset: state.offset,
        limit: state.limit,
        feedType: feedType,
        auth: auth,
      );

      final filtered =
          feedType == FeedType.favorites ? _filterFavorites(resp.items) : resp.items;
      final newItems = <MediaItem>[...state.items, ...filtered];
      final hasMore = state.offset + filtered.length < resp.total;

      state = VideoListState(
        items: newItems,
        isLoading: false,
        hasMore: hasMore,
        error: null,
        offset: state.offset + filtered.length,
        limit: state.limit,
        feedType: feedType,
        orientationMode: orientation,
        hiddenLibraryIds: _hiddenLibraries,
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
