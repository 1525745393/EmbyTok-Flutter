// 媒体仓库抽象接口：定义媒体数据访问的统一契约
//
// 背景：
// video_list_provider.dart 中的 VideoListNotifier 直接依赖 EmbytokService，
// 导致业务逻辑与具体的 Emby API 强耦合。为支持未来的多数据源（Plex、Jellyfin、本地缓存等），
// 引入 Repository 层作为数据访问的抽象。
//
// 职责：
// ✅ 定义媒体数据访问的标准接口（列表、收藏、续播等）
// ✅ 屏蔽底层数据源差异（Emby / Plex / 本地缓存）
// ✅ 为单元测试提供 mock 点
// ❌ 不包含业务逻辑（分页去重、播放状态同步等在 Service/Provider 层处理）
// ❌ 不直接操作 UI 状态

import '../models/models.dart';

/// 分页参数：用于传递分页请求的通用参数
class MediaQueryParams {
  final String libraryId;
  final int limit;
  final int offset;
  final String? sortBy;
  final String? sortOrder;
  final String? searchTerm;
  final bool excludePlayed;

  const MediaQueryParams({
    required this.libraryId,
    this.limit = 50,
    this.offset = 0,
    this.sortBy,
    this.sortOrder,
    this.searchTerm,
    this.excludePlayed = false,
  });

  MediaQueryParams copyWith({
    String? libraryId,
    int? limit,
    int? offset,
    String? sortBy,
    String? sortOrder,
    String? searchTerm,
    bool? excludePlayed,
  }) {
    return MediaQueryParams(
      libraryId: libraryId ?? this.libraryId,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      searchTerm: searchTerm ?? this.searchTerm,
      excludePlayed: excludePlayed ?? this.excludePlayed,
    );
  }
}

/// 媒体仓库抽象接口
///
/// 所有媒体数据源（Emby、Plex、Jellyfin 等）都应实现此接口。
/// 上层业务（VideoListNotifier 等）只依赖此接口，不关心具体实现。
abstract class MediaRepository {
  /// 获取媒体库条目列表（支持分页、排序、搜索）
  ///
  /// 对应 Emby 的 Items 端点，是最通用的列表查询方法。
  Future<PaginatedResponse<MediaItem>> getLibraryItems(
    MediaQueryParams params, {
    required String serverUrl,
    required String token,
    String? userId,
  });

  /// 纯缓存读取媒体库条目列表，同步，不触发网络请求
  ///
  /// 仅从缓存中读取，缓存未命中或已过期时返回 null。
  PaginatedResponse<MediaItem>? peekLibraryItems(
    MediaQueryParams params, {
    required String serverUrl,
    required String token,
    String? userId,
  }) =>
      null;

  /// 获取单个媒体条目的详情
  ///
  /// 对应 Emby 的 /Users/{userId}/Items/{itemId} 端点。
  /// 包含 Overview、Genres、People、MediaSources、UserData 等完整字段。
  Future<MediaItem> getItemDetail(
    String itemId, {
    required String serverUrl,
    required String token,
    String? userId,
  });

  /// 获取收藏的电影/视频列表（支持分页）
  ///
  /// 收藏切换时数据会变，使用中 TTL 缓存，并在 toggleFavorite 后失效。
  Future<FavoritesPageResult> getFavoriteMovies({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  });

