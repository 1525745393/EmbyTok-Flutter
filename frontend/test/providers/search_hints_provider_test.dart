// 搜索建议 Provider 测试：验证防抖和缓存能力

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart;

import 'package:embbytok_flutter/models/models.dart';
import 'package:embbytok_flutter/providers/auth_provider.dart';
import 'package:embbytok_flutter/providers/search_hints_provider.dart';
import 'package:embbytok_flutter/services/embbytok_service.dart';

import '../mocks/mock_services.dart';

void main() {
  late _MockEmbytokService mockService;
  late ProviderContainer container;

  setUp(() {
    mockService = _MockEmbytokService();
    container = ProviderContainer(overrides: [
      authProvider.overrideWith((ref) => AuthNotifier(ref, service: mockService)
        ..state = AuthState(
          isAuthenticated: true,
          embyServerUrl: 'http://test.local',
          token: 'test-token',
          user: const User(id: 'user-1', name: 'Test'),
        )),
      searchHintsStateProvider.overrideWith((ref) {
        return SearchHintsNotifier(ref, service: mockService);
      }),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  group('SearchHintsNotifier 防抖', () {
    test('快速连续输入：只发起最后一次请求', () async {
      when(mockService.searchHints(
        any,
        limit: anyNamed('limit'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => <SearchHint>[]);

      // 模拟快速连续输入
      final notifier = container.read(searchHintsStateProvider.notifier);
      notifier.fetchHints('a');
      notifier.fetchHints('ab');
      notifier.fetchHints('abc');
      notifier.fetchHints('abcd');

      // 等待防抖时间过去（300ms + 余量）
      await Future.delayed(const Duration(milliseconds: 500));

      // 只应调用一次（最后一次 'abcd'）
      verify(mockService.searchHints(
        'abcd',
        limit: anyNamed('limit'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).called(1);

      // 中间的查询不应触发 API
      verifyNever(mockService.searchHints(
        'a',
        limit: anyNamed('limit'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      ));
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
        SearchHint(id: '1', name: 'Batman', type: 'Movie'),
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
        SearchHint(id: '1', name: 'Batman', type: 'Movie'),
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

// 自定义 Mock，避免依赖 generated mock
class _MockEmbytokService extends Mock implements EmbytokService {}
