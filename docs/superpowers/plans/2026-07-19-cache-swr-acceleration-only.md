# 缓存只做加速：SWR 模式重构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将数据缓存从「TTL 直出」改为「SWR（Stale-While-Revalidate）模式」——联网时缓存仅作为加速首屏的占位，始终发起网络请求并以 Emby 返回数据为准，彻底避免数据不一致。

**Architecture:**
- 底层：`CachedMediaRepository` 新增 `peekXxx` 同步纯缓存读取方法，供 SWR 场景调用
- 业务层：各 Provider/View 的首屏加载改为「先 peek 缓存展示 → 后台发网络请求 → 结果回来更新状态」
- 图片缓存（海报/背景图/Logo）保持现状——Emby 图片 URL 含版本标识，缓存天然只做加速
- 断网/离线：纯缓存降级（与现有行为一致）

**Tech Stack:** Flutter 3.x, Dart 3.x, flutter_riverpod, MemoryCache（现有 LRU+TTL）, CachedNetworkImage（现有图片缓存）

---

## 1. 背景与原则

### 核心原则
**缓存只做加速，不做真相源。**

- **有网时**：缓存用于加速首屏显示（毫秒级显示占位数据），但始终发起网络请求，以 Emby 返回的最新数据为准
- **断网时**：缓存作为降级方案，纯缓存模式
- **图片缓存**：海报、背景图、Logo 等静态资源天然是「加速」性质，Emby 图片 URL 含版本标识（ImageTag），缓存不会导致数据不一致，保持现有策略

### 当前架构问题
1. **TTL 直出模式**：`CachedMediaRepository.getXxx()` 命中缓存直接返回，TTL 内不会发起网络请求——用户可能看到过时数据
2. **失效覆盖不完整**：依赖手动 `invalidateXxx()`，写操作（收藏、标记已看）后有遗漏风险
3. **视频流 FeedView 走缓存**：`video_list_notifier.dart` 第 49 行默认使用 `cachedMediaRepositoryProvider`，切换 FeedType 时可能显示旧数据

### 改造范围（按优先级）
| 优先级 | 场景 | 方法 | 说明 |
|--------|------|------|------|
| P0 | FeedView 视频流 | SWR（本计划） | 用户最高频场景 |
| P1 | 收藏页（三栏） | SWR（本计划） | 第二高频场景 |
| P2 | 网格首页/推荐页/演员页/历史页 | SWR（扩展方向） | 模式同上，按需扩展 |
| P3 | 详情页/合集详情/演员详情 | SWR（扩展方向） | 详情页数据变化少 |
| - | 图片缓存 | 不变 | 天然加速性质 |
| - | 元数据（libraries/genres/studios） | 短 TTL 即可 | 极少变化 |

### 非目标
- 不引入新的持久化存储（数据库、Hive 等）——保持纯内存缓存
- 不重构图片缓存
- 不实现离线模式的完整 CRUD

---

## 2. 文件结构映射

| 文件 | 操作 | 职责 |
|------|------|------|
| `frontend/lib/repositories/cached_media_repository.dart` | 修改 | 新增 `peekLibraryItems` / `peekFavoriteMovies` 等同步纯缓存方法 |
| `frontend/lib/providers/video_list_notifier.dart` | 修改 | FeedType.latest 首屏改为 SWR 模式 |
| `frontend/lib/providers/favorites_provider.dart` | 修改 | 收藏页三栏首屏改为 SWR 模式 |
| `frontend/test/repositories/cached_media_repository_test.dart` | 修改 | 新增 peek 方法 + SWR 逻辑测试 |

---

## 3. Phase 1：底层能力 — peek 方法

### Task 1.1：peekLibraryItems 纯缓存读取

**Files:**
- Modify: `frontend/lib/repositories/cached_media_repository.dart`（在 `getLibraryItems` 方法之后添加）
- Test: `frontend/test/repositories/cached_media_repository_test.dart`

- [ ] **Step 1: 写失败测试**

