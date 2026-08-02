# 底部导航栏审查与修复 - 验证清单

> **验证环境限制说明**：当前沙箱环境未安装 Flutter/Dart SDK，无法运行 `flutter test`、`flutter analyze` 等命令。以下标注为 `[x]` 的项通过代码审查（Grep/Read 验证）确认；标注为 `[~]` 的项需在 Flutter SDK 环境下补验。

## 路由索引常量化

- [x] `home_scaffold.dart` 中无 magic number `4`（指代 PageIndices.search）
  - 验证：Grep `currentIndex == [0-5]` 无匹配
- [x] `home_scaffold.dart` 中无 magic number `0`（指代 PageIndices.feed）
  - 验证：Grep `currentIndex != [0-5]` 无匹配；`goToPage(0)` 已改为 `goToPage(PageIndices.feed)` (L186)
- [x] 覆盖层 IndexedStack 的 index 计算使用 `PageIndices.search` 常量
  - 验证：L282 `currentIndex == PageIndices.search ? 0 : 1`
- [x] PopScope 的 currentIndex 判断使用 `PageIndices.feed`/`search`/`history` 常量
  - 验证：L185 `currentIndex != PageIndices.feed && currentIndex != PageIndices.search && currentIndex != PageIndices.history`

## PopScope API 现代化

- [x] `PopScope` 使用 `onPopInvokedWithResult` 而非 `onPopInvoked`
  - 验证：L175 `onPopInvokedWithResult: (bool didPop, dynamic result) async`；Grep `onPopInvoked[^W]` 无匹配
- [~] `flutter analyze lib/views/home_scaffold.dart` 无 `onPopInvoked` deprecation 警告
  - 状态：无法运行（Flutter SDK 不可用）
- [x] 退出确认对话框行为不变（弹出"退出应用？"对话框）
  - 验证：L193-214 AlertDialog 内容保持不变
- [x] 覆盖层页面按返回键回到 Feed 的行为不变
  - 验证：L178-182 `if (pageNavState.isOverlayPage) { ...backToFeed(); return; }` 逻辑不变
- [x] 非 Feed Tab 按返回键回到 Feed 的行为不变
  - 验证：L184-188 逻辑不变，仅 `goToPage(0)` 改为 `goToPage(PageIndices.feed)`
- [x] **修复变量遮蔽问题**：L191 局部变量 `result` 改为 `shouldExit`，避免遮蔽回调参数 `result`
  - 验证：L193 `final shouldExit = await showDialog<bool>`；L219 `if (shouldExit == true)`

## Tab 切换触觉反馈

- [x] `onDestinationSelected` 回调中调用 `HapticFeedback.selectionClick()`
  - 验证：L328 `HapticFeedback.selectionClick();`
- [x] 触觉反馈在 `goToPage` 之前调用
  - 验证：L328 在 L329 `ref.read(...).goToPage(index)` 之前
- [x] 触觉反馈调用不阻塞页面切换（无 await）
  - 验证：L328 `HapticFeedback.selectionClick();` 无 await（返回 Future 但未 await）
- [x] `flutter/services.dart` 已导入（用于 HapticFeedback）
  - 验证：L21 `import 'package:flutter/services.dart';`（原有导入，用于 SystemNavigator）

## 导航状态初始化一致性

- [x] `_load` 方法上方有注释说明异步初始化行为
  - 验证：L54-59 6 行注释说明设计决策
- [x] `_load` 方法逻辑不变（仅添加注释）
  - 验证：L60-68 逻辑与原代码一致
- [x] 注释明确说明覆盖层不持久化的设计决策
  - 验证：L59 "覆盖层页面（search/history）不在此恢复，因为它们是临时操作不应持久化"

## 覆盖层持久化策略文档化

- [x] `goToSearch()` 方法上方有注释说明不持久化的原因
  - 验证：L85-88 注释"不调用 _saveIndex，因为覆盖层是临时操作"
- [x] `goToHistory()` 方法上方有注释说明不持久化的原因
  - 验证：L96-98 注释"同 goToSearch，不持久化覆盖层索引"
- [x] 注释内容一致（说明覆盖层是临时操作）
  - 验证：两处注释均说明覆盖层是临时操作不应恢复

## 测试覆盖

- [x] `test/views/home_scaffold_test.dart` 文件存在
  - 验证：文件已创建（267 行）
- [x] Tab 切换测试覆盖（收藏/演员/设置/首页）
  - 验证：4 个 testWidgets 用例
- [x] 覆盖层显隐测试覆盖（goToSearch/goToHistory/backToFeed/goToPage）
  - 验证：4 个 test 用例
- [x] 生命周期播放控制测试不重复（已被现有测试覆盖）
  - 验证：文件顶部注释说明跳过原因，引用 `feed_autopause_test.dart` 和 `lifecycle_autopause_test.dart`
- [~] `flutter test test/views/home_scaffold_test.dart` 退出码 0
  - 状态：无法运行（Flutter SDK 不可用）
- [~] 现有 `back_navigation_test.dart` 测试仍通过
  - 状态：无法运行（Flutter SDK 不可用）

## 回归验证

- [~] 底部导航栏 4 个 Tab 切换功能正常
  - 状态：需 Flutter SDK 环境下人工验证
- [~] 覆盖层页面（搜索/历史）显隐正常
  - 状态：需 Flutter SDK 环境下人工验证
- [~] 系统返回键拦截行为正常
  - 状态：需 Flutter SDK 环境下人工验证
- [~] 退出确认对话框正常弹出
  - 状态：需 Flutter SDK 环境下人工验证
- [~] App 生命周期切换时视频暂停/恢复正常
  - 状态：需 Flutter SDK 环境下人工验证（纯函数已被现有测试覆盖）
- [~] Feed Tab 可见性切换时视频暂停/恢复正常
  - 状态：需 Flutter SDK 环境下人工验证（纯函数已被现有测试覆盖）
- [x] 刘海屏适配不受影响（SafeInsets 使用不变）
  - 验证：L166 `SafeInsets.bottomOf(context)` 等调用不变
- [x] 工具栏折叠动画不受影响
  - 验证：L295-357 AnimatedContainer/AnimatedOpacity 逻辑不变
- [~] `flutter analyze` 无新增 error 级别告警
  - 状态：无法运行（Flutter SDK 不可用）

## 文档与提交

- [ ] 每个修复独立提交，提交信息准确描述变更
- [ ] 提交前执行 `git diff --cached --stat` 核对暂存内容
- [ ] 提交信息符合项目规范（中文，描述变更内容与原因）

## 验证状态总结

| 类别 | 已验证 [x] | 待验证 [~] | 未开始 [ ] |
|------|-----------|-----------|-----------|
| 路由索引常量化 | 4 | 0 | 0 |
| PopScope API 现代化 | 5 | 1 | 0 |
| Tab 切换触觉反馈 | 4 | 0 | 0 |
| 导航状态初始化一致性 | 3 | 0 | 0 |
| 覆盖层持久化策略文档化 | 3 | 0 | 0 |
| 测试覆盖 | 4 | 2 | 0 |
| 回归验证 | 2 | 7 | 0 |
| 文档与提交 | 0 | 0 | 3 |

**待验证项说明**：7 项回归测试和 2 项测试运行需在 Flutter SDK 环境下执行。1 项 lint 检查需 Flutter SDK。代码层面所有修改已通过 Grep/Read 验证正确。

## 额外修复

- [x] **变量遮蔽问题**：发现并修复 `onPopInvokedWithResult` 回调参数 `result` 与局部变量 `result` 的遮蔽问题，将局部变量改名为 `shouldExit`
