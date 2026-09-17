/// DislikedItemsNotifier 单元测试
///
/// 覆盖：dislike / removeDislike / 幂等 / 持久化恢复 / 损坏数据兜底

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/disliked_items_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DislikedItemsNotifier', () {
    test('dislike 添加到集合并去重', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(dislikedItemsProvider.notifier);
      // 等待异步 load 完成
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.dislike('item-1');
      await notifier.dislike('item-2');
      await notifier.dislike('item-1'); // 重复标记无副作用
      expect(container.read(dislikedItemsProvider), {'item-1', 'item-2'});
    });

    test('空 itemId 不写入', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(dislikedItemsProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.dislike('');
      expect(container.read(dislikedItemsProvider), isEmpty);
    });

    test('removeDislike 移除指定项', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(dislikedItemsProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.dislike('item-1');
      await notifier.dislike('item-2');
      await notifier.removeDislike('item-1');
      expect(container.read(dislikedItemsProvider), {'item-2'});
    });

    test('持久化：dislike 后重建容器可恢复', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      final notifier = container.read(dislikedItemsProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await notifier.dislike('item-persist');
      container.dispose();

      // 新容器：应从 SharedPreferences 恢复
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      container2.read(dislikedItemsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container2.read(dislikedItemsProvider), {'item-persist'});
    });

    test('损坏的持久化数据兜底为空集', () async {
      SharedPreferences.setMockInitialValues(
          {'disliked_item_ids': '{not-valid-json'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(dislikedItemsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(dislikedItemsProvider), isEmpty);
    });
  });
}
