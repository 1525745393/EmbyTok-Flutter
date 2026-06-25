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

/// 视频列表状态：包含分页数据、加载状态和浏览模式
///
/// 核心字段：
/// - [items] 当前加载的媒体项列表
/// - [isLoading] 是否正在加载中
/// - [hasMore] 是否还有更多数据可加载
/// - [totalCount] 媒体库总视频数（用于分页显示)
/// - [feedType] 当前浏览模式（latest/random/favorites/resume）
/// - [sortBy] 排序字段（Emby SortBy 参数）
/// - [sortOrder] 排序顺序（Ascending/Descending）
/// - [searchTerm] 搜索关键词
class VideoListState {
  final List<MediaItem> items;
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
/// - [gridSortOptionProvider] 网格排序变化
/// - [gridSearchQueryProvider] 网格搜索变化
/// - [viewModeProvider] 视图模式变化（切回feed时重置排序搜索）
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
    // 监听 gridSortOptionProvider 变化：网格排序变化时刷新（仅 latest 模式）
    _ref.listen<GridSortOption>(
      gridSortOptionProvider,
      (previous, next) {
        if (next != previous) {
          final viewMode = _ref.read(viewModeProvider);
          final feedType = _ref.read(feedTypeProvider);
          if (viewMode == ViewMode.grid && feedType == FeedType.latest) {
            AppLogger.debug('网格排序变化：${previous?.label} -> ${next.label}，刷新视频列表');
            _applySortAndRefresh(next.sortBy, next.sortOrder);
          }
        }
      },
    );
    // 监听 gridSearchQueryProvider 变化：网格搜索变化时刷新（防抖）
    _ref.listen<String>(
      gridSearchQueryProvider,
      (previous, next) {
        final viewMode = _ref.read(viewModeProvider);
        final feedType = _ref.read(feedTypeProvider);
        if (viewMode == ViewMode.grid && feedType == FeedType.latest) {
          _searchDebounceTimer?.cancel();
          _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
            AppLogger.debug('网格搜索变化："$previous" -> "$next"，刷新视频列表');
            _applySearchAndRefresh(next);
          });
        }
      },
    );
    // 监听 viewModeProvider 变化：切回 feed 模式时重置排序搜索，切到 grid 模式时应用当前排序搜索
    _ref.listen<ViewMode>(
      viewModeProvider,
      (previous, next) {
        if (next == ViewMode.feed && previous == ViewMode.grid) {
          // 切回 feed 模式：如果排序或搜索不是默认值，则重置并刷新
          if (state.sortBy != 'DateCreated,SortName' ||
              state.sortOrder != 'Descending' ||
              state.searchTerm.isNotEmpty) {
            AppLogger.debug('切回 feed 模式，重置排序和搜索');
            // 重置 grid provider 的值
            _ref.read(gridSortOptionProvider.notifier).state = GridSortOption.recentlyAdded;
            _ref.read(gridSearchQueryProvider.notifier).state = '';
            refresh();
          }
        } else if (next == ViewMode.grid && previous == ViewMode.feed) {
          // 切到 grid 模式：应用当前的排序和搜索设置
          final sortOption = _ref.read(gridSortOptionProvider);
          final searchQuery = _ref.read(gridSearchQueryProvider);
          final feedType = _ref.read(feedTypeProvider);
          if (feedType == FeedType.latest) {
            final sortBy = sortOption.sortBy;
            final sortOrder = sortOption.sortOrder;
            // 如果排序或搜索不是默认值，则刷新
            if (sortBy != 'DateCreated,SortName' ||
                sortOrder != 'Descending' ||
                searchQuery.isNotEmpty) {
              AppLogger.debug('切到 grid 模式，应用排序和搜索');
              state = state.copyWith(
                sortBy: sortBy,
                sortOrder: sortOrder,
                searchTerm: searchQuery,
              );
              refresh();
            }
          }
        }
      },
    );
  }

  // 读取认证信息
  AuthState get _auth => _ref.read(authProvider);

  // 应用排序并刷新
  void _applySortAndRefresh(String sortBy, String sortOrder) {
    state = state.copyWith(sortBy: sortBy, sortOrder: sortOrder);
    refresh();
  }

  // 应用搜索并刷新
  void _applySearchAndRefresh(String searchTerm) {
    state = state.copyWith(searchTerm: searchTerm);
    refresh();
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
          // 多库混合：每个库独立 try-catch，一个库失败不影响其他库
          final merged = <MediaItem>[];
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
              merged.addAll(resp.items);
            } catch (e) {
              AppLogger.error('加载库 $libId 推荐列表失败，跳过', error: e);
            }
          }
          loadedItems = merged;
          loadedTotal = merged.length;
          canPaginate = true;
      }

      state = VideoListState(
        items: loadedItems,
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
          }
        } catch (e) {
          AppLogger.error('加载库 $libId 失败，跳过', error: e);
        }
      }

      // 判断是否还有更多：如果所有库返回的条数都等于 perLibLimit，继续有更多
      final hasMore = merged.length >= perLibLimit * selectedIds.length;

      state = VideoListState(
        items: [...state.items, ...merged],
        isLoading: false,
        hasMore: hasMore,
        error: null,
        offset: state.offset + merged.length,
        limit: state.limit,
        feedType: currentFeedType,
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
      limit: 150, // 换一批获取 150 条
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
      // 多库时平均分配，确保总数约为 150 条
      final perLibLimit = selectedIds.isNotEmpty
          ? (150 / selectedIds.length).ceil()
          : 150;
      for (final libId in selectedIds) {
        try {
          final resp = await _service.getLibraryItems(
            libId,
            limit: perLibLimit,
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

      // 截取最多 150 条
      final finalItems = merged.length > 150 ? merged.sublist(0, 150) : merged;

      state = VideoListState(
        items: finalItems,
        isLoading: false,
        hasMore: false,
        error: null,
        offset: finalItems.length,
        limit: 150,
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
    if (state.limit <= 0) return 1;
    return (state.offset / state.limit).floor() + 1;
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

  // 内部方法：加载指定 offset 的页面
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
      offset: offset,
    );

    try {
      AppLogger.debug('加载第 ${(offset / kGridPageSize).floor() + 1} 页', data: {
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

      // 判断是否还有更多
      final hasMore = merged.length >= kGridPageSize * selectedIds.length;

      state = VideoListState(
        items: merged,
        isLoading: false,
        hasMore: hasMore,
        error: null,
        offset: offset + merged.length,
        limit: kGridPageSize,
        totalCount: state.totalCount,
        feedType: state.feedType,
        sortBy: state.sortBy,
        sortOrder: state.sortOrder,
        searchTerm: state.searchTerm,
      );
      AppLogger.debug('分页加载成功', data: {'newCount': merged.length, 'currentPage': currentPage});
    } catch (e) {
      AppLogger.error('分页加载失败', error: e);
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
}

/// 顶层视频列表 Provider：暴露 [VideoListState] 给 UI 使用
///
/// UI 通过 `ref.watch(videoListProvider)` 读取当前视频列表，
/// 通过 `ref.read(videoListProvider.notifier).refresh()` 触发重新加载。
final videoListProvider =
    StateNotifierProvider<VideoListNotifier, VideoListState>((ref) {
  return VideoListNotifier(ref);
});

// ==================== 网格模式排序与搜索 ====================

/// 网格视图排序选项
///
/// 每个选项对应 Emby API 的 SortBy 和 SortOrder 参数
enum GridSortOption {
  resolution(
    label: '分辨率',
    sortBy: 'Height',
    sortOrder: 'Descending',
  ),
  dateCreated(
    label: '加入日期',
    sortBy: 'DateCreated',
    sortOrder: 'Descending',
  ),
  premiereDate(
    label: '发行日期',
    sortBy: 'PremiereDate',
    sortOrder: 'Descending',
  ),
  container(
    label: '媒体容器',
    sortBy: 'Container',
    sortOrder: 'Ascending',
  ),
  officialRating(
    label: '家长评分',
    sortBy: 'OfficialRating',
    sortOrder: 'Ascending',
  ),
  productionYear(
    label: '年份',
    sortBy: 'ProductionYear',
    sortOrder: 'Descending',
  ),
  criticRating(
    label: '影评人评分',
    sortBy: 'CriticRating',
    sortOrder: 'Descending',
  ),
  datePlayed(
    label: '播放日期',
    sortBy: 'DatePlayed',
    sortOrder: 'Descending',
  ),
  runtime(
    label: '播放时长',
    sortBy: 'Runtime',
    sortOrder: 'Descending',
  ),
  playCount(
    label: '播放次数',
    sortBy: 'PlayCount',
    sortOrder: 'Descending',
  ),
  sortName(
    label: '文件名',
    sortBy: 'SortName',
    sortOrder: 'Ascending',
  ),
  size(
    label: '文件尺寸',
    sortBy: 'Size',
    sortOrder: 'Descending',
  ),
  name(
    label: '标题',
    sortBy: 'SortName',
    sortOrder: 'Ascending',
  ),
  bitrate(
    label: '比特率',
    sortBy: 'Bitrate',
    sortOrder: 'Descending',
  ),
  random(
    label: '随机',
    sortBy: 'Random',
    sortOrder: 'Ascending',
  ),
  recentlyAdded(
    label: '最近添加',
    sortBy: 'DateCreated,SortName',
    sortOrder: 'Descending',
  );

  final String label;
  final String sortBy;
  final String sortOrder;

  const GridSortOption({
    required this.label,
    required this.sortBy,
    required this.sortOrder,
  });
}

/// 网格视图排序选项 Provider
final gridSortOptionProvider = StateProvider<GridSortOption>((ref) {
  return GridSortOption.recentlyAdded;
});

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