在测试文件的 `main()` 内追加：
```dart
  group('peekLibraryItems', () {
    late MockEmbytokService mockService;
    late CachedMediaRepository cachedRepo;
    const serverUrl = 'https://test.emby';
    const token = 'test-token';

    setUp(() {
      mockService = MockEmbytokService();
      cachedRepo = CachedMediaRepository(
        EmbyRepository(mockService),
        ttl: const Duration(minutes: 5),
        maxCacheEntries: 10,
      );
    });

    test('缓存未命中时返回 null', () {
      final result = cachedRepo.peekLibraryItems(
        const MediaQueryParams(libraryId: 'lib1', limit: 10, offset: 0),
        serverUrl: serverUrl,
        token: token,
      );
      expect(result, isNull);
    });

    test('缓存命中时返回数据，不触发网络请求', () async {
      final items = [_fakeItem('1', '测试视频')];
      final resp = PaginatedResponse(items: items, totalRecordCount: 1);

      // 先通过 getLibraryItems 写入缓存
      when(mockService.getLibraryItems(
        parentId: anyNamed('parentId'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        filters: anyNamed('filters'),
        sortBy: anyNamed('sortBy'),
        sortOrder: anyNamed('sortOrder'),
      )).thenAnswer((_) async => resp);
      await cachedRepo.getLibraryItems(
        const MediaQueryParams(libraryId: 'lib1', limit: 10, offset: 0),
        serverUrl: serverUrl,
        token: token,
      );

      // peek 应返回缓存数据
      final result = cachedRepo.peekLibraryItems(
        const MediaQueryParams(libraryId: 'lib1', limit: 10, offset: 0),
        serverUrl: serverUrl,
        token: token,
      );
      expect(result, isNotNull);
      expect(result!.items.length, 1);
      expect(result.items.first.name, '测试视频');

      // 验证没有触发新的网络请求（getLibraryItems 只被调用了一次）
      verify(mockService.getLibraryItems(
        parentId: anyNamed('parentId'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        filters: anyNamed('filters'),
        sortBy: anyNamed('sortBy'),
        sortOrder: anyNamed('sortOrder'),
      )).called(1);
    });

    test('过期缓存返回 null', () async {
      final items = [_fakeItem('1', '测试')];
      final resp = PaginatedResponse(items: items, totalRecordCount: 1);
      when(mockService.getLibraryItems(
        parentId: anyNamed('parentId'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        filters: anyNamed('filters'),
        sortBy: anyNamed('sortBy'),
        sortOrder: anyNamed('sortOrder'),
      )).thenAnswer((_) async => resp);

      // 使用 0 秒 TTL，写入后立即过期
      final shortRepo = CachedMediaRepository(
        EmbyRepository(mockService),
        ttl: Duration.zero,
        maxCacheEntries: 10,
      );
      await shortRepo.getLibraryItems(
        const MediaQueryParams(libraryId: 'lib1', limit: 10, offset: 0),
        serverUrl: serverUrl,
        token: token,
      );
      // 等 1ms 确保过期
      await Future.delayed(const Duration(milliseconds: 1));
      final result = shortRepo.peekLibraryItems(
        const MediaQueryParams(libraryId: 'lib1', limit: 10, offset: 0),
        serverUrl: serverUrl,
        token: token,
      );
      expect(result, isNull);
    });
  });
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd /workspace/frontend && /opt/flutter/bin/flutter test test/repositories/cached_media_repository_test.dart -n peekLibraryItems`
Expected: 编译失败（`peekLibraryItems` 未定义）

- [ ] **Step 3: 实现 peekLibraryItems 方法**

在 `CachedMediaRepository` 类中、`getLibraryItems` 方法（第 355 行后）添加：
```dart
  /// 纯缓存读取：偷看媒体库条目（同步，不触发网络请求）
  ///
  /// 用于 SWR 模式：先同步读取缓存展示，然后独立发起网络请求刷新。
  /// 缓存未命中或已过期时返回 null。
  ///
  /// 此方法会更新 LRU 顺序和命中计数（缓存确实被用到了）。
  PaginatedResponse<MediaItem>? peekLibraryItems(
    MediaQueryParams params, {
    required String serverUrl,
    required String token,
  }) {
    final key = _libraryItemsKey(params, serverUrl, token);
    return _libraryItemsCache.get(key);
  }
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd /workspace/frontend && /opt/flutter/bin/flutter test test/repositories/cached_media_repository_test.dart -n peekLibraryItems`
Expected: PASS（3 个测试通过）

