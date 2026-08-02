// PersonDetailView Widget 测试：验证作品列表加载、详情更新、错误状态、空列表等场景
//
// 核心修复场景：作品列表加载成功但详情失败时，仍应显示作品列表（不显示错误状态）。
// 这是对 _loadData 中"详情失败不阻塞作品显示"修复的回归保护。
//
// 测试模式：
// - 使用 ProviderScope + overrides
// - 使用 _MockCachedMediaRepository 模拟缓存仓库
// - 使用 _TestAuthNotifier 设置认证状态
// - 测试数据 MediaItem 不带 imageTags/thumbnailUrl，避免 CachedNetworkImage 发起网络请求

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/cache_providers.dart';
import 'package:embytok_flutter/repositories/cached_media_repository.dart';
import 'package:embytok_flutter/views/person_detail_view.dart';

/// CachedMediaRepository 的 Mock 实现
///
/// PersonDetailView 通过 cachedMediaRepositoryProvider 访问
/// getPersonItems / getPersonDetail，需要 stub 这些方法。
class _MockCachedMediaRepository extends Mock implements CachedMediaRepository {}

/// 构造测试用 MediaItem（不带图片字段，避免 CachedNetworkImage 发起网络请求）
MediaItem _personItem({String id = 'person-1', String title = '测试演员'}) {
  return MediaItem(id: id, title: title, type: 'Person');
}

/// 构造测试用作品 MediaItem
MediaItem _workItem(String id, String title) {
  return MediaItem(id: id, title: title, type: 'Movie');
}

