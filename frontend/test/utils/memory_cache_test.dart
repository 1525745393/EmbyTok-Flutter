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
  });
}