- [ ] **Step 5: Commit**

```bash
cd /workspace
git add frontend/lib/repositories/cached_media_repository.dart frontend/test/repositories/cached_media_repository_test.dart
git commit -m "feat(cache): 新增 peekLibraryItems 纯缓存读取方法

同步读取缓存，不触发网络请求，用于 SWR 模式的缓存占位阶段。
支持 TTL 过期检查和 LRU 顺序更新。"
```

### Task 1.2：peekFavoriteMovies / peekFavoriteBoxSets / peekFavoritePeople

**Files:**
- Modify: `frontend/lib/repositories/cached_media_repository.dart`
- Test: `frontend/test/repositories/cached_media_repository_test.dart`

收藏页有三栏（影片/合集/人物），需要三个 peek 方法。模式同 peekLibraryItems。

- [ ] **Step 1: 写失败测试**

在测试文件 main() 内追加：
```dart
  group('peek 收藏三栏', () {
    late MockEmbytokService mockService;
    late CachedMediaRepository cachedRepo;
    const serverUrl = 'https://test.emby';
    const token = 'test-token';
    const userId = 'user1';

    setUp(() {
      mockService = MockEmbytokService();
      cachedRepo = CachedMediaRepository(
        EmbyRepository(mockService),
        ttl: const Duration(minutes: 5),
        maxCacheEntries: 20,
      );
    });

    test('peekFavoriteMovies 缓存未命中返回 null', () {
      final result = cachedRepo.peekFavoriteMovies(
        serverUrl: serverUrl,
        token: token,
        userId: userId,
        limit: 50,
        offset: 0,
      );
      expect(result, isNull);
    });

    test('peekFavoriteMovies 缓存命中返回数据', () async {
      final items = [_fakeItem('1', '收藏电影')];
      final resp = FavoritesPageResult(items: items, totalCount: 1);
      when(mockService.getFavoriteMovies(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => resp);
      await cachedRepo.getFavoriteMovies(
        serverUrl: serverUrl,
        token: token,
        userId: userId,
        limit: 50,
        offset: 0,
      );

      final result = cachedRepo.peekFavoriteMovies(
        serverUrl: serverUrl,
        token: token,
        userId: userId,
        limit: 50,
        offset: 0,
      );
      expect(result, isNotNull);
      expect(result!.items.first.name, '收藏电影');
    });
  });
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd /workspace/frontend && /opt/flutter/bin/flutter test test/repositories/cached_media_repository_test.dart -n "peek 收藏三栏"`
Expected: 编译失败

- [ ] **Step 3: 实现三个 peek 方法**

在 `CachedMediaRepository` 类中、对应 get 方法之后分别添加：
```dart
  /// 纯缓存读取：偷看收藏影片（同步，不触发网络）
  FavoritesPageResult? peekFavoriteMovies({
    required String serverUrl,
    required String token,
    String? userId,
    int limit = 50,
    int offset = 0,
  }) {
    final key = _favoritesKey(serverUrl, token, userId, limit, offset);
    return _favoritesCache.get(key);
  }

  /// 纯缓存读取：偷看收藏合集（同步，不触发网络）
  FavoritesPageResult? peekFavoriteBoxSets({
    required String serverUrl,
    required String token,
    String? userId,
    int limit = 50,
    int offset = 0,
  }) {
    final key = _boxSetsFavoritesKey(serverUrl, token, userId, limit, offset);
    return _boxSetsFavoritesCache.get(key);
  }

  /// 纯缓存读取：偷看收藏人物（同步，不触发网络）
  FavoritesPageResult? peekFavoritePeople({
    required String serverUrl,
    required String token,
    String? userId,
    int limit = 50,
    int offset = 0,
  }) {
    final key = _favoritesKey('_people', serverUrl, token, userId, limit, offset);
    return _favoritePeopleCache.get(key);
  }
```

