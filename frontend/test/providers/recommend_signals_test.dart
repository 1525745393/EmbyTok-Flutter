/// 推荐信号计算器测试（PR #83 / PR #84）
///
/// 重点验证：
/// - UserBehaviorSignalCalculator.compute 冷启动返回默认信号
/// - Source 权重计算正确（高完播加权、低完播降权）
/// - 黑名单规则（连续 3 次低完播 + 极低完播）
/// - 高完播种子提取
/// - PR #84：时间衰减（半衰期 14 天）

import 'package:flutter_test/flutter_test.dart';

import 'package:embbytok_flutter/providers/recommend_signals.dart';
import 'package:embbytok_flutter/providers/recommend_provider.dart'
    show RecommendSource;
import 'package:embbytok_flutter/providers/watch_stats_provider.dart';

/// 固定参考时间（用于时间衰减测试）
final DateTime _refNow = DateTime(2026, 6, 29, 12, 0, 0);

WatchRecord _record({
  required String id,
  required double rate,
  String source = 'feed',
  int? watchedAt,
}) =>
    WatchRecord(
      itemId: id,
      itemType: 'Movie',
      completionRate: rate,
      watchedAt: watchedAt ?? _refNow.millisecondsSinceEpoch ~/ 1000,
      source: source,
    );

/// 在参考时间之前 N 天的记录
WatchRecord _recordAgo({
  required String id,
  required double rate,
  required int daysAgo,
  String source = 'feed',
}) {
  final ts = _refNow
      .subtract(Duration(days: daysAgo))
      .millisecondsSinceEpoch ~/
      1000;
  return _record(id: id, rate: rate, source: source, watchedAt: ts);
}

