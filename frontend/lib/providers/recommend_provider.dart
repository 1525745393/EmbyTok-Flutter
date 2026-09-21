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
import '../utils/safe_unawaited.dart';
import 'favorites_provider.dart';
import 'library_provider.dart';
import 'recommend_signals.dart';
import 'disliked_items_provider.dart';
part 'recommend/recommend_control.dart';
part 'recommend/recommend_queues.dart';

/// 推荐状态
class RecommendState {
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
    this.nativeGroups = const [],
  });
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

  /// Emby 原生电影推荐分组横幅（"因为你看过 X"），仅首屏加载一次
  final List<NativeRecGroup> nativeGroups;

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
    List<NativeRecGroup>? nativeGroups,
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
      nativeGroups: nativeGroups ?? this.nativeGroups,
    );
  }
}

/// PR #80：推荐项 = MediaItem + 数据源标签
/// - 用于标签分类 UI：UI 可按 source 过滤显示
class RecommendItem {
  // 数据源
  const RecommendItem({
    required this.item,
    required this.source,
    this.nextUpKind,
  });
  final MediaItem item;
  final RecommendSource source;

  /// 关注（nextUp）源的子类：演员新作 / 剧集更新（关注页分组与来源标注依据）
  final NextUpKind? nextUpKind;
}

/// 关注源的子类标记
enum NextUpKind { actorWork, seriesUpdate }

/// PR #80：5 个数据源枚举 + 中文标签
enum RecommendSource {
  latest, // 最新影片（Emby 最新入库）
  nextUp, // 关注
  resume, // 继续观看
  suggestions, // 为你推荐
  nativeRecommendations, // Emby 原生精选
  similar, // 相似
  recommendations, // 高分
  localRecommend, // 移动客户端推荐（本地信号源）
}

extension RecommendSourceLabel on RecommendSource {
  String get key {
    switch (this) {
      case RecommendSource.latest:
        return 'latest';
      case RecommendSource.nextUp:
        return 'nextUp';
      case RecommendSource.resume:
        return 'resume';
      case RecommendSource.suggestions:
        return 'suggestions';
      case RecommendSource.nativeRecommendations:
        return 'nativeRecommendations';
      case RecommendSource.similar:
        return 'similar';
      case RecommendSource.recommendations:
        return 'recommendations';
      case RecommendSource.localRecommend:
        return 'localRecommend';
    }
  }

  // 中文标签（UI 显示用）
  String get label {
    switch (this) {
      case RecommendSource.latest:
        return '最新影片';
      case RecommendSource.nextUp:
        return '关注';
      case RecommendSource.resume:
        return '继续观看';
      case RecommendSource.suggestions:
        return '为你推荐';
      case RecommendSource.nativeRecommendations:
        return '精选';
      case RecommendSource.similar:
        return '相似';
      case RecommendSource.recommendations:
        return '高分';
      case RecommendSource.localRecommend:
        return '移动客户端推荐';
    }
  }
}

/// PR #79：分页 - 单页加载结果
/// 记录一页拉到的项 + 各数据源原始项数（用于 load() 冷启动检测）
class _PageLoadResult {
  const _PageLoadResult({
    required this.tagged,
    required this.nextUpCount,
    required this.resumeCount,
    required this.suggestionsCount,
    required this.allSourcesExhausted,
  });
  final List<RecommendItem> tagged; // 带 source 标签的推荐项
  final int nextUpCount; // NextUp 数据源原始项数
  final int resumeCount; // Resume 数据源原始项数
  final int suggestionsCount; // Task 3：Suggestions 数据源原始项数
  // Task 4：所有数据源是否都已耗尽（true 表示服务器端无更多数据）
  final bool allSourcesExhausted;
}

