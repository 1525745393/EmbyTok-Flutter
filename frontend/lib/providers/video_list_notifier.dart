// 视频列表 Notifier：响应媒体库切换和浏览模式变化自动加载视频
//
// 拆分说明：
// - 状态模型在 [video_list_state.dart] 中定义
// - 全局播放列表在 [playback_list_provider.dart] 中定义（完全独立）
// - 本文件专注于视频列表加载/分页/搜索等核心业务逻辑
//
// 内存管理：
// - [_searchDebounceTimer] 在 [dispose] 中显式 cancel，防止 StateNotifier 销毁后 Timer 继续运行
//   Timer 闭包持有 `_ref`（ProviderContainer 引用），若不 cancel 会导致整个依赖链无法释放

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../repositories/media_repository.dart';
import '../utils/app_preferences.dart' show FeedType, ViewMode;
import '../utils/logger.dart';
import 'app_preferences_providers.dart';
import 'auth_provider.dart';
import 'cache_providers.dart';
import 'library_provider.dart';
import 'video_list_state.dart';
import 'video_playback_controller.dart';

/// 网格视图搜索关键词 Provider
final gridSearchQueryProvider = StateProvider<String>((ref) {
  return '';
});

class VideoListNotifier extends StateNotifier<VideoListState> {
  final Ref _ref;
  final MediaRepository _repo;
  Timer? _searchDebounceTimer;

  // 多库分页时，记录每个库已加载的 item 数量（即下一次请求的 offset）
  // refresh 时清空，loadMore 时各库独立递增，避免多库共用全局 offset 导致的分页错误
  final Map<String, int> _libraryLoadedCounts = <String, int>{};

  ProviderSubscription<List<String>>? _libraryIdsSubscription;
  ProviderSubscription<FeedType>? _feedTypeSubscription;
  ProviderSubscription<bool>? _excludePlayedSubscription;
  ProviderSubscription<String>? _searchQuerySubscription;
  ProviderSubscription<ViewMode>? _viewModeSubscription;

