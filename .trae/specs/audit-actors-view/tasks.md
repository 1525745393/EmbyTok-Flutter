# 演员界面与功能审查 - 任务清单

## [x] Task 1: 消除硬编码颜色

- **Priority**: high
- **Depends On**: None
- **Description**:
  修改 `/workspace/frontend/lib/views/actors_view.dart` L784-796 的 `_buildTypeChip` 方法，消除 3 处硬编码颜色：
  ```dart
  // 修改前
  Color chipColor;
  switch (type) {
    case 'Director':
      chipColor = Colors.orange;
      break;
    case 'Writer':
      chipColor = Colors.green;
      break;
    default: // 'Actor' 或其他
      chipColor = Colors.blue;
      break;
  }
  ```

  **方案**：在 `/workspace/frontend/lib/theme/` 下创建 `actor_type_colors.dart`（参考 `donate_colors.dart` 模式），定义类型颜色常量：
  ```dart
  /// 演员类型标签颜色（业务语义，非 Material 语义）
  /// Director=橙色（导演），Writer=绿色（编剧），Actor=蓝色（演员）
  abstract final class ActorTypeColors {
    const ActorTypeColors._();
    static const director = Color(0xFFFF9800); // Orange
    static const writer = Color(0xFF4CAF50);    // Green
    static const actor = Color(0xFF2196F3);    // Blue
  }
  ```

  修改 `_buildTypeChip` 使用常量：
  ```dart
  Color chipColor;
  switch (type) {
    case 'Director':
      chipColor = ActorTypeColors.director;
      break;
    case 'Writer':
      chipColor = ActorTypeColors.writer;
      break;
    default:
      chipColor = ActorTypeColors.actor;
      break;
  }
  ```

  同时更新 `/workspace/frontend/tool/lints/hardcoded_color_allowlist.json`，添加 `lib/theme/actor_type_colors.dart` 到白名单。

- **Acceptance Criteria Addressed**: Requirement: 演员模块无硬编码颜色
- **Test Requirements**:
  - `programmatic` TR-1.1: `dart run tool/lints/hardcoded_color_lint.dart --path lib/views/actors_view.dart` 退出码 0
  - `programmatic` TR-1.2: `dart run tool/lints/hardcoded_color_lint.dart --path lib/` 退出码 0（actor_type_colors.dart 在白名单内）

## [x] Task 2: 修复滚动位置恢复功能

- **Priority**: high
- **Depends On**: None
- **Description**:
  修改 `/workspace/frontend/lib/views/actors_view.dart`，`_restoreScrollOffset()` 方法（L121-131）已实现但从未被调用。

  **问题**：`initState` L38-42 只调用了 `_restoreState()` 和 `loadActors()`，没有调用 `_restoreScrollOffset()`。

  **修复**：在 `loadActors` 完成后调用 `_restoreScrollOffset()`。修改 `initState` 中的 `addPostFrameCallback`：
  ```dart
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _restoreState();
    // 首次加载演员数据，加载完成后恢复滚动位置
    await ref.read(actorsProvider.notifier).loadActors();
    if (mounted) {
      // 等待一帧让 CustomScrollView 完成布局后再恢复滚动位置
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreScrollOffset();
      });
    }
  });
  ```

  注意：
  - 必须在 `loadActors` 完成后调用，否则 `maxScrollExtent` 可能还是 0
  - 必须等待一帧让 CustomScrollView 完成布局，否则 `hasClients` 可能为 false
  - 检查 `mounted` 避免组件已销毁时调用

- **Acceptance Criteria Addressed**: Requirement: 滚动位置恢复功能可用
- **Test Requirements**:
  - `programmatic` TR-2.1: `_restoreScrollOffset()` 在 `loadActors` 完成后被调用
  - `programmatic` TR-2.2: 调用前检查 `mounted` 和 `_scrollController.hasClients`

## [x] Task 3: 修复详情页错误处理 bug

