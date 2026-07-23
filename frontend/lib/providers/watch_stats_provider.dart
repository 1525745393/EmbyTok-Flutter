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
// - VideoPageItem 视频完播 / deactivate 时回调 recordWatch()
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

  /// 全量替换记录并重算统计（单次遍历，无中间列表分配）
  /// 用于 _loadForUser 批量加载场景
  WatchStatsState copyWith({
    List<WatchRecord>? records,
  }) {
    final list = records ?? this.records;
    final total = list.length;
    // 单次遍历同时累加全量和 7 天统计，避免 where+toList 产生的中间列表
    double sumAll = 0.0;
    int last7Count = 0;
    double last7Sum = 0.0;
    final cutoff = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 7 * 24 * 3600;
    for (final r in list) {
      sumAll += r.completionRate;
      if (r.watchedAt >= cutoff) {
        last7Count++;
        last7Sum += r.completionRate;
      }
    }
    return WatchStatsState(
      records: list,
      totalCount: total,
      avgCompletion: total == 0 ? 0.0 : sumAll / total,
      last7DaysCount: last7Count,
      last7DaysAvgCompletion: last7Count == 0 ? 0.0 : last7Sum / last7Count,
    );
  }

  /// 增量更新：添加单条记录后计算新统计
  /// totalCount / avgCompletion 用增量公式 O(1)
  /// 7 天统计因时间窗口漂移仍需遍历，但可利用时间倒序提前终止
  ///
  /// 前置条件：records 必须按 watchedAt 倒序排列（新记录在前）。
  /// 当前由 _loadForUser 的 sort + 本方法 [record, ...records] 保证。
  WatchStatsState addRecord(WatchRecord record, {int maxRecords = 500}) {
    final newList = [record, ...records];
    // 截断超出上限的旧记录（列表尾部，时间最久远）
    int removedCount = 0;
    double removedSum = 0.0;
    if (newList.length > maxRecords) {
      final removed = newList.sublist(maxRecords);
      removedCount = removed.length;
      for (final r in removed) {
        removedSum += r.completionRate;
      }
      newList.removeRange(maxRecords, newList.length);
    }
    // 增量计算全量统计
    final oldSum = avgCompletion * totalCount;
    final newTotal = totalCount + 1 - removedCount;
    final newSum = oldSum + record.completionRate - removedSum;
    // 7 天统计：单次遍历（时间窗口会漂移，无法纯增量）
    final cutoff = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 7 * 24 * 3600;
    int last7Count = 0;
    double last7Sum = 0.0;
    for (final r in newList) {
      if (r.watchedAt < cutoff) break; // 时间倒序，遇到旧记录可提前终止
      last7Count++;
      last7Sum += r.completionRate;
    }
    return WatchStatsState(
      records: newList,
      totalCount: newTotal,
      avgCompletion: newTotal > 0 ? newSum / newTotal : 0.0,
      last7DaysCount: last7Count,
      last7DaysAvgCompletion: last7Count > 0 ? last7Sum / last7Count : 0.0,
    );
  }
}

/// 完播率统计 Notifier
class WatchStatsNotifier extends StateNotifier<WatchStatsState> {
  WatchStatsNotifier(this._ref) : super(const WatchStatsState()) {
    // 初始化时从本地读
    _init();
    // 监听认证状态变化：登录 → 加载对应用户数据；登出 → 清空内存
    _authSubscription = _ref.listen<AuthState>(authProvider, (previous, next) {
      final prevId = previous?.user?.id;
      final currId = next.user?.id;
      if (prevId != currId) {
        // 用户 ID 变化（登出/切换用户）：重置内存 state
        state = const WatchStatsState();
        if (currId != null) {
          // 新用户登录：加载其数据
          _loadForUser(currId);
        }
      }
    });
  }

  final Ref _ref;
  ProviderSubscription<AuthState>? _authSubscription;

  // PR #81：最多保留 500 条（防止 SharedPreferences 过大）
  static const int _maxRecords = 500;

  // PR #81：完播率过滤阈值
  // - < 0.05（5 秒以下）视为无意义，不记录
  static const double _minCompletionToRecord = 0.05;

  Future<void> _init() async {
    try {
      final auth = _ref.read(authProvider);
      final userId = auth.user?.id;
      if (userId == null) return;
      await _loadForUser(userId);
    } catch (e) {
      AppLogger.debug('完播率统计：初始化失败', data: {'error': e.toString()});
    }
  }

  /// 从本地加载指定用户的完播率记录
  Future<void> _loadForUser(String userId) async {
    try {
      final cacheKey = '$kStorageKeyWatchStats:$userId';
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

  @override
  void dispose() {
    _authSubscription?.close();
    super.dispose();
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

    // 使用增量计算替代 copyWith 全量重算
    state = state.addRecord(record, maxRecords: _maxRecords);

    AppLogger.debug('完播率统计：记录', data: {
      'itemId': itemId,
      'rate': completionRate.toStringAsFixed(2),
      'source': source,
    });

    // 异步持久化（不阻塞）
    unawaited(_saveToCache(state.records));
  }

  /// 清除所有记录
  Future<void> clear() async {
    state = const WatchStatsState();
    try {
      final auth = _ref.read(authProvider);
      final userId = auth.user?.id;
      if (userId == null) return;
      final cacheKey = '$kStorageKeyWatchStats:$userId';
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
      final userId = auth.user?.id;
      if (userId == null) return;
      final cacheKey = '$kStorageKeyWatchStats:$userId';
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
