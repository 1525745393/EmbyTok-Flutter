// 用户行为信号（用于推荐打分接入门控）
//
// 背景（PR #83）：
// PR #81 完播率 Provider 已收集数据但没用于推荐打分。
// 本模块：基于 watchStatsProvider 计算"用户行为信号"，
// 在 recommend_provider 中应用 3 个门控：
//   1. 黑名单过滤：连续低完播率 / 极低完播率的 item 直接屏蔽
//   2. Source 权重：5 数据源按用户对各源的完播率分配配额
//   3. 相似推荐种子：从"高完播 + 高分"中取，而非纯"最近高分"
//
// 设计原则：
// - 数据少时（< 5 条记录）使用默认信号（无门控），避免冷启动误判
// - 系数区间 [0.3, 1.5]，避免过度倾斜
// - 完播率聚合用「指数时间衰减」（半衰期 14 天，PR #84）
//   - 越新的记录对权重影响越大
//   - 避免老的偏好持续干扰新的兴趣

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_preferences_providers.dart';
import 'favorites_provider.dart';
import 'recommend_provider.dart' show RecommendSource;
import 'watch_stats_provider.dart';

/// 用户行为信号（推荐门控用）
class UserBehaviorSignal {
  /// 5 数据源各自的权重系数
  /// - 1.0 = 中性
  /// - > 1.0 = 加权（用户爱看）
  /// - < 1.0 = 降权（用户不爱看）
  final Map<RecommendSource, double> sourceWeights;

  /// 黑名单 itemIds：推荐时直接过滤
  final Set<String> blacklist;

  /// 高完播种子项（用于相似推荐）
  /// - 用户在历史中对哪些高分项有高完播
  /// - 替换原"最近高分项"做相似推荐种子
  final List<String> highCompletionSeeds;

  /// PR #86：收藏种子项（用户主动收藏的 itemId）
  /// - 用户在 Emby 中收藏的 item 代表强烈兴趣
  /// - 用于：
  ///   1. 相似推荐种子（与高完播种子合并，收藏优先）
  ///   2. 黑名单豁免（用户主动喜欢 > 系统推断不爱看）
  final List<String> favoriteSeeds;

  /// 信号强度：用于日志和调试
  /// - weak = 记录数 < 5，使用默认信号
  /// - strong = 记录数 >= 20
  final SignalStrength strength;

  const UserBehaviorSignal({
    required this.sourceWeights,
    required this.blacklist,
    required this.highCompletionSeeds,
    required this.favoriteSeeds,
    required this.strength,
  });

  /// 默认信号：冷启动 / 无数据 / 记录数不足
  /// - 所有源权重 1.0
  /// - 黑名单空
  /// - 种子空（调用方降级为"最近高分项"）
  /// 注意：用 static final 而非 const，避免循环 import 时初始化顺序问题
  static final UserBehaviorSignal defaults = UserBehaviorSignal(
    sourceWeights: <RecommendSource, double>{
      RecommendSource.nextUp: 1.0,
      RecommendSource.resume: 1.0,
      RecommendSource.suggestions: 1.0,
      RecommendSource.similar: 1.0,
      RecommendSource.recommendations: 1.0,
    },
    blacklist: <String>{},
    highCompletionSeeds: <String>[],
    favoriteSeeds: <String>[],
    strength: SignalStrength.weak,
  );

  /// 给定源查权重（未知源返回 1.0）
  double weightFor(RecommendSource source) {
    return sourceWeights[source] ?? 1.0;
  }
}

enum SignalStrength {
  weak, // < 5 条记录，门控基本无效
  medium, // 5-20 条记录
  strong, // >= 20 条记录
}

/// UserBehaviorSignal 计算器
class UserBehaviorSignalCalculator {
  // PR #83：参数常量
  // - 完播率 >= 0.8 → 强正向
  // - 完播率 0.3-0.8 → 中性
  // - 完播率 < 0.3 → 弱负向
  static const double _strongPositiveRate = 0.8;
  static const double _strongNegativeRate = 0.3;

  // PR #83：source 权重区间
  static const double _maxWeight = 1.5;
  static const double _minWeight = 0.3;

