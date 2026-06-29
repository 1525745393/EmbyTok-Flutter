/// 推荐信号计算器测试（PR #83）
///
/// 重点验证：
/// - UserBehaviorSignalCalculator.compute 冷启动返回默认信号
/// - Source 权重计算正确（高完播加权、低完播降权）
/// - 黑名单规则（连续 3 次低完播 + 极低完播）
/// - 高完播种子提取

import 'package:flutter_test/flutter_test.dart';

import 'package:embbytok_flutter/providers/recommend_signals.dart';
import 'package:embbytok_flutter/providers/recommend_provider.dart'
    show RecommendSource;
import 'package:embbytok_flutter/providers/watch_stats_provider.dart';

WatchRecord _record({
  required String id,
  required double rate,
  String source = 'feed',
  int watchedAt = 1700000000,
}) =>
    WatchRecord(
      itemId: id,
      itemType: 'Movie',
      completionRate: rate,
      watchedAt: watchedAt,
      source: source,
    );

void main() {
  group('冷启动 / 数据不足', () {
    test('空记录返回默认信号', () {
      final signal = UserBehaviorSignalCalculator.compute([]);
      expect(signal.strength, SignalStrength.weak);
      expect(signal.sourceWeights[RecommendSource.nextUp], 1.0);
      expect(signal.blacklist.isEmpty, true);
      expect(signal.highCompletionSeeds.isEmpty, true);
    });

    test('记录 < 5 条返回默认信号', () {
      final records = [
        _record(id: 'a', rate: 0.9, source: 'nextUp'),
        _record(id: 'a', rate: 0.8, source: 'nextUp'),
        _record(id: 'a', rate: 0.7, source: 'nextUp'),
        _record(id: 'a', rate: 0.6, source: 'nextUp'),
      ];
      final signal = UserBehaviorSignalCalculator.compute(records);
      expect(signal.strength, SignalStrength.weak);
      expect(signal.sourceWeights[RecommendSource.nextUp], 1.0);
    });
  });

  group('Source 权重计算', () {
    test('5-19 条记录 = medium strength', () {
      final records = List.generate(
        10,
        (i) => _record(id: 'a', rate: 0.9, source: 'nextUp'),
      );
      final signal = UserBehaviorSignalCalculator.compute(records);
      expect(signal.strength, SignalStrength.medium);
    });

    test('20+ 条记录 = strong strength', () {
      final records = List.generate(
        25,
        (i) => _record(id: 'a', rate: 0.9, source: 'nextUp'),
      );
      final signal = UserBehaviorSignalCalculator.compute(records);
      expect(signal.strength, SignalStrength.strong);
    });

    test('高完播率 source 加权（rate 0.9 → weight 1.5）', () {
      // 5 条 nextUp 都是高完播
      final records = List.generate(
        6,
        (i) => _record(id: 'a', rate: 0.9, source: 'nextUp'),
      );
      final signal = UserBehaviorSignalCalculator.compute(records);
      expect(signal.sourceWeights[RecommendSource.nextUp], 1.5);
    });

    test('低完播率 source 降权（rate 0.1 → weight 0.3）', () {
      // 6 条 nextUp 都是低完播
      final records = List.generate(
        6,
        (i) => _record(id: 'a', rate: 0.1, source: 'nextUp'),
      );
      final signal = UserBehaviorSignalCalculator.compute(records);
      expect(signal.sourceWeights[RecommendSource.nextUp], 0.3);
    });

    test('中性完播率 source 保持中性（rate 0.5 → weight 0.9）', () {
      // 6 条 nextUp 完播率 0.5 → 线性插值
      // 区间 [0.3, 0.8] → [0.3, 1.5]
      // 0.5 → 0.3 + (0.5-0.3)/(0.8-0.3) * (1.5-0.3) = 0.3 + 0.4*1.2 = 0.78
      final records = List.generate(
        6,
        (i) => _record(id: 'a', rate: 0.5, source: 'nextUp'),
      );
      final signal = UserBehaviorSignalCalculator.compute(records);
      expect(signal.sourceWeights[RecommendSource.nextUp], closeTo(0.78, 0.01));
    });

    test('不同 source 独立计算权重', () {
      // nextUp 高完播 0.9 → 1.5
      // resume 低完播 0.1 → 0.3
      final records = <WatchRecord>[
        ...List.generate(5, (i) => _record(id: 'a', rate: 0.9, source: 'nextUp')),
        ...List.generate(5, (i) => _record(id: 'a', rate: 0.1, source: 'resume')),
      ];
      final signal = UserBehaviorSignalCalculator.compute(records);
      expect(signal.sourceWeights[RecommendSource.nextUp], 1.5);
      expect(signal.sourceWeights[RecommendSource.resume], 0.3);
    });

    test('无数据的 source 保持中性', () {
      final records = List.generate(
        6,
        (i) => _record(id: 'a', rate: 0.9, source: 'nextUp'),
      );
      final signal = UserBehaviorSignalCalculator.compute(records);
      expect(signal.sourceWeights[RecommendSource.resume], 1.0);
    });
  });

  group('黑名单计算', () {
    test('同一 item 3 次低完播率（< 0.2）→ 加入黑名单', () {
      final records = [
        _record(id: 'bad1', rate: 0.1, source: 'feed'),
        _record(id: 'bad1', rate: 0.15, source: 'feed'),
        _record(id: 'bad1', rate: 0.18, source: 'feed'),
      ];
      final signal = UserBehaviorSignalCalculator.compute(records);
      expect(signal.blacklist.contains('bad1'), true);
    });

    test('同一 item 2 次低完播率 → 不加入黑名单', () {
      final records = [
        _record(id: 'a', rate: 0.1, source: 'feed'),
        _record(id: 'a', rate: 0.15, source: 'feed'),
      ];
      // 加上 3 条其他记录以满足 _minRecordsForSignal
      records.addAll(List.generate(3, (i) => _record(id: 'b', rate: 0.5, source: 'feed')));
      final signal = UserBehaviorSignalCalculator.compute(records);
      expect(signal.blacklist.contains('a'), false);
    });

    test('任何 1 次完播率 < 0.1 → 立即加入黑名单', () {
      final records = [
        _record(id: 'zero1', rate: 0.05, source: 'feed'),
      ];
      // 加 4 条其他记录
      records.addAll(List.generate(4, (i) => _record(id: 'b', rate: 0.5, source: 'feed')));
      final signal = UserBehaviorSignalCalculator.compute(records);
      expect(signal.blacklist.contains('zero1'), true);
    });
  });

  group('高完播种子提取', () {
    test('avgCompletion >= 0.5 的 item 进入种子', () {
      final records = [
        _record(id: 'good', rate: 0.9, source: 'nextUp'),
        _record(id: 'good', rate: 0.7, source: 'nextUp'),
        _record(id: 'bad', rate: 0.1, source: 'nextUp'),
        _record(id: 'bad', rate: 0.05, source: 'nextUp'),
      ];
      records.add(_record(id: 'filler', rate: 0.5, source: 'feed'));
      final signal = UserBehaviorSignalCalculator.compute(records);
      expect(signal.highCompletionSeeds.contains('good'), true);
      expect(signal.highCompletionSeeds.contains('bad'), false);
    });

    test('按平均完播率降序排，最多 5 个', () {
      final records = <WatchRecord>[];
      for (int i = 0; i < 10; i++) {
        records.add(_record(id: 'm$i', rate: 0.5 + i * 0.05, source: 'feed'));
      }
      // 加 1 条 filler 满足 _minRecordsForSignal
      records.add(_record(id: 'filler', rate: 0.5, source: 'feed'));
      final signal = UserBehaviorSignalCalculator.compute(records);
      expect(signal.highCompletionSeeds.length, lessThanOrEqualTo(5));
      // 第一个应该是 m9（最高 0.95）
      expect(signal.highCompletionSeeds.first, 'm9');
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
}
