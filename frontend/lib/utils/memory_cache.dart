// 内存缓存管理器：LRU 淘汰策略 + TTL 过期支持
//
// 设计目标：
// 1. 泛型支持，可缓存任意类型数据
// 2. LRU（最近最少使用）淘汰策略，限制最大内存占用
// 3. 支持 TTL（存活时间），自动过期
// 4. 纯内存实现，不依赖外部存储，速度快

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
class MemoryCache<T> {
  final int maxSize;

  final Map<String, _CacheEntry<T>> _cache = <String, _CacheEntry<T>>{};

  /// 按访问顺序排列的 key 列表（最近使用的在末尾）
  final List<String> _accessOrder = <String>[];

  MemoryCache({required this.maxSize});

  /// 获取缓存值
  ///
  /// 如果 key 不存在或已过期，返回 null。
  /// 访问时会刷新该条目的 LRU 顺序。
  T? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    // 已过期：移除并返回 null
    if (entry.isExpired) {
      _removeEntry(key);
      return null;
    }

    // 刷新访问顺序：移到末尾（最近使用）
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
    while (_cache.length >= maxSize && _accessOrder.isNotEmpty) {
      final oldestKey = _accessOrder.removeAt(0);
      _cache.remove(oldestKey);
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

  /// 清空所有缓存
  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }

  /// 当前缓存条目数量
  int get length => _cache.length;

  /// 检查 key 是否存在（未过期）
  bool containsKey(String key) {
    final entry = _cache[key];
    if (entry == null) return false;
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