  // PR #83：黑名单规则
  // - 同一 item 累计 3 次低完播率（< 0.2）→ 加入黑名单
  // - 任何 1 次完播率 < 0.1（基本没看）→ 立即加入黑名单
  static const int _blacklistLowCountThreshold = 3;
  static const double _blacklistLowRate = 0.2;
  static const double _blacklistZeroRate = 0.1;

  // PR #83：最少记录数（低于此数视为冷启动，使用默认信号）
  static const int _minRecordsForSignal = 5;

  // PR #83：相似推荐种子阈值
  // - communityRating >= 7.0
  // - 该 seed 的平均完播率 >= 0.5
  static const double _seedMinCompletion = 0.5;
  static const int _seedMaxCount = 5;

  // PR #84：时间衰减半衰期（天）- 默认值
  // 实际值由 compute() 的 halfLifeDays 参数传入（来自用户设置）
  // - 14 天前的记录权重衰减到 0.5
  // - 28 天前的记录权重衰减到 0.25
  // - 让用户最近的偏好对推荐影响更大
  static const double _defaultHalfLifeDays = 14.0;

  // PR #84：每个 source 最多纳入聚合的近期记录数（避免数据爆炸）
  // 注意：这是按时间倒序取前 N 条，时间衰减再在内部应用
  static const int _maxRecordsPerSource = 50;

  /// 从完播率记录计算用户行为信号
  /// - 输入：所有观看记录
  /// - 输出：UserBehaviorSignal
  /// - 可选 now：注入当前时间（用于测试），默认 DateTime.now()
  /// - 可选 useWatchHistory：是否使用完播率历史（PR #85）
  ///   - false：直接返回默认信号，无门控
  ///   - true（默认）：按完播率历史计算
  /// - 可选 halfLifeDays：时间衰减半衰期（PR #85）
  ///   - 0 = 不衰减（所有记录等权重）
  ///   - 默认 14.0
  /// - 可选 favoriteIds：用户收藏的 itemIds（PR #86）
  ///   - 进入 favoriteSeeds
  ///   - 黑名单豁免（用户主动喜欢 > 系统推断不爱看）
  static UserBehaviorSignal compute(
    List<WatchRecord> records, {
    DateTime? now,
    bool useWatchHistory = true,
    double halfLifeDays = _defaultHalfLifeDays,
    Set<String> favoriteIds = const <String>{},
  }) {
    // PR #85：用户关闭完播率门控 → 直接返回默认信号
    if (!useWatchHistory) {
      return UserBehaviorSignal(
        sourceWeights: UserBehaviorSignal.defaults.sourceWeights,
        blacklist: UserBehaviorSignal.defaults.blacklist,
        highCompletionSeeds: UserBehaviorSignal.defaults.highCompletionSeeds,
        // PR #86：即使关闭门控，也保留收藏种子
        favoriteSeeds: favoriteIds.toList(growable: false),
        strength: SignalStrength.weak,
      );
    }
    if (records.length < _minRecordsForSignal) {
      // 冷启动：仍保留收藏种子
      return UserBehaviorSignal(
        sourceWeights: UserBehaviorSignal.defaults.sourceWeights,
        blacklist: UserBehaviorSignal.defaults.blacklist,
        highCompletionSeeds: UserBehaviorSignal.defaults.highCompletionSeeds,
        favoriteSeeds: favoriteIds.toList(growable: false),
        strength: SignalStrength.weak,
      );
    }

    final strength = records.length < 20
        ? SignalStrength.medium
        : SignalStrength.strong;
    final reference = now ?? DateTime.now();

    return UserBehaviorSignal(
      sourceWeights: _computeSourceWeights(records, reference, halfLifeDays),
      // PR #86：黑名单过滤 - 收藏项不进入黑名单（用户主动喜欢 > 系统推断不爱看）
      blacklist: _computeBlacklist(records, favoriteIds: favoriteIds),
      highCompletionSeeds: _computeHighCompletionSeeds(records),
      // PR #86：收藏种子直接来自收藏列表
      favoriteSeeds: favoriteIds.toList(growable: false),
      strength: strength,
    );
  }

