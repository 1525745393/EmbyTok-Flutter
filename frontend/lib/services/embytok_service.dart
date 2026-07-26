// 核心业务服务：业务门面，依赖 MediaServerApi 接口
// 设计思路：每个方法都接受可选的 serverUrl / token 参数，调用方可以显式传入，
// 也可以先调用 setupAuth 后使用无参方法。这样既有灵活性又便于 Provider 使用。
// 业务逻辑（字幕缓存、播放上报重试等）保留在此层，纯 API 调用委托给 _api。

import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

import '../models/models.dart';
import '../utils/logger.dart';
import '../utils/memory_cache.dart';
import 'api_client.dart';
import 'emby_server_api.dart';
import 'media_server_api.dart';

class EmbytokService {
  EmbytokService({MediaServerApi? api}) : _api = api ?? EmbyServerApi();

  EmbytokService.withClient(ApiClient client)
      : _api = EmbyServerApi.withClient(client);

  final MediaServerApi _api;

  // 字幕缓存：LRU + TTL，max 50 条，30 分钟过期
  final MemoryCache<List<SubtitleCue>> _subtitleCache =
      MemoryCache<List<SubtitleCue>>(maxSize: 50);

  // ============================
  // 认证配置（设置默认 server/token，后续调用可省略参数）
  // ============================
  void setupAuth({
    required String embyServerUrl,
    required String apiKey,
    String? userId,
  }) {
    _api.setupAuth(
      embyServerUrl: embyServerUrl,
      apiKey: apiKey,
      userId: userId,
    );
  }

  // 清除认证信息
  void clearAuth() {
    _api.clearAuth();
  }

  // ============================
  // 登录：Emby /Users/AuthenticateByName
  // ============================
  Future<User> login({
    required String embyServerUrl,
    required String username,
    required String password,
  }) {
    return _api.login(
      embyServerUrl: embyServerUrl,
      username: username,
      password: password,
    );
  }