- **Priority**: high
- **Depends On**: None
- **Description**:
  修改 `/workspace/frontend/lib/views/person_detail_view.dart` 的 `_loadData` 方法（L68-127）。

  **问题**：作品列表（`worksFuture`）和详情（`detailFuture`）并发加载。当作品列表加载成功但详情加载失败时，外层 try-catch（L119）捕获详情异常后设置 `_error`，导致 UI 显示错误而非已加载的作品列表。

  **修复**：将 `detailFuture` 的错误处理独立出来，不传播到外层 try-catch：
  ```dart
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final cachedRepo = ref.read(cachedMediaRepositoryProvider);
      final serverUrl = auth.embyServerUrl;
      final token = auth.token;
      final userId = auth.user?.id;

      // 作品列表优先加载：先显示作品，再等详情
      final worksFuture = cachedRepo.getPersonItems(
        widget.person.id,
        serverUrl: serverUrl!,
        token: token!,
      );
      final detailFuture = cachedRepo.getPersonDetail(
        widget.person.id,
        serverUrl: serverUrl,
        token: token,
        userId: userId,
      );

      // 作品列表加载完成后先渲染（减少白屏时间）
      worksFuture.then((worksResponse) {
        if (mounted) {
          setState(() {
            _works = worksResponse.items;
            _total = worksResponse.total;
            _loading = false;
          });
        }
      }).catchError((Object e) {
        if (mounted) {
          setState(() {
            _error = e.toString();
            _loading = false;
          });
        }
      });

      // 详情稍后更新（不阻塞作品列表）
      // 修复：详情加载失败不影响作品列表显示，仅 fallback 到原始 person 数据
      try {
        final detail = await detailFuture;
        if (mounted && detail != null) {
          setState(() {
            _personDetail = detail;
          });
        }
      } catch (e) {
        // 详情加载失败，保留 widget.person 作为 fallback，不设置 _error
        AppLogger.error('加载人员详情失败', error: e);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }
  ```

  注意：需在文件顶部添加 `import '../utils/logger.dart';`（如尚未导入）。

- **Acceptance Criteria Addressed**: Requirement: 详情页错误处理不影响已加载作品
- **Test Requirements**:
  - `programmatic` TR-3.1: 详情加载失败时 `_error` 保持为 null（如果作品列表已成功）
  - `programmatic` TR-3.2: 作品列表加载失败时 `_error` 被设置
  - `programmatic` TR-3.3: 详情加载失败时 `_personDetail` 保持为 null，UI fallback 到 `widget.person`

## [x] Task 4: 消除 'null' 字符串占位符 hack

- **Priority**: medium
- **Depends On**: None
- **Description**:
  修改 `/workspace/frontend/lib/views/actors_view.dart` 的 `_saveSelectedType` 和 `_restoreState` 方法。

  **问题**：`_saveSelectedType` 用 `'null'` 字符串作为 null 的占位符，`_restoreState` 用 `savedType == 'null'` 判断。

  **修复**：使用 `prefs.containsKey` 判断键是否存在，type 为 null 时移除键而非写入 'null'：
  ```dart
  // 保存类型筛选
  Future<void> _saveSelectedType(String? type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (type == null) {
        // "全部"类型：移除保存的键，而非写入 'null' 占位符
        await prefs.remove(kStorageKeyActorsSelectedType);
      } else {
        await prefs.setString(kStorageKeyActorsSelectedType, type);
      }
    } catch (_) {}
  }
  ```

  修改 `_restoreState` 中的类型恢复逻辑：
  ```dart
  // 恢复类型筛选
  // 优先用 containsKey 判断，兼容旧版本可能存在的 'null' 字符串数据
  final prefsContainsType = prefs.containsKey(kStorageKeyActorsSelectedType);
  if (prefsContainsType) {
    final savedType = prefs.getString(kStorageKeyActorsSelectedType);
    // 兼容旧版本写入的 'null' 字符串：视为无筛选
    if (savedType != null && savedType.isNotEmpty && savedType != 'null') {
      ref.read(actorsProvider.notifier).setSelectedType(savedType);
    }
  }
  ```

  注意：兼容旧版本写入的 'null' 字符串数据，避免用户升级后已保存的筛选状态丢失。

- **Acceptance Criteria Addressed**: Requirement: 消除 'null' 字符串占位符 hack
- **Test Requirements**:
  - `programmatic` TR-4.1: `_saveSelectedType(null)` 调用 `prefs.remove` 而非写入 'null'
  - `programmatic` TR-4.2: `_restoreState` 用 `containsKey` 判断，兼容旧 'null' 字符串数据

## [x] Task 5: 提取 TabController length 常量

- **Priority**: low
- **Depends On**: None
- **Description**:
  修改 `/workspace/frontend/lib/views/actors_view.dart` L34，将 magic number `3` 提取为命名常量。

  在 `_ActorsViewState` 类中添加静态常量：
  ```dart
  class _ActorsViewState extends ConsumerState<ActorsView> with TickerProviderStateMixin {
    /// 演员页 Tab 数量：全部 / 已关注 / 未关注
    static const int _actorTabsCount = 3;
    
    late TabController _tabController;
    // ...
    
    @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _actorTabsCount, vsync: this);
    // ...
  }
  ```

  同时检查 L71 `if (savedTab != null && savedTab >= 0 && savedTab < 3)` 中的 `3` 是否也应改为 `_actorTabsCount`。