void main() {
  group('冷启动 / 数据不足', () {
    test('空记录返回默认信号', () {
      final signal = UserBehaviorSignalCalculator.compute([], now: _refNow);
      expect(signal.strength, SignalStrength.weak);
      expect(signal.sourceWeights[RecommendSource.nextUp], 1.0);
      expect(signal.blacklist.isEmpty, true);
      expect(signal.highCompletionSeeds.isEmpty, true);
    });

    test('记录 < 5 条返回默认信号', () {
      final records = [
        _recordAgo(id: 'a', rate: 0.9, daysAgo: 1, source: 'nextUp'),
        _recordAgo(id: 'a', rate: 0.8, daysAgo: 2, source: 'nextUp'),
        _recordAgo(id: 'a', rate: 0.7, daysAgo: 3, source: 'nextUp'),
        _recordAgo(id: 'a', rate: 0.6, daysAgo: 4, source: 'nextUp'),
      ];
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      expect(signal.strength, SignalStrength.weak);
      expect(signal.sourceWeights[RecommendSource.nextUp], 1.0);
    });
  });

  group('Source 权重计算', () {
    test('5-19 条记录 = medium strength', () {
      final records = List.generate(
        10,
        (i) => _recordAgo(id: 'a', rate: 0.9, daysAgo: i + 1, source: 'nextUp'),
      );
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      expect(signal.strength, SignalStrength.medium);
    });

    test('20+ 条记录 = strong strength', () {
      final records = List.generate(
        25,
        (i) => _recordAgo(id: 'a', rate: 0.9, daysAgo: i + 1, source: 'nextUp'),
      );
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      expect(signal.strength, SignalStrength.strong);
    });

    test('高完播率 source 加权（rate 0.9 → weight 1.5）', () {
      // 6 条 nextUp 都是高完播
      final records = List.generate(
        6,
        (i) => _recordAgo(id: 'a', rate: 0.9, daysAgo: i + 1, source: 'nextUp'),
      );
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      expect(signal.sourceWeights[RecommendSource.nextUp], 1.5);
    });

    test('低完播率 source 降权（rate 0.1 → weight 0.3）', () {
      // 6 条 nextUp 都是低完播
      final records = List.generate(
        6,
        (i) => _recordAgo(id: 'a', rate: 0.1, daysAgo: i + 1, source: 'nextUp'),
      );
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      expect(signal.sourceWeights[RecommendSource.nextUp], 0.3);
    });

    test('中性完播率 source 线性插值（rate 0.5 → weight 0.78）', () {
      // 6 条 nextUp 完播率 0.5 → 线性插值
      // 区间 [0.3, 0.8] → [0.3, 1.5]
      // 0.5 → 0.3 + (0.5-0.3)/(0.8-0.3) * (1.5-0.3) = 0.3 + 0.4*1.2 = 0.78
      final records = List.generate(
        6,
        (i) => _recordAgo(id: 'a', rate: 0.5, daysAgo: i + 1, source: 'nextUp'),
      );
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      expect(signal.sourceWeights[RecommendSource.nextUp], closeTo(0.78, 0.01));
    });

    test('不同 source 独立计算权重', () {
      // nextUp 高完播 0.9 → 1.5
      // resume 低完播 0.1 → 0.3
      final records = <WatchRecord>[
        ...List.generate(
            5, (i) => _recordAgo(id: 'a', rate: 0.9, daysAgo: i + 1, source: 'nextUp')),
        ...List.generate(
            5, (i) => _recordAgo(id: 'a', rate: 0.1, daysAgo: i + 1, source: 'resume')),
      ];
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      expect(signal.sourceWeights[RecommendSource.nextUp], 1.5);
      expect(signal.sourceWeights[RecommendSource.resume], 0.3);
    });

    test('无数据的 source 保持中性', () {
      final records = List.generate(
        6,
        (i) => _recordAgo(id: 'a', rate: 0.9, daysAgo: i + 1, source: 'nextUp'),
      );
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      expect(signal.sourceWeights[RecommendSource.resume], 1.0);
    });
  });

  group('黑名单计算', () {
    test('同一 item 3 次低完播率（< 0.2）→ 加入黑名单', () {
      final records = [
        _recordAgo(id: 'bad1', rate: 0.1, daysAgo: 1, source: 'feed'),
        _recordAgo(id: 'bad1', rate: 0.15, daysAgo: 2, source: 'feed'),
        _recordAgo(id: 'bad1', rate: 0.18, daysAgo: 3, source: 'feed'),
      ];
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      expect(signal.blacklist.contains('bad1'), true);
    });

    test('同一 item 2 次低完播率 → 不加入黑名单', () {
      final records = [
        _recordAgo(id: 'a', rate: 0.1, daysAgo: 1, source: 'feed'),
        _recordAgo(id: 'a', rate: 0.15, daysAgo: 2, source: 'feed'),
      ];
      // 加上 3 条其他记录以满足 _minRecordsForSignal
      records.addAll(List.generate(
          3, (i) => _recordAgo(id: 'b', rate: 0.5, daysAgo: i + 4, source: 'feed')));
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      expect(signal.blacklist.contains('a'), false);
    });

    test('任何 1 次完播率 < 0.1 → 立即加入黑名单', () {
      final records = [
        _recordAgo(id: 'zero1', rate: 0.05, daysAgo: 1, source: 'feed'),
      ];
      // 加 4 条其他记录
      records.addAll(List.generate(
          4, (i) => _recordAgo(id: 'b', rate: 0.5, daysAgo: i + 2, source: 'feed')));
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      expect(signal.blacklist.contains('zero1'), true);
    });

    test('黑名单不受时间衰减影响（即使旧记录也保留）', () {
      // 30 天前的极低完播率记录 + 4 条新记录
      final records = [
        _recordAgo(id: 'old_bad', rate: 0.05, daysAgo: 30, source: 'feed'),
      ];
      records.addAll(List.generate(
          4, (i) => _recordAgo(id: 'b', rate: 0.5, daysAgo: i + 1, source: 'feed')));
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      // 黑名单不衰减：30 天前的极低完播率记录仍触发黑名单
      expect(signal.blacklist.contains('old_bad'), true);
    });
  });

  group('高完播种子提取', () {
    test('avgCompletion >= 0.5 的 item 进入种子', () {
      final records = [
        _recordAgo(id: 'good', rate: 0.9, daysAgo: 1, source: 'nextUp'),
        _recordAgo(id: 'good', rate: 0.7, daysAgo: 2, source: 'nextUp'),
        _recordAgo(id: 'bad', rate: 0.1, daysAgo: 3, source: 'nextUp'),
        _recordAgo(id: 'bad', rate: 0.05, daysAgo: 4, source: 'nextUp'),
      ];
      records.add(_recordAgo(id: 'filler', rate: 0.5, daysAgo: 5, source: 'feed'));
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      expect(signal.highCompletionSeeds.contains('good'), true);
      expect(signal.highCompletionSeeds.contains('bad'), false);
    });

    test('按平均完播率降序排，最多 5 个', () {
      final records = <WatchRecord>[];
      for (int i = 0; i < 10; i++) {
        records.add(
            _recordAgo(id: 'm$i', rate: 0.5 + i * 0.05, daysAgo: i + 1, source: 'feed'));
      }
      // 加 1 条 filler 满足 _minRecordsForSignal
      records.add(_recordAgo(id: 'filler', rate: 0.5, daysAgo: 12, source: 'feed'));
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      expect(signal.highCompletionSeeds.length, lessThanOrEqualTo(5));
      // 第一个应该是 m9（最高 0.95）
      expect(signal.highCompletionSeeds.first, 'm9');
    });

    test('种子不受时间衰减影响（旧的种子也保留）', () {
      // 60 天前的高完播记录 + 4 条新记录
      final records = <WatchRecord>[
        _recordAgo(id: 'old_good', rate: 0.9, daysAgo: 60, source: 'nextUp'),
      ];
      records.addAll(List.generate(
          4, (i) => _recordAgo(id: 'b', rate: 0.5, daysAgo: i + 1, source: 'feed')));
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      // 种子不衰减：60 天前的高完播记录仍作为种子
      expect(signal.highCompletionSeeds.contains('old_good'), true);
    });
  });

  group('weightFor 辅助方法', () {
    test('未知 source 返回 1.0', () {
      final signal = UserBehaviorSignal.defaults;
      // 5 个源都有默认值
      for (final s in RecommendSource.values) {
        expect(signal.weightFor(s), 1.0);
      }
    });
  });

  // ========== PR #84 新增：时间衰减 ==========

  group('时间衰减（PR #84）', () {
    test('今天记录的权重 = 1.0', () {
      // 5 条新 + 1 条旧的，都相同 rate 0.9
      // 加权平均应该都是 0.9（权重差异被归一化）
      final records = List.generate(
        6,
        (i) => _recordAgo(id: 'a', rate: 0.9, daysAgo: i % 5, source: 'nextUp'),
      );
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      // 6 条记录都 rate 0.9，加权平均 = 0.9 → 1.5
      expect(signal.sourceWeights[RecommendSource.nextUp], 1.5);
    });

    test('新记录主导：旧记录 0.0 + 新记录 1.0 → 加权平均趋近 1.0', () {
      // 5 条 30 天前 rate 0.0（权重 ≈ 0.25）
      // 5 条今天 rate 1.0（权重 = 1.0）
      // 加权平均 ≈ (0.25*0 + 1.0*1) / (0.25 + 1.0) ≈ 0.8 → 1.5
      final records = <WatchRecord>[
        ...List.generate(
            5, (i) => _recordAgo(id: 'o', rate: 0.0, daysAgo: 30, source: 'nextUp')),
        ...List.generate(
            5, (i) => _recordAgo(id: 'n', rate: 1.0, daysAgo: 0, source: 'nextUp')),
      ];
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      // 加权平均应该 >= 0.8（强正向阈值）→ weight 1.5
      expect(signal.sourceWeights[RecommendSource.nextUp], 1.5);
    });

    test('旧记录主导：新记录 0.0 + 旧记录 1.0 → 加权平均降低', () {
      // 5 条 30 天前 rate 1.0（权重 ≈ 0.25）
      // 5 条今天 rate 0.0（权重 = 1.0）
      // 加权平均 ≈ (0.25*1 + 1.0*0) / (0.25 + 1.0) ≈ 0.2 → 0.3
      final records = <WatchRecord>[
        ...List.generate(
            5, (i) => _recordAgo(id: 'o', rate: 1.0, daysAgo: 30, source: 'nextUp')),
        ...List.generate(
            5, (i) => _recordAgo(id: 'n', rate: 0.0, daysAgo: 0, source: 'nextUp')),
      ];
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      // 加权平均应该 < 0.3（弱负向阈值）→ weight 0.3
      expect(signal.sourceWeights[RecommendSource.nextUp], 0.3);
    });

    test('半衰期 14 天：14 天前的记录权重 ≈ 0.5', () {
      // 验证 14 天前记录的权重恰好为 0.5
      // 构造：1 条 14 天前 rate 0.0 + 1 条今天 rate 1.0
      // 加权平均 = (0.5*0 + 1.0*1) / (0.5 + 1.0) = 1/1.5 ≈ 0.667
      // 0.667 在 [0.3, 0.8] → 线性插值 ≈ 0.3 + (0.667-0.3)/(0.8-0.3) * 1.2 ≈ 1.08
      final records = <WatchRecord>[
        _recordAgo(id: 'old', rate: 0.0, daysAgo: 14, source: 'nextUp'),
        _recordAgo(id: 'new', rate: 1.0, daysAgo: 0, source: 'nextUp'),
      ];
      // 加 4 条 filler 满足 _minRecordsForSignal
      records.addAll(List.generate(
          4, (i) => _recordAgo(id: 'f', rate: 0.5, daysAgo: i + 1, source: 'feed')));
      final signal =
          UserBehaviorSignalCalculator.compute(records, now: _refNow);
      // nextUp source 只有 old + new 两条
      // 加权平均 = (0.5*0 + 1.0*1) / (0.5 + 1.0) = 0.667
      // 0.667 → 0.3 + (0.667-0.3)/0.5 * 1.2 = 0.3 + 0.88 = 1.08
      expect(
        signal.sourceWeights[RecommendSource.nextUp],
        closeTo(1.08, 0.01),
      );
    });

    test('compute 不传 now 也应正常工作（默认 DateTime.now()）', () {
      final records = List.generate(
        6,
        (i) => _record(id: 'a', rate: 0.9, source: 'nextUp'),
      );
      // 不传 now，使用 DateTime.now()
      final signal = UserBehaviorSignalCalculator.compute(records);
      // 不崩、返回合理结果即可
      expect(signal.strength, SignalStrength.medium);
      expect(signal.sourceWeights[RecommendSource.nextUp], 1.5);
    });
  });

  // ========== PR #85 新增：用户控制（完播率门控 + 时间衰减半衰期） ==========

  group('用户控制 - 完播率门控（PR #85）', () {
    test('useWatchHistory=false → 直接返回默认信号（无门控）', () {
      // 即使有大量高完播率记录，关闭后应该不应用门控
      final records = List.generate(
        10,
        (i) => _recordAgo(id: 'a', rate: 0.9, daysAgo: i + 1, source: 'nextUp'),
      );
      final signal = UserBehaviorSignalCalculator.compute(
        records,
        now: _refNow,
        useWatchHistory: false,
      );
      // 默认信号：所有 source 权重 = 1.0
      expect(signal.sourceWeights[RecommendSource.nextUp], 1.0);
      expect(signal.blacklist.isEmpty, true);
      expect(signal.highCompletionSeeds.isEmpty, true);
      expect(signal.strength, SignalStrength.weak);
    });

    test('useWatchHistory=true（默认）→ 应用门控', () {
      final records = List.generate(
        10,
        (i) => _recordAgo(id: 'a', rate: 0.9, daysAgo: i + 1, source: 'nextUp'),
      );
      final signal = UserBehaviorSignalCalculator.compute(
        records,
        now: _refNow,
        useWatchHistory: true,
      );
      // 高完播率 → 强正向 → weight 1.5
      expect(signal.sourceWeights[RecommendSource.nextUp], 1.5);
      expect(signal.strength, SignalStrength.medium);
    });
  });

  group('用户控制 - 时间衰减半衰期（PR #85）', () {
    test('halfLifeDays=0 → 不衰减（所有记录等权重）', () {
      // 5 条 30 天前 rate 1.0 + 5 条今天 rate 0.0
      // 不衰减 → 普通平均 = 0.5 → 0.78
      // 衰减（默认 14）→ 加权平均 ≈ 0.185 → 0.3
      final records = <WatchRecord>[
        ...List.generate(
            5, (i) => _recordAgo(id: 'o', rate: 1.0, daysAgo: 30, source: 'nextUp')),
        ...List.generate(
            5, (i) => _recordAgo(id: 'n', rate: 0.0, daysAgo: 0, source: 'nextUp')),
      ];
      final signal = UserBehaviorSignalCalculator.compute(
        records,
        now: _refNow,
        halfLifeDays: 0,
      );
      // 普通平均 0.5 → 0.78
      expect(
        signal.sourceWeights[RecommendSource.nextUp],
        closeTo(0.78, 0.01),
      );
    });

    test('halfLifeDays=3 → 衰减快（旧记录影响小）', () {
      // 5 条 30 天前 rate 1.0（30 天 / 3 = 10 个半衰期 → weight 2^-10 ≈ 0.001）
      // 5 条今天 rate 0.0（weight 1.0）
      // 加权平均 ≈ (0.001*1 + 1*0) / (0.001 + 1) ≈ 0.001 → 0.3
      final records = <WatchRecord>[
        ...List.generate(
            5, (i) => _recordAgo(id: 'o', rate: 1.0, daysAgo: 30, source: 'nextUp')),
        ...List.generate(
            5, (i) => _recordAgo(id: 'n', rate: 0.0, daysAgo: 0, source: 'nextUp')),
      ];
      final signal = UserBehaviorSignalCalculator.compute(
        records,
        now: _refNow,
        halfLifeDays: 3,
      );
      // 衰减非常快，加权平均趋近 0 → 弱负向 → weight 0.3
      expect(signal.sourceWeights[RecommendSource.nextUp], 0.3);
    });

    test('halfLifeDays=90 → 衰减慢（所有记录权重接近）', () {
      // 5 条 30 天前 rate 1.0（30 / 90 = 0.333 个半衰期 → weight 2^-0.333 ≈ 0.794）
      // 5 条今天 rate 0.0（weight 1.0）
      // 加权平均 ≈ (0.794*1 + 1*0) / (0.794 + 1) ≈ 0.443 → 0.3+0.286*1.2=0.64
      final records = <WatchRecord>[
        ...List.generate(
            5, (i) => _recordAgo(id: 'o', rate: 1.0, daysAgo: 30, source: 'nextUp')),
        ...List.generate(
            5, (i) => _recordAgo(id: 'n', rate: 0.0, daysAgo: 0, source: 'nextUp')),
      ];
      final signal = UserBehaviorSignalCalculator.compute(
        records,
        now: _refNow,
        halfLifeDays: 90,
      );
      // 加权平均应该在 0.4-0.5 之间，weight 在 0.5-0.7 之间
      final w = signal.sourceWeights[RecommendSource.nextUp];
      expect(w, greaterThan(0.5));
      expect(w, lessThan(0.8));
    });
  });

  // ========== PR #86 新增：收藏加权 ==========

  group('收藏加权（PR #86）', () {
    test('favoriteSeeds 包含传入的 favoriteIds', () {
      final records = List.generate(
        6,
        (i) => _recordAgo(id: 'a', rate: 0.9, daysAgo: i + 1, source: 'nextUp'),
      );
      final favorites = <String>{'fav1', 'fav2', 'fav3'};
      final signal = UserBehaviorSignalCalculator.compute(
        records,
        now: _refNow,
        favoriteIds: favorites,
      );
      expect(signal.favoriteSeeds, containsAll(favorites));
    });

    test('收藏项即使多次低完播率也不进入黑名单', () {
      // fav1 收藏但有 3 次低完播率（按规则应该进黑名单）
      // 但因为是收藏项，应该豁免
      final records = [
        _recordAgo(id: 'fav1', rate: 0.1, daysAgo: 1, source: 'feed'),
        _recordAgo(id: 'fav1', rate: 0.15, daysAgo: 2, source: 'feed'),
        _recordAgo(id: 'fav1', rate: 0.18, daysAgo: 3, source: 'feed'),
      ];
      records.addAll(List.generate(
          3, (i) => _recordAgo(id: 'b', rate: 0.5, daysAgo: i + 4, source: 'feed')));
      final signal = UserBehaviorSignalCalculator.compute(
        records,
        now: _refNow,
        favoriteIds: <String>{'fav1'},
      );
      // fav1 是收藏 → 不在黑名单
      expect(signal.blacklist.contains('fav1'), false);
    });

    test('收藏项即使完播率 < 0.1 也不进入黑名单（豁免规则 2）', () {
      final records = [
        _recordAgo(id: 'fav1', rate: 0.05, daysAgo: 1, source: 'feed'),
      ];
      records.addAll(List.generate(
          4, (i) => _recordAgo(id: 'b', rate: 0.5, daysAgo: i + 2, source: 'feed')));
      final signal = UserBehaviorSignalCalculator.compute(
        records,
        now: _refNow,
        favoriteIds: <String>{'fav1'},
      );
      // fav1 是收藏 → 不在黑名单（即使 0.05 完播率）
      expect(signal.blacklist.contains('fav1'), false);
    });

    test('非收藏项仍正常进入黑名单', () {
      final records = [
        _recordAgo(id: 'bad1', rate: 0.1, daysAgo: 1, source: 'feed'),
        _recordAgo(id: 'bad1', rate: 0.15, daysAgo: 2, source: 'feed'),
        _recordAgo(id: 'bad1', rate: 0.18, daysAgo: 3, source: 'feed'),
      ];
      final favorites = <String>{'fav1'}; // bad1 不是收藏
      records.addAll(List.generate(
          3, (i) => _recordAgo(id: 'b', rate: 0.5, daysAgo: i + 4, source: 'feed')));
      final signal = UserBehaviorSignalCalculator.compute(
        records,
        now: _refNow,
        favoriteIds: favorites,
      );
      // bad1 不是收藏 → 进黑名单
      expect(signal.blacklist.contains('bad1'), true);
    });

    test('关闭完播率门控时仍保留 favoriteSeeds', () {
      final records = List.generate(
        10,
        (i) => _recordAgo(id: 'a', rate: 0.9, daysAgo: i + 1, source: 'nextUp'),
      );
      final favorites = <String>{'fav1'};
      final signal = UserBehaviorSignalCalculator.compute(
        records,
        now: _refNow,
        useWatchHistory: false, // 关闭门控
        favoriteIds: favorites,
      );
      // 即使关闭门控，favoriteSeeds 仍保留
      expect(signal.favoriteSeeds, contains('fav1'));
      // 其他信号为默认
      expect(signal.sourceWeights[RecommendSource.nextUp], 1.0);
    });

    test('冷启动时仍保留 favoriteSeeds', () {
      // 记录数 < 5（冷启动）
      final records = [
        _recordAgo(id: 'a', rate: 0.9, daysAgo: 1, source: 'nextUp'),
        _recordAgo(id: 'a', rate: 0.8, daysAgo: 2, source: 'nextUp'),
        _recordAgo(id: 'a', rate: 0.7, daysAgo: 3, source: 'nextUp'),
      ];
      final favorites = <String>{'fav1'};
      final signal = UserBehaviorSignalCalculator.compute(
        records,
        now: _refNow,
        favoriteIds: favorites,
      );
      // 冷启动：仍保留 favoriteSeeds
      expect(signal.favoriteSeeds, contains('fav1'));
      // strength = weak（默认信号）
      expect(signal.strength, SignalStrength.weak);
    });

    test('默认信号的 favoriteSeeds 为空', () {
      expect(UserBehaviorSignal.defaults.favoriteSeeds.isEmpty, true);
    });
  });
}
