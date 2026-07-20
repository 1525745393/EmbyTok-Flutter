// 内存缓存管理器：LRU 淘汰策略 + TTL 过期支持 + 统计能力
//
// 设计目标：
// 1. 泛型支持，可缓存任意类型数据
// 2. LRU（最近最少使用）淘汰策略，限制最大内存占用
// 3. 支持 TTL（存活时间），自动过期
// 4. 纯内存实现，不依赖外部存储，速度快
// 5. 内置统计：命中率、淘汰数等，便于调优

/// 缓存统计信息
///
/// 记录缓存的运行时指标，用于性能分析和调优。
/// 统计数据是累计的，调用 [MemoryCache.resetStats] 可重置。
class CacheStats {
  /// 命中次数
  final int hitCount;

  /// 未命中次数
  final int missCount;

  /// 过期但仍有数据的命中次数（SWR stale hits）
  final int staleHitCount;

  /// 被淘汰的条目数（LRU 淘汰）
  final int evictionCount;

  /// 后台刷新触发次数（SWR）
  final int swrRefreshCount;

  const CacheStats({
    this.hitCount = 0,
    this.missCount = 0,
    this.staleHitCount = 0,
    this.evictionCount = 0,
    this.swrRefreshCount = 0,
  });

  /// 总请求数（命中 + 未命中）
  int get totalRequests => hitCount + missCount + staleHitCount;

  /// 命中率（0.0 ~ 1.0，stale 也算有效命中）
  ///
  /// 无请求时返回 0.0。
  double get hitRate {
    if (totalRequests == 0) return 0.0;
    return (hitCount + staleHitCount) / totalRequests;
  }

  CacheStats copyWith({
    int? hitCount,
    int? missCount,
    int? staleHitCount,
    int? evictionCount,
    int? swrRefreshCount,
  }) {
    return CacheStats(
      hitCount: hitCount ?? this.hitCount,
      missCount: missCount ?? this.missCount,
      staleHitCount: staleHitCount ?? this.staleHitCount,
      evictionCount: evictionCount ?? this.evictionCount,
      swrRefreshCount: swrRefreshCount ?? this.swrRefreshCount,
    );
  }
}

/// 单个缓存条目
class _CacheEntry<T> {
  final T value;
  final DateTime createdAt;
  final Duration? ttl;

  _CacheEntry(this.value, {this.ttl}) : createdAt = DateTime.now();

  /// 是否已过期
  bool get isExpired {
    if (ttl == null) return false;
    return DateTime.now().difference(createdAt) > ttl!;
  }
}

/// 内存缓存管理器
///
/// 使用 LRU（最近最少使用）策略管理缓存条目，
/// 当缓存数量超过 [maxSize] 时自动淘汰最久未访问的条目。
/// 支持可选的 TTL（存活时间），过期条目自动失效。
///
/// 内置统计功能，可通过 [stats] 获取命中率、淘汰数等指标。
class MemoryCache<T> {
  final int maxSize;

  final Map<String, _CacheEntry<T>> _cache = <String, _CacheEntry<T>>{};

  /// 按访问顺序排列的 key 列表（最近使用的在末尾）
  final List<String> _accessOrder = <String>[];

  CacheStats _stats = const CacheStats();

  MemoryCache({required this.maxSize});

  /// 当前缓存统计信息
  CacheStats get stats => _stats;

  /// 重置统计数据
  void resetStats() {
    _stats = const CacheStats();
  }

  /// 记录一次命中
  void _recordHit() {
    _stats = _stats.copyWith(hitCount: _stats.hitCount + 1);
  }

  /// 记录一次未命中
  void _recordMiss() {
    _stats = _stats.copyWith(missCount: _stats.missCount + 1);
  }

  /// 记录一次过期命中（SWR stale hit）
  void _recordStaleHit() {
    _stats = _stats.copyWith(staleHitCount: _stats.staleHitCount + 1);
  }

  /// 记录一次 SWR 后台刷新
  void recordSwrRefresh() {
    _stats = _stats.copyWith(swrRefreshCount: _stats.swrRefreshCount + 1);
  }

  /// 记录一次淘汰
  void _recordEviction(int count) {
    if (count <= 0) return;
    _stats = _stats.copyWith(evictionCount: _stats.evictionCount + count);
  }