**注意**：收藏人物的缓存键生成方法名可能不同（`_favoritePeopleKey` 或其他），需根据实际 `_favoritePeopleCache` 的 key 生成方法调整。执行时请先确认 `_favoritePeopleCache` 对应的 key 生成方法名。

- [ ] **Step 4: 运行测试验证通过**

Run: `cd /workspace/frontend && /opt/flutter/bin/flutter test test/repositories/cached_media_repository_test.dart -n "peek 收藏"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /workspace
git add frontend/lib/repositories/cached_media_repository.dart frontend/test/repositories/cached_media_repository_test.dart
git commit -m "feat(cache): 新增收藏三栏 peek 纯缓存读取方法

为收藏页 SWR 改造准备底层能力：peekFavoriteMovies / peekFavoriteBoxSets / peekFavoritePeople。"
```

---

## 4. Phase 2：FeedView 视频流接入 SWR

### Task 2.1：video_list_notifier 改为 SWR 模式

**Files:**
- Modify: `frontend/lib/providers/video_list_notifier.dart`

**背景**：
- `VideoListNotifier` 构造函数默认使用 `cachedMediaRepositoryProvider`（第 49 行）
- `refresh()` 方法（第 187 行）是首屏加载入口，当前直接 `await _repo.getLibraryItems(...)`
- 只改造 `FeedType.latest` 路径（视频流主场景，第 236-288 行），其他 FeedType 暂不改造
- `loadMore` 方法保持不变

- [ ] **Step 1: 确认当前代码无错误**

Run: `cd /workspace/frontend && /opt/flutter/bin/flutter analyze lib/providers/video_list_notifier.dart`
Expected: 0 errors

- [ ] **Step 2: 在文件顶部添加 SWR 辅助类型**

在 `import` 之后、`gridSearchQueryProvider` 之前添加：
```dart
/// SWR 模式首屏加载结果（FeedType.latest 多库混合场景）
///
/// 包含缓存占位数据和网络请求 Future。
/// 多库混合时按库分别读取缓存/发起请求，结果合并去重。
class _SWRLibraryResult {
  final List<MediaItem>? cachedItems;
  final int cachedTotal;
  final Future<_SWRLibraryFreshResult> freshFuture;

  const _SWRLibraryResult({
    required this.cachedItems,
    required this.cachedTotal,
    required this.freshFuture,
  });

  bool get hasCache => cachedItems != null;
}

/// SWR 网络请求结果
class _SWRLibraryFreshResult {
  final List<MediaItem> items;
  final int total;
  final bool allFailed;

  const _SWRLibraryFreshResult({
    required this.items,
    required this.total,
    required this.allFailed,
  });
}
```

- [ ] **Step 3: 在 VideoListNotifier 类中新增 _loadLatestSWR 方法**

