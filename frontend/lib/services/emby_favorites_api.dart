import 'package:dio/dio.dart';
import '../models/models.dart';

abstract interface class EmbyFavoritesApi {
  // ============================

  /// 收藏列表（从服务器获取）
  Future<List<MediaItem>> getFavorites({
    int limit = 100,
    int offset = 0,
    String? serverUrl,
    String? token,
  });

  /// 收藏影片（按类型：电影/剧集/音乐视频/单集）
  Future<FavoritesPageResult> getFavoriteMovies({
    int limit = 50,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
    CancelToken? cancelToken,
    List<String>? includeTypes,
    bool excludePlayed = false,
  });

  /// 收藏合集（BoxSet）
  Future<FavoritesPageResult> getFavoriteBoxSets({
    int limit = 50,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
  });

  /// 收藏人物（Person）
  Future<FavoritesPageResult> getFavoritePeople({
    int limit = 50,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
  });

  /// 获取收藏的各类型数量
  Future<Map<String, int>> getFavoriteCounts({
    String? userId,
    String? serverUrl,
    String? token,
  });

  /// 切换收藏状态
  Future<void> toggleFavorite({
    required String itemId,
    required bool isFavorite,
    String? userId,
    String? serverUrl,
    String? token,
  });

  /// 获取稍后观看列表
  Future<FavoritesPageResult> getWatchlist({
    int limit = 50,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
  });

  /// 切换稍后观看状态
  Future<void> toggleWatchlist({
    required String itemId,
    required bool isWatchlisted,
    String? userId,
    String? serverUrl,
    String? token,
  });

  /// 标记已看
  Future<void> markAsPlayed(
    String itemId, {
    String? serverUrl,
    String? token,
  });

  /// 标记未看
  Future<void> markAsUnplayed(
    String itemId, {
    String? serverUrl,
    String? token,
  });
}