  /// 纯缓存读取收藏的电影/视频列表，同步，不触发网络请求
  ///
  /// 仅从缓存中读取，缓存未命中或已过期时返回 null。
  FavoritesPageResult? peekFavoriteMovies({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) =>
      null;

  /// 获取收藏的合集（BoxSet）列表（支持分页）
  ///
  /// 收藏切换时数据会变，使用中 TTL 缓存，并在 toggleFavorite 后失效。
  Future<FavoritesPageResult> getFavoriteBoxSets({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  });

  /// 纯缓存读取收藏的合集（BoxSet）列表，同步，不触发网络请求
  ///
  /// 仅从缓存中读取，缓存未命中或已过期时返回 null。
  FavoritesPageResult? peekFavoriteBoxSets({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) =>
      null;

  /// 获取续播列表（继续观看）
  Future<PaginatedResponse<MediaItem>> getResumeItems({
    required String serverUrl,
    required String token,
    int limit = 50,
    int offset = 0,
  });

  /// 获取媒体库列表（用户可用的 Views）
  ///
  /// 数据极少变更，适合长 TTL 缓存。
  Future<List<Library>> getLibraries({
    required String serverUrl,
    required String token,
    String? userId,
  });

  /// 获取「下一步观看」列表
  ///
  /// 看完一集后数据会变，适合短 TTL 缓存。
  Future<PaginatedResponse<MediaItem>> getNextUp({
    required String serverUrl,
    required String token,
    int limit = 20,
    String? seriesId,
  });

  /// 获取剧集的季列表
  ///
  /// 季列表很少变化，适合中 TTL 缓存。
  Future<List<MediaItem>> getSeasons(
    String seriesId, {
    required String serverUrl,
    required String token,
  });

  /// 获取剧集的集列表
  ///
  /// 集列表很少变化，适合中 TTL 缓存。
  Future<PaginatedResponse<MediaItem>> getEpisodes(
    String seriesId, {
    String? seasonId,
    int limit = 100,
    int offset = 0,
    required String serverUrl,
    required String token,
  });

  /// 获取相似推荐项目
  ///
  /// 相似推荐基于算法生成，短时间内稳定，适合中 TTL 缓存。
  Future<List<MediaItem>> getSimilarItems(
    String itemId, {
    int limit = 12,
    required String serverUrl,
    required String token,
  });

  /// 获取人员（演员/导演）列表
  ///
  /// 支持按类型和搜索词过滤。人员列表变化不频繁，适合中 TTL 缓存。
  /// 搜索场景应使用短 TTL，列表浏览场景可使用默认中 TTL。
  Future<PaginatedResponse<Person>> getPeople({
    int limit = 50,
    int startIndex = 0,
    List<String>? personTypes,
    String? searchTerm,
    required String serverUrl,
    required String token,
  });

  /// 获取单个演员的详情（包含 overview）
  ///
  /// 演员详情极少变化，适合长 TTL 缓存。
  Future<MediaItem?> getPersonDetail(
    String personId, {
    required String serverUrl,
    required String token,
    String? userId,
  });

  /// 获取某演员出演的作品列表
  ///
  /// 当用户标记作品已看时数据会变，使用中 TTL 缓存，并在 markAsPlayed 后失效。
  Future<PaginatedResponse<MediaItem>> getPersonItems(
    String personId, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  });

  /// 获取收藏的人物列表（支持分页）
  ///
  /// 收藏切换时数据会变，使用中 TTL 缓存，并在 toggleFavorite 后失效。
  Future<FavoritesPageResult> getFavoritePeople({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  });

  /// 纯缓存读取收藏的人物列表，同步，不触发网络请求
  ///
  /// 仅从缓存中读取，缓存未命中或已过期时返回 null。
  FavoritesPageResult? peekFavoritePeople({
    int limit = 50,
    int offset = 0,
    required String serverUrl,
    required String token,
    String? userId,
  }) =>
      null;

  /// 获取推荐列表（基于社区评分、是否已看等过滤）
  ///
  /// 推荐基于算法生成，短时间内稳定，适合中 TTL 缓存。
  /// 缓存键需包含 libraryId + minCommunityRating + excludePlayed + includeItemTypes，
  /// 因为相同 limit/offset 但不同过滤条件的结果不同。
  Future<PaginatedResponse<MediaItem>> getRecommendations({
    int limit = 20,
    int offset = 0,
    String? libraryId,
    String? userId,
    required String serverUrl,
    required String token,
    double minCommunityRating = 4.0,
    bool excludePlayed = true,
    Set<String>? includeItemTypes,
  });

  /// 获取建议列表（Emby 的 Suggestions 端点）
  ///
  /// 与推荐列表类似，短时间内稳定，适合中 TTL 缓存。
  Future<List<MediaItem>> getSuggestions({
    int limit = 20,
    String? userId,
    required String serverUrl,
    required String token,
  });

  /// 获取观看历史
  ///
  /// 用户播放/标记已看后数据会变，使用短 TTL 缓存，并在 markAsPlayed 后失效。
  Future<List<MediaItem>> getWatchHistory({
    int limit = 50,
    String? userId,
    required String serverUrl,
    required String token,
  });

  /// 获取父项的子项列表（如 BoxSet 内的电影、剧集的集等）
  ///
  /// 父项结构变化时数据会变，使用中 TTL 缓存。
  Future<List<MediaItem>> getChildren(
    String parentId, {
    int limit = 100,
    int offset = 0,
    required String serverUrl,
    required String token,
  });

  /// 获取所有类型（Genre）列表
  ///
  /// 类型列表极少变化，适合长 TTL 缓存。
  Future<List<Library>> getGenres({
    int limit = 100,
    required String serverUrl,
    required String token,
  });

  /// 获取指定类型下的影片列表
  ///
  /// 类型下的影片列表变化不频繁，使用中 TTL 缓存。
  Future<PaginatedResponse<MediaItem>> getItemsByGenre(
    String genre, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  });

  /// 获取所有工作室（Studio）列表
  ///
  /// 工作室列表极少变化，适合长 TTL 缓存。
  Future<List<Library>> getStudios({
    int limit = 100,
    required String serverUrl,
    required String token,
  });

  /// 获取指定工作室下的影片列表
  ///
  /// 工作室下的影片列表变化不频繁，使用中 TTL 缓存。
  Future<PaginatedResponse<MediaItem>> getItemsByStudio(
    String studio, {
    int limit = 30,
    int offset = 0,
    required String serverUrl,
    required String token,
  });
}
