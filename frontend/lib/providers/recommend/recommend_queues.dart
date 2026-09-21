// 从 recommend_provider.dart 拆分（part 文件，无行为变化）

part of '../recommend_provider.dart';

// ==================== _RecommendQueues ====================

extension _RecommendQueues on RecommendNotifier {
  Future<bool> _fetchLatestQueue({
    required _LoadContext ctx,
    required Map<String, List<RecommendItem>> queues,
    required String serverUrl,
    required String token,
  }) async {
    try {
      final libraryId =
          ctx.selectedIds.length == 1 ? ctx.selectedIds.first : null;
      final resp = await ctx.repo.getLatestItems(
        limit: RecommendNotifier._pageSize,
        libraryId: libraryId,
        userId: ctx.auth.user?.id,
        serverUrl: serverUrl,
        token: token,
      );
      final q = queues[RecommendNotifier._sourceLatest];
      for (final item in resp.items) {
        if (!ctx.isVideo(item) || ctx.isTooShort(item)) continue;
        if (_shouldSkipItem(
          item,
          signal: ctx.signal,
          favoriteIds: ctx.favoriteIds,
          dislikedIds: ctx.dislikedIds,
          antiFatigueEnabled: ctx.antiFatigueEnabled,
          recentlyShownIds: ctx.recentlyShownIds,
          userRatingEnabled: ctx.userRatingEnabled,
          userRatingMin: ctx.userRatingMin,
        )) {
          continue;
        }
        q?.add(RecommendItem(item: item, source: RecommendSource.latest));
      }
      return resp.items.length >= RecommendNotifier._pageSize;
    } catch (e) {
      AppLogger.error('推荐：加载最新影片失败', error: e);
      return false;
    }
  }

  Future<bool> _fetchNextUpQueue({
    required _LoadContext ctx,
    required Map<String, List<RecommendItem>> queues,
    required String serverUrl,
    required String token,
  }) async {
    try {
      final nextUpQueue = queues[RecommendNotifier._sourceNextUp];
      final userId = ctx.auth.user?.id;

      // 优先：收藏演员的作品（推荐页「追剧」=关注演员的最新片）
      // 关注流按演员逐个拉取：覆盖所有收藏演员，每个演员最多
      // followActorVideoCount 条（用户可自定义），已观看过滤由
      // followOnlyUnwatched 开关控制（默认开启）。
      // 分页拉取所有收藏演员（上限由用户自定义 followMaxActors）。
      List<MediaItem> items = const [];
      var hasMore = false;
      final allFavPeople = <MediaItem>[];
      final maxFavoritePeople = ctx.followMaxActors;
      var favOffset = 0;
      const favPageSize = 50;
      while (allFavPeople.length < maxFavoritePeople) {
        final favPage = await ctx.repo.getFavoritePeople(
          limit: favPageSize,
          offset: favOffset,
          serverUrl: serverUrl,
          token: token,
          userId: userId,
        );
        allFavPeople.addAll(favPage.items);
        if (favPage.items.length < favPageSize) break; // 已拉完
        favOffset += favPageSize;
      }
      final personIds =
          allFavPeople.map((p) => p.id).where((id) => id.isNotEmpty).toList();
      if (personIds.isNotEmpty) {
        final perActor = ctx.followActorVideoCount;
        final all = <MediaItem>[];
        var anyActorReachedLimit = false;
        // 并发分批拉取（复用推荐并发上限），避免一次性发起过多请求
        for (var i = 0;
            i < personIds.length;
            i += RecommendNotifier._maxConcurrentRequests) {
          final batch = personIds
              .skip(i)
              .take(RecommendNotifier._maxConcurrentRequests)
              .toList();
          final responses =
              await Future.wait(batch.map((pid) => ctx.repo.getItemsByPersonIds(
                    personIds: [pid],
                    limit: perActor,
                    serverUrl: serverUrl,
                    token: token,
                    userId: userId,
                  )));
          for (final resp in responses) {
            all.addAll(resp.items);
            if (resp.items.length >= perActor) anyActorReachedLimit = true;
          }
        }
        items = all;
        hasMore = anyActorReachedLimit;
      } else {
        // 无收藏演员：不回退 NextUp，留空队列，
        // 由 UI 在空态引导用户去收藏演员。
        items = const [];
        hasMore = false;
      }

      for (final item in items) {
        if (!ctx.isVideo(item) || ctx.isTooShort(item)) continue;
        // 关注流只展示未看完的（可由「只看未观看」开关关闭）：
        // 已看完的跳过，避免老片占着"新作品"的位置。
        if (ctx.followOnlyUnwatched && item.isWatched) continue;
        if (_shouldSkipItem(
          item,
          signal: ctx.signal,
          favoriteIds: ctx.favoriteIds,
          dislikedIds: ctx.dislikedIds,
          antiFatigueEnabled: ctx.antiFatigueEnabled,
          recentlyShownIds: ctx.recentlyShownIds,
          userRatingEnabled: ctx.userRatingEnabled,
          userRatingMin: ctx.userRatingMin,
        )) {
          continue;
        }
        nextUpQueue?.add(RecommendItem(
          item: item,
          source: RecommendSource.nextUp,
          nextUpKind: NextUpKind.actorWork,
        ));
      }
      return hasMore;
    } catch (e) {
      AppLogger.error('推荐：加载追剧队列失败', error: e);
      return false;
    }
  }

