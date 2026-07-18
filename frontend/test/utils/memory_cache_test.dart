// 内存缓存管理器测试：验证 LRU 淘汰、TTL 过期、基本读写操作

import 'package:flutter_test/flutter_test.dart';

import 'package:embbytok_flutter/utils/memory_cache.dart';

void main() {
  group('MemoryCache', () {
    late MemoryCache<String> cache;

    setUp(() {
      cache = MemoryCache<String>(maxSize: 3);
    });

    test('基本读写：set 后 get 能获取到相同值', () {
      cache.set('key1', 'value1');
      expect(cache.get('key1'), 'value1');
    });

    test('不存在的 key 返回 null', () {
      expect(cache.get('nonexistent'), isNull);
    });

    test('覆盖已存在的 key 会更新值', () {
      cache.set('key1', 'old');
      cache.set('key1', 'new');
      expect(cache.get('key1'), 'new');
    });

    test('LRU 淘汰：超过 maxSize 时淘汰最久未使用的条目', () {
      cache.set('a', '1');
      cache.set('b', '2');
      cache.set('c', '3');

      // 访问 a，让 b 成为最久未使用
      cache.get('a');

      // 插入 d，应淘汰 b
      cache.set('d', '4');

      expect(cache.get('a'), '1');
      expect(cache.get('b'), isNull);
      expect(cache.get('c'), '3');
      expect(cache.get('d'), '4');
    });

    test('set 更新已有条目会刷新访问顺序', () {
      cache.set('a', '1');
      cache.set('b', '2');
      cache.set('c', '3');

      // 更新 a，让 a 变成最近使用
      cache.set('a', '1-updated');

      // 插入 d，应淘汰 b（最久未使用）
      cache.set('d', '4');

      expect(cache.get('a'), '1-updated');
      expect(cache.get('b'), isNull);
      expect(cache.get('c'), '3');
      expect(cache.get('d'), '4');
    });

    test('TTL 过期：已过期的条目返回 null', () async {
      cache.set('key1', 'value1', ttl: const Duration(milliseconds: 50));
      expect(cache.get('key1'), 'value1');

      await Future.delayed(const Duration(milliseconds: 100));

      expect(cache.get('key1'), isNull);
    });

    test('TTL 过期后条目会被从缓存中移除（不占用容量）', () async {
      cache = MemoryCache<String>(maxSize: 2);

      cache.set('a', '1', ttl: const Duration(milliseconds: 50));
      cache.set('b', '2');

      await Future.delayed(const Duration(milliseconds: 100));

      // a 已过期，现在缓存只有 1 个有效条目
      // 再插入 2 个新条目应该都能放进去
      cache.set('c', '3');
      cache.set('d', '4');

      expect(cache.get('a'), isNull);
      expect(cache.get('b'), '2');
      expect(cache.get('c'), '3');
      expect(cache.get('d'), '4');
    });

    test('delete 移除指定条目', () {
      cache.set('key1', 'value1');
      cache.delete('key1');
      expect(cache.get('key1'), isNull);
    });

    test('delete 不存在的 key 不报错', () {
      expect(() => cache.delete('nonexistent'), returnsNormally);
    });

    test('clear 清空所有条目', () {
      cache.set('a', '1');
      cache.set('b', '2');
      cache.clear();

      expect(cache.get('a'), isNull);
      expect(cache.get('b'), isNull);
    });

    test('length 返回当前缓存条目数', () {
      expect(cache.length, 0);

      cache.set('a', '1');
      expect(cache.length, 1);

      cache.set('b', '2');
      expect(cache.length, 2);

      cache.delete('a');
      expect(cache.length, 1);

      cache.clear();
      expect(cache.length, 0);
    });

    test('containsKey 检查 key 是否存在', () {
      expect(cache.containsKey('a'), false);

      cache.set('a', '1');
      expect(cache.containsKey('a'), true);

      cache.delete('a');
      expect(cache.containsKey('a'), false);
    });

    test('maxSize 为 0 时不缓存任何内容', () {
      cache = MemoryCache<String>(maxSize: 0);
      cache.set('a', '1');
      expect(cache.get('a'), isNull);
      expect(cache.length, 0);
    });

    test('deleteWherePrefix：删除所有匹配前缀的条目', () {
      cache.set('user:1', 'Alice');
      cache.set('user:2', 'Bob');
      cache.set('movie:1', 'Inception');
      cache.set('movie:2', 'Avatar');

      cache.deleteWherePrefix('user:');

      expect(cache.get('user:1'), isNull);
      expect(cache.get('user:2'), isNull);
      expect(cache.get('movie:1'), 'Inception');
      expect(cache.get('movie:2'), 'Avatar');
      expect(cache.length, 2);
    });

    test('deleteWherePrefix：无前缀匹配时不删除任何内容', () {
      cache.set('a', '1');
      cache.set('b', '2');

      cache.deleteWherePrefix('nonexistent:');

      expect(cache.length, 2);
      expect(cache.get('a'), '1');
      expect(cache.get('b'), '2');
    });

    test('deleteWherePrefix：空前缀删除所有条目', () {
      cache.set('a', '1');
      cache.set('b', '2');
      cache.set('c', '3');

      cache.deleteWherePrefix('');

      expect(cache.length, 0);
    });

    test('containsKey：已过期的条目返回 false 并被移除', () async {
      cache.set('key1', 'value1', ttl: const Duration(milliseconds: 50));
      expect(cache.containsKey('key1'), true);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(cache.containsKey('key1'), false);
      expect(cache.length, 0);
    });

    test('LRU：连续访问不会导致条目重复', () {
      cache.set('a', '1');
      cache.set('b', '2');
      cache.set('c', '3');

      // 多次访问同一个 key
      cache.get('a');
      cache.get('a');
      cache.get('a');

      // 插入 d，应淘汰 b（最久未使用）
      cache.set('d', '4');

      expect(cache.get('a'), '1');
      expect(cache.get('b'), isNull);
      expect(cache.get('c'), '3');
      expect(cache.get('d'), '4');
      expect(cache.length, 3);
    });

    test('maxSize 为 1 时正常工作', () {
      cache = MemoryCache<String>(maxSize: 1);

      cache.set('a', '1');
      expect(cache.get('a'), '1');
      expect(cache.length, 1);

      cache.set('b', '2');
      expect(cache.get('a'), isNull);
      expect(cache.get('b'), '2');
      expect(cache.length, 1);
    });

    test('set 相同 key 不增加缓存数量', () {
      cache.set('a', '1');
      cache.set('a', '2');
      cache.set('a', '3');

      expect(cache.length, 1);
      expect(cache.get('a'), '3');
    });

    test('TTL：无 TTL 的条目永不过期', () async {
      cache.set('key1', 'value1'); // 无 TTL

      await Future.delayed(const Duration(milliseconds: 50));

      expect(cache.get('key1'), 'value1');
    });

    test('TTL：过期后再 set 可以重新缓存', () async {
      cache.set('key1', 'value1', ttl: const Duration(milliseconds: 50));

      await Future.delayed(const Duration(milliseconds: 100));
      expect(cache.get('key1'), isNull);

      cache.set('key1', 'value2', ttl: const Duration(milliseconds: 50));
      expect(cache.get('key1'), 'value2');
    });

    group('缓存统计', () {
      setUp(() {
        cache = MemoryCache<String>(maxSize: 10);
      });

      test('初始状态：命中和未命中均为 0', () {
        final stats = cache.stats;
        expect(stats.hitCount, 0);
        expect(stats.missCount, 0);
        expect(stats.hitRate, 0.0);
      });

      test('get 命中：hitCount 递增', () {
        cache.set('a', '1');

        cache.get('a'); // 命中
        cache.get('a'); // 再次命中

        final stats = cache.stats;
        expect(stats.hitCount, 2);
        expect(stats.missCount, 0);
        expect(stats.hitRate, 1.0);
      });

      test('get 未命中：missCount 递增', () {
        cache.get('nonexistent'); // 未命中
        cache.get('nonexistent2'); // 再次未命中

        final stats = cache.stats;
        expect(stats.hitCount, 0);
        expect(stats.missCount, 2);
        expect(stats.hitRate, 0.0);
      });

      test('混合命中和未命中：命中率正确计算', () {
        cache.set('a', '1');
        cache.set('b', '2');

        cache.get('a'); // 命中
        cache.get('missing'); // 未命中
        cache.get('b'); // 命中
        cache.get('missing2'); // 未命中
        cache.get('a'); // 命中

        final stats = cache.stats;
        expect(stats.hitCount, 3);
        expect(stats.missCount, 2);
        expect(stats.totalRequests, 5);
        // 3/5 = 0.6
        expect(stats.hitRate, closeTo(0.6, 0.001));
      });

      test('TTL 过期的 get 算作未命中', () async {
        cache.set('key1', 'value1', ttl: const Duration(milliseconds: 50));

        cache.get('key1'); // 命中

        await Future.delayed(const Duration(milliseconds: 100));

        cache.get('key1'); // 已过期，算作未命中

        final stats = cache.stats;
        expect(stats.hitCount, 1);
        expect(stats.missCount, 1);
      });

      test('resetStats：重置统计数据', () {
        cache.set('a', '1');
        cache.get('a');
        cache.get('missing');

        cache.resetStats();

        final stats = cache.stats;
        expect(stats.hitCount, 0);
        expect(stats.missCount, 0);
        expect(stats.hitRate, 0.0);
      });

      test('containsKey 命中/未命中也计入统计', () {
        cache.set('a', '1');

        cache.containsKey('a'); // 命中
        cache.containsKey('missing'); // 未命中

        final stats = cache.stats;
        expect(stats.hitCount, 1);
        expect(stats.missCount, 1);
      });

      test('evictionCount：记录被淘汰的条目数', () {
        cache = MemoryCache<String>(maxSize: 2);

        cache.set('a', '1');
        cache.set('b', '2');
        cache.set('c', '3'); // 淘汰 a

        final stats = cache.stats;
        expect(stats.evictionCount, 1);
      });

      test('多次淘汰：evictionCount 累计', () {
        cache = MemoryCache<String>(maxSize: 2);

        cache.set('a', '1');
        cache.set('b', '2');
        cache.set('c', '3'); // 淘汰 a
        cache.set('d', '4'); // 淘汰 b

        final stats = cache.stats;
        expect(stats.evictionCount, 2);
      });

      test('clear：不重置统计（统计是累计的）', () {
        cache.set('a', '1');
        cache.get('a');

        cache.clear();

        final stats = cache.stats;
        expect(stats.hitCount, 1); // 统计保留
        expect(cache.length, 0); // 数据清空
      });
    });
  });
}