  VideoListNotifier(this._ref, {MediaRepository? repo})
      : _repo = repo ?? _ref.read(cachedMediaRepositoryProvider),
        super(const VideoListState()) {
    // 监听 selectedLibraryIdsProvider 变化：媒体库切换时自动刷新视频列表
    _libraryIdsSubscription = _ref.listen<List<String>>(
      selectedLibraryIdsProvider,
      (previous, next) {
        final prevStr = previous?.join(',') ?? '';
        final nextStr = next.join(',');
        if (next.isNotEmpty && nextStr != prevStr) {
          AppLogger.debug('媒体库变化：[$prevStr] -> [$nextStr]，刷新视频列表');
          // ★ 清除上一个媒体库的 playingItem（PR #61 修复）
          // 原因：换媒体库后旧视频不应再被 _ensurePlayingItemFirst 强制插入到新列表
          // 之前 _ensurePlayingItemFirst 读到旧 currentPlayingIdProvider，
          // 在新 lib 数据中找不到就插入到 [0]，导致 feed 显示旧视频、grid 标"播放中"
          _ref.read(currentPlayingIdProvider.notifier).state = null;
          _ref.read(currentPlayingItemProvider.notifier).state = null;
          refresh();
        }
      },
    );
    // 监听 feedTypeProvider 变化：浏览模式切换时自动刷新
    _feedTypeSubscription = _ref.listen<FeedType>(
      feedTypeProvider,
      (previous, next) {
        if (next != previous) {
          AppLogger.debug('浏览模式变化：${previous?.zhLabel} -> ${next.zhLabel}，刷新视频列表');
          refresh();
        }
      },
    );
    // 监听 feedExcludePlayedProvider 变化：排除已观看切换时自动刷新
    _excludePlayedSubscription = _ref.listen<bool>(
      feedExcludePlayedProvider,
      (previous, next) {
        if (next != previous) {
          AppLogger.debug('视频流排除已观看变化：$previous -> $next，刷新视频列表');
          refresh();
        }
      },
    );
    // 监听 gridSearchQueryProvider 变化：网格搜索只影响 gridItems，不影响 feed 的 items
    // 设计原则：feed 和 grid 数据隔离。搜索是 grid 的本地行为，feed 始终是未过滤的视频流。
    _searchQuerySubscription = _ref.listen<String>(
      gridSearchQueryProvider,
      (previous, next) {
        final viewMode = _ref.read(viewModeProvider);
        // 搜索适用于所有 feedType 的网格视图，不限 latest
        if (viewMode == ViewMode.grid && next != previous) {
          _searchDebounceTimer?.cancel();
          _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
            final currentFeedType = _ref.read(feedTypeProvider);
            AppLogger.debug('网格搜索变化："$previous" -> "$next"，feedType=$currentFeedType，只刷新网格');
            _refreshGridOnly(next);
          });
        }
      },
    );
    // 监听 viewModeProvider 变化：处理视图切换时的视频播放/暂停
    // 核心原则：视频流(feed)的 items 是主数据源，网格只是入口和定位目标
    // 切回 feed 时，feed 的 items 保持不变（不 refresh），无需重置
    _viewModeSubscription = _ref.listen<ViewMode>(viewModeProvider, (previous, next) {
      if (next == ViewMode.feed && previous == ViewMode.grid) {
        // 切回 feed：feed 的 items 不变，无需操作
        AppLogger.debug('切回 feed 模式：保留 feed 数据', data: {
          'itemsCount': state.items.length,
        });
      }
    });
  }

  // 读取认证信息
  AuthState get _auth => _ref.read(authProvider);

  // 仅刷新网格数据（搜索变化时调用）
  // 设计原则：feed 的 items 永远不依赖 gridSearchQueryProvider
  // - 搜索只影响网格的 gridItems
  // - 切回 feed 时不重置 feed 数据
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
              limit: kGridPageSize,
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
      state = state.copyWith(isLoading: false, error: AppError.fromDioException(e, stackTrace: StackTrace.current));
    }
  }

  /// SWR 模式加载最新视频（FeedType.latest 多库混合）
  ///
  /// 先从缓存读取并立即展示（加速首屏），然后发起网络请求获取最新数据。
  /// 始终以网络返回的最新数据为准，缓存仅做加速。
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

    // 第二步：发起网络请求获取最新数据
    final freshFuture = () async {
      final freshSeenIds = <String, MediaItem>{};
      int freshTotal = 0;
      int failedCount = 0;
      for (final libId in libIds) {
        try {
          final resp = await _repo.getLibraryItems(
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
          );
          for (final item in resp.items) {
            if (!freshSeenIds.containsKey(item.id)) {
              freshSeenIds[item.id] = item;
            }
          }
          _libraryLoadedCounts[libId] = resp.items.length;
          freshTotal += resp.total;
        } catch (e) {
          failedCount++;
          _libraryLoadedCounts[libId] = 0;
          AppLogger.error('SWR: 加载库 $libId 失败', error: e);
        }
      }
      return _SWRLatestFreshResult(
        items: freshSeenIds.values.toList(),
        total: freshTotal,
        allFailed: failedCount == libIds.length,
      );
    }();

    return _SWRLatestResult(
      cachedItems: hasCache ? seenIds.values.toList() : null,
      cachedTotal: totalItems,
      freshFuture: freshFuture,
    );
  }

  // 根据当前 feedType 刷新视频列表
  // latest: 走 getLibraryItems 分页（支持多库混合）
  // random: 拉 80 条打乱，不分页（支持多库混合）
  // favorites: 拉 getFavoriteMovies 纯列表，不分页
  // resume: 拉 getResumeItems 续播列表，不分页
  //
  // [forceRefresh] 为 true 时，先清除相关缓存再请求，确保获取最新数据
  Future<void> refresh({bool forceRefresh = false}) async {
    final currentFeedType = _ref.read(feedTypeProvider);
    final selectedIds = _ref.read(selectedLibraryIdsProvider);

    state = VideoListState(
      items: const <MediaItem>[],
      gridItems: const <MediaItem>[],
      gridStartIndex: 0,
      isLoading: true,
      hasMore: true,
      error: null,
      offset: 0,
      limit: state.limit,
      totalCount: 0,
      feedType: currentFeedType,
      sortBy: state.sortBy,
      sortOrder: state.sortOrder,
      searchTerm: state.searchTerm,
    );

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

    try {
      AppLogger.info('刷新视频列表', data: {
        'feedType': currentFeedType.toStorageString(),
        'libraryIds': selectedIds.join(','),
        'forceRefresh': forceRefresh,
      });

      // 强制刷新：通过 CacheController 清除缓存，确保从服务器获取最新数据
      if (forceRefresh) {
        _ref.read(cacheControllerProvider).invalidateAll();
      }

      final List<MediaItem> loadedItems;
      final bool canPaginate;
      int loadedTotal = 0; // 媒体库总视频数（用于分页显示）

      switch (currentFeedType) {
        case FeedType.latest:
          final libIds = selectedIds;
          if (libIds.isEmpty) {
            state = state.copyWith(isLoading: false, hasMore: false);
            return;
          }
          _libraryLoadedCounts.clear();

          final swr = _loadLatestSWR(
            libIds: libIds,
            serverUrl: serverUrl,
            token: token,
            userId: userId,
            limit: state.limit,
            sortBy: state.sortBy,
            sortOrder: state.sortOrder,
            excludePlayed: _ref.read(feedExcludePlayedProvider),
            searchTerm: state.searchTerm.isEmpty ? null : state.searchTerm,
          );

          // 有缓存：立即展示缓存数据，仍显示 loading 指示
          if (swr.hasCache) {
            state = state.copyWith(
              items: swr.cachedItems!,
              gridItems: swr.cachedItems!,
              isLoading: true,
              hasMore: swr.cachedTotal > swr.cachedItems!.length,
              totalCount: swr.cachedTotal,
              error: null,
            );
          }

          // 等待最新数据
          try {
            final fresh = await swr.freshFuture;
            if (fresh.allFailed) {
              if (swr.hasCache) {
                state = state.copyWith(isLoading: false);
              } else {
                state = state.copyWith(
                  isLoading: false,
                  error: AppError.network(message: '所有媒体库均加载失败，请检查网络连接'),
                );
              }
            } else {
              state = state.copyWith(
                items: fresh.items,
                gridItems: fresh.items,
                isLoading: false,
                hasMore: fresh.total > fresh.items.length,
                totalCount: fresh.total,
                error: null,
              );
            }
          } catch (e) {
            if (swr.hasCache) {
              state = state.copyWith(isLoading: false);
            } else {
              state = state.copyWith(
                isLoading: false,
                error: AppError.network(message: e.toString()),
              );
            }
          }
          loadedItems = state.items;
          loadedTotal = state.totalCount;
          canPaginate = true;
          break;

        case FeedType.random:
          final libIds = selectedIds;
          if (libIds.isEmpty) {
            state = state.copyWith(isLoading: false, hasMore: false);
            return;
          }
          // 多库混合：每个库独立 try-catch
          final merged = <MediaItem>[];
          for (final libId in libIds) {
            try {
              final resp = await _repo.getLibraryItems(
                MediaQueryParams(
                  libraryId: libId,
                  limit: (80 / libIds.length).ceil(),
                  offset: 0,
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
          final shuffled = List<MediaItem>.from(merged);
          shuffled.shuffle();
          loadedItems = shuffled;
          loadedTotal = shuffled.length;
          canPaginate = false;

        case FeedType.favorites:
          final favResult = await _repo.getFavoriteMovies(
            serverUrl: serverUrl,
            token: token,
            userId: userId,
          );
          loadedItems = favResult.items;
          loadedTotal = favResult.items.length;
          canPaginate = false;

        case FeedType.resume:
          final resp = await _repo.getResumeItems(
            limit: 50,
            offset: 0,
            serverUrl: serverUrl,
            token: token,
          );
          loadedItems = resp.items;
          loadedTotal = resp.items.length;
          canPaginate = false;
        // 注：FeedType.recommend 已从枚举移除（PR #57）。
        // 推荐现在走独立路由 /recommend + 独立 recommend_provider。
        // 不再与 feed 共享 video_list_provider 数据，避免污染视频流。
      }

      // ★ 关键：保留当前在播视频到 loadedItems 首位
      // 解决"浏览模式切换"时与视频流的冲突：
      //   - 用户在 video-X 播到 30s → 切换浏览模式（latest/random/favorites/resume）→ loadedItems 被替换
      //   - video-X 不在 loadedItems 中 → PageView 仍在 index=N → 但 N 对应的视频变了
      // 解决：把 currentPlayingItem 插到 loadedItems[0]，保持"当前在播视频在列表首位"
      // 注：推荐模式已独立（PR #57），不再走这个路径
      _ensurePlayingItemFirst(loadedItems, source: 'refresh/$currentFeedType');

      state = VideoListState(
        items: loadedItems,
        gridItems: loadedItems,
        gridStartIndex: 0,
        isLoading: false,
        hasMore: canPaginate,
        error: null,
        offset: loadedItems.length,
        limit: state.limit,
        totalCount: loadedTotal,
        feedType: currentFeedType,
      );
      AppLogger.debug('视频列表刷新成功', data: {
        'count': loadedItems.length,
        'feedType': currentFeedType.toStorageString(),
      });
    } catch (e) {
      AppLogger.error('刷新视频列表失败', error: e);
      state = state.copyWith(isLoading: false, error: AppError.fromDioException(e, stackTrace: StackTrace.current));
    }
  }

  // 加载更多：仅在 latest 模式下生效，其它模式不分页
  // 多库模式下，对每个库从 offset/libIds.length 位置继续取 limit 条
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    final currentFeedType = state.feedType;
    if (currentFeedType != FeedType.latest) {
      state = state.copyWith(hasMore: false);
      return;
    }

    final selectedIds = _ref.read(selectedLibraryIdsProvider);
    if (selectedIds.isEmpty) {
      state = state.copyWith(hasMore: false);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    final auth = _auth;
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    final userId = auth.user?.id;
    if (!auth.isAuthenticated || serverUrl == null || token == null) {
      state = state.copyWith(isLoading: false, error: AppError.notAuthenticated());
      return;
    }

    try {
      // 多库分页：每个库独立 offset（_libraryLoadedCounts），避免全局 offset 导致的分页错误
      AppLogger.debug('加载更多视频', data: {
        'offset': state.offset,
        'libraryCount': selectedIds.length,
        'perLibLoaded': _libraryLoadedCounts.toString(),
      });
      final perLibLimit = state.limit;
      // 按 id 去重，与 refresh 逻辑一致
      final seenIds = <String, MediaItem>{};
      int totalAvailable = 0;
      bool allEmpty = true;
      int failedCount = 0;
      for (final libId in selectedIds) {
        try {
          final libOffset = _libraryLoadedCounts[libId] ?? 0;
          final resp = await _repo.getLibraryItems(
            MediaQueryParams(
              libraryId: libId,
              limit: perLibLimit,
              offset: libOffset,
              sortBy: state.sortBy,
              sortOrder: state.sortOrder,
              searchTerm: state.searchTerm.isEmpty ? null : state.searchTerm,
              excludePlayed: _ref.read(feedExcludePlayedProvider),
            ),
            serverUrl: serverUrl,
            token: token,
            userId: userId,
          );
          for (final item in resp.items) {
            if (!seenIds.containsKey(item.id)) {
              seenIds[item.id] = item;
            }
          }
          _libraryLoadedCounts[libId] = libOffset + resp.items.length;
          totalAvailable += resp.total;
          if (resp.items.isNotEmpty) allEmpty = false;
        } catch (e) {
          failedCount++;
          AppLogger.error('加载库 $libId 失败，跳过', error: e);
        }
      }
      final newItems = seenIds.values.toList();

      // 所有库都失败 → 视为加载失败
      if (failedCount == selectedIds.length) {
        state = state.copyWith(
          isLoading: false,
          error: AppError.network(message: '加载更多失败，请检查网络连接'),
        );
        return;
      }

      // 精确判断：当前已加载 + 本次新加载 < 总记录数则还有更多
      // 所有库都返回空 → hasMore=false，避免无限空加载循环
      final newTotal = state.items.length + newItems.length;
      // 加入 newItems.isNotEmpty 守卫：多库去重后若本轮未新增任何唯一条目，
      // 说明已无新内容，避免 totalAvailable（含重复项）导致的 loadMore 无限循环
      final hasMore = !allEmpty &&
          newItems.isNotEmpty &&
          totalAvailable > 0 &&
          newTotal < totalAvailable;

      state = state.copyWith(
        items: [...state.items, ...newItems],
        // 只有当网格还没有手动翻页（gridStartIndex == 0）时，才同步追加到 gridItems
        // 一旦用户翻了网格页，gridItems 就保持独立，不再跟随 feed 追加
        gridItems: state.gridStartIndex == 0 ? [...state.gridItems, ...newItems] : state.gridItems,
        isLoading: false,
        hasMore: hasMore,
        error: null,
        offset: state.offset + newItems.length,
      );
      AppLogger.debug('加载更多成功', data: {'newCount': newItems.length});
    } catch (e) {
      AppLogger.error('加载更多失败', error: e);
      state = state.copyWith(isLoading: false, error: AppError.fromDioException(e, stackTrace: StackTrace.current));
    }
  }

  // 换一批：使用 SortBy=Random 服务端随机排序获取全量数据，本地再洗牌以保证随机性均匀
  //
  // 关键设计（避免破坏 feed/grid 跨视图定位）：
  // 1. **同步更新 items 和 gridItems**：shuffleRandom 是 grid 模式下的"换一批"按钮，
  //    grid 选 video 跳 feed 时（context.go('/?initialId=$id')）通过 _waitForInitialItemToLoad
  //    在 items 中查找目标。如果只改 gridItems 不改 items，新一批的 video 在 feed 中找不到
  //    会触发 loadMore 循环载入旧/新库视频 → 超时跳到 index 0 → 播放错视频（PR #60 修复）。
  // 2. **保留当前在播视频到列表首位**：保证 PosterGridView 的
  //    _scrollToPlayingId 能找到目标，"播放中"卡片能高亮
  Future<void> shuffleRandom() async {
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
      hasMore: false, // 随机模式不支持分页
      error: null,
    );

    try {
      AppLogger.info('换一批：随机获取视频', data: {
        'libraryIds': selectedIds.join(','),
      });

      // 多库场景下使用 Map 按 id 去重，避免同视频在多个库中重复
      final seenIds = <String, MediaItem>{};
      for (final libId in selectedIds) {
        try {
          final resp = await _repo.getLibraryItems(
            MediaQueryParams(
              libraryId: libId,
              limit: kGridPageSize, // 限制单次拉取量，避免大库全量加载导致的内存/性能问题
              offset: 0,
              sortBy: 'Random',
              sortOrder: 'Ascending',
              excludePlayed: _ref.read(feedExcludePlayedProvider),
            ),
            serverUrl: serverUrl,
            token: token,
            userId: userId,
          );
          for (final item in resp.items) {
            if (!seenIds.containsKey(item.id)) {
              seenIds[item.id] = item;
            }
          }
        } catch (e) {
          AppLogger.error('加载库 $libId 失败，跳过', error: e);
        }
      }
      final merged = seenIds.values.toList();

      // 本地再洗牌一次，保证随机性均匀（服务端 SortBy=Random 可能有偏向性）
      if (merged.isNotEmpty) {
        final firstItem = merged.first;
        final rest = merged.skip(1).toList();
        rest.shuffle();
        merged.clear();
        merged.add(firstItem);
        merged.addAll(rest);
      }

      // ★ 关键：保留当前在播视频到 gridItems 首位
      // 服务端返回的全量视频中可能不包含 currentPlayingItemProvider 指示的当前在播视频（如已被删除），
      // 这会导致 PosterGridView 的 _scrollToPlayingId 找不到目标（indexWhere 返回 -1），
      // 切回 grid 时"播放中"定位 + 高亮失效。
      // 解决：调 _ensurePlayingItemFirst 把当前在播视频插到首位（保证能找到）。
      _ensurePlayingItemFirst(merged, source: 'shuffleRandom');

      // ★ 同时更新 items + gridItems（PR #60 修复）
      // - 仅改 gridItems 会导致 grid 选 video 跳 feed 时
      //   _waitForInitialItemToLoad 在 items 中找不到目标，loadMore 循环超时
      // - items 和 gridItems 内容一致：用户从 grid 选 video 跳 feed 后能正确定位
      // - 不修改 feedType/sortBy/sortOrder
      state = state.copyWith(
        items: merged,
        gridItems: merged,
        gridStartIndex: 0,
        isLoading: false,
        hasMore: false,
        error: null,
        offset: merged.length,
      );
      AppLogger.debug('换一批成功', data: {'count': merged.length});
    } catch (e) {
      AppLogger.error('换一批失败', error: e);
      state = state.copyWith(isLoading: false, error: AppError.fromDioException(e, stackTrace: StackTrace.current));
    }
  }

  // 保留当前在播视频到列表首位
  //
  // 作用：解决"feed/grid 跨视图 + 浏览模式切换"场景下当前在播视频丢失的问题
  // 场景：
  //   1. shuffleRandom: 服务端随机 150 条不包含当前在播视频 → grid 定位失效
  //   2. refresh: 切到"推荐"/"收藏"/"最新"等模式时 items 被替换 → 视频流 PageView
  //      仍在 index=N，但 N 对应的视频变了（"播放中"位置错位）
  // 实现：
  //   - 读 currentPlayingIdProvider / currentPlayingItemProvider
  //   - 如果当前在播视频不在 [items] 中，插入到首位
  //   - 已在 [items] 中则不动
  //   - 当前没有在播视频则不动
  void _ensurePlayingItemFirst(List<MediaItem> items, {required String source}) {
    final playingId = _ref.read(currentPlayingIdProvider);
    if (playingId == null || playingId.isEmpty) return;
    if (items.any((item) => item.id == playingId)) return; // 已在列表中
    final playingItem = _ref.read(currentPlayingItemProvider);
    if (playingItem == null) return; // 没有完整 item 引用，跳过
    items.insert(0, playingItem);
    AppLogger.debug('保留当前在播视频到列表首位', data: {
      'source': source,
      'itemId': playingId,
      'listSize': items.length,
    });
  }

  // PR #73：grid 跳 feed 时把 gridItems 同步到 items
  // 场景：用户在 grid 视图选 video 跳到 feed（context.go('/?initialId=$id')），
  //       FeedView 接收 initialId 后调 _waitForInitialItemToLoad 在 items 中查找。
  //       但 grid 的 gridItems（已是新数据）跟 feed 的 items（可能未及时刷新）不一致，
  //       就会找不到目标 → loadMore 循环载入旧/新库视频 → 超时跳到 index 0 → 播放错视频。
  // 解决：在 onTap 中先调本方法，让 items 反映 gridItems，再 setMode(feed) + go，
  //       _waitForInitialItemToLoad 必定能在 items 中找到用户点的视频。
  void setItemsFromGrid() {
    if (identical(state.items, state.gridItems)) return; // 已经一致，无需更新
    state = state.copyWith(items: state.gridItems);
    AppLogger.debug('grid 跳 feed：items 同步为 gridItems', data: {
      'itemsCount': state.items.length,
    });
  }

  // PR #76：grid 跳 feed 时同步跳到用户点的视频（解决换库后跳错 bug）
  // 场景：
  //   - 有正在播放：PageController 仍在旧 X1 位置
  //   - 换库：state.items 变为 lib2 data，但 PageController 不会自动 reset
  //   - grid 点 X2：setMode(feed) 后 PageView 渲染到 PageController 当前 page（= X1 位置）
  //                 即 lib2[X1 位置]，不是 X2
  //   - 之前 _waitForInitialItemToLoad 依赖 widget.initialItemId 变化触发，
  //     但若 setMode(feed) 触发的 build 中 widget.initialItemId 还没更新（context.go 时序），
  //     _processedInitialItemId == initialId 不会重新触发
  // 解决：setItemsFromGrid(focusItemId) 同步触发 feedViewPageJumpRequestProvider，
  //      FeedView.initState 中 listen 这个 provider，强制 _jumpToPageWhenReady(idx)
  //      保证 PageController 跳到 X2 位置，不依赖 widget.initialItemId
  void setItemsFromGridAndJumpTo(String focusItemId) {
    setItemsFromGrid();
    final idx = state.gridItems.indexWhere((item) => item.id == focusItemId);
    if (idx < 0) {
      AppLogger.warn('grid 跳 feed：focusItemId 不在 gridItems 中', data: {
        'itemId': focusItemId,
        'gridItemsCount': state.gridItems.length,
      });
      return;
    }
    AppLogger.debug('grid 跳 feed：请求跳页', data: {
      'itemId': focusItemId,
      'targetIndex': idx,
    });
    _ref.read(feedViewPageJumpRequestProvider.notifier).state = idx;
  }

  // 清除当前错误状态（SnackBar 弹出后重置，避免重复弹出）
  void clearError() {
    state = state.copyWith(error: null);
  }

  // 分页常量：与 EmbyX 保持一致，每页 150 条
  static const int kGridPageSize = 150;

  // 计算当前页码（从 1 开始）
  int get currentPage {
    return (state.gridStartIndex ~/ kGridPageSize) + 1;
  }

  // 计算总页数
  int get totalPages {
    if (state.totalCount <= 0) return 1;
    return (state.totalCount / kGridPageSize).ceil();
  }

  // 是否有上一页
  bool get hasPrevPage => currentPage > 1;

  // 是否有下一页
  bool get hasNextPage => currentPage < totalPages;

  // 跳转到指定页
  Future<void> goToPage(int page) async {
    if (page < 1 || page > totalPages) return;
    final newOffset = (page - 1) * kGridPageSize;
    await _loadPageAt(newOffset);
  }

  // 下一页
  Future<void> nextPage() async {
    if (!hasNextPage) return;
    await goToPage(currentPage + 1);
  }

  // 上一页
  Future<void> prevPage() async {
    if (!hasPrevPage) return;
    await goToPage(currentPage - 1);
  }

  // 内部方法：加载指定 offset 的页面（仅更新网格数据，不影响 feed 的 items）
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
      AppLogger.debug('加载网格第 ${(offset / kGridPageSize).floor() + 1} 页', data: {
        'offset': offset,
        'libraryCount': selectedIds.length,
      });

      final merged = <MediaItem>[];
      for (final libId in selectedIds) {
        try {
          final resp = await _repo.getLibraryItems(
            MediaQueryParams(
              libraryId: libId,
              limit: kGridPageSize,
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
      AppLogger.debug('网格分页加载成功', data: {'newCount': merged.length, 'currentPage': currentPage});
    } catch (e) {
      AppLogger.error('网格分页加载失败', error: e);
      state = state.copyWith(isLoading: false, error: AppError.fromDioException(e, stackTrace: StackTrace.current));
    }
  }

  // 从当前列表移除指定条目（resume 模式播放完毕、删除视频等场景）
  // 同时从 items 和 gridItems 中移除，保持两个列表一致
  void removeItem(String itemId) {
    var items = state.items;
    var gridItems = state.gridItems;
    final idx = items.indexWhere((item) => item.id == itemId);
    if (idx >= 0) {
      items = List<MediaItem>.from(items)..removeAt(idx);
    }
    final gridIdx = gridItems.indexWhere((item) => item.id == itemId);
    if (gridIdx >= 0) {
      gridItems = List<MediaItem>.from(gridItems)..removeAt(gridIdx);
    }
    if (idx < 0 && gridIdx < 0) return;
    state = state.copyWith(items: items, gridItems: gridItems);
    AppLogger.debug('已从列表移除条目', data: {'itemId': itemId});
  }

  // 兼容旧方法名，委托给 removeItem
  void removePlayedItem(String itemId) => removeItem(itemId);

  /// 释放资源：cancel 未完成的防抖 Timer
  ///
  /// Riverpod 的 StateNotifier 在 Provider 被销毁时（如应用退出、登录切换）
  /// 会调用此方法。若不 cancel Timer，Timer 闭包持有 `_ref` 引用，
  /// 间接持有整个 ProviderContainer 依赖链，导致大量对象无法释放。
  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _libraryIdsSubscription?.close();
    _feedTypeSubscription?.close();
    _excludePlayedSubscription?.close();
    _searchQuerySubscription?.close();
    _viewModeSubscription?.close();
    super.dispose();
  }
}

/// SWR 模式首屏加载结果（FeedType.latest 多库混合场景）
class _SWRLatestResult {
  final List<MediaItem>? cachedItems;
  final int cachedTotal;
  final Future<_SWRLatestFreshResult> freshFuture;

  const _SWRLatestResult({
    required this.cachedItems,
    required this.cachedTotal,
    required this.freshFuture,
  });

  bool get hasCache => cachedItems != null;
}

/// SWR 网络请求结果
class _SWRLatestFreshResult {
  final List<MediaItem> items;
  final int total;
  final bool allFailed;

  const _SWRLatestFreshResult({
    required this.items,
    required this.total,
    required this.allFailed,
  });
}

/// 顶层视频列表 Provider：暴露 [VideoListState] 给 UI 使用
///
/// UI 通过 `ref.watch(videoListProvider)` 读取当前视频列表，
/// 通过 `ref.read(videoListProvider.notifier).refresh()` 触发重新加载。
final videoListProvider =
    StateNotifierProvider<VideoListNotifier, VideoListState>((ref) {
  return VideoListNotifier(ref);
});
