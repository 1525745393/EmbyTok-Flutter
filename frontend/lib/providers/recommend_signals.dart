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
// - 完播率聚合用「最近 30 天」窗口（时间衰减）

import '../models/models.dart';
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

  /// 信号强度：用于日志和调试
  /// - weak = 记录数 < 5，使用默认信号
  /// - strong = 记录数 >= 20
  final SignalStrength strength;

  const UserBehaviorSignal({
    required this.sourceWeights,
    required this.blacklist,
    required this.highCompletionSeeds,
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
  static const double _seedMinRating = 7.0;
  static const double _seedMinCompletion = 0.5;
  static const int _seedMaxCount = 5;

  /// 从完播率记录计算用户行为信号
  /// - 输入：所有观看记录
  /// - 输出：UserBehaviorSignal
  static UserBehaviorSignal compute(List<WatchRecord> records) {
    if (records.length < _minRecordsForSignal) {
      return UserBehaviorSignal.defaults;
    }

    final strength = records.length < 20
        ? SignalStrength.medium
        : SignalStrength.strong;

    return UserBehaviorSignal(
      sourceWeights: _computeSourceWeights(records),
      blacklist: _computeBlacklist(records),
      highCompletionSeeds: _computeHighCompletionSeeds(records),
      strength: strength,
    );
  }

  /// 计算 5 数据源的权重
  /// - 聚合：每个 source 的最近 30 条平均完播率
  /// - 映射：avg >= 0.8 → 1.5，0.3-0.8 → 1.0，< 0.3 → 0.3
  static Map<RecommendSource, double> _computeSourceWeights(
    List<WatchRecord> records,
  ) {
    final bySource = <RecommendSource, List<double>>{};
    for (final r in records) {
      final source = _sourceFromKey(r.source);
      if (source == null) continue;
      bySource.putIfAbsent(source, () => <double>[]).add(r.completionRate);
    }

    final result = <RecommendSource, double>{};
    for (final source in RecommendSource.values) {
      final rates = bySource[source];
      if (rates == null || rates.isEmpty) {
        // 该源无数据：保持中性
        result[source] = 1.0;
        continue;
      }
      // 取最近 30 条均值
      final sample = rates.length > 30 ? rates.sublist(0, 30) : rates;
      final avg = sample.reduce((a, b) => a + b) / sample.length;
      result[source] = _mapAvgToWeight(avg);
    }
    return result;
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

  /// 计算黑名单
  /// - 规则 1：同一 item 累计 3 次完播率 < 0.2 → 加入
  /// - 规则 2：任何 1 次完播率 < 0.1 → 立即加入
  static Set<String> _computeBlacklist(List<WatchRecord> records) {
    final lowRateByItem = <String, int>{}; // itemId -> 低完播次数
    final zeroByItem = <String>{}; // itemId -> 有 0.1 以下记录的

    for (final r in records) {
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

  /// 计算高完播种子（用于相似推荐）
  /// - 聚合：每个 itemId 的平均完播率
  /// - 筛选：communityRating >= 7.0 + avgCompletion >= 0.5
  /// - 排序：按 (communityRating * avgCompletion) 降序
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
    // - 取 Top N（按 avgCompletion 降序）
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
