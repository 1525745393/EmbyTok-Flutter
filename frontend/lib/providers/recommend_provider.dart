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
// 数据源（PR #78：推荐规则优化）：
//   1. NextUp 追剧（/Shows/NextUp）
//   2. Resume 续看（/Items/Resume）
//   3. Emby Suggestions 个性化推荐（基于观看历史）
//   4. 多库评分推荐（按社区评分从高到低，阈值 4.0）
//   5. 打乱 + 去重（用 round-robin 轮转替代纯随机）
//
// 过滤：
//   - 仅保留视频类型（Movie/Episode/Video/MusicVideo/Series）
//   - 过滤测试片（时长 < _minRuntimeSec 的）
//   - 评分推荐自动排除已观看（getRecommendations 内部 Filters=IsPlayed=false）
//
// 不分页：与原 FeedType.recommend 行为一致
//
// 修复记录（推荐系统审查专项）：
// P0-1/P0-2：_shouldSkipItem 统一过滤（黑名单 + 反疲劳 + 用户评分低）
// P0-3：追剧 NextUp 插入顺序修正（最近观看优先）
// P1-1/P2-2：_LoadContext + _buildLoadContext 抽离公共逻辑
// P1-2：_loadPage 拆分（5 个 fetch 方法 + _mergeRoundRobin）
// P1-3：userBehaviorSignalProvider 独立缓存 signal
// P1-4：_isLoading 互斥锁防并发
// P1-5：_runWithConcurrencyLimit 限制 HTTP 并发数
// P2-1：移除冗余 items 字段和 merged 字段
// P2-3：空标签分类显示空状态（_withDerived 不再回退）

import 'dart:async';

import 'dart:math' show Random;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../repositories/media_repository.dart';
import '../utils/logger.dart';
import 'app_preferences_providers.dart';
import 'auth_provider.dart';
import 'cache_providers.dart';
import 'favorites_provider.dart';
import 'library_provider.dart';
import 'recommend_signals.dart';
import 'watch_stats_provider.dart';

/// 推荐状态
class RecommendState {
  // PR #80：带数据源标签的推荐项（用于标签分类 UI）
  final List<RecommendItem> taggedItems;
  // PR #80：当前选中的标签（null=全部）
  final String? selectedTag;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int offset; // 当前已加载偏移（用于 loadMore）
  final bool hasMore;
  // PR #78：冷启动标志
  // - true: Suggestion 和 Resume 都为空，可能是新用户或无观看历史
  // - UI 可以显示"先观看几个视频"提示
  final bool isColdStart;

  // 性能优化：预计算的 derived 字段（由 Notifier._withDerived 填充）
  // - 避免在 build 方法中同步做 where + map + length 计算
  // - taggedItems 或 selectedTag 变化时由 Notifier 重新计算
  /// 根据 selectedTag 过滤后的展示列表
  final List<RecommendItem> displayItems;
  /// 各标签的计数（key = RecommendSource.key）
  final Map<String, int> tagCounts;

  const RecommendState({
    this.taggedItems = const [],
    this.selectedTag,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.offset = 0,
    this.hasMore = true,
    this.isColdStart = false,
    this.displayItems = const [],
    this.tagCounts = const {},
  });

  RecommendState copyWith({
    List<RecommendItem>? taggedItems,
    String? selectedTag,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? offset,
    bool? hasMore,
    bool? isColdStart,
    List<RecommendItem>? displayItems,
    Map<String, int>? tagCounts,
  }) {
    return RecommendState(
      taggedItems: taggedItems ?? this.taggedItems,
      selectedTag: selectedTag ?? this.selectedTag,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
      isColdStart: isColdStart ?? this.isColdStart,
      displayItems: displayItems ?? this.displayItems,
      tagCounts: tagCounts ?? this.tagCounts,
    );
  }
}

/// PR #80：推荐项 = MediaItem + 数据源标签
/// - 用于标签分类 UI：UI 可按 source 过滤显示
class RecommendItem {
  final MediaItem item;
  final RecommendSource source; // 数据源
  const RecommendItem({required this.item, required this.source});
}

/// PR #80：5 个数据源枚举 + 中文标签
enum RecommendSource {
  nextUp, // 追剧
  resume, // 续看
  suggestions, // 为你推荐
  similar, // 相似
  recommendations, // 高分
}

extension RecommendSourceLabel on RecommendSource {
  String get key {
    switch (this) {
      case RecommendSource.nextUp:
        return 'nextUp';
      case RecommendSource.resume:
        return 'resume';
      case RecommendSource.suggestions:
        return 'suggestions';
      case RecommendSource.similar:
        return 'similar';
      case RecommendSource.recommendations:
        return 'recommendations';
    }
  }

