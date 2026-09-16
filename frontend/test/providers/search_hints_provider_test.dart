// 搜索建议 Provider 测试：验证防抖和缓存能力


import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/embytok_service_provider.dart';
import 'package:embytok_flutter/providers/search_hints_provider.dart';

import '../mocks/mock_services.dart';

void main() {
  late MockEmbytokService mockService;
  late ProviderContainer container;

  setUp(() {
    mockService = MockEmbytokService();
    container = ProviderContainer(overrides: [
      embytokServiceProvider.overrideWithValue(mockService),
      authProvider.overrideWith((ref) => AuthNotifier(ref)
        ..state = const AuthState(
          isAuthenticated: true,
          embyServerUrl: 'http://test.local',
          token: 'test-token',
          user: const User(
            id: 'user-1',
            name: 'Test',
            accessToken: 'test-token',
          ),
        )),
      searchHintsStateProvider.overrideWith((ref) {
        return SearchHintsNotifier(ref);
      }),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  group('SearchHintsNotifier 防抖', () {
    test('连续输入：Provider 直接执行（防抖已移至 View 层 150ms）', () async {
      when(mockService.searchHints(
        any,
        limit: anyNamed('limit'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => <SearchHint>[]);

      // 模拟连续输入：防抖职责在 View 层（搜索框 150ms），
      // Provider.fetchHints 对每次输入直接发起请求
      final notifier = container.read(searchHintsStateProvider.notifier);
      notifier.fetchHints('a');
      notifier.fetchHints('ab');
      notifier.fetchHints('abc');
      notifier.fetchHints('abcd');

      // 等待异步请求完成
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // 每次输入都发起请求（相同查询由缓存层去重，不同查询不合并）
      for (final q in ['a', 'ab', 'abc', 'abcd']) {
        verify(mockService.searchHints(
          q,
          limit: anyNamed('limit'),
          serverUrl: anyNamed('serverUrl'),
          token: anyNamed('token'),
        )).called(1);
      }
    });

    test('间隔超过防抖时间：每次都发起请求', () async {
      when(mockService.searchHints(
        any,
        limit: anyNamed('limit'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => <SearchHint>[]);

      final notifier = container.read(searchHintsStateProvider.notifier);

      // 第一次输入
      notifier.fetchHints('movie');
      await Future.delayed(const Duration(milliseconds: 400));

      // 第二次输入（间隔 > 300ms）
      notifier.fetchHints('movie2');
      await Future.delayed(const Duration(milliseconds: 400));

      verify(mockService.searchHints(
        'movie',
        limit: anyNamed('limit'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).called(1);
      verify(mockService.searchHints(
        'movie2',
        limit: anyNamed('limit'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).called(1);
    });

    test('空查询：不发起请求并清空状态', () async {
      final notifier = container.read(searchHintsStateProvider.notifier);

      notifier.fetchHints('');

      await Future.delayed(const Duration(milliseconds: 400));

      verifyNever(mockService.searchHints(
        any,
        limit: anyNamed('limit'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      ));
      expect(container.read(searchHintsStateProvider).hints, isEmpty);
    });
  });

  group('SearchHintsNotifier 缓存', () {
    test('相同查询：第二次命中缓存不发起 API', () async {
      when(mockService.searchHints(
        'batman',
        limit: anyNamed('limit'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => [
        const SearchHint(id: '1', name: 'Batman', type: 'Movie'),
      ]);

      final notifier = container.read(searchHintsStateProvider.notifier);

      // 第一次查询
      notifier.fetchHints('batman');
      await Future.delayed(const Duration(milliseconds: 400));

      // 第二次相同查询
      notifier.fetchHints('batman');
      await Future.delayed(const Duration(milliseconds: 400));

      // 只调用一次 API
      verify(mockService.searchHints(
        'batman',
        limit: anyNamed('limit'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).called(1);
    });

    test('不同查询：都发起 API 请求', () async {
      when(mockService.searchHints(
        any,
        limit: anyNamed('limit'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((invocation) async {
        final query = invocation.positionalArguments[0] as String;
        return [SearchHint(id: query, name: query, type: 'Movie')];
      });

      final notifier = container.read(searchHintsStateProvider.notifier);

      notifier.fetchHints('batman');
      await Future.delayed(const Duration(milliseconds: 400));

      notifier.fetchHints('superman');
      await Future.delayed(const Duration(milliseconds: 400));

      verify(mockService.searchHints(
        'batman',
        limit: anyNamed('limit'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).called(1);
      verify(mockService.searchHints(
        'superman',
        limit: anyNamed('limit'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).called(1);
    });

    test('clear：清空状态和缓存', () async {
      when(mockService.searchHints(
        'batman',
        limit: anyNamed('limit'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => [
        const SearchHint(id: '1', name: 'Batman', type: 'Movie'),
      ]);

      final notifier = container.read(searchHintsStateProvider.notifier);

      notifier.fetchHints('batman');
      await Future.delayed(const Duration(milliseconds: 400));

      // 清空
      notifier.clear();

      // 再次查询相同内容（应重新发起 API，因为缓存已清）
      notifier.fetchHints('batman');
      await Future.delayed(const Duration(milliseconds: 400));

      verify(mockService.searchHints(
        'batman',
        limit: anyNamed('limit'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).called(2);
    });
  });
}
