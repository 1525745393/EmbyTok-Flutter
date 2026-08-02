// FavoritesView Widget 测试：验证取消收藏 + 撤销操作的状态一致性
//
// 核心修复场景（对应 spec: audit-ui-screens Task 3）：
// 1. 撤销成功时 UI 保持"已收藏"（toggleFavorite 服务端调用成功）
// 2. 撤销失败时 UI 回滚到"未收藏" + SnackBar 提示"撤销失败，请重试"
//
// 测试模式：
// - 使用 ProviderScope + overrides
// - 使用 _MockCachedMediaRepository 模拟缓存仓库（loadFavorites 数据源）
// - 使用 MockEmbytokService 模拟服务端（toggleFavorite 成功/失败）
// - 使用 _TestAuthNotifier 设置认证状态
// - 测试数据 MediaItem 不带 imageTags，避免 CachedNetworkImage 发起网络请求

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/cache_providers.dart';
import 'package:embytok_flutter/providers/embytok_service_provider.dart';
import 'package:embytok_flutter/repositories/cached_media_repository.dart';
import 'package:embytok_flutter/services/embytok_service.dart';
import 'package:embytok_flutter/views/favorites_view.dart';

import '../mocks/mock_services.dart';

/// CachedMediaRepository 的 Mock 实现
///
/// FavoritesView 通过 cachedMediaRepositoryProvider 访问
/// peekFavoriteMovies / getFavoriteMovies 等，需要 stub 这些方法。
/// 覆写方法签名为可空参数，以便测试中使用 anyNamed 匹配。
class _MockCachedMediaRepository extends Mock implements CachedMediaRepository {
  @override
  FavoritesPageResult? peekFavoriteMovies({
    int? limit,
    int? offset,
    String? serverUrl,
    String? token,
    String? userId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#peekFavoriteMovies, [], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
          #userId: userId,
        }),
        returnValue: null,
      ) as FavoritesPageResult?;

  @override
  FavoritesPageResult? peekFavoriteBoxSets({
    int? limit,
    int? offset,
    String? serverUrl,
    String? token,
    String? userId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#peekFavoriteBoxSets, [], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
          #userId: userId,
        }),
        returnValue: null,
      ) as FavoritesPageResult?;

  @override
  FavoritesPageResult? peekFavoritePeople({
    int? limit,
    int? offset,
    String? serverUrl,
    String? token,
    String? userId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#peekFavoritePeople, [], {
          #limit: limit,
          #offset: offset,
          #serverUrl: serverUrl,
          #token: token,
          #userId: userId,
        }),
        returnValue: null,
      ) as FavoritesPageResult?;

  @override
  Future<FavoritesPageResult> getFavoriteMovies({
    int? limit,
    int? offset,
    String? userId,
    String? serverUrl,
    String? token,
    CancelToken? cancelToken,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getFavoriteMovies, [], {
          #limit: limit,
          #offset: offset,
          #userId: userId,
          #serverUrl: serverUrl,
          #token: token,
          #cancelToken: cancelToken,
        }),
        returnValue: Future.value(
            const FavoritesPageResult(items: <MediaItem>[], totalCount: 0)),
        returnValueForMissingStub: Future.value(
            const FavoritesPageResult(items: <MediaItem>[], totalCount: 0)),
      ) as Future<FavoritesPageResult>;

  @override
  Future<FavoritesPageResult> getFavoriteBoxSets({
    int? limit,
    int? offset,
    String? userId,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getFavoriteBoxSets, [], {
          #limit: limit,
          #offset: offset,
          #userId: userId,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(
            const FavoritesPageResult(items: <MediaItem>[], totalCount: 0)),
        returnValueForMissingStub: Future.value(
            const FavoritesPageResult(items: <MediaItem>[], totalCount: 0)),
      ) as Future<FavoritesPageResult>;

  @override
  Future<FavoritesPageResult> getFavoritePeople({
    int? limit,
    int? offset,
    String? userId,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getFavoritePeople, [], {
          #limit: limit,
          #offset: offset,
          #userId: userId,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(
            const FavoritesPageResult(items: <MediaItem>[], totalCount: 0)),
        returnValueForMissingStub: Future.value(
            const FavoritesPageResult(items: <MediaItem>[], totalCount: 0)),
      ) as Future<FavoritesPageResult>;
}

/// 测试用 AuthNotifier：继承 AuthNotifier，在构造函数中直接设置预设状态
/// 注意：AuthNotifier 构造函数会调用 _loadFromStorage()（异步），
/// 但 _TestAuthNotifier 在构造函数中同步设置 state = initialState，
/// 测试环境中 _loadFromStorage 会失败但不会崩溃（有 try-catch），不会覆盖预设状态。
class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(Ref ref, AuthState initialState) : super(ref) {
    state = initialState;
  }
}

/// 构造测试用 MediaItem（不带 imageTags，避免 CachedNetworkImage 发起网络请求）
MediaItem _movieItem({String id = 'movie-1', String title = '测试影片'}) {
  return MediaItem(id: id, title: title, type: 'Movie');
}

