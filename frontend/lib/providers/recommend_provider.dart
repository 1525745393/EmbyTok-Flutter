// 推荐独立 Provider
//
// 背景（PR #57）：
// 推荐从 FeedType 中移除，改为独立路由 /recommend + 独立数据源。
// 原因：之前推荐和视频流共享 video_list_provider，导致：
//   - 切换到"推荐"时 refresh() 替换 items，污染视频流
//   - PageView index 对应的视频突变
//   - VideoPlayerWidget 需要 didUpdateWidget 重建
// 根治：推荐完全独立，不再影响 feed/grid 任何状态。
//
// 数据源（与原 FeedType.recommend 一致）：
//   1. Emby Suggestions 个性化推荐（基于观看历史）
//   2. 多库评分推荐（按社区评分从高到低，阈值 4.0）
//   3. 打乱 + 去重
//
// 不分页（与原行为一致：loadedTotal = totalItems 但 canPaginate = totalItems > merged.length
// 由于 mixed merge 后 total 不准，目前简单实现为"一次性加载 + 不分页"）

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';
import 'library_provider.dart';

/// 推荐状态
class RecommendState {
  final List<MediaItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int offset; // 当前已加载偏移（用于 loadMore）
  final bool hasMore;

  const RecommendState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.offset = 0,
    this.hasMore = true,
  });

  RecommendState copyWith({
    List<MediaItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? offset,
    bool? hasMore,
  }) {
    return RecommendState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// 推荐 Notifier
class RecommendNotifier extends StateNotifier<RecommendState> {
  RecommendNotifier(this._ref) : super(const RecommendState()) {
    // 进入页面时自动加载
    load();
  }

  final Ref _ref;

  // 推荐每次加载数量
  static const int _pageSize = 20;

  // 服务端单次上限（避免一次拉太多）
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);

    final auth = _ref.read(authProvider);
    final selectedIds = _ref.read(selectedLibraryIdsProvider);

    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
      state = state.copyWith(isLoading: false, hasMore: false, error: '尚未登录');
      return;
    }

    if (selectedIds.isEmpty) {
      state = state.copyWith(isLoading: false, hasMore: false, error: '未选择媒体库');
      return;
    }

    final service = EmbytokService();
    final seenIds = <String>{};
    final merged = <MediaItem>[];

    try {
      // 1. Emby Suggestions 个性化推荐
      try {
        final suggestions = await service.getSuggestions(
          limit: _pageSize,
          serverUrl: auth.embyServerUrl!,
          token: auth.token!,
          userId: auth.user?.id,
        );
        for (final item in suggestions) {
          if (seenIds.add(item.id)) merged.add(item);
        }
      } catch (e) {
        AppLogger.error('推荐：加载个性化推荐失败', error: e);
      }

      // 2. 多库评分推荐
      for (final libId in selectedIds) {
        try {
          final resp = await service.getRecommendations(
            libraryId: libId,
            limit: _pageSize,
            offset: 0,
            serverUrl: auth.embyServerUrl!,
            token: auth.token!,
            userId: auth.user?.id,
          );
          for (final item in resp.items) {
            if (seenIds.add(item.id)) merged.add(item);
          }
        } catch (e) {
          AppLogger.error('推荐：加载库 $libId 推荐列表失败', error: e);
        }
      }

      // 3. 打乱顺序让各库内容均匀分布
      merged.shuffle();

      state = state.copyWith(
        items: merged,
        isLoading: false,
        hasMore: false, // 推荐模式不分页（与原 FeedType.recommend 行为一致）
        offset: merged.length,
        error: null,
      );
      AppLogger.debug('推荐列表加载完成', data: {'count': merged.length});
    } catch (e) {
      AppLogger.error('推荐列表加载失败', error: e);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 刷新（用户下拉刷新时调用）
  Future<void> refresh() async {
    await load();
  }

  /// 清除错误（SnackBar 弹出后重置，避免重复弹出）
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// 推荐 Provider：与 FeedType / video_list_provider 完全解耦
final recommendProvider = StateNotifierProvider<RecommendNotifier, RecommendState>(
  (ref) => RecommendNotifier(ref),
);