  /// 计算 5 数据源的权重（PR #84：时间加权平均）
  /// - 聚合：每个 source 的最近 _maxRecordsPerSource 条记录
  /// - 时间衰减：每条记录按年龄加权（半衰期 halfLifeDays）
  /// - 映射：加权 avg >= 0.8 → 1.5，0.3-0.8 → 1.0，< 0.3 → 0.3
  static Map<RecommendSource, double> _computeSourceWeights(
    List<WatchRecord> records,
    DateTime now,
    double halfLifeDays,
  ) {
    final bySource = <RecommendSource, List<WatchRecord>>{};
    for (final r in records) {
      final source = _sourceFromKey(r.source);
      if (source == null) continue;
      bySource.putIfAbsent(source, () => <WatchRecord>[]).add(r);
    }

    final result = <RecommendSource, double>{};
    for (final source in RecommendSource.values) {
      final recs = bySource[source];
      if (recs == null || recs.isEmpty) {
        // 该源无数据：保持中性
        result[source] = 1.0;
        continue;
      }
      // 取最近 _maxRecordsPerSource 条（records 已是时间倒序）
      final sample = recs.length > _maxRecordsPerSource
          ? recs.sublist(0, _maxRecordsPerSource)
          : recs;
      final weightedAvg = _weightedAverage(sample, now, halfLifeDays);
      result[source] = _mapAvgToWeight(weightedAvg);
    }
    return result;
  }

  /// 时间加权平均（PR #84）
  /// - 公式：sum(timeWeight_i * rate_i) / sum(timeWeight_i)
  /// - 越新的记录权重越大
  /// - halfLifeDays = 0 → 所有记录等权重（退化为普通平均）
  static double _weightedAverage(
    List<WatchRecord> records,
    DateTime now,
    double halfLifeDays,
  ) {
    // PR #85：halfLifeDays <= 0 → 不衰减，普通平均
    if (halfLifeDays <= 0) {
      final total = records.fold<double>(0.0, (s, r) => s + r.completionRate);
      return total / records.length;
    }
    double weightedSum = 0.0;
    double weightSum = 0.0;
    for (final r in records) {
      final w = _timeWeight(r.watchedAt, now, halfLifeDays);
      weightedSum += w * r.completionRate;
      weightSum += w;
    }
    return weightSum == 0 ? 0.0 : weightedSum / weightSum;
  }

  /// 时间衰减权重（PR #84）
  /// - 公式：weight = exp(-Δdays / halfLife * ln(2))
  /// - Δdays = 0 → weight = 1.0
  /// - Δdays = halfLife → weight = 0.5
  /// - Δdays = 2*halfLife → weight = 0.25
  /// - Δdays 为负（未来）按 0 处理（避免权重爆炸）
  /// - 半衰期越长，衰减越慢
  static double _timeWeight(
    int watchedAtUnixSec,
    DateTime now,
    double halfLifeDays,
  ) {
    final watchedAt = DateTime.fromMillisecondsSinceEpoch(
      watchedAtUnixSec * 1000,
    );
    final delta = now.difference(watchedAt);
    final days = delta.inSeconds / 86400.0; // 一天 86400 秒
    if (days <= 0) return 1.0; // 未来或刚发生：满权重
    final decayFactor = days / halfLifeDays;
    return math.exp(-decayFactor * math.ln2);
  }

  /// 平均完播率 → 权重系数
  /// - avg >= 0.8 → 1.5
  /// - avg 0.3-0.8 → 线性插值 0.3-1.5
  /// - avg < 0.3 → 0.3
  static double _mapAvgToWeight(double avg) {
    if (avg >= _strongPositiveRate) return _maxWeight;
    if (avg < _strongNegativeRate) return _minWeight;
    // 线性插值：[0.3, 0.8] → [0.3, 1.5]
    final t = (avg - _strongNegativeRate) / (_strongPositiveRate - _strongNegativeRate);
    return _minWeight + t * (_maxWeight - _minWeight);
  }

