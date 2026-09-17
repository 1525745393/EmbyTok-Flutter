/// VideoCommentsNotifier 单元测试
///
/// 覆盖：addComment / removeComment / 计数 / 空文本过滤 / 持久化恢复 / 损坏数据兜底

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/video_comments_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoCommentsNotifier', () {
    test('addComment 新增评论（新评论在前）并计数', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(videoCommentsProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.addComment('item-1', '第一条');
      await notifier.addComment('item-1', '第二条');
      await notifier.addComment('item-2', '其他视频');

      final comments1 = notifier.commentsFor('item-1');
      expect(comments1.length, 2);
      expect(comments1.first.text, '第二条', reason: '新评论在前');
      expect(notifier.countFor('item-1'), 2);
      expect(notifier.countFor('item-2'), 1);
      expect(notifier.countFor('item-none'), 0);
    });

    test('空文本 / 纯空白 / 空 itemId 不写入', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(videoCommentsProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.addComment('item-1', '   ');
      await notifier.addComment('', '内容');
      expect(notifier.countFor('item-1'), 0);
    });

    test('评论文本自动 trim', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(videoCommentsProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.addComment('item-1', '  好片  ');
      expect(notifier.commentsFor('item-1').single.text, '好片');
    });

    test('removeComment 删除指定评论；删空后清理条目', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(videoCommentsProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.addComment('item-1', '第一条');
      await notifier.addComment('item-1', '第二条');
      final firstId = notifier.commentsFor('item-1').first.id;
      await notifier.removeComment('item-1', firstId);
      expect(notifier.countFor('item-1'), 1);

      final restId = notifier.commentsFor('item-1').first.id;
      await notifier.removeComment('item-1', restId);
      expect(notifier.countFor('item-1'), 0);
      expect(container.read(videoCommentsProvider).containsKey('item-1'),
          isFalse, reason: '删空后不应残留空条目');
    });

    test('removeComment 不存在的 id 无副作用', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(videoCommentsProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.addComment('item-1', '第一条');
      await notifier.removeComment('item-1', 'not-exist');
      expect(notifier.countFor('item-1'), 1);
    });

    test('持久化：写入后重建容器可恢复', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      final notifier = container.read(videoCommentsProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await notifier.addComment('item-1', '持久化评论');
      container.dispose();

      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      container2.read(videoCommentsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final restored = container2.read(videoCommentsProvider);
      expect(restored['item-1']?.single.text, '持久化评论');
    });

    test('并发 add/remove 串行落盘：最终状态完整（写串行化）', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(videoCommentsProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 不 await 地并发发起：add A、add B、remove A
      final f1 = notifier.addComment('item-1', 'A');
      final f2 = notifier.addComment('item-1', 'B');
      // 等前两个 add 的 state 变更生效后再移除 A（模拟用户并发操作）
      await Future<void>.delayed(const Duration(milliseconds: 5));
      // 新评论在前：A 在列表末尾，显式移除 A
      final f3 = notifier.removeComment('item-1',
          notifier.commentsFor('item-1').last.id);
      await Future.wait([f1, f2, f3]);

      // 内存状态：A 被移除、B 保留
      final texts = notifier
          .commentsFor('item-1')
          .map((c) => c.text)
          .toList();
      expect(texts, ['B']);

      // 重建容器：持久化结果与内存一致（未被后写覆盖丢数据）
      container.dispose();
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      container2.read(videoCommentsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final restored = container2.read(videoCommentsProvider);
      final restoredTexts =
          (restored['item-1'] ?? const []).map((c) => c.text).toList();
      expect(restoredTexts, ['B']);
    });

    test('损坏的持久化数据兜底为空表', () async {
      SharedPreferences.setMockInitialValues(
          {'video_local_comments_v1': '[broken'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(videoCommentsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(videoCommentsProvider), isEmpty);
    });
  });
}
