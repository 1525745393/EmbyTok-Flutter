# EmbyTok 沉浸式交互 - 实施计划（Decomposed and Prioritized Task List）

## 任务依赖图
```
Task 1 (constants) ─→ Task 2 (provider) ─→ Task 3 (feed view)
                     ↓                     ↓
                   Task 4 (home scaffold)  Task 5 (immersive system UI)
                     ↓                     ↓
                   Task 6 (video_page_item padding) ─→ Task 7 (CI 验证)
```

## [ ] Task 1: 在 constants.dart 添加沉浸式相关常量
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 新增 `kToolbarAnimMs = 200`（工具栏动画时长）
  - 新增 `kToolbarHeight = 56`（顶部工具栏高度）
  - 新增 `kBottomNavHeight = 64`（底部导航栏高度）
  - 新增 `kToolbarHideDelayMs = 200`（防抖延迟）
  - 新增 `kToolbarAutoHideS = 3`（点击唤醒后的自动隐藏时长秒数）
  - 新增 `kMinSwipeDistancePx = 24`（触发工具栏消隐的最小滑动距离）
- **Acceptance Criteria Addressed**: AC-6（编译/静态分析通过）
- **Test Requirements**:
  - `programmatic` TR-1.1: `flutter analyze lib` 无 error、warning
  - `programmatic` TR-1.2: 所有新增常量可在其他文件中通过 `import 'constants.dart'` 访问
- **Notes**: 此任务代码量极小，但属于后续所有任务的前置依赖

## [x] Task 2: 创建 toolbarVisibilityProvider 状态管理
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 新建文件 `lib/providers/toolbar_visibility_provider.dart`
  - 使用 `StateNotifier<bool>` 封装，初始 state = true（可见）
  - 暴露方法：`show()` / `hide()` / `toggle()` / `showTemporary(Duration autoHideAfter)`
  - 内部维护 `_debounceTimer`：每次请求与当前状态不同且间隔 < kToolbarHideDelayMs 时忽略
  - 在 `providers.dart` 导出新文件
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3
- **Test Requirements**:
  - `programmatic` TR-2.1: `toolbarVisibilityProvider` 可从 `ref.read/watch` 正常访问
  - `human-judgement` TR-2.2: 调用 10 次 `show()` 后再调用 `hide()`，只有 1 次实际状态变更（去重生效）
- **Notes**: 不要在 Provider 内部使用 `Timer` 与 `WidgetsBinding` 的耦合逻辑——所有 UI 定时逻辑放在 Widget 层

## [x] Task 3: 改造 feed_view.dart：滑动监听 + 工具栏动画
- **Priority**: P0
- **Depends On**: Task 2
- **Description**:
  - 在 `_FeedViewState` 中添加 `_lastPageOffset = 0.0` 记录上一次 page 偏移
  - 在 `initState()` 中对 `_pageController.addListener(_onScroll)`
  - 实现 `_onScroll()`：比较当前 offset 与 `_lastPageOffset`，`delta > kMinSwipeDistancePx` → hide，反向 → show
  - `onPageChanged`: 如果新 index > 旧 index 则调用 `ref.read(toolbarVisibilityProvider.notifier).hide()`；否则调用 `show()`
  - 顶部 `TopToolBar(Positioned)` 外层包裹 `AnimatedOpacity` + `AnimatedContainer(height: visible ? kToolbarHeight : 0)`
  - 在 `Stack` 顶层叠放一个透明 `GestureDetector`（behavior: `HitTestBehavior.translucent`），`onTap` 时调用 `showTemporary(Duration(seconds: kToolbarAutoHideS))`
  - 在 `dispose()` 中移除 listener 并调用 `ref.read(toolbarVisibilityProvider.notifier).show()`（确保离开 feed 时恢复可见）
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3, AC-6, AC-7
- **Test Requirements**:
  - `human-judgement` TR-3.1: 真机滑动——向上翻页后工具栏在 200ms 内滑出顶部，动画结束后高度为 0
  - `human-judgement` TR-3.2: 下滑回到前一条后工具栏在 200ms 内滑回顶部
  - `human-judgement` TR-3.3: 点击视频画面空白处，工具栏弹出 3 秒后自动隐藏
  - `programmatic` TR-3.4: `flutter analyze lib` 0 errors
- **Notes**: 手势透明 Detector 必须放在 Stack 顶层且 `behavior: translucent`——否则会吞掉 `TopToolBar` 的按钮点击

## [x] Task 4: 改造 home_scaffold.dart：底部导航栏联动
- **Priority**: P0
- **Depends On**: Task 2
- **Description**:
  - `HomeScaffold` 改为 `ConsumerWidget`（或 `ConsumerStatefulWidget`）
  - `bottomNavigationBar` 使用 `AnimatedContainer(height: visible ? kBottomNavHeight : 0)` 包装 `BottomNavigationBar`
  - `visible` 来源：`ref.watch(toolbarVisibilityProvider)`
  - 在 `BottomNavigationBar` 外层额外加 `ClipRect`，避免动画期间底部图标溢出
  - `AnimatedContainer` 使用与顶栏相同的 `Duration(milliseconds: kToolbarAnimMs)` 和 `Curves.easeOut`
