# 演员界面与功能审查 - 验证清单

> **验证环境限制说明**：当前沙箱环境未安装 Flutter/Dart SDK，无法运行 `flutter test`、`flutter analyze`、`dart run` 等命令。以下标注为 `[x]` 的项通过代码审查（Grep/Read 验证）确认；标注为 `[~]` 的项需在 Flutter SDK 环境下补验。

## 硬编码颜色消除

- [x] `actors_view.dart` 中无 `Colors.orange`、`Colors.green`、`Colors.blue` 硬编码
  - 验证：Grep `Colors\.` 无匹配；L816/819/822 已改为 `ActorTypeColors.director/writer/actor`
- [x] `lib/theme/actor_type_colors.dart` 文件存在并定义类型颜色常量
  - 验证：文件 19 行，`abstract final class ActorTypeColors` 定义三个颜色常量
- [x] `actor_type_colors.dart` 已添加到 `hardcoded_color_allowlist.json` 白名单
  - 验证：白名单 L4 已添加 `"lib/theme/actor_type_colors.dart"`
- [~] `dart run tool/lints/hardcoded_color_lint.dart --path lib/views/actors_view.dart` 退出码 0
  - 状态：无法运行（Flutter SDK 不可用）
- [~] `dart run tool/lints/hardcoded_color_lint.dart --path lib/` 退出码 0
  - 状态：无法运行（Flutter SDK 不可用）

## 滚动位置恢复

- [x] `_restoreScrollOffset()` 在 `loadActors` 完成后被调用
  - 验证：L45 `await ref.read(actorsProvider.notifier).loadActors()` 后 L46-51 调用
- [x] 调用前检查 `mounted` 和 `_scrollController.hasClients`
  - 验证：L46 `if (mounted)` 检查；`_restoreScrollOffset` 内部 L148 `_scrollController.hasClients` 检查
- [x] 调用前等待一帧让 CustomScrollView 完成布局
  - 验证：L47 `WidgetsBinding.instance.addPostFrameCallback` 嵌套
- [x] 滚动位置恢复后不超过 `maxScrollExtent`（已 clamp 处理）
  - 验证：L152 `final safeOffset = offset.clamp(0.0, maxScroll);`

## 详情页错误处理

- [x] 详情加载失败时 `_error` 保持为 null（如果作品列表已成功）
  - 验证：L115-126 详情加载用独立 try-catch 包裹，不设置 `_error`
- [x] 作品列表加载失败时 `_error` 被设置
  - 验证：L103-110 `worksFuture.catchError` 设置 `_error`
- [x] 详情加载失败时 `_personDetail` 保持为 null，UI fallback 到 `widget.person`
  - 验证：L162 `final person = _personDetail ?? widget.person;`
- [x] 详情加载失败时记录日志（`AppLogger.error`）
  - 验证：L125 `AppLogger.error('加载人员详情失败', error: e);`
- [x] `logger.dart` 已导入
  - 验证：L11 `import '../utils/logger.dart';`

## 'null' 字符串 hack 消除

- [x] `_saveSelectedType(null)` 调用 `prefs.remove` 而非写入 'null'
  - 验证：L97-108 null 时 `await prefs.remove(kStorageKeyActorsSelectedType)`
- [x] `_restoreState` 用 `containsKey` 判断键是否存在
  - 验证：L73 `prefs.containsKey(kStorageKeyActorsSelectedType)`
- [x] 兼容旧版本写入的 'null' 字符串数据（视为无筛选）
  - 验证：L77 `savedType != 'null'` 兼容旧数据
- [x] 不写入新的 'null' 字符串数据
  - 验证：`_saveSelectedType` 中无 `'null'` 写入

## TabController length 常量化

- [x] `_actorTabsCount` 静态常量已定义
  - 验证：L28 `static const int _actorTabsCount = 3;`
- [x] `TabController(length: _actorTabsCount, ...)` 使用常量
  - 验证：L38 `TabController(length: _actorTabsCount, vsync: this)`
- [x] `savedTab < _actorTabsCount` 使用常量
  - 验证：L84 `savedTab < _actorTabsCount`

## 空状态死代码清理

- [x] `_buildActorGrid` 增加 `isFavoriteTab` 参数
  - 验证：L218 `bool isFavoriteTab = false,`
- [x] `_buildTabContent` 增加 `isFavoriteTab` 参数并传递给 `_buildActorGrid`
  - 验证：L422 `bool isFavoriteTab = false,`；L447/L473 传递给 `_buildActorGrid`
- [x] "已关注"Tab 空列表时传入 `isFavoriteEmpty: true`
  - 验证：L381 `isFavoriteTab: true`；L225 `isFavoriteEmpty: isFavoriteTab && !isSearchActive`
