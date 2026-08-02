// 推荐系统 Provider 集成测试
//
// 覆盖范围（对应 audit-recommend-system spec Task 5）：
// 1. _shouldSkipItem 过滤逻辑（黑名单 / 反疲劳 / 用户评分低，收藏豁免）
// 2. _mergeRoundRobin 多源合并 + 跨源去重
// 3. _PageLoadResult 新字段验证（suggestionsCount / allSourcesExhausted / hasMore）
//
// 测试策略：
// - 通过 ProviderContainer 覆盖所有依赖，隔离 RecommendNotifier
// - Mock MediaRepository 控制各数据源返回内容
// - 覆盖 userBehaviorSignalProvider 控制黑名单和权重
// - 覆盖 favoritesProvider 控制收藏 ID 集合
// - 通过 SharedPreferences mock 控制反疲劳 / 用户评分偏好

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/app_preferences_providers.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/cache_providers.dart';
import 'package:embytok_flutter/providers/embytok_service_provider.dart';
import 'package:embytok_flutter/providers/favorites_provider.dart';
import 'package:embytok_flutter/providers/library_provider.dart';
import 'package:embytok_flutter/providers/recommend_provider.dart';
import 'package:embytok_flutter/providers/recommend_signals.dart';
import 'package:embytok_flutter/repositories/media_repository.dart';
import 'package:embytok_flutter/utils/constants.dart';

import '../mocks/mock_services.dart';

// ============================================================
// 测试辅助类
// ============================================================

/// 固定认证状态的 AuthNotifier（跳过 _loadFromStorage 的异步恢复）
class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(Ref ref, AuthState initialState) : super(ref) {
    state = initialState;
  }
}

/// 固定媒体库 ID 列表的 SelectedLibraryNotifier
/// 构造函数中直接设置 state，避免依赖 SharedPreferences 和 libraryListProvider
class _FixedSelectedLibraryNotifier extends SelectedLibraryNotifier {
  _FixedSelectedLibraryNotifier(Ref ref, List<String> ids) : super(ref) {
    state = ids;
  }
}

/// 固定收藏 ID 集合的 FavoritesNotifier
/// authProvider 初始即已认证，不触发 loadFavorites，state 保持固定值
class _FixedFavoritesNotifier extends FavoritesNotifier {
  _FixedFavoritesNotifier(Ref ref, Set<String> favIds) : super(ref) {
    state = FavoritesState(favoriteIds: favIds);
  }
}

/// MediaRepository 的 Mock 实现
/// 只覆盖推荐测试需要的 6 个方法，其余方法继承 Mock 默认行为
///
/// 注意：所有参数声明为可空类型，以便测试中能用 anyNamed 匹配 required 参数
/// （mockito 5.x 在 Dart 3 严格 null 检查下，anyNamed 返回 Null 无法赋值给非空参数）
class _MockMediaRepository extends Mock implements MediaRepository {
  // ---- NextUp ----
  @override
  Future<PaginatedResponse<MediaItem>> getNextUp({
    String? serverUrl,
    String? token,
    int? limit,
    String? seriesId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getNextUp, [], {
          #serverUrl: serverUrl,
          #token: token,
          #limit: limit,
          #seriesId: seriesId,
        }),
        returnValue: _emptyPage(),
        returnValueForMissingStub: _emptyPage(),
      ) as Future<PaginatedResponse<MediaItem>>;

  // ---- Resume ----
  @override
  Future<PaginatedResponse<MediaItem>> getResumeItems({
    String? serverUrl,
    String? token,
    int? limit,
    int? offset,
    CancelToken? cancelToken,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getResumeItems, [], {
          #serverUrl: serverUrl,
          #token: token,
          #limit: limit,
          #offset: offset,
          #cancelToken: cancelToken,
        }),
        returnValue: _emptyPage(),
        returnValueForMissingStub: _emptyPage(),
      ) as Future<PaginatedResponse<MediaItem>>;

