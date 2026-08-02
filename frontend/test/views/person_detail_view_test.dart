// PersonDetailView Widget 测试：验证作品列表加载、详情更新、错误状态、空列表等场景
//
// 核心修复场景：
// 1. 作品列表加载成功但详情失败时，仍应显示作品列表（不显示错误状态）。
//    这是对 _loadData 中"详情失败不阻塞作品显示"修复的回归保护。
// 2. token 过期（embyServerUrl/token 为 null）时不应因强制解包崩溃，
//    应友好提示"登录已过期"且不发起任何网络请求。
//    这是对 _loadData / _loadMore 中 null 检查修复的回归保护。
//
// 测试模式（参考 favorites_view_test.dart，兼容 mockito 5.7.0）：
// - 在 _MockCachedMediaRepository 中显式覆写 getPersonItems / getPersonDetail
// - 使用 super.noSuchMethod + Invocation.method 提供 returnValue / returnValueForMissingStub
// - 在 when 调用中使用 anyNamed 匹配参数（避免参数精确匹配导致的 stub 不命中）
// - 使用 ProviderScope + overrides
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
///
/// 关键：mockito 5.7.0 中，`extends Mock implements CachedMediaRepository`
/// 的默认 mock 在 when 上下文中调用方法时会返回 null，但方法返回类型为
/// 非空 `Future<...>`，会触发 `type 'Null' is not a subtype of type ...` 错误。
/// 解决方案：显式覆写方法，参数改为可空，调用 super.noSuchMethod 时
/// 提供 returnValue（when 上下文使用）和 returnValueForMissingStub
/// （未匹配 stub 的真实调用使用），并将返回值 cast 为方法的返回类型。
class _MockCachedMediaRepository extends Mock implements CachedMediaRepository {
  @override
  Future<PaginatedResponse<MediaItem>> getPersonItems(
    String? personId, {
    int? limit,
    int? offset,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getPersonItems, [personId], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(PaginatedResponse<MediaItem>(
          items: const <MediaItem>[],
          total: 0,
          offset: 0,
          limit: 0,
        )),
        returnValueForMissingStub: Future.value(PaginatedResponse<MediaItem>(
          items: const <MediaItem>[],
          total: 0,
          offset: 0,
          limit: 0,
        )),
      ) as Future<PaginatedResponse<MediaItem>>;

  @override
  Future<MediaItem?> getPersonDetail(
    String? personId, {
    String? serverUrl,
    String? token,
    String? userId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getPersonDetail, [personId], {
          #serverUrl: serverUrl,
          #token: token,
          #userId: userId,
        }),
        returnValue: Future<MediaItem?>.value(null),
        returnValueForMissingStub: Future<MediaItem?>.value(null),
      ) as Future<MediaItem?>;
}

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
        any,
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
        any,
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
      // stub 作品列表：返回失败的 Future（异步抛异常）
      // 注意：用 thenAnswer + Future.error 而非 thenThrow，
      // 因为方法签名返回 Future，thenThrow 会同步抛出导致
      // cachedRepo.getPersonItems(...) 调用本身抛出异常，
      // 与真实环境中 Future 完成时失败的语义不一致
      when(mockCachedRepo.getPersonItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) => Future.error(Exception('加载作品失败')));

      // stub 详情：返回 null（不阻塞）
      when(mockCachedRepo.getPersonDetail(
        any,
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
        any,
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

      // stub 详情：返回失败的 Future（异步抛异常）
      // 核心修复场景：详情失败不应阻塞作品显示
      // 注意：用 thenAnswer + Future.error 而非 thenThrow，
      // 因为方法签名返回 Future，thenThrow 会同步抛出导致
      // cachedRepo.getPersonDetail(...) 调用本身抛出异常，
      // 触发 _loadData 外层 try-catch 设置 _error，不符合
      // 真实环境中 Future 完成时失败的语义
      when(mockCachedRepo.getPersonDetail(
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) => Future.error(Exception('详情加载失败')));

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
        any,
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
        any,
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
        any,
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
        any,
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

    // 回归测试：token 过期（为 null）时不应因强制解包崩溃，
    // 应友好提示"登录已过期"且不发起任何网络请求
    testWidgets('token 为 null 时显示登录过期提示且不崩溃',
        (WidgetTester tester) async {
      // 模拟会话过期：embyServerUrl 和 token 均为 null
      testAuthState = const AuthState(
        isAuthenticated: false,
        embyServerUrl: null,
        token: null,
      );

      await tester.pumpWidget(
        buildProviderScope(
          child: PersonDetailView(person: _personItem()),
        ),
      );
      await tester.pumpAndSettle();

      // 验证不抛异常，并显示登录过期错误提示与重试按钮
      expect(find.text('登录已过期，请重新登录'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      // 会话过期时不应发起任何网络请求
      verifyZeroInteractions(mockCachedRepo);
    });

    // 回归测试：作品列表已加载后 token 失效，滚动触发的 _loadMore
    // 不应再次调用 getPersonItems（避免空指针崩溃与无效请求）
    testWidgets('_loadMore 在 token 失效时不调用 getPersonItems',
        (WidgetTester tester) async {
      // 初始 token 有效，加载 30 个作品，total=1000 确保可触发分页
      final works = List.generate(30, (i) => _workItem('w$i', '作品$i'));
      when(mockCachedRepo.getPersonItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => PaginatedResponse<MediaItem>(
            items: works,
            total: 1000,
            offset: 0,
            limit: 30,
          ));
      when(mockCachedRepo.getPersonDetail(
        any,
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

      // 模拟 token 过期：通过 container 动态更新 auth state
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PersonDetailView)),
      );
      (container.read(authProvider.notifier) as _TestAuthNotifier).updateState(
        const AuthState(
          isAuthenticated: false,
          embyServerUrl: null,
          token: null,
        ),
      );
      await tester.pump();

      // 滚动到底部触发 _loadMore：获取 SingleChildScrollView 关联的 ScrollController
      final scrollable = tester.widgetList<Scrollable>(
        find.byWidgetPredicate(
          (widget) => widget is Scrollable && widget.controller != null,
        ),
      ).first;
      final controller = scrollable.controller!;
      // 确保有足够滚动空间，以保证 _onScroll 条件成立从而触发 _loadMore
      expect(controller.position.maxScrollExtent, greaterThan(0));
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();

      // 验证：初始加载时 getPersonItems 调用 1 次，getPersonDetail 调用 1 次
      // token 失效后 _loadMore 未发起分页请求，因此 getPersonItems 仍是 1 次
      verify(mockCachedRepo.getPersonItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).called(1);
      verify(mockCachedRepo.getPersonDetail(
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        userId: anyNamed('userId'),
      )).called(1);
      verifyNoMoreInteractions(mockCachedRepo);
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

  /// 测试辅助：动态更新认证状态（模拟 token 过期等场景）
  void updateState(AuthState newState) {
    state = newState;
  }
}