- [x] "全部"Tab 空列表时传入 `isFavoriteEmpty: false`
  - 验证：默认 `isFavoriteTab: false`，`isFavoriteEmpty` 为 false
- [x] 搜索状态优先于 isFavoriteEmpty（搜索为空时显示搜索空状态）
  - 验证：L225 `isFavoriteTab && !isSearchActive` 搜索时为 false
- [x] `_buildEmptyState` 的 `isFavoriteEmpty` 分支被正确触发
  - 验证：逻辑正确，"已关注"Tab 空列表时触发

## 测试覆盖

- [x] `test/providers/actors_provider_test.dart` 文件存在
  - 验证：文件已创建（467 行）
- [x] `loadActors` 成功/失败/已加载不重复测试覆盖
  - 验证：3 个测试用例
- [x] `searchActors` 防抖/空查询测试覆盖
  - 验证：2 个测试用例
- [x] `setSelectedType` 设置类型并触发重新加载测试覆盖
  - 验证：1 个测试用例
- [x] `toggleFavorite` 乐观更新/失败回滚/无ID测试覆盖
  - 验证：3 个测试用例
- [x] `test/views/person_detail_view_test.dart` 文件存在
  - 验证：文件已创建（218 行）
- [x] 作品列表成功显示测试覆盖
  - 验证：1 个 testWidgets 用例
- [x] 作品列表失败显示错误状态测试覆盖
  - 验证：1 个 testWidgets 用例
- [x] **作品成功但详情失败显示作品列表测试覆盖**（核心场景）
  - 验证：1 个 testWidgets 用例（核心修复场景）
- [x] 详情成功更新人员信息测试覆盖
  - 验证：1 个 testWidgets 用例
- [x] 空作品列表显示"暂无作品"测试覆盖
  - 验证：1 个 testWidgets 用例
- [~] `flutter test test/providers/actors_provider_test.dart` 退出码 0
  - 状态：无法运行（Flutter SDK 不可用）
- [~] `flutter test test/views/person_detail_view_test.dart` 退出码 0
  - 状态：无法运行（Flutter SDK 不可用）

## 回归验证

- [~] 演员列表加载功能正常
  - 状态：需 Flutter SDK 环境下人工验证
- [~] 搜索演员功能正常（防抖 300ms）
  - 状态：需 Flutter SDK 环境下人工验证
- [~] 类型筛选功能正常（全部/演员/导演/编剧）
  - 状态：需 Flutter SDK 环境下人工验证
- [~] Tab 切换功能正常（全部/已关注/未关注）
  - 状态：需 Flutter SDK 环境下人工验证
- [~] 关注/取消关注功能正常（乐观更新 + 失败回滚）
  - 状态：需 Flutter SDK 环境下人工验证
- [~] 演员详情页加载功能正常
  - 状态：需 Flutter SDK 环境下人工验证
- [~] 作品列表分页加载功能正常
  - 状态：需 Flutter SDK 环境下人工验证
- [~] 滚动位置保存和恢复功能正常
  - 状态：需 Flutter SDK 环境下人工验证
- [~] 状态持久化功能正常（类型筛选、Tab 索引、搜索关键词、滚动位置）
  - 状态：需 Flutter SDK 环境下人工验证
- [x] 刘海屏适配不受影响
  - 验证：actors_view.dart 和 person_detail_view.dart 未修改 SafeArea/SafeInsets 相关代码
- [~] `flutter analyze` 无新增 error 级别告警
  - 状态：无法运行（Flutter SDK 不可用）

## 文档与提交

- [ ] 每个修复独立提交，提交信息准确描述变更
- [ ] 提交前执行 `git diff --cached --stat` 核对暂存内容
- [ ] 提交信息符合项目规范（中文，描述变更内容与原因）

## 验证状态总结

| 类别 | 已验证 [x] | 待验证 [~] | 未开始 [ ] |
|------|-----------|-----------|-----------|
| 硬编码颜色消除 | 3 | 2 | 0 |
| 滚动位置恢复 | 4 | 0 | 0 |
| 详情页错误处理 | 5 | 0 | 0 |
| 'null' 字符串 hack 消除 | 4 | 0 | 0 |
| TabController length 常量化 | 3 | 0 | 0 |
| 空状态死代码清理 | 6 | 0 | 0 |
| 测试覆盖 | 10 | 2 | 0 |
| 回归验证 | 1 | 9 | 0 |
| 文档与提交 | 0 | 0 | 3 |

**待验证项说明**：9 项回归测试和 2 项测试运行需在 Flutter SDK 环境下执行。2 项 lint 检查需 Flutter SDK。代码层面所有修改已通过 Grep/Read 验证正确。