  // ---- Suggestions ----
  @override
  Future<List<MediaItem>> getSuggestions({
    int? limit,
    String? userId,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getSuggestions, [], {
          #limit: limit,
          #userId: userId,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<MediaItem>[]),
        returnValueForMissingStub: Future.value(<MediaItem>[]),
      ) as Future<List<MediaItem>>;

  // ---- Recommendations ----
  @override
  Future<PaginatedResponse<MediaItem>> getRecommendations({
    int? limit,
    int? offset,
    String? libraryId,
    String? userId,
    String? serverUrl,
    String? token,
    double? minCommunityRating,
    bool? excludePlayed,
    Set<String>? includeItemTypes,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getRecommendations, [], {
          #limit: limit,
          #offset: offset,
          #libraryId: libraryId,
          #userId: userId,
          #serverUrl: serverUrl,
          #token: token,
          #minCommunityRating: minCommunityRating,
          #excludePlayed: excludePlayed,
          #includeItemTypes: includeItemTypes,
        }),
        returnValue: _emptyPage(),
        returnValueForMissingStub: _emptyPage(),
      ) as Future<PaginatedResponse<MediaItem>>;

  // ---- SimilarItems ----
  @override
  Future<List<MediaItem>> getSimilarItems(
    String? itemId, {
    int? limit,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getSimilarItems, [itemId], {
          #limit: limit,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<MediaItem>[]),
        returnValueForMissingStub: Future.value(<MediaItem>[]),
      ) as Future<List<MediaItem>>;

  // ---- WatchHistory ----
  @override
  Future<List<MediaItem>> getWatchHistory({
    int? limit,
    String? userId,
    String? serverUrl,
    String? token,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getWatchHistory, [], {
          #limit: limit,
          #userId: userId,
          #serverUrl: serverUrl,
          #token: token,
        }),
        returnValue: Future.value(<MediaItem>[]),
        returnValueForMissingStub: Future.value(<MediaItem>[]),
      ) as Future<List<MediaItem>>;

  static Future<PaginatedResponse<MediaItem>> _emptyPage() {
    return Future.value(PaginatedResponse<MediaItem>(
      items: const <MediaItem>[],
      total: 0,
      offset: 0,
      limit: 0,
    ));
  }
}

// ============================================================
// 测试辅助函数
// ============================================================

/// 构造测试用 MediaItem
/// 默认时长 10 分钟（6000000000 ticks），类型 Movie，确保通过 isVideo 和 isTooShort 检查
MediaItem _item(
  String id, {
  String type = 'Movie',
  int? runtimeTicks,
  double? communityRating,
  double? userRating,
  String? seriesId,
}) {
  return MediaItem(
    id: id,
    title: 'Item $id',
    type: type,
    runtimeTicks: runtimeTicks ?? 6000000000, // 10 分钟
    communityRating: communityRating,
    userData: userRating != null ? UserData(rating: userRating) : null,
    seriesId: seriesId,
  );
}

/// 构造包含指定 items 的 PaginatedResponse
PaginatedResponse<MediaItem> _page(List<MediaItem> items) {
  return PaginatedResponse<MediaItem>(
    items: items,
    total: items.length,
    offset: 0,
    limit: items.length,
  );
}

/// 构造带黑名单的自定义 UserBehaviorSignal
UserBehaviorSignal _signalWithBlacklist(Set<String> blacklist) {
  return UserBehaviorSignal(
    sourceWeights: UserBehaviorSignal.defaults.sourceWeights,
    blacklist: blacklist,
    highCompletionSeeds: const <String>[],
    favoriteSeeds: const <String>[],
    strength: SignalStrength.strong,
  );
}

/// 认证测试状态
const AuthState _testAuthState = AuthState(
  isAuthenticated: true,
  user: User(id: 'user-1', name: 'test', accessToken: 'token-1'),
  embyServerUrl: 'http://emby.test',
  token: 'token-1',
);

/// 创建带全部依赖覆盖的 ProviderContainer
///
/// [repo] Mock 媒体仓库（控制各数据源返回内容）
/// [signal] 用户行为信号（控制黑名单和权重）
/// [favoriteIds] 收藏 ID 集合（控制收藏豁免）
/// [recentlyShownIds] 最近展示过的 itemId 集合（控制反疲劳过滤）
/// [antiFatigueEnabled] 是否启用反疲劳（通过 SharedPreferences 控制）
/// [userRatingEnabled] 是否启用用户评分过滤（通过 SharedPreferences 控制）
/// [userRatingMin] 用户评分阈值（通过 SharedPreferences 控制）
ProviderContainer _createContainer({
  required _MockMediaRepository repo,
  UserBehaviorSignal? signal,
  Set<String> favoriteIds = const {},
  Set<String> recentlyShownIds = const {},
  bool antiFatigueEnabled = true,
  bool userRatingEnabled = true,
  double userRatingMin = 4.0,
}) {
  // 通过 SharedPreferences mock 控制偏好设置
  // recentlyShownIds 以 "itemId:timestamp" 格式存储，timestamp 使用当前时间确保不过期
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  SharedPreferences.setMockInitialValues({
    kStorageKeyRecommendAntiFatigueEnabled: antiFatigueEnabled,
    kStorageKeyRecommendUserRatingEnabled: userRatingEnabled,
    kStorageKeyRecommendUserRatingMin: userRatingMin,
    if (recentlyShownIds.isNotEmpty)
      kStorageKeyRecentlyShownItemIds:
          recentlyShownIds.map((id) => '$id:$now').toList(),
  });

  return ProviderContainer(
    overrides: [
      // EmbytokService mock（AuthNotifier 和 FavoritesNotifier 构造时需要读取）
      embytokServiceProvider.overrideWithValue(MockEmbytokService()),
      // 固定认证状态
      authProvider.overrideWith(
        (ref) => _TestAuthNotifier(ref, _testAuthState),
      ),
      // 媒体库列表返回单个库（避免 SelectedLibraryNotifier 依赖网络）
      libraryListProvider.overrideWith((ref) async {
        return [Library(id: 'lib-1', name: 'Movies', type: 'movies')];
      }),
      // 推荐页选中的媒体库 ID
      recommendLibraryIdsProvider.overrideWith(
        (ref) => _FixedSelectedLibraryNotifier(ref, ['lib-1']),
      ),
      // Mock 媒体仓库（控制各数据源返回内容）
      mediaRepositoryProvider.overrideWithValue(repo),
      // 固定用户行为信号（控制黑名单和权重）
      userBehaviorSignalProvider.overrideWithValue(
        signal ?? UserBehaviorSignal.defaults,
      ),
      // 固定收藏状态（控制收藏豁免）
      favoritesProvider.overrideWith(
        (ref) => _FixedFavoritesNotifier(ref, favoriteIds),
      ),
    ],
  );
}

/// 等待 RecommendNotifier 初始 load() 完成
/// 轮询 isLoading 状态，最多等待 2 秒
///
/// 关键：先预读所有偏好 Provider 触发其构造和异步 _load()，
/// 然后等待 _load() 完成后再读取 recommendProvider，
/// 避免因偏好 Provider 的 _load() 未完成导致 _buildLoadContext 读到默认值。
Future<RecommendState> _waitForLoad(ProviderContainer container) async {
  // 预读所有偏好 Provider，触发其构造 + 异步 _load()
  container.read(recommendAntiFatigueEnabledProvider);
  container.read(recommendAntiFatigueDaysProvider);
  container.read(recommendUserRatingEnabledProvider);
  container.read(recommendUserRatingMinProvider);
  container.read(recentlyShownItemIdsProvider);
  container.read(recommendMinRatingProvider);
  container.read(recommendExcludePlayedProvider);
  container.read(recommendMinRuntimeSecProvider);
  container.read(recommendIncludeTypesProvider);

  // 等待所有偏好 Provider 的异步 _load() 完成
  // SharedPreferences mock 读取是微任务级别，200ms 足够
  await Future<void>.delayed(const Duration(milliseconds: 200));

  // 偏好加载完成后再触发 RecommendNotifier._init() → load()
  container.read(recommendProvider);
  for (int i = 0; i < 200; i++) {
    final state = container.read(recommendProvider);
    if (!state.isLoading) return state;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw TimeoutException('RecommendNotifier.load() 未在 2 秒内完成');
}

/// 检查 state.taggedItems 中是否包含指定 itemId
bool _hasItem(RecommendState state, String itemId) {
  return state.taggedItems.any((r) => r.item.id == itemId);
}

// ============================================================
// 测试用例
// ============================================================

void main() {
  group('_shouldSkipItem 过滤逻辑', () {
    late _MockMediaRepository repo;
    late ProviderContainer container;

    tearDown(() {
      container.dispose();
    });

    test('黑名单中的 item 被过滤', () async {
      // 测试 item：在黑名单中，不在收藏中 → 应被过滤
      final testItem = _item('blacklisted-1');
      // 填充 item：不在黑名单中 → 不被过滤（避免冷启动）
      final fillerItem = _item('filler-1');

      repo = _MockMediaRepository();
      when(repo.getNextUp(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        seriesId: anyNamed('seriesId'),
      )).thenAnswer((_) async => _page([fillerItem]));
      when(repo.getSuggestions(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => [testItem]);
      when(repo.getResumeItems(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getRecommendations(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        libraryId: anyNamed('libraryId'),
        userId: anyNamed('userId'),
        minCommunityRating: anyNamed('minCommunityRating'),
        excludePlayed: anyNamed('excludePlayed'),
        includeItemTypes: anyNamed('includeItemTypes'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSimilarItems(
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);
      when(repo.getWatchHistory(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => []);

      container = _createContainer(
        repo: repo,
        signal: _signalWithBlacklist({'blacklisted-1'}),
        favoriteIds: const {},
      );

      final state = await _waitForLoad(container);

      // 黑名单 item 被过滤
      expect(_hasItem(state, 'blacklisted-1'), false,
          reason: '黑名单中的 item 应被过滤');
      // 填充 item 不受影响
      expect(_hasItem(state, 'filler-1'), true,
          reason: '非黑名单 item 不应被过滤');
    });

    test('黑名单 item 在收藏中时不被过滤（收藏豁免）', () async {
      final testItem = _item('blacklisted-fav');
      final fillerItem = _item('filler-2');

      repo = _MockMediaRepository();
      when(repo.getNextUp(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        seriesId: anyNamed('seriesId'),
      )).thenAnswer((_) async => _page([fillerItem]));
      when(repo.getSuggestions(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => [testItem]);
      when(repo.getResumeItems(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getRecommendations(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        libraryId: anyNamed('libraryId'),
        userId: anyNamed('userId'),
        minCommunityRating: anyNamed('minCommunityRating'),
        excludePlayed: anyNamed('excludePlayed'),
        includeItemTypes: anyNamed('includeItemTypes'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSimilarItems(
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);
      when(repo.getWatchHistory(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => []);

      container = _createContainer(
        repo: repo,
        signal: _signalWithBlacklist({'blacklisted-fav'}),
        // blacklisted-fav 在收藏中 → 豁免黑名单
        favoriteIds: {'blacklisted-fav'},
      );

      final state = await _waitForLoad(container);

      // 收藏豁免：黑名单 item 在收藏中时不被过滤
      expect(_hasItem(state, 'blacklisted-fav'), true,
          reason: '黑名单 item 在收藏中时应被豁免');
    });

    test('recentlyShownIds 中的 item 被过滤（antiFatigueEnabled=true）', () async {
      final testItem = _item('recent-1');
      final fillerItem = _item('filler-3');

      repo = _MockMediaRepository();
      when(repo.getNextUp(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        seriesId: anyNamed('seriesId'),
      )).thenAnswer((_) async => _page([fillerItem]));
      when(repo.getSuggestions(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => [testItem]);
      when(repo.getResumeItems(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getRecommendations(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        libraryId: anyNamed('libraryId'),
        userId: anyNamed('userId'),
        minCommunityRating: anyNamed('minCommunityRating'),
        excludePlayed: anyNamed('excludePlayed'),
        includeItemTypes: anyNamed('includeItemTypes'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSimilarItems(
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);
      when(repo.getWatchHistory(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => []);

      container = _createContainer(
        repo: repo,
        recentlyShownIds: {'recent-1'},
        antiFatigueEnabled: true,
      );

      final state = await _waitForLoad(container);

      // 反疲劳过滤：recent-1 在 recentlyShownIds 中且 antiFatigueEnabled=true
      expect(_hasItem(state, 'recent-1'), false,
          reason: 'recentlyShownIds 中的 item 应被反疲劳过滤');
      expect(_hasItem(state, 'filler-3'), true,
          reason: '非 recentlyShownIds 的 item 不受影响');
    });

    test('recentlyShownIds 中的 item 在收藏中时不被过滤（收藏豁免）', () async {
      final testItem = _item('recent-fav');
      final fillerItem = _item('filler-4');

      repo = _MockMediaRepository();
      when(repo.getNextUp(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        seriesId: anyNamed('seriesId'),
      )).thenAnswer((_) async => _page([fillerItem]));
      when(repo.getSuggestions(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => [testItem]);
      when(repo.getResumeItems(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getRecommendations(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        libraryId: anyNamed('libraryId'),
        userId: anyNamed('userId'),
        minCommunityRating: anyNamed('minCommunityRating'),
        excludePlayed: anyNamed('excludePlayed'),
        includeItemTypes: anyNamed('includeItemTypes'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSimilarItems(
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);
      when(repo.getWatchHistory(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => []);

      container = _createContainer(
        repo: repo,
        recentlyShownIds: {'recent-fav'},
        antiFatigueEnabled: true,
        // recent-fav 在收藏中 → 豁免反疲劳
        favoriteIds: {'recent-fav'},
      );

      final state = await _waitForLoad(container);

      // 收藏豁免：recent-fav 在收藏中时不被反疲劳过滤
      expect(_hasItem(state, 'recent-fav'), true,
          reason: 'recentlyShownIds 中的 item 在收藏中时应被豁免');
    });

    test('antiFatigueEnabled=false 时 recentlyShownIds 不生效', () async {
      final testItem = _item('recent-disabled-1');
      final fillerItem = _item('filler-5');

      repo = _MockMediaRepository();
      when(repo.getNextUp(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        seriesId: anyNamed('seriesId'),
      )).thenAnswer((_) async => _page([fillerItem]));
      when(repo.getSuggestions(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => [testItem]);
      when(repo.getResumeItems(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getRecommendations(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        libraryId: anyNamed('libraryId'),
        userId: anyNamed('userId'),
        minCommunityRating: anyNamed('minCommunityRating'),
        excludePlayed: anyNamed('excludePlayed'),
        includeItemTypes: anyNamed('includeItemTypes'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSimilarItems(
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);
      when(repo.getWatchHistory(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => []);

      container = _createContainer(
        repo: repo,
        recentlyShownIds: {'recent-disabled-1'},
        // 关闭反疲劳
        antiFatigueEnabled: false,
      );

      final state = await _waitForLoad(container);

      // antiFatigueEnabled=false 时，recentlyShownIds 不生效
      expect(_hasItem(state, 'recent-disabled-1'), true,
          reason: 'antiFatigueEnabled=false 时 recentlyShownIds 不应过滤');
    });

    test('用户评分低于阈值的 item 被过滤', () async {
      // userRating=2.0 < userRatingMin=4.0 → 应被过滤
      final testItem = _item('low-rating-1', userRating: 2.0);
      final fillerItem = _item('filler-6');

      repo = _MockMediaRepository();
      when(repo.getNextUp(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        seriesId: anyNamed('seriesId'),
      )).thenAnswer((_) async => _page([fillerItem]));
      when(repo.getSuggestions(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => [testItem]);
      when(repo.getResumeItems(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getRecommendations(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        libraryId: anyNamed('libraryId'),
        userId: anyNamed('userId'),
        minCommunityRating: anyNamed('minCommunityRating'),
        excludePlayed: anyNamed('excludePlayed'),
        includeItemTypes: anyNamed('includeItemTypes'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSimilarItems(
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);
      when(repo.getWatchHistory(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => []);

      container = _createContainer(
        repo: repo,
        userRatingEnabled: true,
        userRatingMin: 4.0,
      );

      final state = await _waitForLoad(container);

      // 用户评分 2.0 < 阈值 4.0 → 被过滤
      expect(_hasItem(state, 'low-rating-1'), false,
          reason: '用户评分低于阈值的 item 应被过滤');
    });

    test('用户评分低于阈值但收藏中的 item 不被过滤（收藏豁免）', () async {
      final testItem = _item('low-rating-fav', userRating: 2.0);
      final fillerItem = _item('filler-7');

      repo = _MockMediaRepository();
      when(repo.getNextUp(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        seriesId: anyNamed('seriesId'),
      )).thenAnswer((_) async => _page([fillerItem]));
      when(repo.getSuggestions(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => [testItem]);
      when(repo.getResumeItems(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getRecommendations(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        libraryId: anyNamed('libraryId'),
        userId: anyNamed('userId'),
        minCommunityRating: anyNamed('minCommunityRating'),
        excludePlayed: anyNamed('excludePlayed'),
        includeItemTypes: anyNamed('includeItemTypes'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSimilarItems(
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);
      when(repo.getWatchHistory(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => []);

      container = _createContainer(
        repo: repo,
        userRatingEnabled: true,
        userRatingMin: 4.0,
        // low-rating-fav 在收藏中 → 豁免用户评分过滤
        favoriteIds: {'low-rating-fav'},
      );

      final state = await _waitForLoad(container);

      // 收藏豁免：用户评分低但在收藏中时不被过滤
      expect(_hasItem(state, 'low-rating-fav'), true,
          reason: '用户评分低于阈值但在收藏中时应被豁免');
    });

    test('userRatingEnabled=false 时用户评分过滤不生效', () async {
      final testItem = _item('low-rating-disabled', userRating: 2.0);
      final fillerItem = _item('filler-8');

      repo = _MockMediaRepository();
      when(repo.getNextUp(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        seriesId: anyNamed('seriesId'),
      )).thenAnswer((_) async => _page([fillerItem]));
      when(repo.getSuggestions(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => [testItem]);
      when(repo.getResumeItems(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getRecommendations(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        libraryId: anyNamed('libraryId'),
        userId: anyNamed('userId'),
        minCommunityRating: anyNamed('minCommunityRating'),
        excludePlayed: anyNamed('excludePlayed'),
        includeItemTypes: anyNamed('includeItemTypes'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSimilarItems(
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);
      when(repo.getWatchHistory(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => []);

      container = _createContainer(
        repo: repo,
        // 关闭用户评分过滤
        userRatingEnabled: false,
        userRatingMin: 4.0,
      );

      final state = await _waitForLoad(container);

      // userRatingEnabled=false 时，用户评分过滤不生效
      expect(_hasItem(state, 'low-rating-disabled'), true,
          reason: 'userRatingEnabled=false 时用户评分过滤不应生效');
    });

    test('userRating=null 的 item 不被用户评分过滤', () async {
      // userRating 未设置（null）→ 不被过滤
      final testItem = _item('no-rating-1'); // userData=null → userRating=null
      final fillerItem = _item('filler-9');

      repo = _MockMediaRepository();
      when(repo.getNextUp(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        seriesId: anyNamed('seriesId'),
      )).thenAnswer((_) async => _page([fillerItem]));
      when(repo.getSuggestions(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => [testItem]);
      when(repo.getResumeItems(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getRecommendations(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        libraryId: anyNamed('libraryId'),
        userId: anyNamed('userId'),
        minCommunityRating: anyNamed('minCommunityRating'),
        excludePlayed: anyNamed('excludePlayed'),
        includeItemTypes: anyNamed('includeItemTypes'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSimilarItems(
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);
      when(repo.getWatchHistory(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => []);

      container = _createContainer(
        repo: repo,
        userRatingEnabled: true,
        userRatingMin: 4.0,
      );

      final state = await _waitForLoad(container);

      // userRating=null → 不被用户评分过滤
      expect(_hasItem(state, 'no-rating-1'), true,
          reason: 'userRating=null 的 item 不应被用户评分过滤');
    });
  });

  group('_mergeRoundRobin 多源合并 + 去重', () {
    late _MockMediaRepository repo;
    late ProviderContainer container;

    tearDown(() {
      container.dispose();
    });

    test('多源数据轮转合并：各数据源 item 均出现在结果中', () async {
      // 3 个数据源各返回 2 个 item，使用默认权重（1.0）
      // round-robin 每轮各取 1 个，最终 6 个 item 都应出现
      final nextUpItems = [_item('nu-1'), _item('nu-2')];
      final resumeItems = [_item('re-1'), _item('re-2')];
      final suggestionItems = [_item('sg-1'), _item('sg-2')];

      repo = _MockMediaRepository();
      when(repo.getNextUp(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        seriesId: anyNamed('seriesId'),
      )).thenAnswer((_) async => _page(nextUpItems));
      when(repo.getResumeItems(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => _page(resumeItems));
      when(repo.getSuggestions(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => suggestionItems);
      when(repo.getRecommendations(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        libraryId: anyNamed('libraryId'),
        userId: anyNamed('userId'),
        minCommunityRating: anyNamed('minCommunityRating'),
        excludePlayed: anyNamed('excludePlayed'),
        includeItemTypes: anyNamed('includeItemTypes'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSimilarItems(
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);
      when(repo.getWatchHistory(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => []);

      container = _createContainer(
        repo: repo,
        // 使用默认信号（所有权重 1.0，无黑名单）
        signal: UserBehaviorSignal.defaults,
      );

      final state = await _waitForLoad(container);

      // 验证所有 6 个 item 都出现在结果中
      for (final id in ['nu-1', 'nu-2', 're-1', 're-2', 'sg-1', 'sg-2']) {
        expect(_hasItem(state, id), true, reason: 'item $id 应在合并结果中');
      }

      // 验证 tagCounts 反映各数据源的 item 数量
      expect(state.tagCounts['nextUp'], 2);
      expect(state.tagCounts['resume'], 2);
      expect(state.tagCounts['suggestions'], 2);
    });

    test('相同 itemId 跨源去重：只出现一次', () async {
      // 两个数据源返回相同 id 的 item
      final nextUpItems = [_item('dup-1'), _item('nu-unique')];
      final suggestionItems = [_item('dup-1'), _item('sg-unique')];

      repo = _MockMediaRepository();
      when(repo.getNextUp(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        seriesId: anyNamed('seriesId'),
      )).thenAnswer((_) async => _page(nextUpItems));
      when(repo.getResumeItems(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSuggestions(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => suggestionItems);
      when(repo.getRecommendations(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        libraryId: anyNamed('libraryId'),
        userId: anyNamed('userId'),
        minCommunityRating: anyNamed('minCommunityRating'),
        excludePlayed: anyNamed('excludePlayed'),
        includeItemTypes: anyNamed('includeItemTypes'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSimilarItems(
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);
      when(repo.getWatchHistory(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => []);

      container = _createContainer(
        repo: repo,
        signal: UserBehaviorSignal.defaults,
      );

      final state = await _waitForLoad(container);

      // dup-1 只出现一次（去重）
      final dupCount =
          state.taggedItems.where((r) => r.item.id == 'dup-1').length;
      expect(dupCount, 1, reason: '相同 itemId 跨源应去重，只出现一次');

      // 唯一 item 也出现
      expect(_hasItem(state, 'nu-unique'), true);
      expect(_hasItem(state, 'sg-unique'), true);

      // 总数为 3（dup-1 + nu-unique + sg-unique），不是 4
      expect(state.taggedItems.length, 3,
          reason: '去重后总 item 数应为 3');
    });
  });

  group('_PageLoadResult 新字段验证', () {
    late _MockMediaRepository repo;
    late ProviderContainer container;

    tearDown(() {
      container.dispose();
    });

    test('suggestionsCount 反映 Suggestions 数据源项数', () async {
      // Suggestions 返回 3 个 item，其他源为空（避免冷启动需 NextUp 有数据）
      final nextUpItems = [_item('nu-filler')];
      final suggestionItems = [_item('sg-1'), _item('sg-2'), _item('sg-3')];

      repo = _MockMediaRepository();
      when(repo.getNextUp(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        seriesId: anyNamed('seriesId'),
      )).thenAnswer((_) async => _page(nextUpItems));
      when(repo.getResumeItems(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSuggestions(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => suggestionItems);
      when(repo.getRecommendations(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        libraryId: anyNamed('libraryId'),
        userId: anyNamed('userId'),
        minCommunityRating: anyNamed('minCommunityRating'),
        excludePlayed: anyNamed('excludePlayed'),
        includeItemTypes: anyNamed('includeItemTypes'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSimilarItems(
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);
      when(repo.getWatchHistory(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => []);

      container = _createContainer(
        repo: repo,
        signal: UserBehaviorSignal.defaults,
      );

      final state = await _waitForLoad(container);

      // tagCounts['suggestions'] 反映 Suggestions 数据源的 item 数
      expect(state.tagCounts['suggestions'], 3,
          reason: 'suggestionsCount 应反映 Suggestions 数据源项数');
    });

    test('所有数据源都返回空时 hasMore=false（allSourcesExhausted=true）', () async {
      repo = _MockMediaRepository();
      when(repo.getNextUp(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        seriesId: anyNamed('seriesId'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getResumeItems(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSuggestions(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => []);
      when(repo.getRecommendations(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        libraryId: anyNamed('libraryId'),
        userId: anyNamed('userId'),
        minCommunityRating: anyNamed('minCommunityRating'),
        excludePlayed: anyNamed('excludePlayed'),
        includeItemTypes: anyNamed('includeItemTypes'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSimilarItems(
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);
      when(repo.getWatchHistory(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => []);

      container = _createContainer(
        repo: repo,
        signal: UserBehaviorSignal.defaults,
      );

      final state = await _waitForLoad(container);

      // 所有数据源为空 → allSourcesExhausted=true → hasMore=false
      expect(state.hasMore, false,
          reason: '所有数据源耗尽时 hasMore 应为 false');
      // 冷启动（NextUp + Resume + Suggestions 都为空）
      expect(state.isColdStart, true,
          reason: '所有主要数据源为空时应判定为冷启动');
      // taggedItems 为空（降级推荐也为空）
      expect(state.taggedItems, isEmpty,
          reason: '所有数据源为空时结果应为空');
    });

    test('任一数据源有数据时 hasMore=true', () async {
      // 只有 Suggestions 有数据，其他源为空
      final suggestionItems = [_item('sg-hasmore-1')];

      repo = _MockMediaRepository();
      when(repo.getNextUp(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        seriesId: anyNamed('seriesId'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getResumeItems(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSuggestions(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => suggestionItems);
      when(repo.getRecommendations(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        libraryId: anyNamed('libraryId'),
        userId: anyNamed('userId'),
        minCommunityRating: anyNamed('minCommunityRating'),
        excludePlayed: anyNamed('excludePlayed'),
        includeItemTypes: anyNamed('includeItemTypes'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSimilarItems(
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);
      when(repo.getWatchHistory(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => []);

      container = _createContainer(
        repo: repo,
        signal: UserBehaviorSignal.defaults,
      );

      final state = await _waitForLoad(container);

      // Suggestions 有数据 → allSourcesExhausted=false → hasMore=true
      expect(state.hasMore, true,
          reason: '任一数据源有数据时 hasMore 应为 true');
      // 非冷启动（Suggestions 非空）
      expect(state.isColdStart, false,
          reason: 'Suggestions 有数据时不应判定为冷启动');
      expect(_hasItem(state, 'sg-hasmore-1'), true);
    });

    test('冷启动判定包含 Suggestions 数据源', () async {
      // NextUp 有数据，Resume 和 Suggestions 为空 → 非冷启动
      // 验证 Suggestions 参与冷启动判定（而非仅 NextUp + Resume）
      final nextUpItems = [_item('nu-cold-1')];

      repo = _MockMediaRepository();
      when(repo.getNextUp(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        seriesId: anyNamed('seriesId'),
      )).thenAnswer((_) async => _page(nextUpItems));
      when(repo.getResumeItems(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        cancelToken: anyNamed('cancelToken'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSuggestions(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => []);
      when(repo.getRecommendations(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        libraryId: anyNamed('libraryId'),
        userId: anyNamed('userId'),
        minCommunityRating: anyNamed('minCommunityRating'),
        excludePlayed: anyNamed('excludePlayed'),
        includeItemTypes: anyNamed('includeItemTypes'),
      )).thenAnswer((_) async => _page([]));
      when(repo.getSimilarItems(
        any,
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => []);
      when(repo.getWatchHistory(
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        limit: anyNamed('limit'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => []);

      container = _createContainer(
        repo: repo,
        signal: UserBehaviorSignal.defaults,
      );

      final state = await _waitForLoad(container);

      // NextUp 有数据 → 非冷启动（即使 Resume 和 Suggestions 为空）
      expect(state.isColdStart, false,
          reason: 'NextUp 有数据时不应判定为冷启动');
      expect(_hasItem(state, 'nu-cold-1'), true);
    });
  });
}
