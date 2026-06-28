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

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'app_preferences_providers.dart';
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
  // PR #78：冷启动标志
  // - true: Suggestion 和 Resume 都为空，可能是新用户或无观看历史
  // - UI 可以显示"先观看几个视频"提示
  final bool isColdStart;

  const RecommendState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.offset = 0,
    this.hasMore = true,
    this.isColdStart = false,
  });

  RecommendState copyWith({
    List<MediaItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? offset,
    bool? hasMore,
    bool? isColdStart,
  }) {
    return RecommendState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
      isColdStart: isColdStart ?? this.isColdStart,
    );
  }
}

/// 推荐 Notifier
class RecommendNotifier extends StateNotifier<RecommendState> {
  RecommendNotifier(this._ref) : super(const RecommendState()) {
    // PR #78：先尝试从本地缓存读，立即显示旧数据
    // 然后后台调用 load() 拉取最新数据
    _init();
  }

  final Ref _ref;

  // 异步初始化：缓存 → 后台刷新
  Future<void> _init() async {
    await _loadFromCache();
    // 后台刷新（不阻塞 UI 启动）
    unawaited(load());
  }

  /// 从 SharedPreferences 读取缓存（30 分钟内有效）
  Future<void> _loadFromCache() async {
    try {
      final auth = _ref.read(authProvider);
      if (auth.user?.id == null) return;
      // 缓存按 userId 分键（避免不同账号混用）
      final cacheKey = '$kStorageKeyRecommendCache:${auth.user!.id}';
      final timeKey = '$kStorageKeyRecommendCacheTime:${auth.user!.id}';

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      final ts = prefs.getInt(timeKey) ?? 0;
      if (raw == null || raw.isEmpty) return;

      final age = DateTime.now().millisecondsSinceEpoch ~/ 1000 - ts;
      if (age > kRecommendCacheMaxAgeSec) {
        AppLogger.debug('推荐缓存过期', data: {'ageSec': age});
        return;
      }

      final decoded = json.decode(raw);
      if (decoded is! List) return;
      final items = decoded
          .whereType<Map<String, dynamic>>()
          .map(MediaItem.fromJson)
          .toList();
      if (items.isEmpty) return;

      // 立即用缓存渲染（isLoading=true 会被 load() 切换）
      state = state.copyWith(items: items, isColdStart: false);
      AppLogger.debug('推荐：使用本地缓存', data: {'count': items.length, 'ageSec': age});
    } catch (e) {
      AppLogger.debug('推荐：读缓存失败', data: {'error': e.toString()});
    }
  }

  /// 把当前 items 写入 SharedPreferences
  Future<void> _saveToCache(List<MediaItem> items) async {
    if (items.isEmpty) return;
    try {
      final auth = _ref.read(authProvider);
      if (auth.user?.id == null) return;
      final cacheKey = '$kStorageKeyRecommendCache:${auth.user!.id}';
      final timeKey = '$kStorageKeyRecommendCacheTime:${auth.user!.id}';

      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(items.map((e) => e.toJson()).toList());
      await prefs.setString(cacheKey, encoded);
      await prefs.setInt(timeKey, DateTime.now().millisecondsSinceEpoch ~/ 1000);
    } catch (e) {
      AppLogger.debug('推荐：写缓存失败', data: {'error': e.toString()});
    }
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
  // - 取最近 N 个高评分项（communityRating >= 7.0）
  // - 对每个高分项取 Top K 相似视频
  static const int _similarSeedCount = 3; // 取最近 3 个高分项
  static const int _similarPerSeed = 10; // 每个高分项取 10 个相似
  static const double _similarSeedMinRating = 7.0; // 高分阈值

  // 服务端单次上限（避免一次拉太多）
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);

    final auth = _ref.read(authProvider);
    // PR #66：推荐页改用独立的 recommendLibraryIdsProvider，
    // 视频流和推荐可以分别设置媒体库
    final selectedIds = _ref.read(recommendLibraryIdsProvider);

    // PR #78：读取推荐规则偏好
    final minRating = _ref.read(recommendMinRatingProvider);
    final excludePlayed = _ref.read(recommendExcludePlayedProvider);
    final minRuntimeSec = _ref.read(recommendMinRuntimeSecProvider);
    // 1 tick = 100ns，秒转 tick
    final minRuntimeTicks = minRuntimeSec * 10000000;

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