  // 中文标签（UI 显示用）
  String get label {
    switch (this) {
      case RecommendSource.nextUp:
        return '追剧';
      case RecommendSource.resume:
        return '续看';
      case RecommendSource.suggestions:
        return '为你推荐';
      case RecommendSource.similar:
        return '相似';
      case RecommendSource.recommendations:
        return '高分';
    }
  }
}

/// PR #79：分页 - 单页加载结果
/// 记录一页拉到的项 + 各数据源原始项数（用于 load() 冷启动检测）
class _PageLoadResult {
  final List<RecommendItem> tagged; // 带 source 标签的推荐项
  final int nextUpCount; // NextUp 数据源原始项数
  final int resumeCount; // Resume 数据源原始项数
  const _PageLoadResult({
    required this.tagged,
    required this.nextUpCount,
    required this.resumeCount,
  });
}

/// 加载上下文：封装 load() / loadMore() 共用的配置和计算结果
/// 减少两个方法之间的代码重复
class _LoadContext {
  final AuthState auth;
  final List<String> selectedIds;
  final MediaRepository repo;
  final double minRating;
  final bool excludePlayed;
  final Set<String> includeTypes;
  final int minRuntimeSec;
  final int minRuntimeTicks;
  final UserBehaviorSignal signal;
  final Set<String> favoriteIds;
  final bool antiFatigueEnabled;
  final Set<String> recentlyShownIds;
  final bool userRatingEnabled;
  final double userRatingMin;

  const _LoadContext({
    required this.auth,
    required this.selectedIds,
    required this.repo,
    required this.minRating,
    required this.excludePlayed,
    required this.includeTypes,
    required this.minRuntimeSec,
    required this.minRuntimeTicks,
    required this.signal,
    required this.favoriteIds,
    required this.antiFatigueEnabled,
    required this.recentlyShownIds,
    required this.userRatingEnabled,
    required this.userRatingMin,
  });

  // PR #73：过滤非视频类型 item
  bool isVideo(MediaItem item) => _allowedTypes.contains(item.type);

  // PR #78：时长过滤（避免测试片/预告片污染推荐）
  // 0 表示不过滤
  bool isTooShort(MediaItem item) {
    if (minRuntimeSec == 0) return false;
    final ticks = item.runtimeTicks;
    if (ticks == null) return false;
    return ticks < minRuntimeTicks;
  }

  static const Set<String> _allowedTypes = {
    'Movie',
    'Episode',
    'Video',
    'MusicVideo',
    'Series',
  };
}

/// 推荐 Notifier
class RecommendNotifier extends StateNotifier<RecommendState> {
  RecommendNotifier(this._ref) : super(const RecommendState()) {
    _init();
  }

  final Ref _ref;

  // 加载互斥锁：防止 load() 和 loadMore() 并发执行导致状态冲突
  bool _isLoading = false;

  // 并发请求数上限（多库高分推荐、相似推荐种子等场景）
  // 避免一次性发起过多 HTTP 请求导致服务器压力或连接池耗尽
  static const int _maxConcurrentRequests = 3;

  // 初始化：直接拉取 Emby 最新推荐数据
  // 缓存仅用于本会话内的 MemoryCache 加速（CachedMediaRepository），
  // 不做跨会话磁盘缓存，确保数据始终以 Emby 为准
  Future<void> _init() async {
    unawaited(load());
  }

  // 推荐每次加载数量（PR #78：20 → 30，提升推荐质量）
  static const int _pageSize = 30;

  // 数据源标签：用于日志 + round-robin 队列分组
  static const String _sourceNextUp = 'nextUp';
  static const String _sourceResume = 'resume';
  static const String _sourceSuggestions = 'suggestions';
  static const String _sourceRecommendations = 'recommendations';
  static const String _sourceSimilar = 'similar';

  // PR #78：相似推荐配置
  static const int _similarSeedCount = 3;
  static const int _similarPerSeed = 10;
  static const double _similarSeedMinRating = 7.0;

  // 构建加载上下文（load() 和 loadMore() 共用）
  // 鉴权失败或未选择媒体库时返回 null
  // PR #83 优化：从 userBehaviorSignalProvider 读取缓存的 signal
  _LoadContext? _buildLoadContext() {
    final auth = _ref.read(authProvider);
    final selectedIds = _ref.read(recommendLibraryIdsProvider);

    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
      return null;
    }
    if (selectedIds.isEmpty) {
      return null;
    }

    final repo = _ref.read(cachedMediaRepositoryProvider);

