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

  /// 最近收藏的影片所属合集
  /// Emby 的 BoxSet 本身不支持 IsFavorite 收藏标记，
  /// 因此改为：查询用户收藏的影片 → 提取 CollectionIds → 聚合去重 → 查询合集详情。
  Future<FavoritesPageResult> getFavoriteBoxSets({
    int limit = 50,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final effectiveUserId = userId ?? _defaultUserId;
    final path = (effectiveUserId != null && effectiveUserId.isNotEmpty)
        ? '/Users/$effectiveUserId/Items'
        : '/Items';

    // 第一步：循环翻页拉取收藏的影片，带上 CollectionIds 字段
    // 最多拉 5 页（每页 200，共 1000 条），避免无限循环
    final boxSetIdSet = <String>{};
    const pageSize = 200;
    const maxPages = 5;
    for (var page = 0; page < maxPages; page++) {
      final favoriteParams = <String, dynamic>{
        'Limit': '$pageSize',
        'StartIndex': '${page * pageSize}',
        'Recursive': 'true',
        'Filters': 'IsFavorite',
        'Fields': 'CollectionIds,ImageTags',
        'IncludeItemTypes': 'Movie,Episode,Series,Video',
        'SortBy': 'DateCreated',
        'SortOrder': 'Descending',
      };
      final favResp =
          await _apiClient.get<dynamic>(path, queryParameters: favoriteParams);
      final favData = favResp.data;
      final favItems = favData is List
          ? favData
          : (favData['Items'] as List<dynamic>?) ?? [];

      for (final item in favItems.whereType<Map<String, dynamic>>()) {
        final collectionIds = item['CollectionIds'];
        if (collectionIds is List) {
          for (final cid in collectionIds) {
            if (cid is String && cid.isNotEmpty) boxSetIdSet.add(cid);
          }
        }
      }

      // 不足一页说明已拉完
      if (favItems.length < pageSize) break;
    }

    if (boxSetIdSet.isEmpty) {
      return const FavoritesPageResult(items: [], totalCount: 0);
    }

    final allIds = boxSetIdSet.toList();
    final pagedIds = allIds.skip(offset).take(limit).toList(growable: false);

    // 第三步：按 Ids 批量查询合集详情
    final boxSetParams = <String, dynamic>{
      'Ids': pagedIds.join(','),
      'Fields':
          'Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,ImageTags,UserData',
      'Recursive': 'true',
      if (effectiveUserId != null && effectiveUserId.isNotEmpty)
        'UserId': effectiveUserId,
    };
    final boxResp = await _apiClient.get<dynamic>(
      '/Items',
      queryParameters: boxSetParams,
    );
    final boxData = boxResp.data;
    final boxItems =
        boxData is List ? boxData : (boxData['Items'] as List<dynamic>?) ?? [];

    return FavoritesPageResult(
      items: boxItems
          .whereType<Map<String, dynamic>>()
          .map((e) => MediaItem.fromJson(e))
          .toList(),
      totalCount: allIds.length,
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
    if (itemId.isEmpty) {
      throw AppError.unknown(message: 'itemId 为空，无法切换收藏');
    }
    _ensureConfig(serverUrl, token);
    final effectiveUserId = userId ?? _defaultUserId;
    final path = (effectiveUserId ?? '').isNotEmpty
        ? '/Users/$effectiveUserId/FavoriteItems/$itemId'
        : '/UserFavoriteItems/$itemId';
    try {
      if (isFavorite) {
        await _apiClient.post<dynamic>(path);
      } else {
        // 取消收藏：DELETE 请求（拦截器已自动移除无 body 时的 content-type）
        await _apiClient.delete<dynamic>(
          path,
          headers: const {'Content-Length': '0'},
        );
      }
    } on AppError catch (e) {
      // 403 时多层 fallback，覆盖 nginx/Cloudflare WAF 各种拦截配置
      if (e.statusCode == 403 && token != null && token.isNotEmpty) {
        AppLogger.warn('收藏请求 403，开始多层 fallback',
            data: {'path': path, 'isFavorite': isFavorite});

        // Fallback 1: DELETE + query parameter api_key
        try {
          if (isFavorite) {
            await _apiClient.post<dynamic>(
              path,
              queryParameters: {'api_key': token},
            );
          } else {
            await _apiClient.delete<dynamic>(
              path,
              queryParameters: {'api_key': token},
              headers: const {'Content-Length': '0'},
            );
          }
          AppLogger.debug('Fallback 1 成功（api_key）');
        } on AppError catch (e1) {
          if (e1.statusCode != 403) rethrow;
          // Fallback 2: POST + X-HTTP-Method-Override: DELETE
          // 绕过 Cloudflare/nginx 对 DELETE 方法的拦截
          AppLogger.warn('Fallback 1 仍 403，尝试 POST + Method-Override');
          try {
            final overrideHeaders = <String, dynamic>{
              'X-HTTP-Method-Override': 'DELETE',
            };
            if (!isFavorite) {
              overrideHeaders['Content-Length'] = '0';
            }
            await _apiClient.post<dynamic>(
              path,
              headers: overrideHeaders,
              data: isFavorite ? null : <String, dynamic>{},
            );
            AppLogger.debug('Fallback 2 成功（POST + Method-Override）');
          } on AppError catch (e2) {
            if (e2.statusCode != 403) rethrow;
            // Fallback 3: POST + Method-Override + api_key
            AppLogger.warn('Fallback 2 仍 403，尝试 POST + Method-Override + api_key');
            try {
              final overrideHeaders = <String, dynamic>{
                'X-HTTP-Method-Override': 'DELETE',
              };
              if (!isFavorite) {
                overrideHeaders['Content-Length'] = '0';
              }
              await _apiClient.post<dynamic>(
                path,
                queryParameters: {'api_key': token},
                headers: overrideHeaders,
                data: isFavorite ? null : <String, dynamic>{},
              );
              AppLogger.debug('Fallback 3 成功（POST + Method-Override + api_key）');
            } on AppError catch (e3) {
              if (e3.statusCode == 403) {
                throw AppError.forbidden(
                  message:
                      '服务器拒绝了收藏请求（403）。已尝试 DELETE、api_key、POST+Method-Override 多种方式均被拦截。请检查 Cloudflare/nginx WAF 规则是否允许对 Emby API 的写操作。',
                );
              }
              rethrow;
            }
          }
        }
      } else {
        rethrow;
      }
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

  // ==================== Watchlist（稍后观看） ====================

  /// 获取稍后观看列表
  ///
  /// 注意：`Filters=IsWatchlisted` 需要 Emby Server 4.8+。
  /// 旧版本服务器会返回 400 "Requested value 'IsWatchlisted' was not found"，
  /// 此时优雅降级为空列表，而不是把错误抛给用户。
  Future<FavoritesPageResult> getWatchlist({
    int limit = 50,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    _ensureConfig(serverUrl, token);
    final effectiveUserId = userId ?? _defaultUserId;
    final path = (effectiveUserId ?? '').isNotEmpty
        ? '/Users/$effectiveUserId/Items'
        : '/Items';
    try {
      final resp = await _apiClient.get<dynamic>(
        path,
        queryParameters: {
          'Filters': 'IsWatchlisted',
          'Recursive': 'true',
          'IncludeMediaTypes': 'Video',
          'Limit': '$limit',
          'StartIndex': '$offset',
          'SortBy': 'DateUpdated,SortName',
          'SortOrder': 'Descending,Ascending',
        },
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
    } catch (e) {
      // 旧版 Emby 不支持 IsWatchlisted filter：降级为空列表
      final msg = e.toString();
      if (msg.contains('IsWatchlisted') || msg.contains('not found')) {
        AppLogger.info('服务器不支持 IsWatchlisted 过滤器，稍后观看列表为空', data: {'error': msg});
        return const FavoritesPageResult(items: [], totalCount: 0);
      }
      rethrow;
    }
  }

  /// 切换稍后观看状态
  Future<void> toggleWatchlist({
    required String itemId,
    required bool isWatchlisted,
    String? userId,
    String? serverUrl,
    String? token,
  }) async {
    AppLogger.debug('切换稍后观看状态请求', data: {
      'itemId': itemId,
      'isWatchlisted': isWatchlisted,
    });
    if (itemId.isEmpty) {
      throw AppError.unknown(message: 'itemId 为空，无法切换稍后观看');
    }
    _ensureConfig(serverUrl, token);
    final effectiveUserId = userId ?? _defaultUserId;
    final params = <String, dynamic>{
      if (effectiveUserId != null && effectiveUserId.isNotEmpty)
        'UserId': effectiveUserId,
    };
    final path = '/Items/$itemId/Watchlist';
    if (isWatchlisted) {
      await _apiClient.post<dynamic>(path, queryParameters: params);
    } else {
      await _apiClient.delete<dynamic>(path, queryParameters: params);
    }
  }
}