  Future<bool> _fetchResumeQueue({
    required _LoadContext ctx,
    required Map<String, List<RecommendItem>> queues,
    required String serverUrl,
    required String token,
  }) async {
    try {
      final resp = await ctx.repo.getResumeItems(
        limit: RecommendNotifier._pageSize,
        serverUrl: serverUrl,
        token: token,
        userId: ctx.auth.user?.id,
      );
      final resumeQueue = queues[RecommendNotifier._sourceResume];
      for (final item in resp.items) {
        if (!ctx.isVideo(item) || ctx.isTooShort(item)) continue;
        if (_shouldSkipItem(
          item,
          signal: ctx.signal,
          favoriteIds: ctx.favoriteIds,
          dislikedIds: ctx.dislikedIds,
          antiFatigueEnabled: ctx.antiFatigueEnabled,
          recentlyShownIds: ctx.recentlyShownIds,
          userRatingEnabled: ctx.userRatingEnabled,
          userRatingMin: ctx.userRatingMin,
        )) {
          continue;
        }
        resumeQueue
            ?.add(RecommendItem(item: item, source: RecommendSource.resume));
      }
      return resp.items.length >= RecommendNotifier._pageSize;
    } catch (e) {
      AppLogger.error('推荐：加载 Resume 失败', error: e);
      return false;
    }
  }

  Future<bool> _fetchSuggestionsQueue({
    required _LoadContext ctx,
    required Map<String, List<RecommendItem>> queues,
    required String serverUrl,
    required String token,
    String? userId,
  }) async {
    try {
      final suggestions = await ctx.repo.getSuggestions(
        limit: RecommendNotifier._pageSize,
        serverUrl: serverUrl,
        token: token,
        userId: userId,
      );
      final suggestionsQueue = queues[RecommendNotifier._sourceSuggestions];
      for (final item in suggestions) {
        if (!ctx.isVideo(item) || ctx.isTooShort(item)) continue;
        if (_shouldSkipItem(
          item,
          signal: ctx.signal,
          favoriteIds: ctx.favoriteIds,
          dislikedIds: ctx.dislikedIds,
          antiFatigueEnabled: ctx.antiFatigueEnabled,
          recentlyShownIds: ctx.recentlyShownIds,
          userRatingEnabled: ctx.userRatingEnabled,
          userRatingMin: ctx.userRatingMin,
        )) {
          continue;
        }
        suggestionsQueue?.add(
            RecommendItem(item: item, source: RecommendSource.suggestions));
      }
      return suggestions.length >= RecommendNotifier._pageSize;
    } catch (e) {
      AppLogger.error('推荐：加载个性化推荐失败', error: e);
      return false;
    }
  }