/// 加载上下文：封装 load() / loadMore() 共用的配置和计算结果
/// 减少两个方法之间的代码重复
class _LoadContext {
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
    required this.dislikedIds,
    required this.antiFatigueEnabled,
    required this.recentlyShownIds,
    required this.userRatingEnabled,
    required this.userRatingMin,
    required this.nextUpSeriesCount,
    required this.followActorVideoCount,
    required this.followOnlyUnwatched,
    required this.followMaxActors,
  });
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
  final Set<String> dislikedIds;
  final bool antiFatigueEnabled;
  final Set<String> recentlyShownIds;
  final bool userRatingEnabled;
  final double userRatingMin;
  // 追剧队列数量平衡
  final int nextUpSeriesCount;
  // 关注页：每演员视频数（收藏演员逐个拉取，每个演员最多 N 条）
  final int followActorVideoCount;
  // 关注页：只看未观看（开启后过滤已观看视频）
  final bool followOnlyUnwatched;
  // 关注页：收藏演员拉取上限
  final int followMaxActors;

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
    _subscribeLibraryChanges();
  }

  final Ref _ref;

  // 媒体库变化监听：设置页 chip 增删推荐媒体库后自动刷新（400ms 去抖合并）
  Timer? _libraryRefreshDebounce;

  @override
  void dispose() {
    _libraryRefreshDebounce?.cancel();
    super.dispose();
  }

  // 加载互斥锁：防止 load() 和 loadMore() 并发执行导致状态冲突
  bool _isLoading = false;

  // 并发请求数上限（多库高分推荐、相似推荐种子等场景）
  // 避免一次性发起过多 HTTP 请求导致服务器压力或连接池耗尽
  static const int _maxConcurrentRequests = 3;

  // 初始化：直接拉取 Emby 最新推荐数据
  // 缓存仅用于本会话内的 MemoryCache 加速（CachedMediaRepository），
  // 不做跨会话磁盘缓存，确保数据始终以 Emby 为准

  // 推荐每次加载数量（PR #78：20 → 30，提升推荐质量）
  static const int _pageSize = 30;

  // 数据源标签：用于日志 + round-robin 队列分组
  static const String _sourceLatest = 'latest';
  static const String _sourceNextUp = 'nextUp';
  static const String _sourceResume = 'resume';
  static const String _sourceSuggestions = 'suggestions';
  static const String _sourceNative = 'nativeRecommendations';
  static const String _sourceRecommendations = 'recommendations';
  static const String _sourceSimilar = 'similar';
  static const String _sourceLocal = 'localRecommend';

  // PR #78：相似推荐配置
  static const int _similarSeedCount = 3;
  static const int _similarPerSeed = 10;
  static const double _similarSeedMinRating = 7.0;

  // 构建加载上下文（load() 和 loadMore() 共用）
  // 鉴权失败或未选择媒体库时返回 null
  // PR #83 优化：从 userBehaviorSignalProvider 读取缓存的 signal

  // 记录反推荐疲劳的展示记录

  // 服务端单次上限（避免一次拉太多）
  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Task 2：清理过期的展示记录，使反疲劳天数偏好实际生效
      final antiFatigueDays = _ref.read(recommendAntiFatigueDaysProvider);
      await _ref
          .read(recentlyShownItemIdsProvider.notifier)
          .cleanExpired(antiFatigueDays);

      final ctx = _buildLoadContext();
      if (ctx == null) {
        final auth = _ref.read(authProvider);
        final selectedIds = _ref.read(recommendLibraryIdsProvider);
        if (!auth.isAuthenticated ||
            auth.embyServerUrl == null ||
            auth.token == null) {
          state =
              state.copyWith(isLoading: false, hasMore: false, error: '尚未登录');
          return;
        }
        if (selectedIds.isEmpty) {
          state =
              state.copyWith(isLoading: false, hasMore: false, error: '未选择媒体库');
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

      // Task 3：冷启动判定增加 Suggestions 数据源检查
      final isColdStart = newItems.nextUpCount == 0 &&
          newItems.resumeCount == 0 &&
          newItems.suggestionsCount == 0;

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

      // Task 4：只有所有数据源都耗尽时才认为无更多数据
      final hasMore = !newItems.allSourcesExhausted;

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

      // Task 2：清理过期的展示记录，使反疲劳天数偏好实际生效
      final antiFatigueDays = _ref.read(recommendAntiFatigueDaysProvider);
      await _ref
          .read(recentlyShownItemIdsProvider.notifier)
          .cleanExpired(antiFatigueDays);

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
      // Task 4：只有所有数据源都耗尽时才认为无更多数据
      final hasMore = !newItems.allSourcesExhausted;

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

  // 填充「最新影片」队列：按入库时间倒序

  // 填充「移动客户端推荐」队列：本地行为数据（收藏影片）
  // 与服务器端 Suggestions 区分：这里直接呈现客户端本地收藏，
  // 无收藏时返回空，标签自动隐藏。

  // 填充 NextUp 追剧队列
  // P1-3：返回该数据源是否还有更多数据（items.length >= _pageSize 视为可能还有）
  // 旧实现 items.isNotEmpty 会误判：恰好装满一页 (size=30) 时，服务器已无更多但被认为还有。
  // 保守策略：只要 items 未达 limit 就认为已耗尽；后续若有 PaginatedResponse.totalRecordCount 可替换为精确判断。

  // 填充 Resume 续看队列
  // P1-3：返回该数据源是否还有更多数据（items.length >= _pageSize 视为可能还有）

  // PR #87：从最近看过的 series 拉下一集，插入到 NextUp 队列前面
  // 修复 P0-3：收集所有下一集后一次性插入队首，保证最近观看优先

  // 关注流深化：收藏剧集的更新（主动订阅）
  // 从收藏列表中筛出 Series（用户主动收藏的剧集），逐个拉取其未看新集，
  // 并入 NextUp 队列（标记 seriesUpdate），与收藏演员作品共同构成"关注"内容。

  // 填充个性化推荐队列
  // P1-3：返回该数据源是否还有更多数据（items.length >= _pageSize 视为可能还有）

  // 填充 Emby 原生精选队列（/Movies/Recommendations + /Shows/Recommended）
  // 该源基于观看历史生成、无分页概念，固定返回 hasMore=false；
  // 老版本 Emby / Jellyfin 不支持端点时仓库层已吞掉异常返回空，这里再兜底一层。
  // 仅当用户选定单个媒体库时用 ParentId 限定，多库时做跨库全局推荐。

  // PR #83：用 signal 高完播种子替换"最近高分项"做相似推荐种子
  // PR #86：收藏项优先作为相似种子
  // Task 4：返回该数据源是否还有更多数据（任一种子返回相似项 > 0）

  // 填充多库高分推荐队列
  // P1-3：返回该数据源是否还有更多数据（任一库返回项数 >= _pageSize 视为可能还有）

  // PR #79：抽离 - 冷启动降级：拉一轮更低阈值的评分推荐
  // PR #80：返回带 source 标签的 RecommendItem 列表
  // PR #83+#88+#89：完整过滤（黑名单 + 反疲劳 + 用户评分低）

  // round-robin 合并各队列，按 source 权重分配配额

  // PR #83：从 queues Map 按 RecommendSource 查队列

  // 并发限制工具：限制同时执行的异步任务数
  // 实现思路：滑动窗口，每完成一个就补上一个，保持最多 maxConcurrent 个在跑

  // PR #83+#88+#89：统一的 item 过滤逻辑
  // - 黑名单（收藏豁免）
  // - 反推荐疲劳（收藏豁免）
  // - 用户评分低（收藏豁免）
  // 所有数据源共用此逻辑，确保过滤一致性

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
final recommendProvider =
    StateNotifierProvider<RecommendNotifier, RecommendState>(
  (ref) => RecommendNotifier(ref),
);
