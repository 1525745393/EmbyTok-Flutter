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

  /// 获取收藏的电影/视频列表
  Future<FavoritesPageResult> getFavoriteMovies({
    required String serverUrl,
    required String token,
    String? userId,
  });

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
}