在 `refresh()` 方法之前添加：
```dart
  /// SWR 模式加载最新视频（FeedType.latest 多库混合）
  ///
  /// 先从缓存读取并立即展示（加速首屏），然后发起网络请求获取最新数据。
  /// 始终以网络返回的最新数据为准，缓存仅做加速。
  _SWRLibraryResult _loadLatestSWR({
    required List<String> libIds,
    required String serverUrl,
    required String token,
    required String? userId,
    required int limit,
    required String sortBy,
    required String sortOrder,
    required bool excludePlayed,
    String? searchTerm,
  }) {
    final cachedRepo = _ref.read(cachedMediaRepositoryProvider);
    final seenIds = <String, MediaItem>{};
    int totalItems = 0;
    bool hasCache = false;

    // 第一步：同步读取所有库的缓存，合并去重
    for (final libId in libIds) {
      final cachedResult = cachedRepo.peekLibraryItems(
        MediaQueryParams(
          libraryId: libId,
          limit: limit,
          offset: 0,
          sortBy: sortBy,
          sortOrder: sortOrder,
          searchTerm: searchTerm?.isEmpty == true ? null : searchTerm,
          excludePlayed: excludePlayed,
        ),
        serverUrl: serverUrl,
        token: token,
      );
      if (cachedResult != null) {
        hasCache = true;
        for (final item in cachedResult.items) {
          if (!seenIds.containsKey(item.id)) {
            seenIds[item.id] = item;
          }
        }
        totalItems += cachedResult.total;
        _libraryLoadedCounts[libId] = cachedResult.items.length;
      }
    }

    // 第二步：发起网络请求获取最新数据
    final freshFuture = () async {
      final freshSeenIds = <String, MediaItem>{};
      int freshTotal = 0;
      int failedCount = 0;
      for (final libId in libIds) {
        try {
          final resp = await _repo.getLibraryItems(
            MediaQueryParams(
              libraryId: libId,
              limit: limit,
              offset: 0,
              sortBy: sortBy,
              sortOrder: sortOrder,
              searchTerm: searchTerm?.isEmpty == true ? null : searchTerm,
              excludePlayed: excludePlayed,
            ),
            serverUrl: serverUrl,
            token: token,
            userId: userId,
          );
          for (final item in resp.items) {
            if (!freshSeenIds.containsKey(item.id)) {
              freshSeenIds[item.id] = item;
            }
          }
          _libraryLoadedCounts[libId] = resp.items.length;
          freshTotal += resp.total;
        } catch (e) {
          failedCount++;
          _libraryLoadedCounts[libId] = 0;
          AppLogger.error('SWR: 加载库 $libId 失败', error: e);
        }
      }
      return _SWRLibraryFreshResult(
        items: freshSeenIds.values.toList(),
        total: freshTotal,
        allFailed: failedCount == libIds.length,
      );
    }();

    return _SWRLibraryResult(
      cachedItems: hasCache ? seenIds.values.toList() : null,
      cachedTotal: totalItems,
      freshFuture: freshFuture,
    );
  }
```

- [ ] **Step 4: 修改 refresh 方法的 FeedType.latest 路径**

将 `case FeedType.latest:` 块（原 236-288 行）替换为：
```dart
        case FeedType.latest:
          final libIds = selectedIds;
          if (libIds.isEmpty) {
            state = state.copyWith(isLoading: false, hasMore: false);
            return;
          }
          _libraryLoadedCounts.clear();

          final swr = _loadLatestSWR(
            libIds: libIds,
            serverUrl: serverUrl,
            token: token,
            userId: userId,
            limit: state.limit,
            sortBy: state.sortBy,
            sortOrder: state.sortOrder,
            excludePlayed: _ref.read(feedExcludePlayedProvider),
            searchTerm: state.searchTerm.isEmpty ? null : state.searchTerm,
          );

          // 有缓存：立即展示缓存数据，仍显示 loading 指示（数据可能过时）
          if (swr.hasCache) {
            state = state.copyWith(
              items: swr.cachedItems!,
              gridItems: swr.cachedItems!,
              isLoading: true,
              hasMore: swr.cachedTotal > swr.cachedItems!.length,
              totalCount: swr.cachedTotal,
              error: null,
            );
          }

          // 等待最新数据
          try {
            final fresh = await swr.freshFuture;
            if (fresh.allFailed) {
              // 所有库都失败：有缓存则保留缓存并清 loading，无缓存则报错
              if (swr.hasCache) {
                state = state.copyWith(isLoading: false);
              } else {
                state = state.copyWith(
                  isLoading: false,
                  error: AppError.network(
                    message: '所有媒体库均加载失败，请检查网络连接',
                  ),
                );
              }
            } else {
              state = state.copyWith(
                items: fresh.items,
                gridItems: fresh.items,
                isLoading: false,
                hasMore: fresh.total > fresh.items.length,
                totalCount: fresh.total,
                error: null,
              );
            }
          } catch (e) {
            if (swr.hasCache) {
              state = state.copyWith(isLoading: false);
            } else {
              state = state.copyWith(
                isLoading: false,
                error: AppError.network(message: e.toString()),
              );
            }
          }
          loadedItems = state.items;
          loadedTotal = state.totalCount;
          canPaginate = true;
          break;
```

