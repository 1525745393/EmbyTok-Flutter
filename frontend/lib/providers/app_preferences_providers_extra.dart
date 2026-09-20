// 从 app_preferences_providers.dart 拆分（part 文件，无行为变化）

part of 'app_preferences_providers.dart';

class RecommendNextUpSeriesCountNotifier extends StateNotifier<int> {
  RecommendNextUpSeriesCountNotifier() : super(5) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.recommendNextUpSeriesCount;
  }

  Future<void> setCount(int count) async {
    final clamped = count.clamp(1, 10);
    state = clamped;
    final current = await const AppPreferencesService().load();
    await const AppPreferencesService()
        .save(current.copyWith(recommendNextUpSeriesCount: clamped));
  }
}

final recommendNextUpSeriesCountProvider =
    StateNotifierProvider<RecommendNextUpSeriesCountNotifier, int>(
  (ref) => RecommendNextUpSeriesCountNotifier(),
);

// 推荐 - 追剧：收藏演员新作品条数（默认 20，范围 [5,40]）
class RecommendFavActorNewCountNotifier extends StateNotifier<int> {
  RecommendFavActorNewCountNotifier() : super(20) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.recommendFavActorNewCount;
  }

  Future<void> setCount(int count) async {
    final clamped = count.clamp(5, 40);
    state = clamped;
    final current = await const AppPreferencesService().load();
    await const AppPreferencesService()
        .save(current.copyWith(recommendFavActorNewCount: clamped));
  }
}

final recommendFavActorNewCountProvider =
    StateNotifierProvider<RecommendFavActorNewCountNotifier, int>(
  (ref) => RecommendFavActorNewCountNotifier(),
);

// 关注页 - 每演员视频数（默认 3，范围 [1,10]）
class FollowActorVideoCountNotifier extends StateNotifier<int> {
  FollowActorVideoCountNotifier() : super(3) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.followActorVideoCount;
  }

  Future<void> setCount(int count) async {
    final clamped = count.clamp(1, 10);
    state = clamped;
    final current = await const AppPreferencesService().load();
    await const AppPreferencesService()
        .save(current.copyWith(followActorVideoCount: clamped));
  }
}

final followActorVideoCountProvider =
    StateNotifierProvider<FollowActorVideoCountNotifier, int>(
  (ref) => FollowActorVideoCountNotifier(),
);

// 关注页 - 只看未观看（默认 true）
class FollowOnlyUnwatchedNotifier extends StateNotifier<bool> {
  FollowOnlyUnwatchedNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.followOnlyUnwatched;
  }

  Future<void> setOnlyUnwatched(bool value) async {
    state = value;
    final current = await const AppPreferencesService().load();
    await const AppPreferencesService()
        .save(current.copyWith(followOnlyUnwatched: value));
  }
}

final followOnlyUnwatchedProvider =
    StateNotifierProvider<FollowOnlyUnwatchedNotifier, bool>(
  (ref) => FollowOnlyUnwatchedNotifier(),
);

// 推荐标签数据源映射（label → source key，默认一对一，用户可自定义）
class RecommendTagSourceMappingNotifier
    extends StateNotifier<Map<String, String>> {
  RecommendTagSourceMappingNotifier()
      : super(const {
          '最新影片': 'latest',
          '继续观看': 'resume',
          '为你推荐': 'suggestions',
          '精选': 'nativeRecommendations',
          '相似': 'similar',
          '高分': 'recommendations',
          '移动客户端推荐': 'localRecommend',
        }) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.recommendTagSourceMapping;
  }

  Future<void> setMapping(String label, String sourceKey) async {
    final updated = Map<String, String>.from(state)..[label] = sourceKey;
    state = updated;
    final current = await const AppPreferencesService().load();
    await const AppPreferencesService()
        .save(current.copyWith(recommendTagSourceMapping: updated));
  }

  Future<void> resetMapping() async {
    const defaults = <String, String>{
      '最新影片': 'latest',
      '继续观看': 'resume',
      '为你推荐': 'suggestions',
      '精选': 'nativeRecommendations',
      '相似': 'similar',
      '高分': 'recommendations',
      '移动客户端推荐': 'localRecommend',
    };
    state = defaults;
    final current = await const AppPreferencesService().load();
    await const AppPreferencesService()
        .save(current.copyWith(recommendTagSourceMapping: defaults));
  }
}

final recommendTagSourceMappingProvider = StateNotifierProvider<
    RecommendTagSourceMappingNotifier, Map<String, String>>(
  (ref) => RecommendTagSourceMappingNotifier(),
);

// PR #88：最近展示过的 itemId 列表（用于反推荐疲劳）
// - Set<String> 表示 itemId（对外接口不变）
// - 内部维护 _shownAtMap: Map<String, int> 记录 itemId → shownAt 时间戳（秒）
// - 持久化格式：List<String>，每项 "itemId:timestamp"
// - 最多保留 500 个（按 shownAt 升序 FIFO 清理）
// - 兼容旧格式：不含 ":" 视为 shownAt=0（始终过期，下次 cleanExpired 时清除）
class RecentlyShownItemIdsNotifier extends StateNotifier<Set<String>> {
  RecentlyShownItemIdsNotifier() : super(<String>{}) {
    _load();
  }

