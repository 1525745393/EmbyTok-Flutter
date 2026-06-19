// 视频列表分页加载：支持按媒体库筛选、下拉刷新与无限滚动
// 关键特性：
// 1. 监听 selectedLibraryIdProvider 变化，自动触发视频加载
// 2. 支持分页（offset/limit）
// 3. 支持方向过滤（通过 filteredVideoListProvider）

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/app_preferences.dart' show OrientationMode, FeedType;
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
/// - [feedType] 当前浏览模式（latest/random/favorites/resume）
class VideoListState {
  final List<MediaItem> items;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int offset;
  final int limit;
  final FeedType feedType; // 当前浏览模式

  const VideoListState({
    this.items = const <MediaItem>[],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.offset = 0,
    this.limit = kDefaultPageLimit,
    this.feedType = FeedType.latest,
  });

  VideoListState copyWith({
    List<MediaItem>? items,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? offset,
    int? limit,
    FeedType? feedType,
  }) {
    return VideoListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
      feedType: feedType ?? this.feedType,
    );
  }
}

/// 视频列表 Notifier：响应媒体库切换和浏览模式变化自动加载视频
///
/// 内部监听：
/// - [selectedLibraryIdProvider] 媒体库选择变化
/// - [feedTypeProvider] 浏览模式变化（latest/random/favorites/resume）
class VideoListNotifier extends StateNotifier<VideoListState> {
  final Ref _ref;
  final EmbytokService _service;

  VideoListNotifier(this._ref, {EmbytokService? service})
      : _service = service ?? EmbytokService(),
        super(const VideoListState()) {
    // 监听 selectedLibraryIdProvider 变化：媒体库切换时自动刷新视频列表
    _ref.listen<String?>(
      selectedLibraryIdProvider,
      (previous, next) {
        if (next != null && next.isNotEmpty && next != previous) {
          AppLogger.debug('媒体库变化：$previous -> $next，刷新视频列表');
          refresh(libraryId: next);
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
  }

  // 读取认证信息
  AuthState get _auth => _ref.read(authProvider);

  // 根据当前 feedType 刷新视频列表
  // latest: 走 getLibraryItems 分页
  // random: 拉 80 条打乱，不分页
  // favorites: 拉 getFavoriteMovies 纯列表，不分页
  // resume: 拉 getResumeItems 续播列表，不分页
  Future<void> refresh({String? libraryId}) async {
    final currentFeedType = _ref.read(feedTypeProvider);

    state = VideoListState(
      items: const <MediaItem>[],
      isLoading: true,
      hasMore: true,
      error: null,
      offset: 0,
      limit: state.limit,
      feedType: currentFeedType,
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
        'libraryId': libraryId,
      });

      final List<MediaItem> loadedItems;
      final int totalCount;
      final bool canPaginate;

      switch (currentFeedType) {
        case FeedType.latest:
          final targetLibraryId = libraryId ?? _ref.read(selectedLibraryIdProvider);
          if (targetLibraryId == null || targetLibraryId.isEmpty) {
            state = state.copyWith(isLoading: false, hasMore: false);
            return;
          }
          final resp = await _service.getLibraryItems(
            targetLibraryId,
            limit: state.limit,
            offset: 0,
            serverUrl: auth.embyServerUrl!,
            token: auth.token!,
          );
          loadedItems = resp.items;
          totalCount = resp.total;
          canPaginate = true;

        case FeedType.random:
          final targetLibraryId = libraryId ?? _ref.read(selectedLibraryIdProvider);
          if (targetLibraryId == null || targetLibraryId.isEmpty) {
            state = state.copyWith(isLoading: false, hasMore: false);
            return;
          }
          final resp = await _service.getLibraryItems(
            targetLibraryId,
            limit: 80,
            offset: 0,
            serverUrl: auth.embyServerUrl!,
            token: auth.token!,
          );
          final shuffled = List<MediaItem>.from(resp.items);
          shuffled.shuffle();
          loadedItems = shuffled;
          totalCount = shuffled.length;
          canPaginate = false;

        case FeedType.favorites:
          final favList = await _service.getFavoriteMovies(
            serverUrl: auth.embyServerUrl!,
            token: auth.token!,
            userId: auth.user?.id,
          );
          loadedItems = favList;
          totalCount = favList.length;
          canPaginate = false;

        case FeedType.resume:
          final resp = await _service.getResumeItems(
            limit: 50,
            offset: 0,
            serverUrl: auth.embyServerUrl!,
            token: auth.token!,
          );
          loadedItems = resp.items;
          totalCount = resp.total;
          canPaginate = false;
      }

      final hasMore = canPaginate && (state.limit > 0) && (loadedItems.length < totalCount);

      state = VideoListState(
        items: loadedItems,
        isLoading: false,
        hasMore: hasMore,
        error: null,
        offset: loadedItems.length,
        limit: state.limit,
        feedType: currentFeedType,
      );
      AppLogger.debug('视频列表刷新成功', data: {
        'count': loadedItems.length,
        'total': totalCount,
        'feedType': currentFeedType.toStorageString(),
      });
    } catch (e) {
      AppLogger.error('刷新视频列表失败', error: e);
      final message = e is String ? e : '加载视频失败：$e';
      state = state.copyWith(isLoading: false, error: message);
    }
  }

  // 加载更多：仅在 latest 模式下生效，其它模式不分页
  Future<void> loadMore({String? libraryId}) async {
    if (state.isLoading || !state.hasMore) return;

    final currentFeedType = state.feedType;
    // random/favorites/resume 不分页
    if (currentFeedType != FeedType.latest) {
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
      final targetLibraryId = libraryId ?? _ref.read(selectedLibraryIdProvider);
      if (targetLibraryId == null || targetLibraryId.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      AppLogger.debug('加载更多视频', data: {'offset': state.offset});
      final resp = await _service.getLibraryItems(
        targetLibraryId,
        limit: state.limit,
        offset: state.offset,
        serverUrl: auth.embyServerUrl!,
        token: auth.token!,
      );

      final newItems = <MediaItem>[...state.items, ...resp.items];
      final hasMore = state.offset + resp.items.length < resp.total;

      state = VideoListState(
        items: newItems,
        isLoading: false,
        hasMore: hasMore,
        error: null,
        offset: state.offset + resp.items.length,
        limit: state.limit,
        feedType: currentFeedType,
      );
      AppLogger.debug('加载更多成功', data: {'newCount': resp.items.length});
    } catch (e) {
      AppLogger.error('加载更多失败', error: e);
      final message = e is String ? e : '加载更多失败：$e';
      state = state.copyWith(isLoading: false, error: message);
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