**注意**：原代码中 `loadedItems`、`loadedTotal`、`canPaginate` 是 switch 外的变量，在 break 之前赋值供后续使用。需确保这些变量在 SWR 路径中正确赋值。

- [ ] **Step 5: 运行 analyze 验证无错误**

Run: `cd /workspace/frontend && /opt/flutter/bin/flutter analyze lib/providers/video_list_notifier.dart`
Expected: 0 errors

- [ ] **Step 6: Commit**

```bash
cd /workspace
git add frontend/lib/providers/video_list_notifier.dart
git commit -m "perf(feed): 视频流首屏接入 SWR 缓存模式

FeedType.latest 采用 Stale-While-Revalidate：
先展示缓存数据加速首屏，后台请求 Emby 最新数据，
最终以服务器数据为准，缓存仅做加速。"
```

---

## 5. Phase 3：收藏页接入 SWR

### Task 3.1：favorites_provider 改为 SWR 模式

**Files:**
- Modify: `frontend/lib/providers/favorites_provider.dart`

**背景**：
- `loadFavorites()` 方法（第 183 行）并行拉取三栏收藏（影片/合集/人物）
- 当前直接 `await cachedRepo.getFavoriteMovies()` 等，命中缓存则返回旧数据
- 改为 SWR：先同步 peek 三栏缓存并立即展示，然后并行发起网络请求更新

- [ ] **Step 1: 确认当前代码无错误**

Run: `cd /workspace/frontend && /opt/flutter/bin/flutter analyze lib/providers/favorites_provider.dart`
Expected: 0 errors

- [ ] **Step 2: 修改 loadFavorites 方法为 SWR 模式**