  Future<bool> _fetchNativeRecommendationsQueue({
    required _LoadContext ctx,
    required Map<String, List<RecommendItem>> queues,
    required String serverUrl,
    required String token,
    String? userId,
  }) async {
    try {
      final libraryId =
          ctx.selectedIds.length == 1 ? ctx.selectedIds.first : null;
      final items = await ctx.repo.getNativeRecommendations(
        userId: userId,
        libraryId: libraryId,
        serverUrl: serverUrl,
        token: token,
      );
      final queue = queues[RecommendNotifier._sourceNative];
      for (final item in items) {
        if (!ctx.isVideo(item) || ctx.isTooShort(item)) continue;
        if (_shouldSkipItem(
          item,
          signal: ctx.signal,
          favoriteIds: ctx.favoriteIds,
          dislikedIds: ctx.dislikedIds,
          antiFatigueEnabled: ctx.antiFatigueEnabled,
          recentlyShownIds: ctx.recentlyShownIds,
          userRatingEnabled: ctx.userRatingEnabled,
          userRatingMin: ctx.userRatingMin,
        )) {
          continue;
        }
        queue?.add(RecommendItem(
            item: item, source: RecommendSource.nativeRecommendations));
      }
      // 原生精选无分页，不参与"还有更多"判定
      return false;
    } catch (e) {
      AppLogger.error('推荐：加载 Emby 原生精选失败', error: e);
      return false;
    }
  }

  Future<bool> _fetchSimilarQueue({
    required _LoadContext ctx,
    required Map<String, List<RecommendItem>> queues,
    required String serverUrl,
    required String token,
    String? userId,
    required List<MediaItem> watchHistory,
  }) async {
    try {
      final history = watchHistory;
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
          if ((item.communityRating ?? 0) >=
              RecommendNotifier._similarSeedMinRating) {
            seedByItemId.putIfAbsent(item.id, () => item);
          }
        }
      }

