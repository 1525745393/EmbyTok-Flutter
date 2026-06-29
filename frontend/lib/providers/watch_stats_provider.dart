// 完播率统计 Provider
//
// 背景（PR #81）：
// 推荐规则需要"用户真实反馈信号"才能不断优化。
// 仅靠"是否完整观看"（userData.played）太粗粒度——
// 用户跳过 5 分钟短视频 vs 看完整 2 小时电影，userData 都是 played=true。
// 完播率（playbackPosition / runtime）能反映"用户对内容感兴趣程度"。
//
// 用途：
// 1. 设置页展示用户观看统计（总次数、平均完播率、最近 7 天趋势）
// 2. 未来可接入推荐打分：完播率高的相似 source，下次推荐加权
//
// 数据流：
// - VideoPageItem 视频完播 / dispose 时回调 recordWatch()
// - Provider 写入 SharedPreferences（按 userId 分键，最多保留 500 条）
// - 设置页读 provider 展示统计

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';

/// 单次观看记录
class WatchRecord {
  final String itemId; // 视频 ID
  final String itemType; // Movie/Episode/...
  final String? itemTitle; // 标题（仅用于设置页展示最近 10 条）
  final double completionRate; // 完播率 [0.0, 1.0]
  final int watchedAt; // unix 时间戳（秒）
  final String source; // 数据源 key（nextUp/resume/suggestions/similar/recommendations/feed）

  const WatchRecord({
    required this.itemId,
    required this.itemType,
    required this.completionRate,
    required this.watchedAt,
    this.itemTitle,
    this.source = 'feed',
  });

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'itemType': itemType,
        'itemTitle': itemTitle,
        'completionRate': completionRate,
        'watchedAt': watchedAt,
        'source': source,
      };

  factory WatchRecord.fromJson(Map<String, dynamic> json) => WatchRecord(
        itemId: json['itemId'] as String? ?? '',
        itemType: json['itemType'] as String? ?? 'Movie',
        itemTitle: json['itemTitle'] as String?,
        completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0.0,
        watchedAt: json['watchedAt'] as int? ?? 0,
        source: json['source'] as String? ?? 'feed',
      );
}

/// 完播率统计状态
class WatchStatsState {
  // 最近 N 条观看记录（按时间倒序）
  final List<WatchRecord> records;
  // 总观看次数
  final int totalCount;
  // 平均完播率（0.0-1.0）
  final double avgCompletion;
  // 最近 7 天观看次数
  final int last7DaysCount;
  // 最近 7 天平均完播率
  final double last7DaysAvgCompletion;

  const WatchStatsState({
    this.records = const [],
    this.totalCount = 0,
    this.avgCompletion = 0.0,
    this.last7DaysCount = 0,
    this.last7DaysAvgCompletion = 0.0,
  });

  WatchStatsState copyWith({
    List<WatchRecord>? records,
  }) {
    final list = records ?? this.records;
    final total = list.length;
    final avg = total == 0
        ? 0.0
        : list.fold<double>(0.0, (sum, r) => sum + r.completionRate) / total;
    // 最近 7 天
    final cutoff = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 7 * 24 * 3600;
    final last7 = list.where((r) => r.watchedAt >= cutoff).toList();
    final last7Avg = last7.isEmpty
        ? 0.0
        : last7.fold<double>(0.0, (sum, r) => sum + r.completionRate) /
            last7.length;
    return WatchStatsState(
      records: list,
      totalCount: total,
      avgCompletion: avg,
      last7DaysCount: last7.length,
      last7DaysAvgCompletion: last7Avg,
    );
  }
}

/// 完播率统计 Notifier
class WatchStatsNotifier extends StateNotifier<WatchStatsState> {
  WatchStatsNotifier(this._ref) : super(const WatchStatsState()) {
    // 初始化时从本地读
    _init();
  }

  final Ref _ref;

  // PR #81：最多保留 500 条（防止 SharedPreferences 过大）
  static const int _maxRecords = 500;

  // PR #81：完播率过滤阈值
  // - < 0.05（5 秒以下）视为无意义，不记录
  static const double _minCompletionToRecord = 0.05;

  Future<void> _init() async {
    try {
      final auth = _ref.read(authProvider);
      if (auth.user?.id == null) return;
      final cacheKey = '$kStorageKeyWatchStats:${auth.user!.id}';

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = json.decode(raw);
      if (decoded is! List) return;
      final records = decoded
          .whereType<Map<String, dynamic>>()
          .map(WatchRecord.fromJson)
          .toList();
      // 按时间倒序
      records.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
      state = state.copyWith(records: records);
      AppLogger.debug('完播率统计：加载本地', data: {'count': records.length});
    } catch (e) {
      AppLogger.debug('完播率统计：读本地失败', data: {'error': e.toString()});
    }
  }

  /// PR #81：记录一次观看
  /// - completionRate: 0.0-1.0
  /// - 低于 _minCompletionToRecord 不记录（无效观看）
  /// - source: 数据源 key（nextUp/resume/.../feed）
  void recordWatch({
    required String itemId,
    required String itemType,
    String? itemTitle,
    required double completionRate,
    String source = 'feed',
  }) {
    if (completionRate < _minCompletionToRecord) {
      AppLogger.debug('完播率统计：跳过（太低）', data: {
        'itemId': itemId,
        'rate': completionRate,
      });
      return;
    }
    if (completionRate > 1.0) completionRate = 1.0;

    final record = WatchRecord(
      itemId: itemId,
      itemType: itemType,
      itemTitle: itemTitle,
      completionRate: completionRate,
      watchedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      source: source,
    );

    // 插入到头部 + 截断
    final newList = [record, ...state.records];
    if (newList.length > _maxRecords) {
      newList.removeRange(_maxRecords, newList.length);
    }
    state = state.copyWith(records: newList);

    AppLogger.debug('完播率统计：记录', data: {
      'itemId': itemId,
      'rate': completionRate.toStringAsFixed(2),
      'source': source,
    });

    // 异步持久化（不阻塞）
    unawaited(_saveToCache(newList));
  }

  /// 清除所有记录
  Future<void> clear() async {
    state = const WatchStatsState();
    try {
      final auth = _ref.read(authProvider);
      if (auth.user?.id == null) return;
      final cacheKey = '$kStorageKeyWatchStats:${auth.user!.id}';
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(cacheKey);
      AppLogger.info('完播率统计：已清除');
    } catch (e) {
      AppLogger.debug('完播率统计：清除失败', data: {'error': e.toString()});
    }
  }

  Future<void> _saveToCache(List<WatchRecord> records) async {
    try {
      final auth = _ref.read(authProvider);
      if (auth.user?.id == null) return;
      final cacheKey = '$kStorageKeyWatchStats:${auth.user!.id}';
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(records.map((r) => r.toJson()).toList());
      await prefs.setString(cacheKey, encoded);
    } catch (e) {
      AppLogger.debug('完播率统计：写本地失败', data: {'error': e.toString()});
    }
  }
}

/// 完播率统计 Provider
final watchStatsProvider =
    StateNotifierProvider<WatchStatsNotifier, WatchStatsState>(
  (ref) => WatchStatsNotifier(ref),
);