将 `loadFavorites()` 方法体（第 183-312 行）替换为：
```dart
  Future<void> loadFavorites() async {
    if (_isLoading) return;

    _isLoading = true;
    state = state.copyWith(
      isLoading: true,
      error: null,
      moviesError: null,
      boxSetsError: null,
      peopleError: null,
    );
    AppLogger.info('加载收藏列表（三栏，SWR 模式）');

    final auth = _auth;
    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
      _isLoading = false;
      state = state.copyWith(isLoading: false, error: '尚未登录');
      return;
    }

    final serverUrl = auth.embyServerUrl!;
    final token = auth.token!;
    final userId = auth.user?.id;
    final cachedRepo = _ref.read(cachedMediaRepositoryProvider);

    // ===== SWR 第一步：同步读取缓存，立即展示 =====
    List<MediaItem>? cachedMovies;
    List<MediaItem>? cachedBoxSets;
    List<MediaItem>? cachedPeople;
    int cachedMoviesTotal = 0;
    int cachedBoxSetsTotal = 0;
    int cachedPeopleTotal = 0;
    bool hasAnyCache = false;

    // 影片
    final cachedMoviesResult = cachedRepo.peekFavoriteMovies(
      serverUrl: serverUrl,
      token: token,
      userId: userId,
      limit: _kFavoritesPageSize,
      offset: 0,
    );
    if (cachedMoviesResult != null) {
      cachedMovies = cachedMoviesResult.items;
      cachedMoviesTotal = cachedMoviesResult.totalCount;
      hasAnyCache = true;
    }

    // 合集
    final cachedBoxSetsResult = cachedRepo.peekFavoriteBoxSets(
      serverUrl: serverUrl,
      token: token,
      userId: userId,
      limit: _kFavoritesPageSize,
      offset: 0,
    );
    if (cachedBoxSetsResult != null) {
      cachedBoxSets = cachedBoxSetsResult.items;
      cachedBoxSetsTotal = cachedBoxSetsResult.totalCount;
      hasAnyCache = true;
    }

    // 人物
    final cachedPeopleResult = cachedRepo.peekFavoritePeople(
      serverUrl: serverUrl,
      token: token,
      userId: userId,
      limit: _kFavoritesPageSize,
      offset: 0,
    );
    if (cachedPeopleResult != null) {
      cachedPeople = cachedPeopleResult.items;
      cachedPeopleTotal = cachedPeopleResult.totalCount;
      hasAnyCache = true;
    }

    // 有缓存则立即展示（isLoading 仍为 true，表示数据可能过时）
    if (hasAnyCache) {
      final cachedIds = _mergeIds(
        cachedMovies ?? const <MediaItem>[],
        cachedBoxSets ?? const <MediaItem>[],
        cachedPeople ?? const <MediaItem>[],
      );
      state = FavoritesState(
        movies: cachedMovies ?? const <MediaItem>[],
        boxSets: cachedBoxSets ?? const <MediaItem>[],
        people: cachedPeople ?? const <MediaItem>[],
        isLoading: true,
        error: null,
        favoriteIds: cachedIds,
        hasMoreMovies: cachedMoviesTotal > (cachedMovies?.length ?? 0),
        hasMoreBoxSets: cachedBoxSetsTotal > (cachedBoxSets?.length ?? 0),
        hasMorePeople: cachedPeopleTotal > (cachedPeople?.length ?? 0),
      );
    }

    // ===== SWR 第二步：并行发起网络请求 =====
    List<MediaItem> movies = cachedMovies ?? [];
    List<MediaItem> boxSets = cachedBoxSets ?? [];
    List<MediaItem> people = cachedPeople ?? [];
    String? moviesError;
    String? boxSetsError;
    String? peopleError;
    int moviesTotal = cachedMoviesTotal;
    int boxSetsTotal = cachedBoxSetsTotal;
    int peopleTotal = cachedPeopleTotal;

    await Future.wait<void>([
      // 收藏影片
      () async {
        try {
          final result = await _ref.read(cachedMediaRepositoryProvider).getFavoriteMovies(
            limit: _kFavoritesPageSize,
            offset: 0,
            serverUrl: serverUrl,
            token: token,
            userId: userId,
          );
          movies = result.items;
          moviesTotal = result.totalCount;
          _moviesLoaded = movies.length;
        } catch (e) {
          moviesError = e is String ? e : '加载失败：$e';
          AppLogger.error('加载收藏影片失败', error: e);
        }
      }(),
      // 收藏合集
      () async {
        try {
          final result = await _ref.read(cachedMediaRepositoryProvider).getFavoriteBoxSets(
            limit: _kFavoritesPageSize,
            offset: 0,
            serverUrl: serverUrl,
            token: token,
            userId: userId,
          );
          boxSets = result.items;
          boxSetsTotal = result.totalCount;
          _boxSetsLoaded = boxSets.length;
        } catch (e) {
          boxSetsError = e is String ? e : '加载失败：$e';
          AppLogger.error('加载收藏合集失败', error: e);
        }
      }(),
      // 收藏人物
      () async {
        try {
          final result = await _ref.read(cachedMediaRepositoryProvider).getFavoritePeople(
            limit: _kFavoritesPageSize,
            offset: 0,
            serverUrl: serverUrl,
            token: token,
            userId: userId,
          );
          people = result.items;
          peopleTotal = result.totalCount;
          _peopleLoaded = people.length;
        } catch (e) {
          peopleError = e is String ? e : '加载失败：$e';
          AppLogger.error('加载收藏人物失败', error: e);
        }
      }(),
    ], eagerError: false);

    // 合并 favoriteIds
    final ids = _mergeIds(movies, boxSets, people);

    // 全部失败才设置全局 error（但有缓存时保留缓存数据，不报错）
    final allFailed =
        moviesError != null && boxSetsError != null && peopleError != null;
    final shouldShowError = allFailed && !hasAnyCache;

    state = FavoritesState(
      movies: movies,
      boxSets: boxSets,
      people: people,
      isLoading: false,
      error: shouldShowError ? '全部收藏加载失败' : null,
      moviesError: moviesError,
      boxSetsError: boxSetsError,
      peopleError: peopleError,
      favoriteIds: ids,
      hasMoreMovies: moviesTotal > movies.length,
      hasMoreBoxSets: boxSetsTotal > boxSets.length,
      hasMorePeople: peopleTotal > people.length,
    );
    _hasLoaded = true;
    AppLogger.info('收藏列表加载完成（SWR）', data: {
      'movies': '${movies.length}/$moviesTotal',
      'boxSets': '${boxSets.length}/$boxSetsTotal',
      'people': '${people.length}/$peopleTotal',
      'fromCache': hasAnyCache,
    });
    _isLoading = false;
  }
```

