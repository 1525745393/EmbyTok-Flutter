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
  // PR #79：原 MediaItem 列表（用于兼容历史逻辑，缓存、loadMore）
  final List<MediaItem> items;
  // PR #80：带数据源标签的推荐项（用于标签分类 UI）
  // - 与 items 一一对应，但额外标注来自哪个数据源
  // - 标签切换时只过滤 taggedItems，不影响 items
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

  const RecommendState({
    this.items = const [],
    this.taggedItems = const [],
    this.selectedTag,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.offset = 0,
    this.hasMore = true,
    this.isColdStart = false,
  });

  RecommendState copyWith({
    List<MediaItem>? items,
    List<RecommendItem>? taggedItems,
    String? selectedTag,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? offset,
    bool? hasMore,
    bool? isColdStart,
  }) {
    return RecommendState(
      items: items ?? this.items,
      taggedItems: taggedItems ?? this.taggedItems,
      selectedTag: selectedTag ?? this.selectedTag,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
      isColdStart: isColdStart ?? this.isColdStart,
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
/// PR #80：增加 tagged 字段（带 source 标签的列表）
class _PageLoadResult {
  final List<MediaItem> merged; // 去重 + round-robin 后的列表
  final List<RecommendItem> tagged; // 与 merged 一一对应，带 source 标签
  final int nextUpCount; // NextUp 数据源原始项数
  final int resumeCount; // Resume 数据源原始项数
  const _PageLoadResult({
    required this.merged,
    required this.tagged,
    required this.nextUpCount,
    required this.resumeCount,
  });
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
      // PR #80：缓存不含 source 信息，taggedItems 设为空（待 load() 重新填充）
      state = state.copyWith(items: items, taggedItems: const [], isColdStart: false);
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
    // PR #79：类型偏好（空集合时不过滤）
    final includeTypes = _ref.read(recommendIncludeTypesProvider);
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
    // PR #79：分页 - 第一页从 0 开始
    final seenIds = <String>{}; // 去重用（首次加载全空）

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

    // PR #79：抽离核心加载逻辑，支持分页
    // 返回该页拉到的所有新项（去重后）
    final newItems = await _loadPage(
      service: service,
      auth: auth,
      selectedIds: selectedIds,
      minRating: minRating,
      excludePlayed: excludePlayed,
      includeTypes: includeTypes,
      minRuntimeSec: minRuntimeSec,
      isTooShort: isTooShort,
      isVideo: isVideo,
      seenIds: seenIds,
    );

    // 冷启动判定：建议数据源 + Resume 都为空
    final isColdStart = newItems.nextUpCount == 0 &&
        newItems.resumeCount == 0;

    // PR #79：首次加载启用冷启动降级
    if (isColdStart) {
      AppLogger.info('推荐：冷启动模式，评分阈值降级');
      final degradedRating = minRating > 3.0 ? 3.0 : minRating;
      // 把降级拉到的新项也并入 merged（PR #80：同时合并 tagged）
      final degradedItems = await _loadRecommendations(
        service: service,
        auth: auth,
        selectedIds: selectedIds,
        minCommunityRating: degradedRating,
        excludePlayed: excludePlayed,
        includeTypes: includeTypes,
        minRuntimeSec: minRuntimeSec,
        isTooShort: isTooShort,
        seenIds: seenIds,
      );
      newItems.merged.addAll(degradedItems.map((r) => r.item));
      newItems.tagged.addAll(degradedItems);
    }

    // PR #79：分页 - 如果新项数 < _pageSize（5 数据源都不足一页），标记无更多
    final hasMore = newItems.merged.length >= _pageSize;

    state = state.copyWith(
      items: newItems.merged,
      taggedItems: newItems.tagged,
      isLoading: false,
      hasMore: hasMore,
      offset: newItems.merged.length,
      error: null,
      isColdStart: isColdStart && newItems.merged.length < _pageSize ~/ 2,
    );
    // PR #78：写入本地缓存（下次启动 < 30 分钟直接用）
    await _saveToCache(newItems.merged);
    AppLogger.debug('推荐列表加载完成', data: {
      'count': newItems.merged.length,
      'minRating': minRating,
      'excludePlayed': excludePlayed,
      'minRuntimeSec': minRuntimeSec,
      'includeTypes': includeTypes.toList(),
      'isColdStart': isColdStart,
      'hasMore': hasMore,
    });
  }

  /// PR #79：分页加载下一页
  /// 复用 5 数据源逻辑，结果去重后 append 到 state.items
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);

    final auth = _ref.read(authProvider);
    final selectedIds = _ref.read(recommendLibraryIdsProvider);
    final minRating = _ref.read(recommendMinRatingProvider);
    final excludePlayed = _ref.read(recommendExcludePlayedProvider);
    final minRuntimeSec = _ref.read(recommendMinRuntimeSecProvider);
    final includeTypes = _ref.read(recommendIncludeTypesProvider);
    final minRuntimeTicks = minRuntimeSec * 10000000;

    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
      state = state.copyWith(isLoadingMore: false, hasMore: false);
      return;
    }
    if (selectedIds.isEmpty) {
      state = state.copyWith(isLoadingMore: false, hasMore: false);
      return;
    }

    final service = EmbytokService();
    // PR #79：从已显示的 items 构建 seenIds（去重）
    final seenIds = state.items.map((i) => i.id).toSet();

    const allowedTypes = <String>{
      'Movie',
      'Episode',
      'Video',
      'MusicVideo',
      'Series',
    };
    bool isVideo(MediaItem item) => allowedTypes.contains(item.type);
    bool isTooShort(MediaItem item) {
      if (minRuntimeSec == 0) return false;
      if (item.runtimeTicks == null) return false;
      return item.runtimeTicks! < minRuntimeTicks;
    }

    final newItems = await _loadPage(
      service: service,
      auth: auth,
      selectedIds: selectedIds,
      minRating: minRating,
      excludePlayed: excludePlayed,
      includeTypes: includeTypes,
      minRuntimeSec: minRuntimeSec,
      isTooShort: isTooShort,
      isVideo: isVideo,
      seenIds: seenIds,
    );

    final merged = [...state.items, ...newItems.merged];
    final taggedMerged = [...state.taggedItems, ...newItems.tagged];
    // PR #79：hasMore = (新加项数 >= _pageSize)，否则认为没有更多
    final hasMore = newItems.merged.length >= _pageSize;

    state = state.copyWith(
      items: merged,
      taggedItems: taggedMerged,
      isLoadingMore: false,
      hasMore: hasMore,
      offset: merged.length,
    );
    AppLogger.debug('推荐 loadMore 完成', data: {
      'newCount': newItems.merged.length,
      'total': merged.length,
      'hasMore': hasMore,
    });
  }

  // PR #79：抽离 - 拉一页（5 数据源 + round-robin）
  // PR #80：每个 item 带 source 标签（用于 UI 分类过滤）
  // 返回 _PageLoadResult，包含 merged 列表（去重 round-robin 后的纯 MediaItem）
  // + taggedList（与 merged 一一对应的带 source 标签的 RecommendItem）
  // + 各数据源原始项数（供 load() 冷启动检测）
  Future<_PageLoadResult> _loadPage({
    required EmbytokService service,
    required auth,
    required List<String> selectedIds,
    required double minRating,
    required bool excludePlayed,
    required Set<String> includeTypes,
    required int minRuntimeSec,
    required bool Function(MediaItem) isTooShort,
    required bool Function(MediaItem) isVideo,
    required Set<String> seenIds,
  }) async {
    // PR #80：队列存 RecommendItem 而非 MediaItem，保留 source 信息
    final queues = <String, List<RecommendItem>>{
      _sourceNextUp: <RecommendItem>[],
      _sourceResume: <RecommendItem>[],
      _sourceSuggestions: <RecommendItem>[],
      _sourceRecommendations: <RecommendItem>[],
      _sourceSimilar: <RecommendItem>[],
    };

    Future<void> fetchNextUp() async {
      try {
        final resp = await service.getNextUp(
          limit: _pageSize,
          serverUrl: auth.embyServerUrl!,
          token: auth.token!,
        );
        for (final item in resp.items) {
          if (!isVideo(item) || isTooShort(item)) continue;
          queues[_sourceNextUp]!
              .add(RecommendItem(item: item, source: RecommendSource.nextUp));
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
          queues[_sourceResume]!
              .add(RecommendItem(item: item, source: RecommendSource.resume));
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
          queues[_sourceSuggestions]!.add(
              RecommendItem(item: item, source: RecommendSource.suggestions));
        }
      } catch (e) {
        AppLogger.error('推荐：加载个性化推荐失败', error: e);
      }
    }

    Future<void> fetchSimilarFromRecentHighRated() async {
      try {
        final history = await service.getWatchHistory(
          limit: 50,
          userId: auth.user?.id,
          serverUrl: auth.embyServerUrl!,
          token: auth.token!,
        );
        final highRated = history
            .where((i) => (i.communityRating ?? 0) >= _similarSeedMinRating)
            .take(_similarSeedCount)
            .toList();
        if (highRated.isEmpty) {
          return;
        }
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
            queues[_sourceSimilar]!
                .add(RecommendItem(item: item, source: RecommendSource.similar));
          }
        }
      } catch (e) {
        AppLogger.error('推荐：Similar 流程失败', error: e);
      }
    }

    await Future.wait([
      fetchNextUp(),
      fetchResume(),
      fetchSuggestions(),
      fetchSimilarFromRecentHighRated(),
      ..._fetchRecommendations(
        service: service,
        auth: auth,
        selectedIds: selectedIds,
        minCommunityRating: minRating,
        excludePlayed: excludePlayed,
        includeTypes: includeTypes,
        isTooShort: isTooShort,
        seenIds: seenIds,
        queues: queues,
      ),
    ]);

    // round-robin
    for (final list in queues.values) {
      list.shuffle();
    }
    // PR #79：在 round-robin 清空队列前记录原始项数（用于 load() 冷启动检测）
    final nextUpCount = queues[_sourceNextUp]!.length;
    final resumeCount = queues[_sourceResume]!.length;
    final order = <String>[
      _sourceNextUp,
      _sourceResume,
      _sourceSuggestions,
      _sourceSimilar,
      _sourceRecommendations,
    ];
    final merged = <MediaItem>[];
    final tagged = <RecommendItem>[];
    while (order.any((key) => queues[key]!.isNotEmpty)) {
      for (final key in order) {
        final q = queues[key]!;
        if (q.isNotEmpty) {
          final r = q.removeAt(0);
          if (seenIds.add(r.item.id)) {
            merged.add(r.item);
            tagged.add(r);
          }
        }
      }
    }
    return _PageLoadResult(
      merged: merged,
      tagged: tagged,
      nextUpCount: nextUpCount,
      resumeCount: resumeCount,
    );
  }

  // PR #79：抽离 - 多库评分推荐 future 列表
  // PR #80：queues 改为存 RecommendItem
  List<Future<void>> _fetchRecommendations({
    required EmbytokService service,
    required auth,
    required List<String> selectedIds,
    required double minCommunityRating,
    required bool excludePlayed,
    required Set<String> includeTypes,
    required bool Function(MediaItem) isTooShort,
    required Set<String> seenIds,
    required Map<String, List<RecommendItem>> queues,
  }) {
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
            minCommunityRating: minCommunityRating,
            excludePlayed: excludePlayed,
            includeItemTypes: includeTypes,
          );
          for (final item in resp.items) {
            if (isTooShort(item)) continue;
            queues[_sourceRecommendations]!.add(RecommendItem(
                item: item, source: RecommendSource.recommendations));
          }
        } catch (e) {
          AppLogger.error('推荐：加载库 $libId 推荐列表失败', error: e);
        }
      }();
    }).toList();
  }

  // PR #79：抽离 - 冷启动降级：拉一轮更低阈值的评分推荐
  // PR #80：返回带 source 标签的 RecommendItem 列表（source = recommendations）
  Future<List<RecommendItem>> _loadRecommendations({
    required EmbytokService service,
    required auth,
    required List<String> selectedIds,
    required double minCommunityRating,
    required bool excludePlayed,
    required Set<String> includeTypes,
    required int minRuntimeSec,
    required bool Function(MediaItem) isTooShort,
    required Set<String> seenIds,
  }) async {
    final results = <RecommendItem>[];
    await Future.wait(selectedIds.map((libId) async {
      try {
        final resp = await service.getRecommendations(
          libraryId: libId,
          limit: _pageSize,
          offset: 0,
          serverUrl: auth.embyServerUrl!,
          token: auth.token!,
          userId: auth.user?.id,
          minCommunityRating: minCommunityRating,
          excludePlayed: excludePlayed,
          includeItemTypes: includeTypes,
        );
        for (final item in resp.items) {
          if (isTooShort(item)) continue;
          if (seenIds.add(item.id)) {
            results.add(RecommendItem(
                item: item, source: RecommendSource.recommendations));
          }
        }
      } catch (e) {
        AppLogger.error('推荐：冷启动降级加载失败', error: e);
      }
    }));
    return results;
  }

  /// 刷新（用户下拉刷新时调用）
  Future<void> refresh() async {
    await load();
  }

  /// PR #80：选择标签（切换数据源分类）
  /// - tag=null 表示「全部」
  /// - 仅影响 view 渲染（view 按 taggedItems.filter(...).item 渲染）
  void selectTag(String? tag) {
    state = state.copyWith(selectedTag: tag);
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