    // PR #73：过滤非视频类型 item
    // 修复 Emby Suggestions API 返回 Tag/Genre 类型字段导致推荐页显示非视频的问题
    const allowedTypes = <String>{
      'Movie',
      'Episode',
      'Video',
      'MusicVideo',
      'Series',
    };
    bool isVideo(MediaItem item) => allowedTypes.contains(item.type);

    // PR #78：时长过滤（避免测试片/预告片污染推荐）
    // 0 表示不过滤
    bool isTooShort(MediaItem item) {
      if (minRuntimeSec == 0) return false;
      if (item.runtimeTicks == null) return false; // 无时长信息：保留
      return item.runtimeTicks! < minRuntimeTicks;
    }

    // 各数据源结果队列（用于 round-robin 轮转）
    final queues = <String, List<MediaItem>>{
      _sourceNextUp: <MediaItem>[],
      _sourceResume: <MediaItem>[],
      _sourceSuggestions: <MediaItem>[],
      _sourceRecommendations: <MediaItem>[],
      _sourceSimilar: <MediaItem>[],
    };

    // PR #78：并发请求所有数据源（替代 for 循环顺序）
    // 每个 Future 内部 try-catch，单个失败不影响整体
    Future<void> fetchNextUp() async {
      try {
        final resp = await service.getNextUp(
          limit: _pageSize,
          serverUrl: auth.embyServerUrl!,
          token: auth.token!,
        );
        for (final item in resp.items) {
          if (!isVideo(item) || isTooShort(item)) continue;
          queues[_sourceNextUp]!.add(item);
        }
      } catch (e) {
        AppLogger.error('推荐：加载 NextUp 失败', error: e);
      }
    }

    Future<void> fetchResume() async {
      try {
        final resp = await service.getResumeItems(
          limit: _pageSize,
          serverUrl: auth.embyServerUrl!,
          token: auth.token!,
        );
        for (final item in resp.items) {
          if (!isVideo(item) || isTooShort(item)) continue;
          queues[_sourceResume]!.add(item);
        }
      } catch (e) {
        AppLogger.error('推荐：加载 Resume 失败', error: e);
      }
    }

    Future<void> fetchSuggestions() async {
      try {
        final suggestions = await service.getSuggestions(
          limit: _pageSize,
          serverUrl: auth.embyServerUrl!,
          token: auth.token!,
          userId: auth.user?.id,
        );
        for (final item in suggestions) {
          if (!isVideo(item) || isTooShort(item)) continue;
          queues[_sourceSuggestions]!.add(item);
        }
      } catch (e) {
        AppLogger.error('推荐：加载个性化推荐失败', error: e);
      }
    }

    // PR #78：相似推荐
    // - 拉取用户最近观看历史，过滤 communityRating >= 7.0
    // - 对每个高分项调用 /Items/{id}/Similar
    // - 合并所有相似项（去重 + 过滤）
    Future<void> fetchSimilarFromRecentHighRated() async {
      try {
        // 拉取最近 50 条观看历史
        final history = await service.getWatchHistory(
          limit: 50,
          userId: auth.user?.id,
          serverUrl: auth.embyServerUrl!,
          token: auth.token!,
        );
        // 过滤高分项（communityRating >= 7.0）
        final highRated = history
            .where((i) => (i.communityRating ?? 0) >= _similarSeedMinRating)
            .take(_similarSeedCount)
            .toList();
        if (highRated.isEmpty) {
          AppLogger.debug('推荐：无高分历史，跳过 Similar');
          return;
        }
        // 并发拉取每个高分项的 Similar
        final similarLists = await Future.wait(highRated.map((seed) async {
          try {
            return await service.getSimilarItems(
              seed.id,
              limit: _similarPerSeed,
              serverUrl: auth.embyServerUrl!,
              token: auth.token!,
            );
          } catch (e) {
            AppLogger.error('推荐：加载 ${seed.id} Similar 失败', error: e);
            return <MediaItem>[];
          }
        }));
        for (final list in similarLists) {
          for (final item in list) {
            if (!isVideo(item) || isTooShort(item)) continue;
            queues[_sourceSimilar]!.add(item);
          }
        }
      } catch (e) {
        AppLogger.error('推荐：Similar 流程失败', error: e);
      }
    }

