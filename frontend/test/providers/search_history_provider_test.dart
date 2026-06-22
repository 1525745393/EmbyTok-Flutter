/// SearchHistoryNotifier 测试
///
/// 重点验证：
/// - 添加搜索词（去重 + 按时间排序）
/// - 删除搜索词
/// - 清空搜索历史
/// - 不超过 kMaxSearchHistory 条记录
/// - 持久化到 SharedPreferences

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embbytok_flutter/providers/search_history_provider.dart';
import 'package:embbytok_flutter/utils/constants.dart';

void main() {
  group('SearchHistoryNotifier', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初始状态为空列表', () {
      final state = container.read(searchHistoryProvider);
      expect(state, isEmpty);
    });

    test('add 添加搜索词到列表顶部', () async {
      final notifier = container.read(searchHistoryProvider.notifier);
      notifier.add('动作电影');
      await Future.delayed(const Duration(milliseconds: 20));
      final state = container.read(searchHistoryProvider);
      expect(state, ['动作电影']);
    });

    test('add 重复词自动移到顶部', () async {
      final notifier = container.read(searchHistoryProvider.notifier);
      notifier.add('动作电影');
      notifier.add('科幻电影');
      notifier.add('动作电影'); // 重复添加
      await Future.delayed(const Duration(milliseconds: 20));
      final state = container.read(searchHistoryProvider);
      expect(state.length, 2);
      expect(state.first, '动作电影');
      expect(state.last, '科幻电影');
    });

    test('add 忽略空字符串和纯空白', () async {
      final notifier = container.read(searchHistoryProvider.notifier);
      notifier.add('');
      notifier.add('   ');
      notifier.add('有效内容');
      await Future.delayed(const Duration(milliseconds: 20));
      final state = container.read(searchHistoryProvider);
      expect(state, ['有效内容']);
    });

    test('add 超过 kMaxSearchHistory 时自动截断', () async {
      final notifier = container.read(searchHistoryProvider.notifier);
      for (int i = 0; i < kMaxSearchHistory + 5; i++) {
        notifier.add('搜索词 $i');
      }
      await Future.delayed(const Duration(milliseconds: 20));
      final state = container.read(searchHistoryProvider);
      expect(state.length, kMaxSearchHistory);
    });

    test('remove 删除指定搜索词', () async {
      final notifier = container.read(searchHistoryProvider.notifier);
      notifier.add('动作');
      notifier.add('科幻');
      notifier.add('爱情');
      notifier.remove('科幻');
      await Future.delayed(const Duration(milliseconds: 20));
      final state = container.read(searchHistoryProvider);
      expect(state, isNot(contains('科幻')));
      expect(state, contains('动作'));
      expect(state, contains('爱情'));
    });

    test('clear 清空所有搜索历史', () async {
      final notifier = container.read(searchHistoryProvider.notifier);
      notifier.add('电影 1');
      notifier.add('电影 2');
      notifier.clear();
      await Future.delayed(const Duration(milliseconds: 20));
      final state = container.read(searchHistoryProvider);
      expect(state, isEmpty);
    });

    test('从 SharedPreferences 恢复搜索历史', () async {
      SharedPreferences.setMockInitialValues({
        kStorageKeySearchHistory: json.encode(['最近搜索 1', '最近搜索 2', '最近搜索 3']),
      });

      final newContainer = ProviderContainer();
      await Future.delayed(const Duration(milliseconds: 100));

      final state = newContainer.read(searchHistoryProvider);
      expect(state.length, 3);
      expect(state.first, '最近搜索 1');
      newContainer.dispose();
    });

    test('SharedPreferences 损坏时忽略错误', () async {
      SharedPreferences.setMockInitialValues({
        kStorageKeySearchHistory: 'not a json array',
      });

      final newContainer = ProviderContainer();
      await Future.delayed(const Duration(milliseconds: 100));

      final state = newContainer.read(searchHistoryProvider);
      // 损坏的配置被忽略，使用空列表
      expect(state, isEmpty);
      newContainer.dispose();
    });
  });
}
