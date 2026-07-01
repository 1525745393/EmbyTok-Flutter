// 视频列表分页加载：支持按媒体库筛选、下拉刷新与无限滚动
// 关键特性：
// 1. 监听 selectedLibraryIdsProvider 变化，自动触发视频加载
// 2. 支持分页（offset/limit）
// 3. 支持方向过滤（通过 filteredVideoListProvider）
// 4. 网格模式支持服务端排序和搜索

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/app_preferences.dart' show OrientationMode, FeedType, ViewMode;
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'app_preferences_providers.dart';
import 'auth_provider.dart';
import 'library_provider.dart';
import 'video_playback_controller.dart';

/// 视频列表状态：包含分页数据、加载状态和浏览模式
///
/// 核心字段：
/// - [items] 当前加载的媒体项列表（feed 模式使用）
/// - [gridItems] 网格视图专用列表（grid 模式使用，是 items 的子集）
/// - [gridStartIndex] 网格视图的全局起始偏移（用于 feed 模式跳转）
/// - [isLoading] 是否正在加载中
/// - [hasMore] 是否还有更多数据可加载
/// - [totalCount] 媒体库总视频数（用于分页显示)
/// - [feedType] 当前浏览模式（latest/random/favorites/resume）
/// - [sortBy] 排序字段（Emby SortBy 参数）
/// - [sortOrder] 排序顺序（Ascending/Descending）
/// - [searchTerm] 搜索关键词
class VideoListState {
  final List<MediaItem> items;
  final List<MediaItem> gridItems; // 网格视图专用列表（裁剪后）
  final int gridStartIndex; // 网格视图的全局起始偏移
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int offset;
  final int limit;
  final int totalCount; // 媒体库总视频数，用于分页显示
  final FeedType feedType; // 当前浏览模式
  final String sortBy;
  final String sortOrder;
  final String searchTerm;

  const VideoListState({
    this.items = const <MediaItem>[],
    this.gridItems = const <MediaItem>[],
    this.gridStartIndex = 0,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.offset = 0,
    this.limit = kDefaultPageLimit,
    this.totalCount = 0,
    this.feedType = FeedType.latest,
    this.sortBy = 'DateCreated,SortName',
    this.sortOrder = 'Descending',
    this.searchTerm = '',
  });

  VideoListState copyWith({
    List<MediaItem>? items,
    List<MediaItem>? gridItems,
    int? gridStartIndex,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? offset,
    int? limit,
    int? totalCount,
    FeedType? feedType,
    String? sortBy,
    String? sortOrder,
    String? searchTerm,
  }) {
    return VideoListState(
      items: items ?? this.items,
      gridItems: gridItems ?? this.gridItems,
      gridStartIndex: gridStartIndex ?? this.gridStartIndex,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
      totalCount: totalCount ?? this.totalCount,
      feedType: feedType ?? this.feedType,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      searchTerm: searchTerm ?? this.searchTerm,
    );
  }
}

/// 视频列表 Notifier：响应媒体库切换和浏览模式变化自动加载视频
///
/// 内部监听：
/// - [selectedLibraryIdsProvider] 媒体库选择变化
/// - [feedTypeProvider] 浏览模式变化（latest/random/favorites/resume）
/// - [gridSearchQueryProvider] 网格搜索变化
/// - [viewModeProvider] 视图模式变化（切回feed时重置搜索）
///
/// 内存管理：
/// - [_searchDebounceTimer] 在 [dispose] 中显式 cancel，防止 StateNotifier 销毁后 Timer 继续运行
///   Timer 闭包持有 `_ref`（ProviderContainer 引用），若不 cancel 会导致整个依赖链无法释放
class VideoListNotifier extends StateNotifier<VideoListState> {
  final Ref _ref;
  final EmbytokService _service;
  Timer? _searchDebounceTimer;

