// 回归测试：登录界面审查 F1
//
// 缺陷：切换服务器时新服务器返回 401（密码错/账号不存在）会走 ApiClient 的
// 全局 401 回调；旧实现判断 state.isAuthenticated（旧服务器仍登录）后直接
// logout()，把原服务器会话一起清掉，而调用方还提示「切换失败（保持原服务器）」。
//
// 修复：AuthNotifier 增加 _loggingIn 标志，登录请求执行期间的 401 视为凭证
// 校验失败，不触发自动登出。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/embytok_service_provider.dart';
import 'package:embytok_flutter/services/api_client.dart';

import '../mocks/mock_services.dart';
import '../mocks/mock_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('登录请求期间的 401 不应登出当前会话', () {
    late MockEmbytokService mockService;
    late MockFlutterSecureStorage mockSecureStorage;
    late ApiClient sharedApiClient;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockService = MockEmbytokService();
      mockSecureStorage = MockFlutterSecureStorage();
      sharedApiClient = ApiClient(baseUrl: 'http://server-a.example.com');
      // AuthNotifier 构造时把 401 回调挂在这个实例上
      when(mockService.apiClient).thenReturn(sharedApiClient);
    });

    tearDown(() {
      container.dispose();
    });

    ProviderContainer createContainer() {
      return ProviderContainer(
        overrides: [
          embytokServiceProvider.overrideWithValue(mockService),
          secureStorageProvider.overrideWithValue(mockSecureStorage),
          authProvider.overrideWith((ref) => AuthNotifier(ref)),
        ],
      );
    }

    test('login() 进行中收到 401 回调：保持旧服务器登录态', () async {
      // 登录请求挂起，模拟「正在向新服务器认证」
      final loginCompleter = Completer<User>();
      when(mockService.login(
        embyServerUrl: anyNamed('embyServerUrl'),
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenAnswer((_) => loginCompleter.future);

      container = createContainer();
      final notifier = container.read(authProvider.notifier);
      await pumpEventQueue();

      // 构造「已登录服务器 A」的状态
      notifier.enterLocalMode();
      expect(container.read(authProvider).isAuthenticated, isTrue);

      // 发起切换到服务器 B 的登录（不 await，保持 _loggingIn=true）
      final loginFuture = notifier.login(
          'http://server-b.example.com', 'user-b', 'wrong-password');
      await pumpEventQueue();

      // 新服务器返回 401 → ApiClient 触发全局 onUnauthorized
      sharedApiClient.onUnauthorized?.call();
      await pumpEventQueue();

      expect(
        container.read(authProvider).isAuthenticated,
        isTrue,
        reason: '登录请求自身的 401 属于凭证校验失败，不得登出已登录的旧服务器',
      );

      // 收尾：让挂起的登录以失败结束，释放 _loggingIn
      loginCompleter.completeError(Exception('401 Unauthorized'));
      await expectLater(loginFuture, throwsA(isA<Exception>()));
      await pumpEventQueue();
    });

    test('非登录期间的 401 仍然触发自动登出（保护原有行为）', () async {
      when(mockService.login(
        embyServerUrl: anyNamed('embyServerUrl'),
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenAnswer((_) async =>
          const User(id: 'u', name: 'n', accessToken: 'token'));

      container = createContainer();
      final notifier = container.read(authProvider.notifier);
      await pumpEventQueue();

      notifier.enterLocalMode();
      expect(container.read(authProvider).isAuthenticated, isTrue);

      // 没有进行中的登录：会话过期的 401 应清空登录态
      sharedApiClient.onUnauthorized?.call();
      await pumpEventQueue();

      expect(container.read(authProvider).isAuthenticated, isFalse);
    });
  });
}