void main() {
  late MockEmbytokService mockService;
  late _MockCachedMediaRepository mockCachedRepo;
  late AuthState testAuthState;

  setUp(() {
    mockService = MockEmbytokService();
    mockCachedRepo = _MockCachedMediaRepository();
    testAuthState = AuthState(
      isAuthenticated: true,
      user: User(id: 'user-1', name: 'test', accessToken: 'test-token'),
      embyServerUrl: 'http://emby.example.com',
      token: 'test-token',
    );
  });

  /// 构建带 overrides 的 ProviderScope
  ProviderScope buildProviderScope({required Widget child}) {
    return ProviderScope(
      overrides: [
        embytokServiceProvider.overrideWithValue(mockService),
        cachedMediaRepositoryProvider.overrideWithValue(mockCachedRepo),
        authProvider.overrideWith(
          (ref) => _TestAuthNotifier(ref, testAuthState),
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  /// Stub loadFavorites：peek 返回 null（无缓存），get 返回指定数据
  void stubLoadFavorites(List<MediaItem> movies) {
    // peek 返回 null（无缓存），强制走网络
    when(mockCachedRepo.peekFavoriteMovies(
      limit: anyNamed('limit'),
      offset: anyNamed('offset'),
      serverUrl: anyNamed('serverUrl'),
      token: anyNamed('token'),
      userId: anyNamed('userId'),
    )).thenReturn(null);
    when(mockCachedRepo.peekFavoriteBoxSets(
      limit: anyNamed('limit'),
      offset: anyNamed('offset'),
      serverUrl: anyNamed('serverUrl'),
      token: anyNamed('token'),
      userId: anyNamed('userId'),
    )).thenReturn(null);
    when(mockCachedRepo.peekFavoritePeople(
      limit: anyNamed('limit'),
      offset: anyNamed('offset'),
      serverUrl: anyNamed('serverUrl'),
      token: anyNamed('token'),
      userId: anyNamed('userId'),
    )).thenReturn(null);

    // get 返回测试数据
    when(mockCachedRepo.getFavoriteMovies(
      limit: anyNamed('limit'),
      offset: anyNamed('offset'),
      serverUrl: anyNamed('serverUrl'),
      token: anyNamed('token'),
      userId: anyNamed('userId'),
      cancelToken: anyNamed('cancelToken'),
    )).thenAnswer((_) async => FavoritesPageResult(
          items: movies,
          totalCount: movies.length,
        ));
    when(mockCachedRepo.getFavoriteBoxSets(
      limit: anyNamed('limit'),
      offset: anyNamed('offset'),
      serverUrl: anyNamed('serverUrl'),
      token: anyNamed('token'),
      userId: anyNamed('userId'),
    )).thenAnswer((_) async =>
        const FavoritesPageResult(items: <MediaItem>[], totalCount: 0));
    when(mockCachedRepo.getFavoritePeople(
      limit: anyNamed('limit'),
      offset: anyNamed('offset'),
      serverUrl: anyNamed('serverUrl'),
      token: anyNamed('token'),
      userId: anyNamed('userId'),
    )).thenAnswer((_) async =>
        const FavoritesPageResult(items: <MediaItem>[], totalCount: 0));
  }

  group('FavoritesView 撤销操作', () {
    testWidgets('撤销成功时 UI 保持已收藏', (tester) async {
      final item = _movieItem();
      stubLoadFavorites([item]);

      // toggleFavorite 全部成功
      when(mockService.toggleFavorite(
        itemId: anyNamed('itemId'),
        isFavorite: anyNamed('isFavorite'),
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async {});

      await tester.pumpWidget(
        buildProviderScope(child: const FavoritesView()),
      );
      await tester.pumpAndSettle();

      // 验证卡片显示
      expect(find.text('测试影片'), findsOneWidget);

      // 长按卡片打开操作菜单
      await tester.longPress(find.text('测试影片'));
      await tester.pumpAndSettle();

      // 点击"取消收藏"
      await tester.tap(find.text('取消收藏'));
      await tester.pumpAndSettle();

      // 验证"已取消收藏" SnackBar 出现
      expect(find.textContaining('已取消收藏'), findsOneWidget);

      // 点击"撤销"
      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();

      // 验证影片重新出现在列表中（撤销成功，重新收藏）
      expect(find.text('测试影片'), findsOneWidget);
      // 不应出现"撤销失败"提示
      expect(find.text('撤销失败，请重试'), findsNothing);
    });

    testWidgets('撤销失败时显示撤销失败提示', (tester) async {
      final item = _movieItem();
      stubLoadFavorites([item]);

      // toggleFavorite：取消收藏成功，重新收藏（撤销）失败
      when(mockService.toggleFavorite(
        itemId: anyNamed('itemId'),
        isFavorite: anyNamed('isFavorite'),
        userId: anyNamed('userId'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((invocation) async {
        final isFavorite = invocation.namedArguments[#isFavorite] as bool;
        if (isFavorite) {
          // 重新收藏（撤销）失败
          throw Exception('重新收藏失败');
        }
        // 取消收藏成功
      });

      await tester.pumpWidget(
        buildProviderScope(child: const FavoritesView()),
      );
      await tester.pumpAndSettle();

      // 验证卡片显示
      expect(find.text('测试影片'), findsOneWidget);

      // 长按卡片打开操作菜单
      await tester.longPress(find.text('测试影片'));
      await tester.pumpAndSettle();

      // 点击"取消收藏"
      await tester.tap(find.text('取消收藏'));
      await tester.pumpAndSettle();

      // 验证"已取消收藏" SnackBar 出现
      expect(find.textContaining('已取消收藏'), findsOneWidget);

      // 点击"撤销"
      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();

      // 验证"撤销失败，请重试" SnackBar 出现
      expect(find.text('撤销失败，请重试'), findsOneWidget);
      // 影片不应出现在列表中（撤销失败，状态回滚到未收藏）
      expect(find.text('测试影片'), findsNothing);
    });
  });
}