      final highRated = seedByItemId.values
          .where((i) =>
              (i.communityRating ?? 0) >=
              RecommendNotifier._similarSeedMinRating)
          .toList()
        ..sort((a, b) =>
            (b.communityRating ?? 0).compareTo(a.communityRating ?? 0));
      final topSeeds =
          highRated.take(RecommendNotifier._similarSeedCount).toList();
      if (topSeeds.isEmpty) {
        return false;
      }
      // 并发限制：最多同时请求 RecommendNotifier._maxConcurrentRequests 个种子
      final tasks = topSeeds
          .map((seed) => () async {
                try {
                  return await ctx.repo.getSimilarItems(
                    seed.id,
                    limit: RecommendNotifier._similarPerSeed,
                    serverUrl: serverUrl,
                    token: token,
                    userId: ctx.auth.user?.id,
                  );
                } catch (e) {
                  AppLogger.error('推荐：加载 ${seed.id} Similar 失败', error: e);
                  return <MediaItem>[];
                }
              })
          .toList();
      final similarLists = await _runWithConcurrencyLimit(tasks);
      // P1-3：任一种子返回项数 >= RecommendNotifier._similarPerSeed 视为可能还有更多
      // （旧实现 list.isNotEmpty 会误判：恰好装满时服务器已无更多但被认为还有）
      var hasMore = false;
      for (final list in similarLists) {
        if (list.length >= RecommendNotifier._similarPerSeed) hasMore = true;
        final similarQueue = queues[RecommendNotifier._sourceSimilar];
        for (final item in list) {
          if (!ctx.isVideo(item) || ctx.isTooShort(item)) continue;
          if (_shouldSkipItem(
            item,
            signal: ctx.signal,
            favoriteIds: ctx.favoriteIds,
            dislikedIds: ctx.dislikedIds,
            antiFatigueEnabled: ctx.antiFatigueEnabled,
            recentlyShownIds: ctx.recentlyShownIds,
            userRatingEnabled: ctx.userRatingEnabled,
            userRatingMin: ctx.userRatingMin,
          )) {
            continue;
          }
          similarQueue
              ?.add(RecommendItem(item: item, source: RecommendSource.similar));
        }
      }
      return hasMore;
    } catch (e) {
      AppLogger.error('推荐：Similar 流程失败', error: e);
      return false;
    }
  }

  Future<bool> _fetchRecommendationsQueue({
    required _LoadContext ctx,
    required Map<String, List<RecommendItem>> queues,
    required Set<String> seenIds,
  }) async {
    final serverUrl = ctx.auth.embyServerUrl;
    final token = ctx.auth.token;
    final userId = ctx.auth.user?.id;
    if (serverUrl == null || token == null) return false;
    // Dart 单线程模型，闭包并发执行时共享变量安全
    var hasMore = false;
    // 并发限制：最多同时请求 RecommendNotifier._maxConcurrentRequests 个库
    final tasks = ctx.selectedIds
        .map((libId) => () async {
              try {
                final resp = await ctx.repo.getRecommendations(
                  libraryId: libId,
                  limit: RecommendNotifier._pageSize,
                  offset: 0,
                  serverUrl: serverUrl,
                  token: token,
                  userId: userId,
                  minCommunityRating: ctx.minRating,
                  excludePlayed: ctx.excludePlayed,
                  includeItemTypes: ctx.includeTypes,
                );
                // P1-3：items 未达 limit 视为该库已耗尽
                if (resp.items.length >= RecommendNotifier._pageSize)
                  hasMore = true;
                for (final item in resp.items) {
                  if (ctx.isTooShort(item)) continue;
                  if (_shouldSkipItem(
                    item,
                    signal: ctx.signal,
                    favoriteIds: ctx.favoriteIds,
                    dislikedIds: ctx.dislikedIds,
                    antiFatigueEnabled: ctx.antiFatigueEnabled,
                    recentlyShownIds: ctx.recentlyShownIds,
                    userRatingEnabled: ctx.userRatingEnabled,
                    userRatingMin: ctx.userRatingMin,
                  )) {
                    continue;
                  }
                  if (seenIds.add(item.id)) {
                    queues[RecommendNotifier._sourceRecommendations]?.add(
                        RecommendItem(
                            item: item,
                            source: RecommendSource.recommendations));
                  }
                }
              } catch (e) {
                AppLogger.error('推荐：加载库 $libId 推荐列表失败', error: e);
              }
            })
        .toList();
    await _runWithConcurrencyLimit(tasks);
    return hasMore;
  }

  Future<bool> _fetchLocalRecommendQueue({
    required _LoadContext ctx,
    required Map<String, List<RecommendItem>> queues,
    required String serverUrl,
    required String token,
  }) async {
    try {
      final resp = await ctx.repo.getFavoriteMovies(
        limit: RecommendNotifier._pageSize,
        serverUrl: serverUrl,
        token: token,
        userId: ctx.auth.user?.id,
      );
      final q = queues[RecommendNotifier._sourceLocal];
      for (final item in resp.items) {
        if (!ctx.isVideo(item) || ctx.isTooShort(item)) continue;
        q?.add(
            RecommendItem(item: item, source: RecommendSource.localRecommend));
      }
      return resp.hasMore;
    } catch (e) {
      AppLogger.error('推荐：加载移动客户端推荐失败', error: e);
      return false;
    }
  }

  Future<void> _fetchNextUpByRecentSeries({
    required _LoadContext ctx,
    required Map<String, List<RecommendItem>> queues,
    required String serverUrl,
    required String token,
    String? userId,
    required List<MediaItem> watchHistory,
  }) async {
    try {
      final recentSeriesLimit = ctx.nextUpSeriesCount;
      final history = watchHistory;
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

      // 并发限制：最多同时请求 RecommendNotifier._maxConcurrentRequests 个 series
      final tasks = recentSeriesIds
          .map((sid) => () async {
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
              })
          .toList();
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
            dislikedIds: ctx.dislikedIds,
            antiFatigueEnabled: ctx.antiFatigueEnabled,
            recentlyShownIds: ctx.recentlyShownIds,
            userRatingEnabled: ctx.userRatingEnabled,
            userRatingMin: ctx.userRatingMin,
          )) {
            continue;
          }
          allNextUp.add(RecommendItem(
            item: item,
            source: RecommendSource.nextUp,
            nextUpKind: NextUpKind.seriesUpdate,
          ));
        }
      }
      if (allNextUp.isNotEmpty) {
        final nextUpQueue = queues[RecommendNotifier._sourceNextUp];
        nextUpQueue?.insertAll(0, allNextUp);
      }
    } catch (e) {
      AppLogger.error('推荐：NextUp by series 流程失败', error: e);
    }
  }

  Future<void> _fetchNextUpByFavoriteSeries({
    required _LoadContext ctx,
    required Map<String, List<RecommendItem>> queues,
    required String serverUrl,
    required String token,
    String? userId,
  }) async {
    try {
      // 收藏列表（getFavoriteMovies 默认包含 Series 类型）
      final favorites = _ref.read(favoritesProvider);
      final seriesIds = <String>[];
      final seen = <String>{};
      for (final m in favorites.movies) {
        if (m.type != 'Series') continue;
        final sid = m.id;
        if (sid.isEmpty || seen.contains(sid)) continue;
        seen.add(sid);
        seriesIds.add(sid);
        if (seriesIds.length >= ctx.followMaxActors) break;
      }
      if (seriesIds.isEmpty) return;

      // 并发限制：最多同时请求 RecommendNotifier._maxConcurrentRequests 个 series
      final tasks = seriesIds
          .map((sid) => () async {
                try {
                  final resp = await ctx.repo.getNextUp(
                    limit: 3,
                    seriesId: sid,
                    serverUrl: serverUrl,
                    token: token,
                  );
                  return resp.items;
                } catch (e) {
                  AppLogger.error('推荐：收藏 series $sid NextUp 失败', error: e);
                  return <MediaItem>[];
                }
              })
          .toList();
      final nextUpLists = await _runWithConcurrencyLimit(tasks);

      final allNextUp = <RecommendItem>[];
      for (final list in nextUpLists) {
        // 同 series 内按季 + 集号排序（老集在前，最新集在后）
        final sorted = List<MediaItem>.from(list)
          ..sort((a, b) {
            final sa = a.parentIndexNumber ?? 0;
            final sb = b.parentIndexNumber ?? 0;
            if (sa != sb) return sa.compareTo(sb);
            return (a.indexNumber ?? 0).compareTo(b.indexNumber ?? 0);
          });
        for (final item in sorted) {
          if (!ctx.isVideo(item) || ctx.isTooShort(item)) continue;
          if (item.isWatched) continue;
          if (_shouldSkipItem(
            item,
            signal: ctx.signal,
            favoriteIds: ctx.favoriteIds,
            dislikedIds: ctx.dislikedIds,
            antiFatigueEnabled: ctx.antiFatigueEnabled,
            recentlyShownIds: ctx.recentlyShownIds,
            userRatingEnabled: ctx.userRatingEnabled,
            userRatingMin: ctx.userRatingMin,
          )) {
            continue;
          }
          allNextUp.add(RecommendItem(
            item: item,
            source: RecommendSource.nextUp,
            nextUpKind: NextUpKind.seriesUpdate,
          ));
        }
      }
      if (allNextUp.isNotEmpty) {
        final nextUpQueue = queues[RecommendNotifier._sourceNextUp];
        nextUpQueue?.insertAll(0, allNextUp);
      }
    } catch (e) {
      AppLogger.error('推荐：收藏剧集更新流程失败', error: e);
    }
  }

  _PageLoadResult _mergeRoundRobin({
    required Map<String, List<RecommendItem>> queues,
    required UserBehaviorSignal signal,
    required Set<String> seenIds,
    // Task 4：各数据源是否还有更多数据
    // 索引顺序与 _loadPage 中 Future.wait 一致：
    // [0]=Latest, [1]=NextUp, [2]=Resume, [3]=Suggestions,
    // [4]=Native, [5]=Similar, [6]=Recommendations, [7]=Local
    required List<bool> sourceHasMore,
  }) {
    for (final list in queues.values) {
      list.shuffle();
    }
    final nextUpCount = queues[RecommendNotifier._sourceNextUp]?.length ?? 0;
    final resumeCount = queues[RecommendNotifier._sourceResume]?.length ?? 0;
    final suggestionsCount =
        queues[RecommendNotifier._sourceSuggestions]?.length ?? 0;
    final sourceOrder = <RecommendSource>[
      RecommendSource.latest,
      RecommendSource.nextUp,
      RecommendSource.resume,
      RecommendSource.suggestions,
      RecommendSource.nativeRecommendations,
      RecommendSource.similar,
      RecommendSource.recommendations,
      RecommendSource.localRecommend,
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
    // Task 4：所有数据源都返回空结果时，认为服务器端已无更多数据
    final allSourcesExhausted = !sourceHasMore.any((h) => h);
    return _PageLoadResult(
      tagged: tagged,
      nextUpCount: nextUpCount,
      resumeCount: resumeCount,
      suggestionsCount: suggestionsCount,
      allSourcesExhausted: allSourcesExhausted,
    );
  }

  List<RecommendItem> _queueOf(
    Map<String, List<RecommendItem>> queues,
    RecommendSource source,
  ) {
    switch (source) {
      case RecommendSource.latest:
        return queues[RecommendNotifier._sourceLatest] ?? const [];
      case RecommendSource.nextUp:
        return queues[RecommendNotifier._sourceNextUp] ?? const [];
      case RecommendSource.resume:
        return queues[RecommendNotifier._sourceResume] ?? const [];
      case RecommendSource.suggestions:
        return queues[RecommendNotifier._sourceSuggestions] ?? const [];
      case RecommendSource.nativeRecommendations:
        return queues[RecommendNotifier._sourceNative] ?? const [];
      case RecommendSource.similar:
        return queues[RecommendNotifier._sourceSimilar] ?? const [];
      case RecommendSource.recommendations:
        return queues[RecommendNotifier._sourceRecommendations] ?? const [];
      case RecommendSource.localRecommend:
        return queues[RecommendNotifier._sourceLocal] ?? const [];
    }
  }

  Future<List<T>> _runWithConcurrencyLimit<T>(
    List<Future<T> Function()> tasks, {
    int maxConcurrent = RecommendNotifier._maxConcurrentRequests,
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
    // 并发限制：最多同时请求 RecommendNotifier._maxConcurrentRequests 个库
    final tasks = ctx.selectedIds
        .map((libId) => () async {
              try {
                final resp = await ctx.repo.getRecommendations(
                  libraryId: libId,
                  limit: RecommendNotifier._pageSize,
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
                    dislikedIds: ctx.dislikedIds,
                    antiFatigueEnabled: ctx.antiFatigueEnabled,
                    recentlyShownIds: ctx.recentlyShownIds,
                    userRatingEnabled: ctx.userRatingEnabled,
                    userRatingMin: ctx.userRatingMin,
                  )) {
                    continue;
                  }
                  if (seenIds.add(item.id)) {
                    results.add(RecommendItem(
                        item: item, source: RecommendSource.recommendations));
                  }
                }
              } catch (e) {
                AppLogger.error('推荐：冷启动降级加载失败', error: e);
              }
            })
        .toList();
    await _runWithConcurrencyLimit(tasks);
    return results;
  }
}