- **Acceptance Criteria Addressed**: AC-1, AC-7
- **Test Requirements**:
  - `human-judgement` TR-4.1: 滑动切换视频时，底部导航栏同步向上折叠消失（高度 0，透明度 0）
  - `human-judgement` TR-4.2: 切回搜索/收藏页后底部导航栏恢复可见（通过 Task 3 的 dispose 逻辑）
  - `programmatic` TR-4.3: `flutter analyze lib` 0 errors
- **Notes**: 由于 `HomeScaffold` 包裹 `FeedView`，Provider 可以跨组件共享——这也是使用 Riverpod 的原因

## [x] Task 5: 改造 feed_view.dart：沉浸式系统 UI 模式切换
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - `_FeedViewState` 实现 `WidgetsBindingObserver`
  - 在 `initState()` 中注册 `WidgetsBinding.instance.addObserver(this)`，在 `dispose()` 中移除
  - 实现 `didChangeMetrics()`：调用 `setState(() {})` 触发重新布局以读取新的 `MediaQuery.padding`
  - `_toggleFullscreen()` 在进入横屏时，调用 `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`；退出时恢复为 `SystemUiMode.edgeToEdge`
  - 额外设置 `SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light))` 以确保状态栏透明
  - 在进入横屏时，调用 `ref.read(toolbarVisibilityProvider.notifier).hide()`（横屏不需要系统顶栏和 App 工具栏）
  - 在退出横屏时，调用 `ref.read(toolbarVisibilityProvider.notifier).show()`
- **Acceptance Criteria Addressed**: AC-4, AC-5, AC-7
- **Test Requirements**:
  - `human-judgement` TR-5.1: 点击全屏按钮后，Android 状态栏和导航栏消失（黑条）
  - `human-judgement` TR-5.2: 点击退出全屏后，状态栏/导航栏回到透明 edge-to-edge 模式
  - `programmatic` TR-5.3: `flutter analyze lib` 0 errors
- **Notes**: `WidgetsBindingObserver` 的 `dispose` 中必须调用 `removeObserver`，否则会泄漏

## [x] Task 6: 改造 video_page_item.dart：动态安全 padding
- **Priority**: P1
- **Depends On**: Task 1, Task 5
- **Description**:
  - 将 `ConsumerWidget` 改为 `ConsumerStatefulWidget` 以便读取 `MediaQuery`
  - `build()` 中读取 `MediaQuery.of(context).padding`
  - 右侧按钮区 padding：`EdgeInsets.only(right: max(16.0, padding.right) + 16, bottom: max(24.0, padding.bottom) + 16)`
  - 左侧标题区 padding：`EdgeInsets.fromLTRB(16, max(80.0, padding.top + 24), 96, 24)`（顶部额外留出工具栏空间）
  - 读取 `toolbarVisibilityProvider` 状态：如果工具栏隐藏，则标题区 `top = max(24.0, padding.top + 16)`（减少顶部空白）
- **Acceptance Criteria Addressed**: AC-4, AC-1
- **Test Requirements**:
  - `human-judgement` TR-6.1: notch/Dynamic Island 手机上，顶部标题不被系统 UI 遮挡
  - `human-judgement` TR-6.2: 横屏沉浸式模式下，右侧收藏/播放按钮不被底部手势条遮挡
  - `programmatic` TR-6.3: `flutter analyze lib` 0 errors
- **Notes**: `max()` 需要 `import 'dart:math'`

## [x] Task 7: CI 验证与发布准备
- **Priority**: P2
- **Depends On**: Task 3, Task 4, Task 5, Task 6
- **Description**:
  - 本地（或 CI）运行 `flutter analyze --no-pub lib`，必须 0 error
  - 运行 `flutter pub get` 确认依赖无冲突
  - 手动验证 AC-1 到 AC-7 的全部验收项
  - 提交前自检：确认没有硬编码 `Colors.grey`、`Colors.black54` 等颜色（遵循 NFR-4）
- **Acceptance Criteria Addressed**: AC-6
- **Test Requirements**:
  - `programmatic` TR-7.1: `flutter analyze lib` 0 errors, 0 warnings, 0 info
  - `human-judgement` TR-7.2: 人工遍历每个验收项通过
- **Notes**: 发现 CI 问题时，不要创建新 task——直接修改相关文件并更新对应 task 的状态

## 风险与备注

- **Task 3/4 联动风险**: `toolbarVisibilityProvider` 是全局的——切换到搜索/收藏等非 feed 页面后 Provider 状态可能为"已隐藏"，导致底部导航栏消失。**解决方案**: 在 `_FeedViewState.dispose()` 中强制调用 `show()` 重置。
- **横屏模式下的 onPageChanged 风险**: 用户横屏时可能也会滑动——需要确保横屏下 `onPageChanged` 不触发反向 `show()`。**解决方案**: 在 Task 3 中用 `ref.read(isFullscreenProvider)` 包裹逻辑：横屏下始终保持 hide。
- **iOS 上 immersiveSticky 行为不同**: 某些 iOS 版本可能需要 `SystemUiMode.leanBack` 替代。暂使用 `immersiveSticky`，在 iOS 上由 Flutter 框架自动降级。