  VideoListNotifier(this._ref, {EmbytokService? service})
      : _service = service ?? EmbytokService(),
        super(const VideoListState()) {
    // 监听 selectedLibraryIdsProvider 变化：媒体库切换时自动刷新视频列表
    _ref.listen<List<String>>(
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
    _ref.listen<FeedType>(
      feedTypeProvider,
      (previous, next) {
        if (next != previous) {
          AppLogger.debug('浏览模式变化：${previous?.zhLabel} -> ${next.zhLabel}，刷新视频列表');
          refresh();
        }
      },
    );
    // 监听 gridSearchQueryProvider 变化：网格搜索只影响 gridItems，不影响 feed 的 items
    // 设计原则：feed 和 grid 数据隔离。搜索是 grid 的本地行为，feed 始终是未过滤的视频流。
    _ref.listen<String>(
      gridSearchQueryProvider,
      (previous, next) {
        final viewMode = _ref.read(viewModeProvider);
        final feedType = _ref.read(feedTypeProvider);
        if (viewMode == ViewMode.grid && feedType == FeedType.latest && next != previous) {
          _searchDebounceTimer?.cancel();
          _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
            AppLogger.debug('网格搜索变化："$previous" -> "$next"，只刷新网格');
            _refreshGridOnly(next);
          });
        }
      },
    );
    // 监听 viewModeProvider 变化：处理视图切换时的视频播放/暂停
    // 核心原则：视频流(feed)的 items 是主数据源，网格只是入口和定位目标
    // 切回 feed 时，feed 的 items 保持不变（不 refresh），无需重置
    _ref.listen<ViewMode>(viewModeProvider, (previous, next) {
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
          final resp = await _service.getLibraryItems(
            libId,
            limit: kGridPageSize,
            offset: 0,
            serverUrl: serverUrl,
            token: token,
            userId: userId,
            sortBy: state.sortBy,
            sortOrder: state.sortOrder,
            searchTerm: searchTerm.isEmpty ? null : searchTerm,
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
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // 根据当前 feedType 刷新视频列表
  // latest: 走 getLibraryItems 分页（支持多库混合）
  // random: 拉 80 条打乱，不分页（支持多库混合）
  // favorites: 拉 getFavoriteMovies 纯列表，不分页
  // resume: 拉 getResumeItems 续播列表，不分页
  Future<void> refresh() async {
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
        error: '尚未登录',
      );
      return;
    }

    try {
      AppLogger.info('刷新视频列表', data: {
        'feedType': currentFeedType.toStorageString(),
        'libraryIds': selectedIds.join(','),
      });

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
          // 多库混合：每个库独立 try-catch，一个库失败不影响其他库
          final merged = <MediaItem>[];
          int totalItems = 0;
          for (final libId in libIds) {
            try {
              final resp = await _service.getLibraryItems(
                libId,
                limit: state.limit,
                offset: 0,
                serverUrl: serverUrl,
                token: token,
                userId: userId,
                sortBy: state.sortBy,
                sortOrder: state.sortOrder,
                searchTerm: state.searchTerm.isEmpty ? null : state.searchTerm,
              );
              merged.addAll(resp.items);
              totalItems += resp.total; // 累加每个库的总视频数
            } catch (e) {
              AppLogger.error('加载库 $libId 失败，跳过', error: e);
            }
          }
          loadedItems = merged;
          loadedTotal = totalItems;
          canPaginate = true;

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
              final resp = await _service.getLibraryItems(
                libId,
                limit: (80 / libIds.length).ceil(),
                offset: 0,
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
          final favList = await _service.getFavoriteMovies(
            serverUrl: serverUrl,
            token: token,
            userId: userId,
          );
          loadedItems = favList;
          loadedTotal = favList.length;
          canPaginate = false;

        case FeedType.resume:
          final resp = await _service.getResumeItems(
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
      state = state.copyWith(isLoading: false, error: e.toString());
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
      state = state.copyWith(isLoading: false, error: '尚未登录');
      return;
    }

    try {
      // 多库分页：使用当前 offset 作为起点，每个库独立获取 limit 条
      AppLogger.debug('加载更多视频', data: {'offset': state.offset, 'libraryCount': selectedIds.length});
      final perLibLimit = state.limit;
      final merged = <MediaItem>[];
      int totalAvailable = 0; // 累加各库 TotalRecordCount
      for (final libId in selectedIds) {
        try {
          final resp = await _service.getLibraryItems(
            libId,
            limit: perLibLimit,
            offset: state.offset,
            serverUrl: serverUrl,
            token: token,
            userId: userId,
            sortBy: state.sortBy,
            sortOrder: state.sortOrder,
            searchTerm: state.searchTerm.isEmpty ? null : state.searchTerm,
          );
          merged.addAll(resp.items);
          totalAvailable += resp.total;
        } catch (e) {
          AppLogger.error('加载库 $libId 失败，跳过', error: e);
        }
      }

      // 精确判断：当前已加载 + 本次新加载 < 总记录数则还有更多
      final newTotal = state.items.length + merged.length;
      final hasMore = totalAvailable > 0 && newTotal < totalAvailable;

      state = state.copyWith(
        items: [...state.items, ...merged],
        // 只有当网格还没有手动翻页（gridStartIndex == 0）时，才同步追加到 gridItems
        // 一旦用户翻了网格页，gridItems 就保持独立，不再跟随 feed 追加
        gridItems: state.gridStartIndex == 0 ? [...state.gridItems, ...merged] : state.gridItems,
        isLoading: false,
        hasMore: hasMore,
        error: null,
        offset: state.offset + merged.length,
      );
      AppLogger.debug('加载更多成功', data: {'newCount': merged.length});
    } catch (e) {
      AppLogger.error('加载更多失败', error: e);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // 换一批：使用 SortBy=Random 服务端随机排序，获取 150 条随机视频
  //
  // 关键设计（避免破坏 feed/grid 跨视图定位）：
  // 1. **同步更新 items 和 gridItems**：shuffleRandom 是 grid 模式下的"换一批"按钮，
  //    grid 选 video 跳 feed 时（context.go('/?initialId=$id')）通过 _waitForInitialItemToLoad
  //    在 items 中查找目标。如果只改 gridItems 不改 items，新一批的 video 在 feed 中找不到
  //    会触发 loadMore 循环直到超时（PR #60 修复）。
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
        error: '尚未登录',
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

      final merged = <MediaItem>[];
      for (final libId in selectedIds) {
        try {
          final resp = await _service.getLibraryItems(
            libId,
            limit: 10000, // 不限制数量，取全部
            offset: 0,
            serverUrl: serverUrl,
            token: token,
            userId: userId,
            sortBy: 'Random',
            sortOrder: 'Ascending',
          );
          merged.addAll(resp.items);
        } catch (e) {
          AppLogger.error('加载库 $libId 失败，跳过', error: e);
        }
      }

      // 随机模式下加载完，直接原地洗牌（保持第一个视频在首位）
      if (merged.isNotEmpty) {
        final firstItem = merged.first;
        final rest = merged.skip(1).toList();
        rest.shuffle();
        merged.clear();
        merged.add(firstItem);
        merged.addAll(rest);
      }

      // ★ 关键：保留当前在播视频到 gridItems 首位
      // 服务端随机返回的 150 条视频可能不包含 currentPlayingItemProvider 指示的当前在播视频，
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
      state = state.copyWith(isLoading: false, error: e.toString());
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
        error: '尚未登录',
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
          final resp = await _service.getLibraryItems(
            libId,
            limit: kGridPageSize,
            offset: offset,
            serverUrl: serverUrl,
            token: token,
            userId: userId,
            sortBy: state.sortBy,
            sortOrder: state.sortOrder,
            searchTerm: state.searchTerm.isEmpty ? null : state.searchTerm,
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
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // 从当前列表移除已播放完毕的条目（仅 resume 模式下需要）
  // 播放完毕后 Emby 服务端会从 resume 列表移除，本地同步移除避免显示过期条目
  void removePlayedItem(String itemId) {
    if (state.feedType != FeedType.resume) return;
    final items = state.items;
    final idx = items.indexWhere((item) => item.id == itemId);
    if (idx < 0) return;
    final newItems = List<MediaItem>.from(items)..removeAt(idx);
    state = state.copyWith(items: newItems);
    AppLogger.debug('已从 resume 列表移除播放完毕条目', data: {'itemId': itemId});
  }

  /// 释放资源：cancel 未完成的防抖 Timer
  ///
  /// Riverpod 的 StateNotifier 在 Provider 被销毁时（如应用退出、登录切换）
  /// 会调用此方法。若不 cancel Timer，Timer 闭包持有 `_ref` 引用，
  /// 间接持有整个 ProviderContainer 依赖链，导致大量对象无法释放。
  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }
}

/// 顶层视频列表 Provider：暴露 [VideoListState] 给 UI 使用
///
/// UI 通过 `ref.watch(videoListProvider)` 读取当前视频列表，
/// 通过 `ref.read(videoListProvider.notifier).refresh()` 触发重新加载。
final videoListProvider =
    StateNotifierProvider<VideoListNotifier, VideoListState>((ref) {
  return VideoListNotifier(ref);
});

// ==================== 网格模式搜索 ====================

/// 网格视图搜索关键词 Provider
final gridSearchQueryProvider = StateProvider<String>((ref) {
  return '';
});

// ==================== 方向过滤的派生 Provider ====================

/// 根据屏幕方向模式过滤后的视频列表
///
/// - [OrientationMode.vertical] 仅保留竖屏视频
/// - [OrientationMode.horizontal] 仅保留横屏视频
/// - [OrientationMode.both] 返回全部视频
final filteredVideoListProvider = Provider<List<MediaItem>>((ref) {
  final videoState = ref.watch(videoListProvider);
  final orientationMode = ref.watch(orientationModeProvider);

  // 如果是加载中或错误状态，直接返回原列表
  if (videoState.isLoading || videoState.error != null) {
    return videoState.items;
  }

  // 根据方向模式过滤
  return videoState.items.where((item) {
    return switch (orientationMode) {
      OrientationMode.vertical => item.isPortrait,
      OrientationMode.horizontal => item.isLandscape,
      OrientationMode.both => true, // 显示全部
    };
  }).toList();
});

// ==================== 全局播放列表 Provider ====================

/// 全局播放列表状态：用于支持从任意页面跳转到播放页时传递视频列表
///
/// 在跳转到播放页之前，各页面应设置此 Provider 的值
class PlaybackListState {
  final List<MediaItem> items;
  final String? currentItemId;

  const PlaybackListState({
    this.items = const [],
    this.currentItemId,
  });

  PlaybackListState copyWith({
    List<MediaItem>? items,
    String? currentItemId,
  }) {
    return PlaybackListState(
      items: items ?? this.items,
      currentItemId: currentItemId ?? this.currentItemId,
    );
  }
}

/// 全局播放列表 Notifier：用于设置当前页面的视频列表
final playbackListProvider =
    StateNotifierProvider<PlaybackListNotifier, PlaybackListState>((ref) {
  return PlaybackListNotifier();
});

class PlaybackListNotifier extends StateNotifier<PlaybackListState> {
  PlaybackListNotifier() : super(const PlaybackListState());

  /// 设置播放列表
  void setPlaybackList(List<MediaItem> items, String currentItemId) {
    state = PlaybackListState(items: items, currentItemId: currentItemId);
  }

  /// 清空播放列表
  void clear() {
    state = const PlaybackListState();
  }
}

// ==================== 网格模式过滤与排序后的派生 Provider ====================

/// 网格模式下的视频列表
///
/// 说明：排序和搜索已通过 Emby 服务端 API 实现，
/// 这里直接返回 videoListProvider 的数据。
/// 保留此 provider 是为了保持 API 一致性，
/// 未来如果需要客户端额外过滤可以在这里添加。
final gridFilteredVideoListProvider = Provider<List<MediaItem>>((ref) {
  final videoState = ref.watch(videoListProvider);
  return videoState.items;
});

/// 网格模式下点击选中的视频 ID
///
/// 已废弃：网格 → 视频流的跳转现在通过 GoRouter `?initialId=<itemId>` 透传。
/// 保留此 provider 是为了与历史代码兼容（部分测试仍可能引用）。
/// 后续 PR 将彻底删除。
@Deprecated('使用 GoRouter ?initialId= 透传，不再需要此 provider')
final gridSelectedItemIdProvider = StateProvider<String?>((ref) => null);

/// 从 feed 切回网格时需要定位到的视频 ID
///
/// 已废弃：feed → grid 的回显定位现在由 currentPlayingIdProvider 驱动。
/// PosterGridView 监听 currentPlayingIdProvider 后自行滚动。
@Deprecated('使用 currentPlayingIdProvider，不再需要此 provider')
final feedToGridJumpItemIdProvider = StateProvider<String?>((ref) => null);
