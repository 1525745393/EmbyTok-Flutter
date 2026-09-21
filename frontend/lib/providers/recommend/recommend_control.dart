// 从 recommend_provider.dart 拆分（part 文件，无行为变化）

part of '../recommend_provider.dart';

// ==================== _RecommendControl ====================

extension _RecommendControl on RecommendNotifier {
  Future<void> _init() async {
    safeUnawaited(load(), context: 'RecommendNotifier._init');
  }

  void _subscribeLibraryChanges() {
    _ref.listen<List<String>>(
      recommendLibraryIdsProvider,
      (previous, next) {
        final prevStr = previous?.join(',') ?? '';
        final nextStr = next.join(',');
        if (next.isEmpty || nextStr == prevStr) return;
        // 合并连续变更（如 chip 快速增删），避免触发多次重复加载
        _libraryRefreshDebounce?.cancel();
        _libraryRefreshDebounce = Timer(
          const Duration(milliseconds: 400),
          () => safeUnawaited(refresh(),
              context: 'RecommendNotifier.libraryChange'),
        );
      },
    );
  }

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
    // 用户显式"不感兴趣"集合（本地持久化）
    final dislikedIds = _ref.read(dislikedItemsProvider);
    // 追剧队列数量平衡
    final nextUpSeriesCount = _ref.read(recommendNextUpSeriesCountProvider);
    // 关注页：每演员视频数 / 只看未观看
    final followActorVideoCount = _ref.read(followActorVideoCountProvider);
    final followOnlyUnwatched = _ref.read(followOnlyUnwatchedProvider);
    final followMaxActors = _ref.read(followMaxActorsProvider);

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
      dislikedIds: dislikedIds,
      antiFatigueEnabled: antiFatigueEnabled,
      recentlyShownIds: recentlyShownIds,
      userRatingEnabled: userRatingEnabled,
      userRatingMin: userRatingMin,
      nextUpSeriesCount: nextUpSeriesCount,
      followActorVideoCount: followActorVideoCount,
      followOnlyUnwatched: followOnlyUnwatched,
      followMaxActors: followMaxActors,
    );
  }

  void _recordRecentlyShownItems(
    Iterable<String> itemIds,
    bool antiFatigueEnabled,
  ) {
    if (antiFatigueEnabled && itemIds.isNotEmpty) {
      safeUnawaited(
        _ref.read(recentlyShownItemIdsProvider.notifier).addAll(itemIds),
        context: 'RecommendNotifier._recordRecentlyShownItems',
      );
    }
  }

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
        suggestionsCount: 0,
        allSourcesExhausted: true,
      );
    }
    // 合并拉取观看历史：相似种子筛选与「最近剧集下一集」都需要，
    // 原先两处各自 getWatchHistory（200/50）造成重复请求，此处只拉一次。
    List<MediaItem> watchHistory = const [];
    try {
      watchHistory = await ctx.repo.getWatchHistory(
        limit: 200,
        userId: userId,
        serverUrl: serverUrl,
        token: token,
      );
    } catch (e) {
      AppLogger.error('推荐：加载观看历史失败', error: e);
    }

    final queues = <String, List<RecommendItem>>{
      RecommendNotifier._sourceLatest: <RecommendItem>[],
      RecommendNotifier._sourceNextUp: <RecommendItem>[],
      RecommendNotifier._sourceResume: <RecommendItem>[],
      RecommendNotifier._sourceSuggestions: <RecommendItem>[],
      RecommendNotifier._sourceNative: <RecommendItem>[],
      RecommendNotifier._sourceRecommendations: <RecommendItem>[],
      RecommendNotifier._sourceSimilar: <RecommendItem>[],
      RecommendNotifier._sourceLocal: <RecommendItem>[],
    };

    // Task 4：并发拉取各数据源，收集各源是否还有更多数据的标记
    // _fetchNextUpByRecentSeries 也填充 NextUp 队列，但不参与 hasMore 判定
    final nextUpByRecentFuture = _fetchNextUpByRecentSeries(
      ctx: ctx,
      queues: queues,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
      watchHistory: watchHistory,
    );
    // 关注流深化：收藏剧集的更新（主动订阅），同样不参与 hasMore 判定
    final nextUpByFavSeriesFuture = _fetchNextUpByFavoriteSeries(
      ctx: ctx,
      queues: queues,
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    );
    // 顺序对应 sourceHasMore 索引：
    // [0]=Latest, [1]=NextUp, [2]=Resume, [3]=Suggestions,
    // [4]=Native, [5]=Similar, [6]=Recommendations, [7]=Local
    final sourceHasMore = await Future.wait<bool>([
      _fetchLatestQueue(
          ctx: ctx, queues: queues, serverUrl: serverUrl, token: token),
      _fetchNextUpQueue(
          ctx: ctx, queues: queues, serverUrl: serverUrl, token: token),
      _fetchResumeQueue(
          ctx: ctx, queues: queues, serverUrl: serverUrl, token: token),
      _fetchSuggestionsQueue(
          ctx: ctx,
          queues: queues,
          serverUrl: serverUrl,
          token: token,
          userId: userId),
      _fetchNativeRecommendationsQueue(
          ctx: ctx,
          queues: queues,
          serverUrl: serverUrl,
          token: token,
          userId: userId),
      _fetchSimilarQueue(
          ctx: ctx,
          queues: queues,
          serverUrl: serverUrl,
          token: token,
          userId: userId,
          watchHistory: watchHistory),
      _fetchRecommendationsQueue(ctx: ctx, queues: queues, seenIds: seenIds),
      _fetchLocalRecommendQueue(
          ctx: ctx, queues: queues, serverUrl: serverUrl, token: token),
    ]);
    await nextUpByRecentFuture;
    await nextUpByFavSeriesFuture;

    return _mergeRoundRobin(
      queues: queues,
      signal: ctx.signal,
      seenIds: seenIds,
      sourceHasMore: sourceHasMore,
    );
  }

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

  bool _shouldSkipItem(
    MediaItem item, {
    required UserBehaviorSignal signal,
    required Set<String> favoriteIds,
    required Set<String> dislikedIds,
    required bool antiFatigueEnabled,
    required Set<String> recentlyShownIds,
    required bool userRatingEnabled,
    required double userRatingMin,
  }) {
    final isBlacklisted =
        signal.blacklist.contains(item.id) && !favoriteIds.contains(item.id);
    final isDisliked =
        dislikedIds.contains(item.id) && !favoriteIds.contains(item.id);
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

    return isBlacklisted || isDisliked || isRecentlyShown || isUserRatingLow();
  }
}
