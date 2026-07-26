import 'package:dio/dio.dart';

import '../models/models.dart';

abstract class MediaServerApi {
  // ============================
  // 认证与用户相关
  // ============================

  /// 设置默认认证信息，后续调用可省略参数
  void setupAuth({
    required String embyServerUrl,
    required String apiKey,
    String? userId,
  });

  /// 清除认证信息
  void clearAuth();

  /// 用户登录，返回用户信息和访问令牌
  Future<User> login({
    required String embyServerUrl,
    required String username,
    required String password,
  });

  // ============================
  // 媒体库与视图
  // ============================

  /// 获取媒体库列表
  ///
  /// 优先使用用户视角 /Users/{userId}/Views，向后兼容 /Library/VirtualFolders
  Future<List<Library>> getLibraries({
    String? userId,
    String? serverUrl,
    String? token,
  });

  /// 获取用户视图（getLibraries 的别名，语义更明确）
  Future<List<Library>> getUserViews({
    String? userId,
    String? serverUrl,
    String? token,
  });

  // ============================
  // 媒体列表与详情
  // ============================

  /// 获取某媒体库下的视频列表
  Future<PaginatedResponse<MediaItem>> getLibraryItems(
    String libraryId, {
    int limit = 20,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
    String sortBy = 'DateCreated,SortName',
    String sortOrder = 'Descending',
    String? searchTerm,
    bool excludePlayed = false,
    CancelToken? cancelToken,
  });

  /// 获取项详情
  Future<MediaItem> getItemDetail(
    String itemId, {
    String? userId,
    String? serverUrl,
    String? token,
  });

  /// 获取子项（孩子节点）
  Future<List<MediaItem>> getChildren(
    String parentId, {
    int limit = 100,
    int offset = 0,
    String? serverUrl,
    String? token,
  });

  /// 删除指定的媒体项
  Future<void> deleteItem({
    required String itemId,
    required String serverUrl,
    required String token,
  });

  // ============================
  // 推荐与发现
  // ============================

  /// 继续观看列表
  Future<PaginatedResponse<MediaItem>> getResumeItems({
    int limit = 20,
    int offset = 0,
    String? serverUrl,
    String? token,
    CancelToken? cancelToken,
  });

  /// 推荐列表
  ///
  /// 按社区评分从高到低排序，默认排除已观看
  Future<PaginatedResponse<MediaItem>> getRecommendations({
    int limit = 20,
    int offset = 0,
    String? libraryId,
    String? userId,
    String? serverUrl,
    String? token,
    double minCommunityRating = 4.0,
    bool excludePlayed = true,
    Set<String>? includeItemTypes,
  });

  /// 个性化推荐
  ///
  /// 基于 Suggestions API，利用观看历史做智能推荐
  Future<List<MediaItem>> getSuggestions({
    int limit = 20,
    String? userId,
    String? serverUrl,
    String? token,
  });

  /// Next Up（下一步看什么）—— 剧集的下一集
  ///
  /// 可选 seriesId：传入则只返回指定剧集的下一集
  Future<PaginatedResponse<MediaItem>> getNextUp({
    int limit = 20,
    String? seriesId,
    String? serverUrl,
    String? token,
  });

  /// 最近添加
  Future<PaginatedResponse<MediaItem>> getRecentlyAdded({
    int limit = 20,
    int offset = 0,
    String? libraryId,
    String? userId,
    String? serverUrl,
    String? token,
  });

  /// 相似影片
  Future<List<MediaItem>> getSimilarItems(
    String itemId, {
    int limit = 20,
    String? serverUrl,
    String? token,
  });

  /// 预告片
  Future<PaginatedResponse<MediaItem>> getTrailers({
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  });

  // ============================
  // 剧集相关
  // ============================

  /// 剧集季列表
  Future<List<MediaItem>> getSeasons(
    String seriesId, {
    String? serverUrl,
    String? token,
  });

  /// 剧集集列表
  Future<PaginatedResponse<MediaItem>> getEpisodes(
    String seriesId, {
    String? seasonId,
    int limit = 100,
    int offset = 0,
    String? serverUrl,
    String? token,
  });

  // ============================
  // 人员相关
  // ============================

  /// 人员（演员/导演）列表
  Future<PaginatedResponse<Person>> getPeople({
    int limit = 50,
    int startIndex = 0,
    List<String>? personTypes,
    String? searchTerm,
    String? serverUrl,
    String? token,
  });

  /// 某演员出演的作品
  Future<PaginatedResponse<MediaItem>> getPersonItems(
    String personId, {
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  });

