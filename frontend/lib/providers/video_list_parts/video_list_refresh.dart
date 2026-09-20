// 从 video_list_notifier.dart 拆分（part 文件，无行为变化）

part of '../video_list_notifier.dart';

// ==================== _VideoListRefresh ====================

extension _VideoListRefresh on VideoListNotifier {
  Future<void> _refreshGridOnly(String searchTerm) async {
    final selectedIds = _ref.read(selectedLibraryIdsProvider);
    final auth = _auth;
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    final userId = auth.user?.id;

    if (!auth.isAuthenticated || serverUrl == null || token == null) {
      return;
    }

    state = state.copyWith(
      gridItems: const <MediaItem>[],
      gridStartIndex: 0,
      isLoading: true,
      error: null,
    );

    try {
      final merged = <MediaItem>[];
      int totalAvailable = 0;
      for (final libId in selectedIds) {
        try {
          final resp = await _repo.getLibraryItems(
            MediaQueryParams(
              libraryId: libId,
              limit: VideoListNotifier.kGridPageSize,
              offset: 0,
              sortBy: state.sortBy,
              sortOrder: state.sortOrder,
              searchTerm: searchTerm.isEmpty ? null : searchTerm,
              excludePlayed: _ref.read(feedExcludePlayedProvider),
            ),
            serverUrl: serverUrl,
            token: token,
            userId: userId,
          );
          merged.addAll(resp.items);
          totalAvailable += resp.total;
        } catch (e) {
          AppLogger.error('刷新网格库 $libId 失败，跳过', error: e);
        }
      }
      state = state.copyWith(
        gridItems: merged,
        totalCount: totalAvailable,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.error('刷新网格失败', error: e);
      state = state.copyWith(
          isLoading: false,
          error: AppError.wrap(e, stackTrace: StackTrace.current));
    }
  }

  Future<_ParallelLoadResult> _parallelLoadLibraries(
    List<String> libIds,
    Future<PaginatedResponse<MediaItem>> Function(String libId) loader, {
    void Function(_LibLoadResult result)? onEachResult,
  }) async {
    final results = await Future.wait<_LibLoadResult>(
      libIds.map((libId) async {
        try {
          final resp = await loader(libId);
          return _LibLoadResult.success(libId, resp.items, resp.total);
        } catch (e) {
          AppLogger.error('加载库 $libId 失败', error: e);
          return _LibLoadResult.failure(libId, e);
        }
      }),
      eagerError: false,
    );

    final seenIds = <String, MediaItem>{};
    int total = 0;
    int failedCount = 0;

    for (final result in results) {
      onEachResult?.call(result);
      if (result.isSuccess) {
        for (final item in result.items!) {
          if (!seenIds.containsKey(item.id)) {
            seenIds[item.id] = item;
          }
        }
        total += result.total!;
      } else {
        failedCount++;
      }
    }

    return _ParallelLoadResult(
      items: seenIds.values.toList(),
      total: total,
      allFailed: failedCount == libIds.length,
      perLibraryResults: results,
    );
  }

  _SWRLatestResult _loadLatestSWR({
    required List<String> libIds,
    required String serverUrl,
    required String token,
    required String? userId,
    required int limit,
    required String sortBy,
    required String sortOrder,
    required bool excludePlayed,
    String? searchTerm,
    CancelToken? cancelToken,
  }) {
    final seenIds = <String, MediaItem>{};
    int totalItems = 0;
    bool hasCache = false;

    // 第一步：同步读取所有库的缓存，合并去重
    for (final libId in libIds) {
      final cachedResult = _repo.peekLibraryItems(
        MediaQueryParams(
          libraryId: libId,
          limit: limit,
          offset: 0,
          sortBy: sortBy,
          sortOrder: sortOrder,
          searchTerm: searchTerm?.isEmpty == true ? null : searchTerm,
          excludePlayed: excludePlayed,
        ),
        serverUrl: serverUrl,
        token: token,
      );
      if (cachedResult != null) {
        hasCache = true;
        for (final item in cachedResult.items) {
          if (!seenIds.containsKey(item.id)) {
            seenIds[item.id] = item;
          }
        }
        totalItems += cachedResult.total;
        _libraryLoadedCounts[libId] = cachedResult.items.length;
      }
    }

    // 第二步：并行加载所有媒体库，合并去重
    // 使用 Future.wait 并行执行，总耗时 = 最慢的单个库，而非各库之和
    final freshFuture = () async {
      final result = await _parallelLoadLibraries(
        libIds,
        (libId) => _repo.getLibraryItems(
          MediaQueryParams(
            libraryId: libId,
            limit: limit,
            offset: 0,
            sortBy: sortBy,
            sortOrder: sortOrder,
            searchTerm: searchTerm?.isEmpty == true ? null : searchTerm,
            excludePlayed: excludePlayed,
          ),
          serverUrl: serverUrl,
          token: token,
          userId: userId,
          cancelToken: cancelToken,
        ),
        onEachResult: (r) {
          // refresh 从 offset=0 开始，计数直接等于本次返回数量
          _libraryLoadedCounts[r.libId] = r.isSuccess ? r.items!.length : 0;
        },
      );
      return _SWRLatestFreshResult(
        items: result.items,
        total: result.total,
        allFailed: result.allFailed,
      );
    }();

    return _SWRLatestResult(
      cachedItems: hasCache ? seenIds.values.toList() : null,
      cachedTotal: totalItems,
      freshFuture: freshFuture,
    );
  }
}