  // ============================
  // 媒体库列表：默认使用 /Users/{userId}/Views（用户视角），向后兼容 /Library/VirtualFolders
  // ============================
  Future<List<Library>> getLibraries({
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getLibraries(
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 用户视图：GET /Users/{userId}/Views（getLibraries 的别名，语义更明确）
  // ============================
  Future<List<Library>> getUserViews({
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getUserViews(
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 获取某媒体库下的视频列表
  // ============================
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
  }) {
    return _api.getLibraryItems(
      libraryId,
      limit: limit,
      offset: offset,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
      sortBy: sortBy,
      sortOrder: sortOrder,
      searchTerm: searchTerm,
      excludePlayed: excludePlayed,
      cancelToken: cancelToken,
    );
  }

  // ============================
  // 获取项详情
  // ============================
  Future<MediaItem> getItemDetail(
    String itemId, {
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getItemDetail(
      itemId,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 继续观看列表
  // ============================
  Future<PaginatedResponse<MediaItem>> getResumeItems({
    int limit = 20,
    int offset = 0,
    String? serverUrl,
    String? token,
    CancelToken? cancelToken,
  }) {
    return _api.getResumeItems(
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
      cancelToken: cancelToken,
    );
  }

  // ============================
  // 推荐列表：按社区评分从高到低排序，评分阈值 4.0（满分 10）
  // 默认排除已观看（IsPlayed=false），避免推已完结的视频
  // 评分阈值可通过 minCommunityRating 参数覆盖（PR #78：推荐优化）
  // includeItemTypes 可控制推荐范围（PR #79：类型偏好）
  // ============================
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
  }) {
    return _api.getRecommendations(
      limit: limit,
      offset: offset,
      libraryId: libraryId,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
      minCommunityRating: minCommunityRating,
      excludePlayed: excludePlayed,
      includeItemTypes: includeItemTypes,
    );
  }

  // ============================
  // 个性化推荐：基于 Emby Suggestions API，利用观看历史做智能推荐
  // ============================
  Future<List<MediaItem>> getSuggestions({
    int limit = 20,
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getSuggestions(
      limit: limit,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // Next Up（下一步看什么）—— 剧集的下一集
  // 可选 seriesId：传入则只返回指定剧集的下一集
  // ============================
  Future<PaginatedResponse<MediaItem>> getNextUp({
    int limit = 20,
    String? seriesId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getNextUp(
      limit: limit,
      seriesId: seriesId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 最近添加
  // ============================
  Future<PaginatedResponse<MediaItem>> getRecentlyAdded({
    int limit = 20,
    int offset = 0,
    String? libraryId,
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getRecentlyAdded(
      limit: limit,
      offset: offset,
      libraryId: libraryId,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 相似影片
  // ============================
  Future<List<MediaItem>> getSimilarItems(
    String itemId, {
    int limit = 20,
    String? serverUrl,
    String? token,
  }) {
    return _api.getSimilarItems(
      itemId,
      limit: limit,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 人员（演员/导演）列表
  // ============================
  Future<PaginatedResponse<Person>> getPeople({
    int limit = 50,
    int startIndex = 0,
    List<String>? personTypes,
    String? searchTerm,
    String? serverUrl,
    String? token,
  }) {
    return _api.getPeople(
      limit: limit,
      startIndex: startIndex,
      personTypes: personTypes,
      searchTerm: searchTerm,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 某演员出演的作品
  // ============================
  Future<PaginatedResponse<MediaItem>> getPersonItems(
    String personId, {
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) {
    return _api.getPersonItems(
      personId,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 获取单个演员详情（包含 overview）
  //
  // 注意：Emby 的 /Items/{id} 端点对 Person 类型可能不返回 Overview，
  // 但 /Users/{userId}/Items 列表端点会返回。因此使用列表端点 + Ids 参数
  // 获取单条记录，保证 Overview 字段。
  // ============================
  Future<MediaItem?> getPersonDetail(
    String personId, {
    String? serverUrl,
    String? token,
    String? userId,
  }) {
    return _api.getPersonDetail(
      personId,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    );
  }

  // ============================
  // 类型列表（Genres）
  // ============================
  Future<List<Library>> getGenres({
    int limit = 100,
    String? serverUrl,
    String? token,
  }) {
    return _api.getGenres(
      limit: limit,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 某类型下的影片
  // ============================
  Future<PaginatedResponse<MediaItem>> getItemsByGenre(
    String genre, {
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) {
    return _api.getItemsByGenre(
      genre,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 工作室列表
  // ============================
  Future<List<Library>> getStudios({
    int limit = 100,
    String? serverUrl,
    String? token,
  }) {
    return _api.getStudios(
      limit: limit,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 某工作室下的影片
  // ============================
  Future<PaginatedResponse<MediaItem>> getItemsByStudio(
    String studio, {
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) {
    return _api.getItemsByStudio(
      studio,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 收藏列表（从 Emby 获取）
  // ============================
  Future<List<MediaItem>> getFavorites({
    int limit = 100,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) {
    return _api.getFavorites(
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 收藏影片（按类型：电影/剧集/音乐视频/单集，使用用户视图路径，与 EmbyX 对齐）
  // ============================
  Future<FavoritesPageResult> getFavoriteMovies({
    int limit = 50,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
    CancelToken? cancelToken,
  }) {
    return _api.getFavoriteMovies(
      limit: limit,
      offset: offset,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
      cancelToken: cancelToken,
    );
  }

  // ============================
  // 收藏合集（BoxSet，使用用户视图路径，与 EmbyX 对齐）
  // ============================
  Future<FavoritesPageResult> getFavoriteBoxSets({
    int limit = 50,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getFavoriteBoxSets(
      limit: limit,
      offset: offset,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 收藏人物（Person，使用用户视图路径，与 EmbyX 对齐）
  // ============================
  Future<FavoritesPageResult> getFavoritePeople({
    int limit = 50,
    int offset = 0,
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getFavoritePeople(
      limit: limit,
      offset: offset,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 切换收藏状态（带 userId 端点，与 EmbyX 对齐）
  // ============================
  Future<void> toggleFavorite({
    required String itemId,
    required bool isFavorite,
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.toggleFavorite(
      itemId: itemId,
      isFavorite: isFavorite,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 标记已看 / 未看
  // ============================
  Future<void> markAsPlayed(
    String itemId, {
    String? serverUrl,
    String? token,
  }) {
    return _api.markAsPlayed(
      itemId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<void> markAsUnplayed(
    String itemId, {
    String? serverUrl,
    String? token,
  }) {
    return _api.markAsUnplayed(
      itemId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 剧集季列表
  // ============================
  Future<List<MediaItem>> getSeasons(
    String seriesId, {
    String? serverUrl,
    String? token,
  }) {
    return _api.getSeasons(
      seriesId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 剧集集列表
  // ============================
  Future<PaginatedResponse<MediaItem>> getEpisodes(
    String seriesId, {
    String? seasonId,
    int limit = 100,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) {
    return _api.getEpisodes(
      seriesId,
      seasonId: seasonId,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 预告片
  // ============================
  Future<PaginatedResponse<MediaItem>> getTrailers({
    int limit = 30,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) {
    return _api.getTrailers(
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 播放信息（通过 getItemDetail 获取，MediaSources 在详情中已包含）
  // ============================
  Future<MediaItem?> getPlaybackInfo(
    String itemId, {
    String? serverUrl,
    String? token,
  }) {
    return _api.getPlaybackInfo(
      itemId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 字幕 Cues 加载（从 Emby 获取并解析 SRT/VTT）
  // - index: 字幕轨道 index（与 MediaStream.index）
  // - mediaSourceId: 媒体源 ID
  //
  // 字幕 URL 格式：/Videos/{itemId}/{mediaSourceId}/Subtitles/{index}/0/Stream.{format}
  // 返回：按 start / end / text
  // ============================
  Future<List<SubtitleCue>> getSubtitleCues({
    required String itemId,
    required String mediaSourceId,
    required int index,
    String format = 'srt',
    String? serverUrl,
    String? token,
  }) async {
    // 内存缓存：仅缓存成功且非空的结果，避免重复请求
    // 空结果和失败请求不缓存，确保下次可以重试
    final cacheKey = '${itemId}_${mediaSourceId}_${index}_$format';
    final cached = _subtitleCache.get(cacheKey);
    if (cached != null) {
      AppLogger.debug('字幕缓存命中',
          data: {'cacheKey': cacheKey, 'count': cached.length});
      return cached;
    }
    try {
      final cues = await _api.getSubtitleCues(
        itemId: itemId,
        mediaSourceId: mediaSourceId,
        index: index,
        format: format,
        serverUrl: serverUrl,
        token: token,
      );
      // 仅缓存非空结果
      if (cues.isNotEmpty) {
        _subtitleCache.set(cacheKey, cues);
      }
      return cues;
    } catch (e) {
      // 字幕加载失败不中断播放，不缓存失败结果以便下次重试
      AppLogger.warn('字幕请求失败', data: {
        'itemId': itemId,
        'mediaSourceId': mediaSourceId,
        'index': index,
        'format': format,
        'error': e.toString(),
      });
      return const <SubtitleCue>[];
    }
  }

  /// 清空字幕缓存（视频切换或用户登出时调用）
  void clearSubtitleCache() {
    _subtitleCache.clear();
  }

  /// 本地字幕文件最大大小（字节），默认 5MB
  ///
  /// 防止用户选择过大的文件导致内存问题
  static const int maxSubtitleFileSize = 5 * 1024 * 1024;

  /// 从本地文件加载字幕（外挂字幕）
  ///
  /// [filePath] 本地文件路径
  /// [format] 字幕格式（srt/vtt/ass/ssa），不传则从文件扩展名推断
  Future<List<SubtitleCue>> getSubtitleCuesFromFile({
    required String filePath,
    String? format,
  }) async {
    AppLogger.debug('从本地文件加载字幕',
        data: {'filePath': filePath, 'format': format});
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        AppLogger.warn('本地字幕文件不存在', data: {'filePath': filePath});
        return const <SubtitleCue>[];
      }
      // 文件大小校验：避免过大文件导致内存问题
      final fileSize = await file.length();
      if (fileSize > maxSubtitleFileSize) {
        AppLogger.warn('本地字幕文件过大', data: {
          'filePath': filePath,
          'fileSize': fileSize,
          'maxSize': maxSubtitleFileSize,
        });
        return const <SubtitleCue>[];
      }
      final content = await file.readAsString();
      if (content.isEmpty) {
        AppLogger.warn('本地字幕文件为空', data: {'filePath': filePath});
        return const <SubtitleCue>[];
      }
      // 从文件扩展名推断格式
      final effectiveFormat = format ?? _detectFormatFromPath(filePath);
      final cues = parseSubtitle(content, effectiveFormat);
      AppLogger.debug('本地字幕加载完成', data: {
        'filePath': filePath,
        'format': effectiveFormat,
        'cuesCount': cues.length,
      });
      return cues;
    } catch (e) {
      AppLogger.warn('本地字幕加载失败', data: {
        'filePath': filePath,
        'error': e.toString(),
      });
      return const <SubtitleCue>[];
    }
  }

  /// 从文件路径推断字幕格式
  String _detectFormatFromPath(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'vtt':
      case 'webvtt':
        return 'vtt';
      case 'ass':
      case 'ssa':
        return 'ass';
      case 'srt':
      case 'subrip':
      default:
        return 'srt';
    }
  }

  // ============================
  // 上报播放进度 / 停止位置
  // ============================

  // 上报播放能力（播放开始前调用）
  Future<void> reportCapabilities({
    String? serverUrl,
    String? token,
  }) {
    return _api.reportCapabilities(
      serverUrl: serverUrl,
      token: token,
    );
  }

  // 上报播放开始（带指数退避重试）
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
  }) async {
    try {
      await _retry(
        () => _api.reportPlaybackStart(
          itemId: itemId,
          mediaSourceId: mediaSourceId,
          playSessionId: playSessionId,
          isPaused: isPaused,
          isMuted: isMuted,
          volumeLevel: volumeLevel,
          playMethod: playMethod,
          serverUrl: serverUrl,
          token: token,
        ),
        operationName: '上报播放开始',
      );
    } catch (e) {
      AppLogger.debug('上报播放开始失败', data: {'error': e.toString()});
    }
  }

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
  }) {
    return _api.reportPlaybackPosition(
      itemId: itemId,
      positionTicks: positionTicks,
      mediaSourceId: mediaSourceId,
      playSessionId: playSessionId,
      isPaused: isPaused,
      isMuted: isMuted,
      volumeLevel: volumeLevel,
      playMethod: playMethod,
      eventName: eventName,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<void> reportPlaybackStopped({
    required String itemId,
    required int positionTicks,
    String? mediaSourceId,
    String? playSessionId,
    String? serverUrl,
    String? token,
  }) async {
    try {
      await _retry(
        () => _api.reportPlaybackStopped(
          itemId: itemId,
          positionTicks: positionTicks,
          mediaSourceId: mediaSourceId,
          playSessionId: playSessionId,
          serverUrl: serverUrl,
          token: token,
        ),
        operationName: '上报播放停止',
      );
    } catch (e) {
      AppLogger.debug('上报播放停止失败', data: {'error': e.toString()});
    }
  }

  // ============================
  // 观看历史（从 Emby 获取最近观看的条目）
  //
  // 优先使用用户级路径 /Users/{userId}/Items，该路径在多数 Emby 服务器上
  // 对继续观看列表的权限更明确。若 userId 为空，则降级到全局 /Items
  // 并附加 UserId 查询参数保证向后兼容。
  // ============================
  Future<List<MediaItem>> getWatchHistory({
    int limit = 50,
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.getWatchHistory(
      limit: limit,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 搜索提示
  // ============================
  Future<List<SearchHint>> searchHints(
    String query, {
    int limit = 20,
    String? serverUrl,
    String? token,
  }) {
    return _api.searchHints(
      query,
      limit: limit,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 通用搜索（获取完整 MediaItem 对象，使用用户视图路径，与 EmbyX 对齐）
  // ============================
  Future<PaginatedResponse<MediaItem>> searchItems(
    String query, {
    int limit = 30,
    int offset = 0,
    List<String>? includeTypes,
    String? userId,
    String? serverUrl,
    String? token,
  }) {
    return _api.searchItems(
      query,
      limit: limit,
      offset: offset,
      includeTypes: includeTypes,
      userId: userId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 搜索人物（演员/导演/编剧）
  // ============================
  Future<List<Map<String, dynamic>>> searchPersons(
    String query, {
    int limit = 20,
    String? serverUrl,
    String? token,
  }) {
    return _api.searchPersons(
      query,
      limit: limit,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 获取子项（孩子节点）
  // ============================
  Future<List<MediaItem>> getChildren(
    String parentId, {
    int limit = 100,
    int offset = 0,
    String? serverUrl,
    String? token,
  }) {
    return _api.getChildren(
      parentId,
      limit: limit,
      offset: offset,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 续播云同步：使用 DisplayPreferences 实现跨设备续播同步
  // ============================

  // 保存续播位置到云端（DisplayPreferences）
  Future<void> saveCloudSync({
    required String itemId,
    required String libraryId,
    String? libraryType,
    String? serverUrl,
    String? token,
  }) {
    return _api.saveCloudSync(
      itemId: itemId,
      libraryId: libraryId,
      libraryType: libraryType,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // 从云端获取续播位置
  Future<Map<String, dynamic>?> checkCloudSync({
    String? serverUrl,
    String? token,
  }) {
    return _api.checkCloudSync(
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 通用 POST 请求
  // ============================
  Future<dynamic> postRaw(
    String path, {
    Map<String, dynamic>? queryParameters,
    dynamic data,
    String? serverUrl,
    String? token,
  }) {
    return _api.postRaw(
      path,
      queryParameters: queryParameters,
      data: data,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 通用 DELETE 请求
  // ============================
  Future<dynamic> deleteRaw(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? serverUrl,
    String? token,
  }) {
    return _api.deleteRaw(
      path,
      queryParameters: queryParameters,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 删除媒体项
  // ============================
  /// 删除指定的媒体项（调用 Emby DELETE /Items/{itemId}）
  Future<void> deleteItem({
    required String itemId,
    required String serverUrl,
    required String token,
  }) {
    return _api.deleteItem(
      itemId: itemId,
      serverUrl: serverUrl,
      token: token,
    );
  }

  // ============================
  // 内部辅助方法
  // ============================

  // 指数退避重试：用于播放上报等关键操作
  // - maxAttempts: 最多重试次数（含首次），默认 3 次
  // - delayMs: 初始延迟毫秒数，每次翻倍，带 50% 抖动
  Future<void> _retry(
    Future<void> Function() fn, {
    int maxAttempts = 3,
    int initialDelayMs = 1000,
    String operationName = 'operation',
  }) async {
    var attempt = 0;
    var delay = initialDelayMs;
    final random = Random();
    while (true) {
      attempt++;
      try {
        await fn();
        return; // 成功
      } catch (e) {
        if (attempt >= maxAttempts) {
          AppLogger.warn('$operationName 失败（$maxAttempts 次尝试均失败）',
              data: {'error': e.toString()});
          rethrow;
        }
        // 指数退避 + 50% 随机抖动，避免多设备同时重试产生雪崩
        final jitter = (delay * 0.5 * random.nextDouble()).toInt();
        final waitMs = delay + jitter;
        AppLogger.debug('$operationName 第 $attempt 次失败，${waitMs}ms 后重试',
            data: {'error': e.toString()});
        await Future<void>.delayed(Duration(milliseconds: waitMs));
        delay *= 2;
      }
    }
  }
}