  // itemId → (shownAt 时间戳, entryOrder 添加序号)；与 state.keys 保持同步
  // entryOrder 用于在 shownAt 相同（同一秒内批量添加）时仍保证严格 FIFO
  final Map<String, ({int ts, int order})> _shownAtMap =
      <String, ({int ts, int order})>{};
  int _nextOrder = 0;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(kStorageKeyRecentlyShownItemIds) ??
        const <String>[];
    _shownAtMap.clear();
    int order = 0;
    for (final raw in list) {
      // 兼容旧格式：不含 ":" 视为 shownAt=0（始终过期，下次 cleanExpired 清除）
      final colonIdx = raw.lastIndexOf(':');
      if (colonIdx < 0) {
        _shownAtMap[raw] = (ts: 0, order: order++);
        continue;
      }
      final itemId = raw.substring(0, colonIdx);
      final ts = int.tryParse(raw.substring(colonIdx + 1));
      if (itemId.isEmpty || ts == null) continue;
      _shownAtMap[itemId] = (ts: ts, order: order++);
    }
    _nextOrder = order;
    state = _shownAtMap.keys.toSet();
  }

  Future<void> addAll(Iterable<String> itemIds) async {
    if (itemIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final id in itemIds) {
      _shownAtMap[id] = (ts: now, order: _nextOrder++);
    }
    // 容量限制 500，超过则按 (shownAt 升序, entryOrder 升序) 删除最早的（严格 FIFO）
    const int maxCount = 500;
    if (_shownAtMap.length > maxCount) {
      final sortedEntries = _shownAtMap.entries.toList()
        ..sort((a, b) {
          final cmp = a.value.ts.compareTo(b.value.ts);
          if (cmp != 0) return cmp;
          return a.value.order.compareTo(b.value.order);
        });
      final removeCount = _shownAtMap.length - maxCount;
      for (int i = 0; i < removeCount; i++) {
        _shownAtMap.remove(sortedEntries[i].key);
      }
    }
    state = _shownAtMap.keys.toSet();
    await _persist();
  }

  Future<void> clear() async {
    _shownAtMap.clear();
    _nextOrder = 0;
    state = <String>{};
    await _persist();
  }

  // PR #88 Task 2：清理超过指定天数的展示记录
  // now - shownAt > days * 86400 即视为过期
  Future<void> cleanExpired(int days) async {
    if (days <= 0 || _shownAtMap.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final threshold = days * 86400;
    final expiredKeys = <String>[];
    _shownAtMap.forEach((key, value) {
      if (now - value.ts > threshold) {
        expiredKeys.add(key);
      }
    });
    if (expiredKeys.isEmpty) return;
    for (final key in expiredKeys) {
      _shownAtMap.remove(key);
    }
    state = _shownAtMap.keys.toSet();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    // 持久化时按 order 排序，保证加载后列表顺序与写入一致（去重后仍 FIFO）
    final list = _shownAtMap.entries.toList()
      ..sort((a, b) => a.value.order.compareTo(b.value.order));
    final persisted =
        list.map((e) => '${e.key}:${e.value.ts}').toList(growable: false);
    await prefs.setStringList(kStorageKeyRecentlyShownItemIds, persisted);
  }
}

final recentlyShownItemIdsProvider =
    StateNotifierProvider<RecentlyShownItemIdsNotifier, Set<String>>(
  (ref) => RecentlyShownItemIdsNotifier(),
);

// PR #89：用户控制 - 用户评分加权开关
// - true（默认）：用户评分 < recommendUserRatingMin 的 item 跳过（除非收藏）
// - false：仅按 communityRating 过滤
class RecommendUserRatingEnabledNotifier extends StateNotifier<bool> {
  RecommendUserRatingEnabledNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.recommendUserRatingEnabled;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    final current = await const AppPreferencesService().load();
    await const AppPreferencesService().save(
      current.copyWith(recommendUserRatingEnabled: value),
    );
  }
}

final recommendUserRatingEnabledProvider =
    StateNotifierProvider<RecommendUserRatingEnabledNotifier, bool>(
  (ref) => RecommendUserRatingEnabledNotifier(),
);

// PR #89：用户控制 - 最低用户评分阈值（0-10，默认 4.0）
// - 范围 [0.0, 10.0]
// - 0 = 不过滤（仅按 communityRating）
class RecommendUserRatingMinNotifier extends StateNotifier<double> {
  RecommendUserRatingMinNotifier() : super(4.0) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.recommendUserRatingMin;
  }

  Future<void> setMin(double value) async {
    // 范围 [0, 10]
    final clamped = value.clamp(0.0, 10.0);
    state = clamped;
    final current = await const AppPreferencesService().load();
    await const AppPreferencesService().save(
      current.copyWith(recommendUserRatingMin: clamped),
    );
  }
}

final recommendUserRatingMinProvider =
    StateNotifierProvider<RecommendUserRatingMinNotifier, double>(
  (ref) => RecommendUserRatingMinNotifier(),
);

// ==================== 收藏夹类型筛选 ====================

/// 收藏夹显示的媒体类型（Movie/Series/BoxSet/Person 的子集）
class FavoriteIncludeTypesNotifier extends StateNotifier<Set<String>> {
  FavoriteIncludeTypesNotifier()
      : super(const <String>{
          'Movie',
          'Series',
          'BoxSet',
          'Person',
        }) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(kStorageKeyFavoriteIncludeTypes);
      if (list != null) {
        state = list.toSet();
      }
    } catch (_) {}
  }

  /// 切换某个类型
  Future<void> toggle(String type) async {
    final next = state.contains(type)
        ? (state.toSet()..remove(type))
        : (state.toSet()..add(type));
    // 至少保留一个类型
    if (next.isEmpty) {
      AppLogger.debug('收藏：类型偏好不能全空');
      return;
    }
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(kStorageKeyFavoriteIncludeTypes, next.toList());
    } catch (_) {}
  }
}

final favoriteIncludeTypesProvider =
    StateNotifierProvider<FavoriteIncludeTypesNotifier, Set<String>>(
  (ref) => FavoriteIncludeTypesNotifier(),
);