- **Acceptance Criteria Addressed**: Requirement: TabController length 使用常量
- **Test Requirements**:
  - `programmatic` TR-5.1: `TabController(length: _actorTabsCount, ...)` 使用常量
  - `programmatic` TR-5.2: `savedTab < _actorTabsCount` 使用常量

## [x] Task 6: 清理空状态死代码

- **Priority**: medium
- **Depends On**: None
- **Description**:
  修改 `/workspace/frontend/lib/views/actors_view.dart` 的 `_buildActorGrid` 和 `_buildEmptyState`。

  **问题**：
  1. `_buildActorGrid` L199 调用 `_buildEmptyState(isSearchEmpty: isSearchActive, isFavoriteEmpty: false)` 永远传入 `false`
  2. `_buildEmptyState` 的 `isFavoriteEmpty` 分支（L513-568）永远不会被触发，是死代码
  3. 但"已关注"Tab 为空时应显示"暂无关注的演员"引导提示

  **修复**：需要区分是哪个 Tab 的空状态。修改 `_buildActorGrid` 增加参数：
  ```dart
  Widget _buildActorGrid(
    List<Person> actors,
    String? embyServerUrl,
    String? token,
    Set<String> favoritedIds,
    bool isSearchActive, {
    bool isFavoriteTab = false,
  }) {
    if (actors.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(
          isSearchEmpty: isSearchActive,
          isFavoriteEmpty: isFavoriteTab && !isSearchActive,
        ),
      );
    }
    // ... 原逻辑
  }
  ```

  修改 `_buildTabContent` 调用处传入 `isFavoriteTab`：
  ```dart
  // 已关注 Tab
  _buildTabContent(
    actors: favoritedActors,
    // ...
    isFavoriteTab: true,
  ),
  ```

  `_buildTabContent` 需增加 `isFavoriteTab` 参数并传递给 `_buildActorGrid`。

- **Acceptance Criteria Addressed**: Requirement: "已关注"Tab 空状态正确显示
- **Test Requirements**:
  - `programmatic` TR-6.1: "已关注"Tab 空列表时调用 `_buildEmptyState(isFavoriteEmpty: true)`
  - `programmatic` TR-6.2: "全部"Tab 空列表时调用 `_buildEmptyState(isFavoriteEmpty: false)`
  - `programmatic` TR-6.3: 搜索状态优先于 isFavoriteEmpty（搜索为空时显示搜索空状态）

## [x] Task 7: 补充测试用例

- **Priority**: medium
- **Depends On**: Task 1, Task 3, Task 4
- **Description**:
  在 `/workspace/frontend/test/` 下创建两个测试文件：

  ### 7.1 `test/providers/actors_provider_test.dart`

  覆盖以下场景：
  - `loadActors` 成功加载演员列表
  - `loadActors` 失败时设置 error 状态
  - `loadActors` 已加载且非 forceRefresh 时不重复加载
  - `searchActors` 防抖 300ms 后触发搜索
  - `searchActors` 空查询清空搜索结果
  - `setSelectedType` 设置类型并触发重新加载
  - `toggleFavorite` 乐观更新关注状态
  - `toggleFavorite` 失败时回滚关注状态
  - `toggleFavorite` 无 ID 的演员不操作

  注意：mock `EmbytokService`、`cachedMediaRepositoryProvider`、`authProvider`。

  ### 7.2 `test/views/person_detail_view_test.dart`

  覆盖以下场景：
  - 作品列表加载成功时显示作品列表
  - 作品列表加载失败时显示错误状态
  - **作品列表成功但详情失败时显示作品列表**（Task 3 修复的核心场景）
  - 详情加载成功时更新人员信息
  - 分页加载更多作品（_loadMore）
  - 空作品列表显示"暂无作品"

  注意：mock `cachedMediaRepositoryProvider`、`authProvider`。

- **Test Requirements**:
  - `programmatic` TR-7.1: 所有新增测试通过
  - `programmatic` TR-7.2: `flutter test test/providers/actors_provider_test.dart` 退出码 0
  - `programmatic` TR-7.3: `flutter test test/views/person_detail_view_test.dart` 退出码 0

# Task Dependencies

- Task 7 依赖 Task 1, 3, 4（测试基于修复后的代码）
- Task 1, 2, 3, 4, 5, 6 之间无依赖，可并行执行
