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
    // 监听 viewModeProvider 变化：处理视图切换时的数据同步
    // 核心原则：视频流(feed)的 items 是主数据源，网格只是入口和定位目标
    // - 切回 feed 时，feed 的 items 保持不变（不 refresh），无需重置
    // - 切到网格时，根据 feedToGridJumpItemIdProvider 准备对应页（路由透传 itemId）
    _ref.listen<ViewMode>(viewModeProvider, (previous, next) {
      if (next == ViewMode.feed && previous == ViewMode.grid) {
        // 切回 feed：feed 的 items 不变，无需操作
        AppLogger.debug('切回 feed 模式：保留 feed 数据', data: {
          'itemsCount': state.items.length,
        });
      }
      // 切到 grid 的逻辑由 feedToGridJumpItemIdProvider listener 处理
    });
    // 监听 feedToGridJumpItemIdProvider：feed→grid 切换时根据 itemId 准备网格页
    // 这是"路由 + 起始 itemId 透传"模式的核心：所有跨视图定位都通过这个 provider
    _ref.listen<String?>(feedToGridJumpItemIdProvider, (previous, next) {
      if (next == null || next.isEmpty) return;
      // 只在 grid 模式被显示时响应
      if (_ref.read(viewModeProvider) != ViewMode.grid) return;
      AppLogger.debug('切到 grid 模式：定位到指定视频', data: {'itemId': next});
      updateGridForFeedItem(next);
      // 清理 signal，等待下次切换
      _ref.read(feedToGridJumpItemIdProvider.notifier).state = null;
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

    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
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
            serverUrl: auth.embyServerUrl!,
            token: auth.token!,
            userId: auth.user?.id,
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
    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
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
                serverUrl: auth.embyServerUrl!,
                token: auth.token!,
                userId: auth.user?.id,
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
                serverUrl: auth.embyServerUrl!,
                token: auth.token!,
                userId: auth.user?.id,
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
            serverUrl: auth.embyServerUrl!,
            token: auth.token!,
            userId: auth.user?.id,
          );
          loadedItems = favList;
          loadedTotal = favList.length;
          canPaginate = false;

        case FeedType.resume:
          final resp = await _service.getResumeItems(
            limit: 50,
            offset: 0,
            serverUrl: auth.embyServerUrl!,
            token: auth.token!,
          );
          loadedItems = resp.items;
          loadedTotal = resp.items.length;
          canPaginate = false;

        case FeedType.recommend:
          final libIds = selectedIds;
          if (libIds.isEmpty) {
            state = state.copyWith(isLoading: false, hasMore: false);
            return;
          }
          // 推荐模式：社区评分 + 个性化推荐混合，打乱排序，去重
          final merged = <MediaItem>[];
          int totalItems = 0;
          final seenIds = <String>{}; // 去重用

          // 1. 先尝试 Emby Suggestions 个性化推荐
          try {
            final suggestions = await _service.getSuggestions(
              limit: state.limit,
              serverUrl: auth.embyServerUrl!,
              token: auth.token!,
              userId: auth.user?.id,
            );
            for (final item in suggestions) {
              if (seenIds.add(item.id)) {
                merged.add(item);
              }
            }
          } catch (e) {
            AppLogger.error('加载个性化推荐失败，跳过', error: e);
          }

          // 2. 多库评分推荐：每个库独立 try-catch
          for (final libId in libIds) {
            try {
              final resp = await _service.getRecommendations(
                libraryId: libId,
                limit: state.limit,
                offset: 0,
                serverUrl: auth.embyServerUrl!,
                token: auth.token!,
                userId: auth.user?.id,
              );
              totalItems += resp.total;
              for (final item in resp.items) {
                if (seenIds.add(item.id)) {
                  merged.add(item);
                }
              }
            } catch (e) {
              AppLogger.error('加载库 $libId 推荐列表失败，跳过', error: e);
            }
          }

          // 3. 打乱顺序让各库内容均匀分布
          merged.shuffle();
          loadedItems = merged;
          loadedTotal = totalItems;
          canPaginate = totalItems > merged.length; // 精确判断是否还有更多
      }

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

  // 加载更多：仅在 latest 和 recommend 模式下生效，其它模式不分页
  // 多库模式下，对每个库从 offset/libIds.length 位置继续取 limit 条
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    final currentFeedType = state.feedType;
    if (currentFeedType != FeedType.latest && currentFeedType != FeedType.recommend) {
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
    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
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
          if (currentFeedType == FeedType.recommend) {
            final resp = await _service.getRecommendations(
              libraryId: libId,
              limit: perLibLimit,
              offset: state.offset,
              serverUrl: auth.embyServerUrl!,
              token: auth.token!,
              userId: auth.user?.id,
            );
            merged.addAll(resp.items);
            totalAvailable += resp.total;
          } else {
            final resp = await _service.getLibraryItems(
              libId,
              limit: perLibLimit,
              offset: state.offset,
              serverUrl: auth.embyServerUrl!,
              token: auth.token!,
              userId: auth.user?.id,
              sortBy: state.sortBy,
              sortOrder: state.sortOrder,
              searchTerm: state.searchTerm.isEmpty ? null : state.searchTerm,
            );
            merged.addAll(resp.items);
            totalAvailable += resp.total;
          }
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
  // 与 refresh() 的区别：始终使用 Random 排序，且不改变当前的 sortOption 设置
  Future<void> shuffleRandom() async {
    final selectedIds = _ref.read(selectedLibraryIdsProvider);
    final auth = _auth;

    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
      state = state.copyWith(
        isLoading: false,
        error: '尚未登录',
      );
      return;
    }

    state = state.copyWith(
      items: const <MediaItem>[],
      isLoading: true,
      hasMore: false, // 随机模式不支持分页
      error: null,
      offset: 0,
      limit: 0, // 不限制数量，加载全部
      feedType: FeedType.latest,
      sortBy: 'Random',
      sortOrder: 'Ascending',
      searchTerm: '',
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
            serverUrl: auth.embyServerUrl!,
            token: auth.token!,
            userId: auth.user?.id,
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

      // 不再截取，使用全部随机数据
      final finalItems = merged;

      state = VideoListState(
        items: finalItems,
        gridItems: finalItems,
        gridStartIndex: 0,
        isLoading: false,
        hasMore: false,
        error: null,
        offset: finalItems.length,
        limit: finalItems.length,
        totalCount: finalItems.length,
        feedType: FeedType.latest,
        sortBy: 'Random',
        sortOrder: 'Ascending',
      );
      AppLogger.debug('换一批成功', data: {'count': finalItems.length});
    } catch (e) {
      AppLogger.error('换一批失败', error: e);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
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

    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
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
            serverUrl: auth.embyServerUrl!,
            token: auth.token!,
            userId: auth.user?.id,
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

  // 从 feed 切回网格时，更新网格数据以包含目标 item
  // 策略：将网格重置为第一页（使用 feed 已加载的 items），并标记需要滚动到的 item
  void updateGridForFeedItem(String targetItemId) {
    final feedItems = state.items;
    // 目标在 feed 已加载的 items 中的位置
    final indexInFeed = feedItems.indexWhere((item) => item.id == targetItemId);
    if (indexInFeed < 0) {
      // 不在已加载列表中，重置到第一页
      state = state.copyWith(
        gridItems: feedItems.length > kGridPageSize ? feedItems.sublist(0, kGridPageSize) : feedItems,
        gridStartIndex: 0,
      );
      return;
    }

    // 计算目标视频应该在哪一页（每页150条，简单用整数除法估算）
    // 注意：多库情况下这是估算值，但目标页肯定在第一页或后续，我们把所在页加载为当前页
    // 简单策略：直接将 gridItems 设为从包含目标视频的位置开始
    // 但网格分页要求每页 150 条，我们简化处理：始终显示第一页，如果目标在第一页就能滚动到
    final firstPageEnd = feedItems.length > kGridPageSize ? kGridPageSize : feedItems.length;
    if (indexInFeed < firstPageEnd) {
      // 目标在第一页内，直接显示第一页
      state = state.copyWith(
        gridItems: feedItems.length > kGridPageSize ? feedItems.sublist(0, kGridPageSize) : feedItems,
        gridStartIndex: 0,
      );
    } else {
      // 目标不在已加载的第一页范围内，显示 feed 已加载的最后一页（包含目标）
      // 简单起见，显示最后一整页开始的数据
      final pageStart = (indexInFeed ~/ kGridPageSize) * kGridPageSize;
      final pageEnd = pageStart + kGridPageSize;
      state = state.copyWith(
        gridItems: feedItems.length > pageEnd ? feedItems.sublist(pageStart, pageEnd) : feedItems.sublist(pageStart),
        gridStartIndex: pageStart,
      );
    }
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
/// 用于：网格模式点击视频后，切换到视频流模式并从该视频开始播放
final gridSelectedItemIdProvider = StateProvider<String?>((ref) => null);

/// 从 feed 切回网格时需要定位到的视频 ID
///
/// 用于：视频流模式切换回网格时，自动滚动到当前播放视频的位置
final feedToGridJumpItemIdProvider = StateProvider<String?>((ref) => null);