    // 多库评分推荐：每个库单独并发请求
    // PR #78：传入用户配置的评分阈值和排除已观看开关
    List<Future<void>> fetchRecommendationsFutures() {
      return selectedIds.map((libId) {
        return () async {
          try {
            final resp = await service.getRecommendations(
              libraryId: libId,
              limit: _pageSize,
              offset: 0,
              serverUrl: auth.embyServerUrl!,
              token: auth.token!,
              userId: auth.user?.id,
              minCommunityRating: minRating,
              excludePlayed: excludePlayed,
            );
            for (final item in resp.items) {
              if (!isVideo(item) || isTooShort(item)) continue;
              queues[_sourceRecommendations]!.add(item);
            }
          } catch (e) {
            AppLogger.error('推荐：加载库 $libId 推荐列表失败', error: e);
          }
        }();
      }).toList();
    }

    try {
      // PR #78：所有数据源并发拉取（Future.wait）
      await Future.wait([
        fetchNextUp(),
        fetchResume(),
        fetchSuggestions(),
        fetchSimilarFromRecentHighRated(),
        ...fetchRecommendationsFutures(),
      ]);

      // PR #78：round-robin 轮转排序
      // 替代原 shuffle()：保证每个数据源的内容都能被看到，避免高分库垄断
      // 优先级：NextUp > Resume > Suggestions > Similar > Recommendations
      final merged = <MediaItem>[];
      // 每个源内部打乱一次（让同源内不同项随机）
      for (final list in queues.values) {
        list.shuffle();
      }
      // round-robin：每个队列头部取一个，直到所有队列都空
      final order = <String>[
        _sourceNextUp,
        _sourceResume,
        _sourceSuggestions,
        _sourceSimilar,
        _sourceRecommendations,
      ];
      while (order.any((key) => queues[key]!.isNotEmpty)) {
        for (final key in order) {
          final q = queues[key]!;
          if (q.isNotEmpty) {
            final item = q.removeAt(0);
            if (seenIds.add(item.id)) {
              merged.add(item);
            }
          }
        }
      }

      // PR #78：冷启动检测
      // - Suggestion 和 Resume 都为空：可能是新用户或无观看历史
      // - 这种情况自动降级评分阈值（4.0 → 3.0）并补充评分推荐
      final isColdStart = queues[_sourceSuggestions]!.isEmpty &&
          queues[_sourceResume]!.isEmpty;

      if (isColdStart) {
        AppLogger.info('推荐：冷启动模式，评分阈值降级');
        // 降低评分阈值到 3.0 拉一轮评分推荐
        final degradedRating = minRating > 3.0 ? 3.0 : minRating;
        await Future.wait(selectedIds.map((libId) async {
          try {
            final resp = await service.getRecommendations(
              libraryId: libId,
              limit: _pageSize,
              offset: 0,
              serverUrl: auth.embyServerUrl!,
              token: auth.token!,
              userId: auth.user?.id,
              minCommunityRating: degradedRating,
              excludePlayed: excludePlayed,
            );
            for (final item in resp.items) {
              if (!isVideo(item) || isTooShort(item)) continue;
              if (seenIds.add(item.id)) {
                queues[_sourceRecommendations]!.add(item);
              }
            }
          } catch (e) {
            AppLogger.error('推荐：冷启动降级加载失败', error: e);
          }
        }));
        // 重新洗牌评分推荐（让新加的项也随机分布）
        queues[_sourceRecommendations]!.shuffle();
      }

      state = state.copyWith(
        items: merged,
        isLoading: false,
        hasMore: false, // 推荐模式不分页（与原 FeedType.recommend 行为一致）
        offset: merged.length,
        error: null,
        isColdStart: isColdStart && merged.length < _pageSize ~/ 2,
      );
      // PR #78：写入本地缓存（下次启动 < 30 分钟直接用）
      await _saveToCache(merged);
      AppLogger.debug('推荐列表加载完成', data: {
        'count': merged.length,
        'minRating': minRating,
        'excludePlayed': excludePlayed,
        'minRuntimeSec': minRuntimeSec,
        'isColdStart': isColdStart,
        'nextUp': queues[_sourceNextUp]!.length,
        'resume': queues[_sourceResume]!.length,
        'suggestions': queues[_sourceSuggestions]!.length,
        'similar': queues[_sourceSimilar]!.length,
        'recommendations': queues[_sourceRecommendations]!.length,
      });
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