    // PR #78：读取推荐规则偏好
    final minRating = _ref.read(recommendMinRatingProvider);
    final excludePlayed = _ref.read(recommendExcludePlayedProvider);
    final minRuntimeSec = _ref.read(recommendMinRuntimeSecProvider);
    final includeTypes = _ref.read(recommendIncludeTypesProvider);
    final minRuntimeTicks = minRuntimeSec * 10000000;

    // PR #88：取最近展示记录
    final antiFatigueEnabled = _ref.read(recommendAntiFatigueEnabledProvider);
    final recentlyShownIds = _ref.read(recentlyShownItemIdsProvider);
    // PR #89：用户评分加权
    final userRatingEnabled = _ref.read(recommendUserRatingEnabledProvider);
    final userRatingMin = _ref.read(recommendUserRatingMinProvider);
    final favoriteIds = _ref.read(favoritesProvider).favoriteIds;

    // PR #83 优化：从 userBehaviorSignalProvider 读取缓存，避免每次重算
    final signal = _ref.read(userBehaviorSignalProvider);

    if (signal.strength != SignalStrength.weak) {
      AppLogger.debug('推荐：用户行为信号', data: {
        'strength': signal.strength.name,
        'weights': signal.sourceWeights
            .map((k, v) => MapEntry(k.key, v.toStringAsFixed(2))),
        'blacklistSize': signal.blacklist.length,
        'seedsCount': signal.highCompletionSeeds.length,
      });
    }