void main() {
  late _MockCachedMediaRepository mockCachedRepo;
  late AuthState testAuthState;

  setUp(() {
    mockCachedRepo = _MockCachedMediaRepository();
    testAuthState = AuthState(
      isAuthenticated: true,
      user: User(id: 'user-1', name: 'test', accessToken: 'test-token'),
      embyServerUrl: 'http://emby.example.com',
      token: 'test-token',
    );
  });

  // 构建带 overrides 的 ProviderScope
  ProviderScope buildProviderScope({required Widget child}) {
    return ProviderScope(
      overrides: [
        cachedMediaRepositoryProvider.overrideWithValue(mockCachedRepo),
        authProvider.overrideWith(
          (ref) => _TestAuthNotifier(ref, testAuthState),
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('PersonDetailView', () {
    testWidgets('作品列表加载成功时显示作品列表', (WidgetTester tester) async {
      final works = [
        _workItem('w1', '作品一'),
        _workItem('w2', '作品二'),
      ];

      // stub 作品列表：返回 2 个作品
      when(mockCachedRepo.getPersonItems(
        'person-1',
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => PaginatedResponse<MediaItem>(
            items: works,
            total: works.length,
            offset: 0,
            limit: 30,
          ));

      // stub 详情：返回 null（避免 CachedNetworkImage 渲染）
      when(mockCachedRepo.getPersonDetail(
        'person-1',
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => null);

      await tester.pumpWidget(
        buildProviderScope(
          child: PersonDetailView(person: _personItem()),
        ),
      );
      await tester.pumpAndSettle();

      // 验证作品列表显示
      expect(find.text('作品一'), findsOneWidget);
      expect(find.text('作品二'), findsOneWidget);
      // 不应显示"暂无作品"或错误状态
      expect(find.text('暂无作品'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      // 不应显示加载指示器
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('作品列表加载失败时显示错误状态', (WidgetTester tester) async {
      // stub 作品列表：抛异常
      when(mockCachedRepo.getPersonItems(
        'person-1',
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow(Exception('加载作品失败'));

      // stub 详情：返回 null（不阻塞）
      when(mockCachedRepo.getPersonDetail(
        'person-1',
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => null);

      await tester.pumpWidget(
        buildProviderScope(
          child: PersonDetailView(person: _personItem()),
        ),
      );
      await tester.pumpAndSettle();

      // 验证错误状态显示
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      // 不应显示作品
      expect(find.text('暂无作品'), findsNothing);
    });

    testWidgets('作品列表成功但详情失败时显示作品列表（核心修复场景）',
        (WidgetTester tester) async {
      final works = [
        _workItem('w1', '作品一'),
        _workItem('w2', '作品二'),
      ];

      // stub 作品列表：成功返回
      when(mockCachedRepo.getPersonItems(
        'person-1',
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => PaginatedResponse<MediaItem>(
            items: works,
            total: works.length,
            offset: 0,
            limit: 30,
          ));

      // stub 详情：抛异常（核心修复场景：详情失败不应阻塞作品显示）
      when(mockCachedRepo.getPersonDetail(
        'person-1',
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        userId: anyNamed('userId'),
      )).thenThrow(Exception('详情加载失败'));

      await tester.pumpWidget(
        buildProviderScope(
          child: PersonDetailView(person: _personItem()),
        ),
      );
      await tester.pumpAndSettle();

      // 验证作品列表正常显示（详情失败不应导致错误状态）
      expect(find.text('作品一'), findsOneWidget);
      expect(find.text('作品二'), findsOneWidget);
      // 不应显示错误状态
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.text('重试'), findsNothing);
      // 不应显示"暂无作品"
      expect(find.text('暂无作品'), findsNothing);
    });

    testWidgets('详情加载成功时更新人员信息', (WidgetTester tester) async {
      final works = [_workItem('w1', '作品一')];

      // stub 作品列表：成功返回
      when(mockCachedRepo.getPersonItems(
        'person-1',
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => PaginatedResponse<MediaItem>(
            items: works,
            total: works.length,
            offset: 0,
            limit: 30,
          ));

      // stub 详情：返回带新标题的 MediaItem
      // widget.person.title='测试演员'，详情返回 title='详情演员名'
      // 验证 UI 显示详情中的姓名而非 widget.person 的姓名
      final detailItem = MediaItem(
        id: 'person-1',
        title: '详情演员名',
        type: 'Person',
      );
      when(mockCachedRepo.getPersonDetail(
        'person-1',
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => detailItem);

      await tester.pumpWidget(
        buildProviderScope(
          child: PersonDetailView(person: _personItem(title: '原始演员名')),
        ),
      );
      await tester.pumpAndSettle();

      // AppBar 标题应显示详情中的姓名
      expect(find.text('详情演员名'), findsWidgets);
      // 原始姓名不应再显示（widget.person.title 被详情覆盖）
      expect(find.text('原始演员名'), findsNothing);
    });

    testWidgets('空作品列表显示"暂无作品"', (WidgetTester tester) async {
      // stub 作品列表：返回空列表
      when(mockCachedRepo.getPersonItems(
        'person-1',
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => PaginatedResponse<MediaItem>(
            items: const <MediaItem>[],
            total: 0,
            offset: 0,
            limit: 30,
          ));

      // stub 详情：返回 null
      when(mockCachedRepo.getPersonDetail(
        'person-1',
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => null);

      await tester.pumpWidget(
        buildProviderScope(
          child: PersonDetailView(person: _personItem()),
        ),
      );
      await tester.pumpAndSettle();

      // 验证"暂无作品"显示
      expect(find.text('暂无作品'), findsOneWidget);
      // 不应显示错误状态
      expect(find.byIcon(Icons.error_outline), findsNothing);
      // 不应显示加载指示器
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}

// 测试用 AuthNotifier：继承 AuthNotifier，在构造函数中直接设置预设状态
// 注意：AuthNotifier 构造函数会调用 _loadFromStorage()（异步），
// 但 _TestAuthNotifier 在构造函数中同步设置 state = initialState，
// 测试环境中 _loadFromStorage 会失败但不会崩溃（有 try-catch），不会覆盖预设状态。
class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(Ref ref, AuthState initialState) : super(ref) {
    state = initialState;
  }
}
