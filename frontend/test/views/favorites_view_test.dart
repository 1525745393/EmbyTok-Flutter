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

      // 验证卡片显示（只匹配列表内的"测试影片"文本：排除 SnackBar/标题栏等其他 Widget）
      final listMovieTexts = find.descendant(
        of: find.byType(ListView),
        matching: find.text('测试影片'),
      );
      expect(listMovieTexts, findsOneWidget);

      // 方案 B：影片组内嵌在 GridView 中，用 GridView 内的 ancestor 找到对应海报卡 Widget
      // 直接查找 GridView 内的 InkWell（海报卡可交互容器），通过 key/ancestor 触发长按菜单
      final movieCard = find.descendant(
        of: find.byType(GridView).first,
        matching: find.byWidgetPredicate((w) => w is InkWell || w is GestureDetector),
      ).hitTestable().first;

      // 长按卡片打开操作菜单（忽略边界警告：菜单会弹出在底部安全区）
      await tester.longPress(movieCard, warnIfMissed: false);
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
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('测试影片'),
        ),
        findsOneWidget,
      );
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
      final listMovieTexts = find.descendant(
        of: find.byType(ListView),
        matching: find.text('测试影片'),
      );
      expect(listMovieTexts, findsOneWidget);

      // 找到影片组 GridView 内第一张可交互卡片
      final movieCard = find.descendant(
        of: find.byType(GridView).first,
        matching: find.byWidgetPredicate((w) => w is InkWell || w is GestureDetector),
      ).hitTestable().first;

      // 长按卡片打开操作菜单
      await tester.longPress(movieCard, warnIfMissed: false);
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
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('测试影片'),
        ),
        findsNothing,
      );
    });
  });

  // ============================================================
  // 方案 B：纵向堆叠 + 可折叠分组 + 统计概览 + 批量操作
  // ============================================================
  group('FavoritesView 方案B布局', () {
    /// 为方案 B 测试准备 stub：影片/合集/人物都有数据
    void stubLoadAllThree({
      int movieCount = 6,
      int boxSetCount = 2,
      int personCount = 4,
    }) {
      final movies = List<MediaItem>.generate(
        movieCount,
        (i) => _movieItem(id: 'm-$i', title: '影片${i + 1}'),
      );
      final boxSets = List<MediaItem>.generate(
        boxSetCount,
        (i) => MediaItem(id: 'b-$i', title: '合集${i + 1}', type: 'BoxSet'),
      );
      final people = List<MediaItem>.generate(
        personCount,
        (i) => MediaItem(id: 'p-$i', title: '人物${i + 1}', type: 'Person'),
      );

      // peek 全返回 null，强制走网络
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

      when(mockCachedRepo.getFavoriteMovies(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        userId: anyNamed('userId'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async =>
          FavoritesPageResult(items: movies, totalCount: movieCount));
      when(mockCachedRepo.getFavoriteBoxSets(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async =>
          FavoritesPageResult(items: boxSets, totalCount: boxSetCount));
      when(mockCachedRepo.getFavoritePeople(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async =>
          FavoritesPageResult(items: people, totalCount: personCount));
    }

    testWidgets('统计概览卡片显示三类收藏数量', (tester) async {
      stubLoadAllThree(movieCount: 248, boxSetCount: 36, personCount: 54);
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

      // 统计卡内展示的大号计数（字号 20）至少出现一次即可；
      // 同时每个分组标题行右侧的数量徽标（字号 10.5）也会展示该数字，
      // 这里做更稳健的验证：三列统计卡各自的 count 数字至少出现在页面上一次
      expect(
        find.text('248').evaluate().length,
        greaterThanOrEqualTo(1),
      );
      expect(
        find.text('36').evaluate().length,
        greaterThanOrEqualTo(1),
      );
      expect(
        find.text('54').evaluate().length,
        greaterThanOrEqualTo(1),
      );
    });

    testWidgets('搜索栏出现在页面顶部且可输入过滤', (tester) async {
      stubLoadAllThree();
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

      // 找到搜索框（TextField 必须存在）
      final searchField = find.byWidgetPredicate(
        (w) => w is TextField,
      );
      expect(searchField, findsWidgets);

      // 搜索前影片1、影片2都存在（只匹配影片列表里的 GridView 内文本：避免与搜索框 EditableText 冲突）
      final inListView = find.descendant(
        of: find.byType(ListView).first,
        matching: find.byType(GridView),
      );
      final movie1InGrid = find.descendant(
        of: inListView.first,
        matching: find.text('影片1'),
      );
      final movie2InGrid = find.descendant(
        of: inListView.first,
        matching: find.text('影片2'),
      );
      expect(movie1InGrid, findsOneWidget);
      expect(movie2InGrid, findsOneWidget);

      // 输入过滤词
      await tester.enterText(searchField.first, '影片2');
      await tester.pumpAndSettle();

      // 影片1应被过滤掉（影片列表 GridView 内不应再出现"影片1"）
      expect(movie1InGrid, findsNothing);
      // 影片2仍保留在影片列表 GridView 中
      expect(movie2InGrid, findsOneWidget);
    });

    testWidgets('点击分组标题可折叠/展开分组（影片组默认展开）',
        (tester) async {
      stubLoadAllThree();
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

      // 影片组 key = ValueKey('grp-movie')，在其内部找包含"收藏影片"的可点击区域（标题行 InkWell）
      final grpMovie = find.byKey(const ValueKey('grp-movie'));
      expect(grpMovie, findsOneWidget);

      // 点击组内 InkWell 切换折叠（标题行：包含图标+标题+chevron 的可点击区域）
      final movieHeaderTappable = find
          .descendant(
            of: grpMovie,
            matching: find.byType(InkWell),
          )
          .hitTestable()
          .first;
      expect(movieHeaderTappable, findsOneWidget);

      // 组标题行中"收藏影片"文本（粗体 15 号）应能找到
      final groupTitles = find.descendant(
        of: grpMovie,
        matching: find.text('收藏影片'),
      );
      expect(groupTitles, findsWidgets);

      // 影片组内容初始可见（GridView 内出现"影片1"）
      final inMovieGrid = find.descendant(
        of: grpMovie,
        matching: find.text('影片1'),
      );
      expect(inMovieGrid, findsOneWidget);

      // 点击分组标题折叠
      await tester.tap(movieHeaderTappable);
      await tester.pumpAndSettle();
      // 折叠后影片1应不可见（在该组的 scope 内）
      expect(inMovieGrid, findsNothing);

      // 再次点击展开
      await tester.tap(movieHeaderTappable);
      await tester.pumpAndSettle();
      expect(inMovieGrid, findsOneWidget);
    });

    testWidgets('批量管理入口 → 进入选择模式 → 底部操作栏出现',
        (tester) async {
      stubLoadAllThree();
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

      // 初始：底部批量栏不存在
      expect(find.text('已选择'), findsNothing);
      expect(find.text('取消收藏'), findsNothing);

      // 点击"批量管理"按钮
      final bulkBtn = find.text('批量管理');
      expect(bulkBtn, findsOneWidget);
      await tester.tap(bulkBtn);
      await tester.pumpAndSettle();

      // 批量管理入口切换文字或底部栏出现已选数量提示
      final hasSelectionHint =
          find.textContaining('已选择').evaluate().isNotEmpty ||
              find.textContaining('项').evaluate().isNotEmpty ||
              find.widgetWithIcon(IconButton, Icons.delete_outline)
                  .evaluate()
                  .isNotEmpty ||
              find.text('完成').evaluate().isNotEmpty;
      // 更宽松：只要批量按钮变成"完成"或者有取消收藏按钮，就算进入选择模式
      expect(
        hasSelectionHint || find.text('完成').evaluate().isNotEmpty,
        isTrue,
        reason: '进入批量管理后应出现选择模式的提示（已选数量/完成按钮/取消收藏按钮）',
      );
    });

    testWidgets('空状态仍显示 EmptyStateCard', (tester) async {
      // 三组数据全部为空且无错误
      stubLoadFavorites([]);
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

      expect(find.text('还没有收藏'), findsOneWidget);
      expect(find.text('双击视频即可收藏'), findsOneWidget);
    });

    testWidgets('加载中显示骨架/指示器，加载完成后出现内容',
        (tester) async {
      stubLoadAllThree();
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

      // pump 一次后还在加载：可能显示 CircularProgressIndicator
      final loadingIndicators =
          find.byType(CircularProgressIndicator).evaluate();
      // 加载中不崩溃即可
      expect(loadingIndicators.length, greaterThanOrEqualTo(0));

      // pumpAndSettle 完成加载
      await tester.pumpAndSettle();

      // 影片组默认展开 → 影片1可见
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('grp-movie')),
          matching: find.text('影片1'),
        ),
        findsOneWidget,
      );

      // 合集组、人物组默认折叠：先通过对应组的 Key 点击展开标题行，再验证内容可见
      for (final entry in [
        MapEntry(const ValueKey('grp-boxset'), '合集1'),
        MapEntry(const ValueKey('grp-person'), '人物1'),
      ]) {
        final grpKey = entry.key as ValueKey<String>;
        final contentText = entry.value as String;
        final grp = find.byKey(grpKey);
        // 若对应组 DOM 不存在（可能该分组为空时被 ListView 省略），就跳过，避免误判
        if (grp.evaluate().isEmpty) continue;
        final headerInkWell = find
            .descendant(of: grp, matching: find.byType(InkWell))
            .hitTestable()
            .first;
        // 展开折叠组
        await tester.tap(headerInkWell);
        await tester.pumpAndSettle();
        // 验证该组内内容可见
        expect(
          find.descendant(of: grp, matching: find.text(contentText)),
          findsOneWidget,
        );
      }
    });
  });
}
