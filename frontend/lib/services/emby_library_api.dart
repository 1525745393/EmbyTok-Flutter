import 'package:dio/dio.dart';
import '../models/models.dart';

abstract interface class EmbyLibraryApi {
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
    String? includeItemTypes,
    String? playedFilter,
    String? genre,
    bool resumable = false,
    int? year,
    double? minCommunityRating,
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
}