**注意**：
- 网络请求仍然通过 `cachedMediaRepositoryProvider` 发出（`getFavoriteMovies` 等），因为请求结果需要写入缓存供下次使用
- 缓存读取用 `peekXxx`（同步，不触发网络），网络请求用 `getXxx`（异步，触发网络并写入缓存）
- `_moviesLoaded` / `_boxSetsLoaded` / `_peopleLoaded` 在网络请求成功后更新，供 `loadMore` 使用
- `toggleFavorite` 的乐观更新逻辑不受影响（它直接操作 state，不走缓存）

- [ ] **Step 3: 运行 analyze 验证无错误**

Run: `cd /workspace/frontend && /opt/flutter/bin/flutter analyze lib/providers/favorites_provider.dart`
Expected: 0 errors

- [ ] **Step 4: Commit**

```bash
cd /workspace
git add frontend/lib/providers/favorites_provider.dart
git commit -m "perf(favorites): 收藏页接入 SWR 缓存模式

三栏收藏首屏采用 Stale-While-Revalidate：
先展示缓存数据加速，后台请求 Emby 最新数据，
最终以服务器数据为准，缓存仅做加速。"
```

---

## 6. Phase 4：扩展方向（按需执行）

以下页面改造模式与 Phase 2/3 一致，按需逐步扩展。每个页面的改造步骤为：
1. 在 `CachedMediaRepository` 中新增对应 `peekXxx` 方法
2. 修改 Provider/View 的首屏加载方法：先 peek 缓存 → 再网络请求 → 更新状态
3. `loadMore` / 分页方法保持不变

| 页面 | Provider/View | 对应 peek 方法 | 优先级 |
|------|--------------|---------------|--------|
| 推荐页 | `recommend_provider.dart` | `peekRecommendations` / `peekSuggestions` | P2 |
| 演员页 | `actors_provider.dart` | `peekPeople` | P2 |
| 观看历史 | `watch_history_provider.dart` | `peekWatchHistory` | P2 |
| 搜索页 | `search_view.dart` | 搜索场景 TTL 已很短（30s），可跳过 | P3 |
| 详情页 | `item_detail_provider.dart` | `peekItemDetail` | P3 |
| 合集详情 | `boxset_detail_view.dart` | `peekChildren` | P3 |
| 演员详情 | `person_detail_view.dart` | `peekPersonDetail` / `peekPersonItems` | P3 |
| 媒体库列表 | `library_provider.dart` | `peekLibraries` | P3（元数据，变化极少） |

---

## 7. 风险评估与回滚

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| SWR 导致双倍网络请求（缓存 + 网络） | 确定 | 低（性能） | 首屏加速 + 数据一致性的权衡，接受 |
| 缓存 → 新数据切换导致 UI 闪烁 | 中 | 中（体验） | 数据量小时差异不明显；列表差异大时可考虑淡入动画 |
| 部分 Provider 改造遗漏导致不一致 | 中 | 中 | 逐文件 grep 确认所有首屏加载路径 |
| 网络失败时用户看到旧数据 + loading 消失 | 中 | 低 | 有缓存时保留缓存，不报错；无缓存时报错（现有逻辑） |
| MemoryCache 命中率下降 | 高 | 低 | 预期行为——缓存只做加速，不做真相源 |

**回滚方案**：每个 Phase 独立 commit，可逐个 revert。
整体回滚：`git revert` 所有 SWR 相关 commit。

---

## 8. 完成标准

- [ ] `peekLibraryItems` 方法 + 测试通过
- [ ] 收藏三栏 peek 方法 + 测试通过
- [ ] FeedView 视频流（FeedType.latest）接入 SWR
- [ ] 收藏页三栏接入 SWR
- [ ] 全量 analyze 0 errors
- [ ] 全量测试无新增失败
- [ ] 每个 Phase 独立 commit，message 规范
