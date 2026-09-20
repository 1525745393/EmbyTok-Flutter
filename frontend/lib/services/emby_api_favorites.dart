// 从 emby_server_api.dart 拆分（part 文件，无行为变化）

part of 'emby_server_api.dart';

// ==================== _EmbyFavoritesApi ====================

mixin _EmbyFavoritesApi on EmbyServerApiBase {
  Future<List<MediaItem>> getFavorites({
    int limit = 100,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'Filters': 'IsFavorite',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      'SortBy': 'DateCreated',
      'SortOrder': 'Descending',
    };
    final resp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: params,
    );
    final items = resp.data is List
        ? resp.data as List<dynamic>
        : (resp.data['Items'] as List<dynamic>?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => MediaItem.fromJson(e))
        .toList();
  }

  Future<FavoritesPageResult> getFavoriteMovies({
    int limit = 50,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
    CancelToken? cancelToken,
    List<String>? includeTypes,
    bool excludePlayed = false,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'Filters': 'IsFavorite',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData,People',
      'IncludeItemTypes': includeTypes != null && includeTypes.isNotEmpty
          ? includeTypes.join(',')
          : 'Movie,Episode,Video,MusicVideo,Series,BoxSet,Person',
      'ExcludeItemTypes': 'Playlist',
      'SortBy': 'DateCreated',
      'SortOrder': 'Descending',
    };
    // 修复：支持排除已观看
    // 正确用法是 IsUnplayed，而不是 IsPlayed=false
    if (excludePlayed) {
      params['Filters'] = 'IsFavorite,IsUnplayed';
    }

    final effectiveUserId = userId ?? _defaultUserId;
    final path = (effectiveUserId != null && effectiveUserId.isNotEmpty)
        ? '/Users/$effectiveUserId/Items'
        : '/Items';

    final resp = await _apiClient.get<dynamic>(
      path,
      queryParameters: params,
      cancelToken: cancelToken,
    );
    final data = resp.data;
    final items = data is List ? data : (data['Items'] as List<dynamic>?) ?? [];
    final totalCount = data is Map
        ? (data['TotalRecordCount'] as int?) ?? items.length
        : items.length;
    return FavoritesPageResult(
      items: items
          .whereType<Map<String, dynamic>>()
          .map((e) => MediaItem.fromJson(e))
          .toList(),
      totalCount: totalCount,
    );
  }

  Future<FavoritesPageResult> getFavoriteBoxSets({
    int limit = 50,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'Filters': 'IsFavorite',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      'IncludeItemTypes': 'BoxSet',
      'SortBy': 'DateCreated',
      'SortOrder': 'Descending',
    };

    final effectiveUserId = userId ?? _defaultUserId;
    final path = (effectiveUserId != null && effectiveUserId.isNotEmpty)
        ? '/Users/$effectiveUserId/Items'
        : '/Items';

    final resp = await _apiClient.get<dynamic>(
      path,
      queryParameters: params,
    );
    final data = resp.data;
    final items = data is List ? data : (data['Items'] as List<dynamic>?) ?? [];
    final totalCount = data is Map
        ? (data['TotalRecordCount'] as int?) ?? items.length
        : items.length;
    return FavoritesPageResult(
      items: items
          .whereType<Map<String, dynamic>>()
          .map((e) => MediaItem.fromJson(e))
          .toList(),
      totalCount: totalCount,
    );
  }

  Future<FavoritesPageResult> getFavoritePeople({
    int limit = 50,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final params = <String, dynamic>{
      'Limit': '$limit',
      'StartIndex': '$offset',
      'Recursive': 'true',
      'Filters': 'IsFavorite',
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      'IncludeItemTypes': 'Person',
      'SortBy': 'DateCreated',
      'SortOrder': 'Descending',
    };

    final effectiveUserId = userId ?? _defaultUserId;
    final path = (effectiveUserId != null && effectiveUserId.isNotEmpty)
        ? '/Users/$effectiveUserId/Items'
        : '/Items';

    final resp = await _apiClient.get<dynamic>(
      path,
      queryParameters: params,
    );
    final data = resp.data;
    final items = data is List ? data : (data['Items'] as List<dynamic>?) ?? [];
    final totalCount = data is Map
        ? (data['TotalRecordCount'] as int?) ?? items.length
        : items.length;
    return FavoritesPageResult(
      items: items
          .whereType<Map<String, dynamic>>()
          .map((e) => MediaItem.fromJson(e))
          .toList(),
      totalCount: totalCount,
    );
  }

  Future<void> toggleFavorite({
    required String itemId,
    required bool isFavorite,
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    AppLogger.debug('切换收藏状态请求', data: {
      'itemId': itemId,
      'isFavorite': isFavorite,
    });
    _ensureConfig(serverUrl, token);
    final effectiveUserId = userId ?? _defaultUserId;
    final path = (effectiveUserId ?? '').isNotEmpty
        ? '/Users/$effectiveUserId/FavoriteItems/$itemId'
        : '/UserFavoriteItems/$itemId';
    if (isFavorite) {
      await _apiClient.post<dynamic>(path);
    } else {
      await _apiClient.delete<dynamic>(path);
    }
    AppLogger.debug('收藏状态已更新');
  }

  Future<Map<String, int>> getFavoriteCounts({
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    const types = ['Movie', 'Series', 'BoxSet', 'Person'];
    final params = <String, dynamic>{
      'Filters': 'IsFavorite',
      'IncludeItemTypes': types.join(','),
    };
    final effectiveUserId = userId ?? _defaultUserId;
    final path = (effectiveUserId ?? '').isNotEmpty
        ? '/Users/$effectiveUserId/Items/Counts'
        : '/Items/Counts';
    try {
      final resp = await _apiClient.get<dynamic>(
        path,
        queryParameters: params,
      );
      final data = resp.data;
      if (data is Map<String, dynamic>) {
        final result = <String, int>{};
        for (final type in types) {
          result[type] = (data[type] as int?) ?? 0;
        }
        return result;
      }
      return {};
    } catch (e) {
      AppLogger.error('获取收藏数量失败', error: e);
      return {};
    }
  }

  Future<void> markAsPlayed(
    String itemId, {
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    await _apiClient.post<dynamic>('/UserPlayedItems/$itemId');
  }

  Future<void> markAsUnplayed(
    String itemId, {
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    await _apiClient.delete<dynamic>('/UserPlayedItems/$itemId');
  }
}