  /// 获取单个演员详情（包含 overview）
  Future<MediaItem?> getPersonDetail(
    String personId, {
    String? serverUrl,
    String? token,
    String? userId,
  });

  // ============================
  // 分类与工作室
  // ============================

  /// 类型列表（Genres）
  Future<List<Library>> getGenres({
    int limit = 100,
    String? serverUrl,
    String? token,
  });

  /// 某类型下的影片
  Future<PaginatedResponse<MediaItem>> getItemsByGenre(
    String genre, {
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  });

  /// 工作室列表
  Future<List<Library>> getStudios({
    int limit = 100,
    String? serverUrl,
    String? token,
  });

  /// 某工作室下的影片
  Future<PaginatedResponse<MediaItem>> getItemsByStudio(
    String studio, {
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  });

  // ============================
  // 收藏相关
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

  /// 切换收藏状态
  Future<void> toggleFavorite({
    required String itemId,
    required bool isFavorite,
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

  // ============================
  // 播放信息与字幕
  // ============================

  /// 获取播放信息
  Future<MediaItem?> getPlaybackInfo(
    String itemId, {
    String? serverUrl,
    String? token,
  });

  /// 字幕 Cues 加载（从服务器获取并解析 SRT/VTT）
  Future<List<SubtitleCue>> getSubtitleCues({
    required String itemId,
    required String mediaSourceId,
    required int index,
    String format = 'srt',
    String? serverUrl,
    String? token,
  });

  /// 清空字幕缓存（视频切换或用户登出时调用）
  void clearSubtitleCache();

  /// 从本地文件加载字幕（外挂字幕）
  Future<List<SubtitleCue>> getSubtitleCuesFromFile({
    required String filePath,
    String? format,
  });

  // ============================
  // 播放上报
  // ============================

  /// 上报播放能力（播放开始前调用）
  Future<void> reportCapabilities({
    String? serverUrl,
    String? token,
  });

  /// 上报播放开始
  Future<void> reportPlaybackStart({
    required String itemId,
    String? mediaSourceId,
    String? playSessionId,
    bool isPaused = false,
    bool isMuted = false,
    int? volumeLevel,
    String playMethod = 'DirectPlay',
    String? serverUrl,
    String? token,
  });

  /// 上报播放进度
  Future<void> reportPlaybackPosition({
    required String itemId,
    required int positionTicks,
    String? mediaSourceId,
    String? playSessionId,
    bool isPaused = false,
    bool isMuted = false,
    int? volumeLevel,
    String playMethod = 'DirectPlay',
    String eventName = 'TimeUpdate',
    String? serverUrl,
    String? token,
  });

  /// 上报播放停止
  Future<void> reportPlaybackStopped({
    required String itemId,
    required int positionTicks,
    String? mediaSourceId,
    String? playSessionId,
    String? serverUrl,
    String? token,
  });

  // ============================
  // 搜索相关
  // ============================

  /// 搜索提示
  Future<List<SearchHint>> searchHints(
    String query, {
    int limit = 20,
    String? serverUrl,
    String? token,
  });

  /// 通用搜索（获取完整 MediaItem 对象）
  Future<PaginatedResponse<MediaItem>> searchItems(
    String query, {
    int limit = 30,
    int offset = 0,
    List<String>? includeTypes,
    String? userId,
    String? serverUrl,
    String? token,
  });

  /// 搜索人物（演员/导演/编剧）
  Future<List<Map<String, dynamic>>> searchPersons(
    String query, {
    int limit = 20,
    String? serverUrl,
    String? token,
  });

  // ============================
  // 观看历史
  // ============================

  /// 观看历史（从服务器获取最近观看的条目）
  Future<List<MediaItem>> getWatchHistory({
    int limit = 50,
    String? userId,
    String? serverUrl,
    String? token,
  });

  // ============================
  // 云同步
  // ============================

  /// 保存续播位置到云端（DisplayPreferences）
  Future<void> saveCloudSync({
    required String itemId,
    required String libraryId,
    String? libraryType,
    String? serverUrl,
    String? token,
  });

  /// 从云端获取续播位置
  Future<Map<String, dynamic>?> checkCloudSync({
    String? serverUrl,
    String? token,
  });

  // ============================
  // 其他通用方法
  // ============================

  /// 通用 POST 请求
  Future<dynamic> postRaw(
    String path, {
    Map<String, dynamic>? queryParameters,
    dynamic data,
    String? serverUrl,
    String? token,
  });

  /// 通用 DELETE 请求
  Future<dynamic> deleteRaw(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? serverUrl,
    String? token,
  });
}