  /// 获取缓存值
  ///
  /// 如果 key 不存在或已过期，返回 null。
  /// 访问时会刷新该条目的 LRU 顺序。
  T? get(String key) {
    final entry = _cache[key];
    if (entry == null) {
      _recordMiss();
      return null;
    }

    // 已过期：不移除（留给 getStale），返回 null
    if (entry.isExpired) {
      _recordMiss();
      return null;
    }

    _recordHit();

    // 刷新访问顺序：移到末尾（最近使用）
    _accessOrder.remove(key);
    _accessOrder.add(key);

    return entry.value;
  }

  /// 获取缓存值（包括已过期的）

  /// 检查指定 key 是否已过期（不影响 LRU 顺序或统计）
  bool isExpired(String key) {
    final entry = _cache[key];
    if (entry == null) return false;
    return entry.isExpired;
  }

  /// 与 [get] 不同，即使条目已过期也会返回（用于 SWR 模式）。
  ///
  /// 与 [get] 不同，即使条目已过期也会返回（用于 SWR 模式）。
  /// 仅在 key 完全不存在时返回 null。
  /// 访问时会刷新 LRU 顺序。
  T? getStale(String key) {
    final entry = _cache[key];
    if (entry == null) {
      _recordMiss();
      return null;
    }

    // 已过期：仍返回数据，记录为 stale hit
    if (entry.isExpired) {
      _recordStaleHit();
    } else {
      _recordHit();
    }

    // 刷新访问顺序
    _accessOrder.remove(key);
    _accessOrder.add(key);

    return entry.value;
  }

  /// 设置缓存值
  ///
  /// [ttl] 为可选的存活时间，过期后自动失效。
  /// 如果 key 已存在，更新值并刷新访问顺序。
  /// 如果超过 [maxSize]，淘汰最久未使用的条目。
  void set(String key, T value, {Duration? ttl}) {
    if (maxSize <= 0) return;

    // 已存在：更新值并刷新顺序
    if (_cache.containsKey(key)) {
      _cache[key] = _CacheEntry<T>(value, ttl: ttl);
      _accessOrder.remove(key);
      _accessOrder.add(key);
      return;
    }

    // 容量检查：先清理过期条目，释放空间
    _cleanExpired();

    // 如果还是满了，淘汰最久未使用的
    int evicted = 0;
    while (_cache.length >= maxSize && _accessOrder.isNotEmpty) {
      final oldestKey = _accessOrder.removeAt(0);
      _cache.remove(oldestKey);
      evicted++;
    }
    if (evicted > 0) {
      _recordEviction(evicted);
    }

    // 容量检查（可能 maxSize=0 或全部过期后仍不满足）
    if (_cache.length >= maxSize) return;

    _cache[key] = _CacheEntry<T>(value, ttl: ttl);
    _accessOrder.add(key);
  }

  /// 删除指定缓存条目
  void delete(String key) {
    _removeEntry(key);
  }

  /// 删除所有以 [prefix] 开头的缓存条目
  ///
  /// 用于批量失效某一类缓存（如某个媒体库的所有分页数据）。
  void deleteWherePrefix(String prefix) {
    final keysToDelete = <String>[];
    for (final key in _cache.keys) {
      if (key.startsWith(prefix)) {
        keysToDelete.add(key);
      }
    }
    for (final key in keysToDelete) {
      _removeEntry(key);
    }
  }

  /// 清空所有缓存
  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }

  /// 当前缓存条目数量
  int get length => _cache.length;

  /// 检查 key 是否存在（未过期）
  /// 注意：纯存在性检查，不记录命中/未命中统计，统计仅在 get() 时累计
  bool containsKey(String key) {
    final entry = _cache[key];
    if (entry == null) {
      return false;
    }
    if (entry.isExpired) {
      _removeEntry(key);
      return false;
    }
    return true;
  }

  /// 移除单个条目（同时从 cache 和 accessOrder 中删除）
  void _removeEntry(String key) {
    _cache.remove(key);
    _accessOrder.remove(key);
  }

  /// 清理所有已过期的条目
  void _cleanExpired() {
    final expiredKeys = <String>[];
    for (final entry in _cache.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }
    for (final key in expiredKeys) {
      _removeEntry(key);
    }
  }
}
