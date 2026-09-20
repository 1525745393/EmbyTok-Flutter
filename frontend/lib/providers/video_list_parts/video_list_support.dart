// 从 video_list_notifier.dart 拆分（part 文件，无行为变化）

part of '../video_list_notifier.dart';

// ==================== 私有辅助类 ====================

class _SWRLatestResult {
  const _SWRLatestResult({
    required this.cachedItems,
    required this.cachedTotal,
    required this.freshFuture,
  });
  final List<MediaItem>? cachedItems;
  final int cachedTotal;
  final Future<_SWRLatestFreshResult> freshFuture;

  bool get hasCache => cachedItems != null;
}

/// SWR 网络请求结果
class _SWRLatestFreshResult {
  const _SWRLatestFreshResult({
    required this.items,
    required this.total,
    required this.allFailed,
  });
  final List<MediaItem> items;
  final int total;
  final bool allFailed;
}

/// 单库加载结果（成功 / 失败 二选一）
///
/// 用于并行加载时的单库状态包装，便于统一合并。
/// 成功时 [items] 和 [total] 非空，失败时 [error] 非空。
class _LibLoadResult {
  const _LibLoadResult.success(this.libId, this.items, this.total)
      : error = null;

  const _LibLoadResult.failure(this.libId, this.error)
      : items = null,
        total = null;
  final String libId;
  final List<MediaItem>? items;
  final int? total;
  final Object? error;

  bool get isSuccess => error == null;
}

/// 多库并行加载合并结果
///
/// [items] 和 [total] 是跨库去重后的合并结果；
/// [perLibraryResults] 保留每个库的原始结果，供调用方做计数等副作用。
class _ParallelLoadResult {
  const _ParallelLoadResult({
    required this.items,
    required this.total,
    required this.allFailed,
    required this.perLibraryResults,
  });
  final List<MediaItem> items;
  final int total;
  final bool allFailed;
  final List<_LibLoadResult> perLibraryResults;
}

/// 顶层视频列表 Provider：暴露 [VideoListState] 给 UI 使用
///
/// UI 通过 `ref.watch(videoListProvider)` 读取当前视频列表，
/// 通过 `ref.read(videoListProvider.notifier).refresh()` 触发重新加载。
final videoListProvider =
    StateNotifierProvider<VideoListNotifier, VideoListState>((ref) {
  return VideoListNotifier(ref);
});

// ==================== 私有加载方法 ====================

extension _VideoListSupport on VideoListNotifier {
  void _ensurePlayingItemFirst(List<MediaItem> items,
      {required String source}) {
    final playingState = _ref.read(playbackStateProvider);
    final playingId = playingState.id;
    if (playingId == null || playingId.isEmpty) return;
    if (items.any((item) => item.id == playingId)) return; // 已在列表中
    final playingItem = playingState.item;
    if (playingItem == null) return; // 没有完整 item 引用，跳过
    items.insert(0, playingItem);
    AppLogger.debug('保留当前在播视频到列表首位', data: {
      'source': source,
      'itemId': playingId,
      'listSize': items.length,
    });
  }

  Future<void> _loadPageAt(int offset) async {
    final selectedIds = _ref.read(selectedLibraryIdsProvider);
    final auth = _auth;
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    final userId = auth.user?.id;

    if (!auth.isAuthenticated || serverUrl == null || token == null) {
      state = state.copyWith(
        isLoading: false,
        error: AppError.notAuthenticated(),
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
    );

    try {
      AppLogger.debug(
          '加载网格第 ${(offset / VideoListNotifier.kGridPageSize).floor() + 1} 页',
          data: {
            'offset': offset,
            'libraryCount': selectedIds.length,
          });

      final merged = <MediaItem>[];
      for (final libId in selectedIds) {
        try {
          final resp = await _repo.getLibraryItems(
            MediaQueryParams(
              libraryId: libId,
              limit: VideoListNotifier.kGridPageSize,
              offset: offset,
              sortBy: state.sortBy,
              sortOrder: state.sortOrder,
              searchTerm: state.searchTerm.isEmpty ? null : state.searchTerm,
              excludePlayed: _ref.read(feedExcludePlayedProvider),
            ),
            serverUrl: serverUrl,
            token: token,
            userId: userId,
          );
          merged.addAll(resp.items);
        } catch (e) {
          AppLogger.error('加载库 $libId 失败，跳过', error: e);
        }
      }

      // 网格分页：只更新 gridItems 和 gridStartIndex，不修改 feed 的 items
      // feed 的 items 保持独立的无限滚动状态，不受网格翻页影响
      state = state.copyWith(
        gridItems: merged,
        gridStartIndex: offset,
        isLoading: false,
        error: null,
      );
      AppLogger.debug('网格分页加载成功',
          data: {'newCount': merged.length, 'currentPage': currentPage});
    } catch (e) {
      AppLogger.error('网格分页加载失败', error: e);
      state = state.copyWith(
          isLoading: false,
          error: AppError.wrap(e, stackTrace: StackTrace.current));
    }
  }
}