    return _LoadContext(
      auth: auth,
      selectedIds: selectedIds,
      repo: repo,
      minRating: minRating,
      excludePlayed: excludePlayed,
      includeTypes: includeTypes,
      minRuntimeSec: minRuntimeSec,
      minRuntimeTicks: minRuntimeTicks,
      signal: signal,
      favoriteIds: favoriteIds,
      antiFatigueEnabled: antiFatigueEnabled,
      recentlyShownIds: recentlyShownIds,
      userRatingEnabled: userRatingEnabled,
      userRatingMin: userRatingMin,
    );
  }

  // 记录反推荐疲劳的展示记录
  void _recordRecentlyShownItems(
    Iterable<String> itemIds,
    bool antiFatigueEnabled,
  ) {
    if (antiFatigueEnabled && itemIds.isNotEmpty) {
      unawaited(_ref.read(recentlyShownItemIdsProvider.notifier).addAll(itemIds));
    }
  }

  // 服务端单次上限（避免一次拉太多）
  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
    state = state.copyWith(isLoading: true, error: null);

    final ctx = _buildLoadContext();
    if (ctx == null) {
      final auth = _ref.read(authProvider);
      final selectedIds = _ref.read(recommendLibraryIdsProvider);
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
      return;
    }

    final seenIds = <String>{};

    // PR #79：抽离核心加载逻辑，支持分页
    final newItems = await _loadPage(
      ctx: ctx,
      seenIds: seenIds,
    );

    // 冷启动判定：建议数据源 + Resume 都为空
    final isColdStart = newItems.nextUpCount == 0 &&
        newItems.resumeCount == 0;

    // PR #79：首次加载启用冷启动降级
    List<RecommendItem> finalTagged = newItems.tagged;
    if (isColdStart) {
      AppLogger.info('推荐：冷启动模式，评分阈值降级');
      final degradedRating = ctx.minRating > 3.0 ? 3.0 : ctx.minRating;
      final degradedItems = await _loadRecommendations(
        ctx: ctx,
        minCommunityRating: degradedRating,
        seenIds: seenIds,
      );
      finalTagged = [...finalTagged, ...degradedItems];
    }

    // PR #79：分页 - 如果新项数 < _pageSize（5 数据源都不足一页），标记无更多
    final hasMore = finalTagged.length >= _pageSize;

    state = _withDerived(state.copyWith(
      taggedItems: finalTagged,
      isLoading: false,
      hasMore: hasMore,
      offset: finalTagged.length,
      error: null,
      isColdStart: isColdStart && finalTagged.length < _pageSize ~/ 2,
    ));
    // PR #88：记录展示过的 itemId（用于反推荐疲劳）
    _recordRecentlyShownItems(
      finalTagged.map((r) => r.item.id),
      ctx.antiFatigueEnabled,
    );
    AppLogger.debug('推荐列表加载完成', data: {
      'count': finalTagged.length,
      'minRating': ctx.minRating,
      'excludePlayed': ctx.excludePlayed,
      'minRuntimeSec': ctx.minRuntimeSec,
      'includeTypes': ctx.includeTypes.toList(),
      'isColdStart': isColdStart,
      'hasMore': hasMore,
    });
    } finally {
      _isLoading = false;
    }
  }

  /// PR #79：分页加载下一页
  /// 复用 5 数据源逻辑，结果去重后 append 到 state.taggedItems
  Future<void> loadMore() async {
    if (_isLoading) return;
    if (state.isLoadingMore || !state.hasMore) return;
    _isLoading = true;
    try {
    state = state.copyWith(isLoadingMore: true);

    final ctx = _buildLoadContext();
    if (ctx == null) {
      state = state.copyWith(isLoadingMore: false, hasMore: false);
      return;
    }

    // PR #79：从已显示的 items 构建 seenIds（去重）
    final seenIds = state.taggedItems.map((r) => r.item.id).toSet();

    final newItems = await _loadPage(
      ctx: ctx,
      seenIds: seenIds,
    );

    final merged = [...state.taggedItems, ...newItems.tagged];
    // PR #79：hasMore = (新加项数 >= _pageSize)，否则认为没有更多
    final hasMore = newItems.tagged.length >= _pageSize;

    state = _withDerived(state.copyWith(
      taggedItems: merged,
      isLoadingMore: false,
      hasMore: hasMore,
      offset: merged.length,
    ));
    // PR #88：记录新展示的 itemId
    _recordRecentlyShownItems(
      newItems.tagged.map((r) => r.item.id),
      ctx.antiFatigueEnabled,
    );
    AppLogger.debug('推荐 loadMore 完成', data: {
      'newCount': newItems.tagged.length,
      'total': merged.length,
      'hasMore': hasMore,
    });
    } finally {
      _isLoading = false;
    }
  }

  // PR #79：抽离 - 拉一页（5 数据源 + round-robin）
  // PR #80：每个 item 带 source 标签（用于 UI 分类过滤）
  // PR #83：完播率接入门控（黑名单 + source 权重 + 相似种子）
  // PR #86：favoriteIds 传入 - 黑名单跳过收藏
  // PR #88：antiFatigueEnabled + recentlyShownIds 传入 - X 天内不重推
  // PR #89：userRatingEnabled + userRatingMin 传入 - 用户评分 < 阈值跳过
  // 返回 _PageLoadResult，包含 taggedList（带 source 标签的 RecommendItem）
  // + 各数据源原始项数（供 load() 冷启动检测）
  Future<_PageLoadResult> _loadPage({
    required _LoadContext ctx,
    required Set<String> seenIds,
  }) async {
    final serverUrl = ctx.auth.embyServerUrl;
    final token = ctx.auth.token;
    final userId = ctx.auth.user?.id;
    if (serverUrl == null || token == null) {
      return const _PageLoadResult(
        tagged: [],
        nextUpCount: 0,
        resumeCount: 0,
      );
    }
    final queues = <String, List<RecommendItem>>{
      _sourceNextUp: <RecommendItem>[],
      _sourceResume: <RecommendItem>[],
      _sourceSuggestions: <RecommendItem>[],
      _sourceRecommendations: <RecommendItem>[],
      _sourceSimilar: <RecommendItem>[],
    };

    await Future.wait([
      _fetchNextUpQueue(ctx: ctx, queues: queues, serverUrl: serverUrl, token: token),
      _fetchResumeQueue(ctx: ctx, queues: queues, serverUrl: serverUrl, token: token),
      _fetchNextUpByRecentSeries(ctx: ctx, queues: queues, serverUrl: serverUrl, token: token, userId: userId),
      _fetchSuggestionsQueue(ctx: ctx, queues: queues, serverUrl: serverUrl, token: token, userId: userId),
      _fetchSimilarQueue(ctx: ctx, queues: queues, serverUrl: serverUrl, token: token, userId: userId),
      _fetchRecommendationsQueue(ctx: ctx, queues: queues, seenIds: seenIds),
    ]);

    return _mergeRoundRobin(
      queues: queues,
      signal: ctx.signal,
      seenIds: seenIds,
    );
  }

  // 填充 NextUp 追剧队列
  Future<void> _fetchNextUpQueue({
    required _LoadContext ctx,
    required Map<String, List<RecommendItem>> queues,
    required String serverUrl,
    required String token,
  }) async {
    try {
      final resp = await ctx.repo.getNextUp(
        limit: _pageSize,
        serverUrl: serverUrl,
        token: token,
      );
      final nextUpQueue = queues[_sourceNextUp];
      for (final item in resp.items) {
        if (!ctx.isVideo(item) || ctx.isTooShort(item)) continue;
        if (_shouldSkipItem(
          item,
          signal: ctx.signal,
          favoriteIds: ctx.favoriteIds,
          antiFatigueEnabled: ctx.antiFatigueEnabled,
          recentlyShownIds: ctx.recentlyShownIds,
          userRatingEnabled: ctx.userRatingEnabled,
          userRatingMin: ctx.userRatingMin,
        )) continue;
        nextUpQueue?.add(RecommendItem(item: item, source: RecommendSource.nextUp));
      }
    } catch (e) {
      AppLogger.error('推荐：加载 NextUp 失败', error: e);
    }
  }

  // 填充 Resume 续看队列
  Future<void> _fetchResumeQueue({
    required _LoadContext ctx,
    required Map<String, List<RecommendItem>> queues,
    required String serverUrl,
    required String token,
  }) async {
    try {
      final resp = await ctx.repo.getResumeItems(
        limit: _pageSize,
        serverUrl: serverUrl,
        token: token,
      );
      final resumeQueue = queues[_sourceResume];
      for (final item in resp.items) {
        if (!ctx.isVideo(item) || ctx.isTooShort(item)) continue;
        if (_shouldSkipItem(
          item,
          signal: ctx.signal,
          favoriteIds: ctx.favoriteIds,
          antiFatigueEnabled: ctx.antiFatigueEnabled,
          recentlyShownIds: ctx.recentlyShownIds,
          userRatingEnabled: ctx.userRatingEnabled,
          userRatingMin: ctx.userRatingMin,
        )) continue;
        resumeQueue?.add(RecommendItem(item: item, source: RecommendSource.resume));
      }
    } catch (e) {
      AppLogger.error('推荐：加载 Resume 失败', error: e);
    }
  }

  // PR #87：从最近看过的 series 拉下一集，插入到 NextUp 队列前面
  // 修复 P0-3：收集所有下一集后一次性插入队首，保证最近观看优先
  Future<void> _fetchNextUpByRecentSeries({
    required _LoadContext ctx,
    required Map<String, List<RecommendItem>> queues,
    required String serverUrl,
    required String token,
    String? userId,
  }) async {
    try {
      const int recentSeriesLimit = 3;
      final history = await ctx.repo.getWatchHistory(
        limit: 50,
        userId: userId,
        serverUrl: serverUrl,
        token: token,
      );
      final seenSeriesIds = <String>{};
      final recentSeriesIds = <String>[];
      for (final item in history) {
        final sid = item.seriesId;
        if (sid == null || sid.isEmpty) continue;
        if (seenSeriesIds.contains(sid)) continue;
        seenSeriesIds.add(sid);
        recentSeriesIds.add(sid);
        if (recentSeriesIds.length >= recentSeriesLimit) break;
      }
      if (recentSeriesIds.isEmpty) return;

      // 并发限制：最多同时请求 _maxConcurrentRequests 个 series
      final tasks = recentSeriesIds.map((sid) => () async {
        try {
          final resp = await ctx.repo.getNextUp(
            limit: 3,
            seriesId: sid,
            serverUrl: serverUrl,
            token: token,
          );
          return resp.items;
        } catch (e) {
          AppLogger.error('推荐：加载 series $sid NextUp 失败', error: e);
          return <MediaItem>[];
        }
      }).toList();
      final nextUpLists = await _runWithConcurrencyLimit(tasks);

      // P0-3 修复：一次性收集所有下一集后插入队首
      // 遍历顺序 = recentSeriesIds 顺序（最近观看优先），同 series 内按 season+index 排序
      final allNextUp = <RecommendItem>[];
      for (final list in nextUpLists) {
        final sorted = List<MediaItem>.from(list)
          ..sort((a, b) {
            final sa = a.parentIndexNumber ?? 0;
            final sb = b.parentIndexNumber ?? 0;
            if (sa != sb) return sa.compareTo(sb);
            return (a.indexNumber ?? 0).compareTo(b.indexNumber ?? 0);
          });
        for (final item in sorted) {
          if (!ctx.isVideo(item) || ctx.isTooShort(item)) continue;
          if (_shouldSkipItem(
            item,
            signal: ctx.signal,
            favoriteIds: ctx.favoriteIds,
            antiFatigueEnabled: ctx.antiFatigueEnabled,
            recentlyShownIds: ctx.recentlyShownIds,
            userRatingEnabled: ctx.userRatingEnabled,
            userRatingMin: ctx.userRatingMin,
          )) continue;
          allNextUp.add(RecommendItem(item: item, source: RecommendSource.nextUp));
        }
      }
      if (allNextUp.isNotEmpty) {
        final nextUpQueue = queues[_sourceNextUp];
        nextUpQueue?.insertAll(0, allNextUp);
      }
    } catch (e) {
      AppLogger.error('推荐：NextUp by series 流程失败', error: e);
    }
  }

  // 填充个性化推荐队列
  Future<void> _fetchSuggestionsQueue({
    required _LoadContext ctx,
    required Map<String, List<RecommendItem>> queues,
    required String serverUrl,
    required String token,
    String? userId,
  }) async {
    try {
      final suggestions = await ctx.repo.getSuggestions(
        limit: _pageSize,
        serverUrl: serverUrl,
        token: token,
        userId: userId,
      );
      final suggestionsQueue = queues[_sourceSuggestions];
      for (final item in suggestions) {
        if (!ctx.isVideo(item) || ctx.isTooShort(item)) continue;
        if (_shouldSkipItem(
          item,
          signal: ctx.signal,
          favoriteIds: ctx.favoriteIds,
          antiFatigueEnabled: ctx.antiFatigueEnabled,
          recentlyShownIds: ctx.recentlyShownIds,
          userRatingEnabled: ctx.userRatingEnabled,
          userRatingMin: ctx.userRatingMin,
        )) continue;
        suggestionsQueue?.add(
            RecommendItem(item: item, source: RecommendSource.suggestions));
      }
    } catch (e) {
      AppLogger.error('推荐：加载个性化推荐失败', error: e);
    }
  }

  // PR #83：用 signal 高完播种子替换"最近高分项"做相似推荐种子
  // PR #86：收藏项优先作为相似种子
  Future<void> _fetchSimilarQueue({
    required _LoadContext ctx,
    required Map<String, List<RecommendItem>> queues,
    required String serverUrl,
    required String token,
    String? userId,
  }) async {
    try {
      final history = await ctx.repo.getWatchHistory(
        limit: 200,
        userId: userId,
        serverUrl: serverUrl,
        token: token,
      );
      final seedByItemId = <String, MediaItem>{};

      // 1. 收藏种子（PR #86）
      if (ctx.signal.favoriteSeeds.isNotEmpty) {
        final favoriteSet = ctx.signal.favoriteSeeds.toSet();
        for (final item in history) {
          if (favoriteSet.contains(item.id)) {
            seedByItemId[item.id] = item;
          }
        }
      }

      // 2. 完播种子（PR #83）
      if (ctx.signal.highCompletionSeeds.isNotEmpty) {
        final completionSet = ctx.signal.highCompletionSeeds.toSet();
        for (final item in history) {
          if (seedByItemId.containsKey(item.id)) continue;
          if (completionSet.contains(item.id)) {
            seedByItemId[item.id] = item;
          }
        }
      }

      // 3. 降级：最近高分项
      if (seedByItemId.isEmpty) {
        for (final item in history) {
          if ((item.communityRating ?? 0) >= _similarSeedMinRating) {
            seedByItemId.putIfAbsent(item.id, () => item);
          }
        }
      }

      final highRated = seedByItemId.values
          .where((i) => (i.communityRating ?? 0) >= _similarSeedMinRating)
          .toList()
        ..sort((a, b) =>
            (b.communityRating ?? 0).compareTo(a.communityRating ?? 0));
      final topSeeds = highRated.take(_similarSeedCount).toList();
      if (topSeeds.isEmpty) {
        return;
      }
      // 并发限制：最多同时请求 _maxConcurrentRequests 个种子
      final tasks = topSeeds.map((seed) => () async {
        try {
          return await ctx.repo.getSimilarItems(
            seed.id,
            limit: _similarPerSeed,
            serverUrl: serverUrl,
            token: token,
          );
        } catch (e) {
          AppLogger.error('推荐：加载 ${seed.id} Similar 失败', error: e);
          return <MediaItem>[];
        }
      }).toList();
      final similarLists = await _runWithConcurrencyLimit(tasks);
      for (final list in similarLists) {
        final similarQueue = queues[_sourceSimilar];
        for (final item in list) {
          if (!ctx.isVideo(item) || ctx.isTooShort(item)) continue;
          if (_shouldSkipItem(
            item,
            signal: ctx.signal,
            favoriteIds: ctx.favoriteIds,
            antiFatigueEnabled: ctx.antiFatigueEnabled,
            recentlyShownIds: ctx.recentlyShownIds,
            userRatingEnabled: ctx.userRatingEnabled,
            userRatingMin: ctx.userRatingMin,
          )) continue;
          similarQueue?.add(RecommendItem(item: item, source: RecommendSource.similar));
        }
      }
    } catch (e) {
      AppLogger.error('推荐：Similar 流程失败', error: e);
    }
  }

  // 填充多库高分推荐队列
  Future<void> _fetchRecommendationsQueue({
    required _LoadContext ctx,
    required Map<String, List<RecommendItem>> queues,
    required Set<String> seenIds,
  }) async {
    final serverUrl = ctx.auth.embyServerUrl;
    final token = ctx.auth.token;
    final userId = ctx.auth.user?.id;
    if (serverUrl == null || token == null) return;
    // 并发限制：最多同时请求 _maxConcurrentRequests 个库
    final tasks = ctx.selectedIds.map((libId) => () async {
      try {
        final resp = await ctx.repo.getRecommendations(
          libraryId: libId,
          limit: _pageSize,
          offset: 0,
          serverUrl: serverUrl,
          token: token,
          userId: userId,
          minCommunityRating: ctx.minRating,
          excludePlayed: ctx.excludePlayed,
          includeItemTypes: ctx.includeTypes,
        );
        for (final item in resp.items) {
          if (ctx.isTooShort(item)) continue;
          if (_shouldSkipItem(
            item,
            signal: ctx.signal,
            favoriteIds: ctx.favoriteIds,
            antiFatigueEnabled: ctx.antiFatigueEnabled,
            recentlyShownIds: ctx.recentlyShownIds,
            userRatingEnabled: ctx.userRatingEnabled,
            userRatingMin: ctx.userRatingMin,
          )) continue;
          if (seenIds.add(item.id)) {
            queues[_sourceRecommendations]?.add(RecommendItem(
                item: item, source: RecommendSource.recommendations));
          }
        }
      } catch (e) {
        AppLogger.error('推荐：加载库 $libId 推荐列表失败', error: e);
      }
    }).toList();
    await _runWithConcurrencyLimit(tasks);
  }

  // PR #79：抽离 - 冷启动降级：拉一轮更低阈值的评分推荐
  // PR #80：返回带 source 标签的 RecommendItem 列表
  // PR #83+#88+#89：完整过滤（黑名单 + 反疲劳 + 用户评分低）
  Future<List<RecommendItem>> _loadRecommendations({
    required _LoadContext ctx,
    required double minCommunityRating,
    required Set<String> seenIds,
  }) async {
    final serverUrl = ctx.auth.embyServerUrl;
    final token = ctx.auth.token;
    final userId = ctx.auth.user?.id;
    if (serverUrl == null || token == null) return [];
    final results = <RecommendItem>[];
    // 并发限制：最多同时请求 _maxConcurrentRequests 个库
    final tasks = ctx.selectedIds.map((libId) => () async {
      try {
        final resp = await ctx.repo.getRecommendations(
          libraryId: libId,
          limit: _pageSize,
          offset: 0,
          serverUrl: serverUrl,
          token: token,
          userId: userId,
          minCommunityRating: minCommunityRating,
          excludePlayed: ctx.excludePlayed,
          includeItemTypes: ctx.includeTypes,
        );
        for (final item in resp.items) {
          if (ctx.isTooShort(item)) continue;
          if (_shouldSkipItem(
            item,
            signal: ctx.signal,
            favoriteIds: ctx.favoriteIds,
            antiFatigueEnabled: ctx.antiFatigueEnabled,
            recentlyShownIds: ctx.recentlyShownIds,
            userRatingEnabled: ctx.userRatingEnabled,
            userRatingMin: ctx.userRatingMin,
          )) continue;
          if (seenIds.add(item.id)) {
            results.add(RecommendItem(
                item: item, source: RecommendSource.recommendations));
          }
        }
      } catch (e) {
        AppLogger.error('推荐：冷启动降级加载失败', error: e);
      }
    }).toList();
    await _runWithConcurrencyLimit(tasks);
    return results;
  }

  // round-robin 合并各队列，按 source 权重分配配额
  _PageLoadResult _mergeRoundRobin({
    required Map<String, List<RecommendItem>> queues,
    required UserBehaviorSignal signal,
    required Set<String> seenIds,
  }) {
    for (final list in queues.values) {
      list.shuffle();
    }
    final nextUpCount = queues[_sourceNextUp]?.length ?? 0;
    final resumeCount = queues[_sourceResume]?.length ?? 0;
    final sourceOrder = <RecommendSource>[
      RecommendSource.nextUp,
      RecommendSource.resume,
      RecommendSource.suggestions,
      RecommendSource.similar,
      RecommendSource.recommendations,
    ];
    final tagged = <RecommendItem>[];
    final rng = Random();
    while (sourceOrder.any((s) => _queueOf(queues, s).isNotEmpty)) {
      for (final source in sourceOrder) {
        final q = _queueOf(queues, source);
        if (q.isEmpty) continue;
        final w = signal.weightFor(source);
        int take;
        if (w < 0.7) {
          if (!rng.nextBool()) continue;
          take = 1;
        } else {
          take = w.round().clamp(1, 3);
        }
        for (int i = 0; i < take && q.isNotEmpty; i++) {
          final r = q.removeAt(0);
          if (seenIds.add(r.item.id)) {
            tagged.add(r);
          }
        }
      }
    }
    return _PageLoadResult(
      tagged: tagged,
      nextUpCount: nextUpCount,
      resumeCount: resumeCount,
    );
  }

  // PR #83：从 queues Map 按 RecommendSource 查队列
  List<RecommendItem> _queueOf(
    Map<String, List<RecommendItem>> queues,
    RecommendSource source,
  ) {
    switch (source) {
      case RecommendSource.nextUp:
        return queues[_sourceNextUp] ?? const [];
      case RecommendSource.resume:
        return queues[_sourceResume] ?? const [];
      case RecommendSource.suggestions:
        return queues[_sourceSuggestions] ?? const [];
      case RecommendSource.similar:
        return queues[_sourceSimilar] ?? const [];
      case RecommendSource.recommendations:
        return queues[_sourceRecommendations] ?? const [];
    }
  }

  // 并发限制工具：限制同时执行的异步任务数
  // 实现思路：滑动窗口，每完成一个就补上一个，保持最多 maxConcurrent 个在跑
  static Future<List<T>> _runWithConcurrencyLimit<T>(
    List<Future<T> Function()> tasks, {
    int maxConcurrent = _maxConcurrentRequests,
  }) async {
    if (tasks.isEmpty) return const [];
    final results = List<T?>.filled(tasks.length, null);
    int nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final i = nextIndex++;
        if (i >= tasks.length) return;
        results[i] = await tasks[i]();
      }
    }

    final workerCount = maxConcurrent.clamp(1, tasks.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return results.cast<T>();
  }

  // PR #83+#88+#89：统一的 item 过滤逻辑
  // - 黑名单（收藏豁免）
  // - 反推荐疲劳（收藏豁免）
  // - 用户评分低（收藏豁免）
  // 所有数据源共用此逻辑，确保过滤一致性
  bool _shouldSkipItem(
    MediaItem item, {
    required UserBehaviorSignal signal,
    required Set<String> favoriteIds,
    required bool antiFatigueEnabled,
    required Set<String> recentlyShownIds,
    required bool userRatingEnabled,
    required double userRatingMin,
  }) {
    final isBlacklisted =
        signal.blacklist.contains(item.id) && !favoriteIds.contains(item.id);
    final isRecentlyShown = antiFatigueEnabled &&
        recentlyShownIds.contains(item.id) &&
        !favoriteIds.contains(item.id);
    bool isUserRatingLow() {
      if (!userRatingEnabled) return false;
      if (userRatingMin <= 0) return false;
      if (favoriteIds.contains(item.id)) return false;
      final ur = item.userRating;
      if (ur == null) return false;
      return ur < userRatingMin;
    }
    return isBlacklisted || isRecentlyShown || isUserRatingLow();
  }

  /// 刷新（用户下拉刷新时调用）
  Future<void> refresh() async {
    await load();
  }

  /// 性能优化：为 state 补充预计算的 derived 字段
  ///
  /// 把 build 方法中的同步过滤 + 计数逻辑提前到 Provider 层：
  /// - [displayItems]：按 selectedTag 过滤后的列表
  /// - [tagCounts]：各数据源标签的项数（用于标签栏徽标）
  ///
  /// 在 taggedItems 或 selectedTag 变化时调用，避免每次 widget rebuild
  /// 都重复执行 O(n) 的 where + map + length 操作。
  RecommendState _withDerived(RecommendState s) {
    final tag = s.selectedTag;
    final displayItems = tag == null
        ? s.taggedItems
        : s.taggedItems
            .where((r) => r.source.key == tag)
            .toList(growable: false);

    final tagCounts = <String, int>{};
    for (final item in s.taggedItems) {
      final key = item.source.key;
      tagCounts[key] = (tagCounts[key] ?? 0) + 1;
    }

    return s.copyWith(
      displayItems: displayItems,
      tagCounts: tagCounts,
    );
  }

  /// PR #80：选择标签（切换数据源分类）
  /// - tag=null 表示「全部」
  /// - 仅影响 view 渲染（view 按 taggedItems.filter(...).item 渲染）
  void selectTag(String? tag) {
    state = _withDerived(state.copyWith(selectedTag: tag));
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