  /// 计算黑名单（不使用时间衰减，避免反复进出）
  /// - 规则 1：同一 item 累计 3 次完播率 < 0.2 → 加入
  /// - 规则 2：任何 1 次完播率 < 0.1 → 立即加入
  /// - PR #86：收藏项不进入黑名单（用户主动标记喜欢 > 系统推断不爱看）
  static Set<String> _computeBlacklist(
    List<WatchRecord> records, {
    Set<String> favoriteIds = const <String>{},
  }) {
    final lowRateByItem = <String, int>{}; // itemId -> 低完播次数
    final zeroByItem = <String>{}; // itemId -> 有 0.1 以下记录的

    for (final r in records) {
      // PR #86：收藏项不参与黑名单统计
      if (favoriteIds.contains(r.itemId)) continue;
      if (r.completionRate < _blacklistLowRate) {
        lowRateByItem[r.itemId] = (lowRateByItem[r.itemId] ?? 0) + 1;
      }
      if (r.completionRate < _blacklistZeroRate) {
        zeroByItem.add(r.itemId);
      }
    }

    final blacklist = <String>{};
    // 规则 1
    lowRateByItem.forEach((id, count) {
      if (count >= _blacklistLowCountThreshold) {
        blacklist.add(id);
      }
    });
    // 规则 2
    blacklist.addAll(zeroByItem);
    return blacklist;
  }

  /// 计算高完播种子（不使用时间衰减）
  /// - 聚合：每个 itemId 的平均完播率
  /// - 筛选：avgCompletion >= 0.5
  /// - 取 Top 5
  /// 注意：本方法只看 records 里有 title + communityRating 信息的项
  /// - 实际调用方应传入 MediaItem 列表来补全
  static List<String> _computeHighCompletionSeeds(List<WatchRecord> records) {
    // 按 itemId 聚合
    final byItem = <String, List<double>>{};
    for (final r in records) {
      byItem.putIfAbsent(r.itemId, () => <double>[]).add(r.completionRate);
    }
    // 计算平均完播率
    final avgByItem = <String, double>{};
    byItem.forEach((id, rates) {
      avgByItem[id] = rates.reduce((a, b) => a + b) / rates.length;
    });
    // 筛选：avgCompletion >= _seedMinCompletion
    final sorted = avgByItem.entries
        .where((e) => e.value >= _seedMinCompletion)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .take(_seedMaxCount)
        .map((e) => e.key)
        .toList(growable: false);
  }

  /// 字符串 source key → RecommendSource 枚举
  /// - 'nextUp' → nextUp
  /// - 'resume' → resume
  /// - 'suggestions' → suggestions
  /// - 'similar' → similar
  /// - 'recommendations' → recommendations
  /// - 'feed' 或其他 → null（不算 source）
  static RecommendSource? _sourceFromKey(String key) {
    switch (key) {
      case 'nextUp':
        return RecommendSource.nextUp;
      case 'resume':
        return RecommendSource.resume;
      case 'suggestions':
        return RecommendSource.suggestions;
      case 'similar':
        return RecommendSource.similar;
      case 'recommendations':
        return RecommendSource.recommendations;
      default:
        return null;
    }
  }
}

/// PR #83 优化：独立的 userBehaviorSignalProvider
///
/// 将 signal 计算从 recommend_provider._buildLoadContext() 抽离出来，
/// 作为独立的 Provider 缓存结果。好处：
/// - 避免每次 load() / loadMore() 都重算 signal
/// - watchStats / 收藏 / 偏好变化时自动重算
/// - 其他模块也可以复用 signal（如调试面板）
///
/// 依赖：
/// - watchStatsProvider：完播率记录
/// - recommendUseWatchHistoryProvider：是否启用门控
/// - recommendHalfLifeDaysProvider：时间衰减半衰期
/// - favoritesProvider：收藏列表（黑名单豁免 + 收藏种子）
final userBehaviorSignalProvider = Provider<UserBehaviorSignal>((ref) {
  final watchStats = ref.watch(watchStatsProvider);
  final useWatchHistory = ref.watch(recommendUseWatchHistoryProvider);
  final halfLifeDays = ref.watch(recommendHalfLifeDaysProvider);
  final favorites = ref.watch(favoritesProvider);

  return UserBehaviorSignalCalculator.compute(
    watchStats.records,
    useWatchHistory: useWatchHistory,
    halfLifeDays: halfLifeDays,
    favoriteIds: favorites.favoriteIds,
  );
});
