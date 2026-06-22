# EmbyTok 响应式设计 - 实施计划

## [ ] Task 1: 添加半透明渐变常量到 constants.dart 和 colors.dart
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 在 [colors.dart](file:///workspace/frontend/lib/utils/colors.dart) 添加半透明黑颜色常量：`overlayBlack = Color(0xAA000000)`，`overlayBlackDeep = Color(0xCC000000)`
  - 在 [constants.dart](file:///workspace/frontend/lib/utils/constants.dart) 添加高度/透明度相关参数（如需要）
- **Acceptance Criteria Addressed**: AC-1, AC-2, NFR-3, NFR-4
- **Test Requirements**:
  - `human-judgement` TR-1.1: 常量命名清晰、语义明确，在后续 Task 中被引用
  - `human-judgement` TR-1.2: 透明度值（0xAA）在深色视频背景下提供足够的对比度
- **Notes**: `0xAA` 透明度约 67%，在黑暗背景上提供良好的可读性和视觉深度；如果实际效果不佳，可调整到 `0xBB` 或 `0xCC`

## [ ] Task 2: 顶部工具栏改为半透明渐变叠加
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 修改 [feed_view.dart](file:///workspace/frontend/lib/views/feed_view.dart) 的 `_buildAnimatedToolBar()` 方法：将背景 `decoration` 改为 `LinearGradient`（自顶向下 `Color(0xAA000000)` → `Color(0x00000000)`）
  - 移除顶部工具栏的底部边框 `Border(bottom: BorderSide(color: dividerColor, width: 0.5))`
  - 使用 `Positioned(top: 0, left: 0, right: 0)` 包裹工具栏，使其在 Stack 中绝对定位在顶部
  - 工具栏内容保留 `SafeArea`，但不影响视频内容的布局
- **Acceptance Criteria Addressed**: AC-1, AC-3, AC-4
- **Test Requirements**:
  - `human-judgement` TR-2.1: 工具栏顶部可见状态栏图标，视频内容透过工具栏可见
  - `human-judgement` TR-2.2: 工具栏底部边缘是渐变消失的柔和效果，无硬边框
  - `human-judgement` TR-2.3: 工具栏的图标（菜单、文件夹、方向过滤、视图切换、全屏、静音）清晰可见，与背景对比度足够
- **Notes**: 渐变从 `begin: Alignment.topCenter, end: Alignment.bottomCenter`，底部透明度为 0，这样工具栏不会在视频上留下一个明显的"阴影块"

## [ ] Task 3: 底部导航栏改为半透明渐变叠加
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 修改 [home_scaffold.dart](file:///workspace/frontend/lib/views/home_scaffold.dart) 的 `AnimatedContainer` 底部导航栏：将背景 `decoration` 改为 `LinearGradient`（自底向上 `Color(0xAA000000)` → `Color(0x00000000)`）
  - 移除底部导航栏的顶部分隔线 `Border(top: BorderSide(color: dividerColor, width: 0.5))`
  - 设置 `BottomNavigationBar` 的 `backgroundColor: Colors.transparent`，让它使用外部容器的渐变
  - 设置 `BottomNavigationBar` 的 `elevation: 0`，避免自带阴影
  - 保留 `SafeArea` 让导航项避开底部手势条
- **Acceptance Criteria Addressed**: AC-2, AC-3, AC-8
- **Test Requirements**:
  - `human-judgement` TR-3.1: 底部导航栏从底部边缘向上渐变消失，视频内容透过可见
  - `human-judgement` TR-3.2: 导航项图标（feed/search/favorites/history/settings）在所有选中/未选中状态下都清晰可读
  - `human-judgement` TR-3.3: 底部手势条（如 Android 12+ 的手势导航条）在渐变背景下可见且不冲突
- **Notes**: 底部导航栏目前是 Scaffold 的 `bottomNavigationBar` 属性，会自动占据空间。要实现真正的"叠加在视频上"，需要改变架构：改为在 `body: Stack` 中使用 `Positioned(bottom: 0)` 放置导航栏。这是本次 Task 的核心技术点

## [ ] Task 4: 视频内容区全屏延伸（架构调整）
- **Priority**: P0
- **Depends On**: Task 2, Task 3
- **Description**:
  - 在 [home_scaffold.dart](file:///workspace/frontend/lib/views/home_scaffold.dart) 中，将原来的 `Scaffold(body: IndexedStack, bottomNavigationBar: AnimatedContainer)` 改为 `Scaffold(body: Stack(children: [IndexedStack, Positioned(bottom:0, ...)]))`
  - 这样，视频内容 `IndexedStack` 会 `fill` 整个屏幕，而底部导航栏用 `Positioned(bottom: 0)` 叠加
  - `Scaffold.backgroundColor` 保持 `backgroundColor`
  - 视频内容区的 `SafeArea` 全部移除（让视频延伸到边缘）
- **Acceptance Criteria Addressed**: AC-3, AC-6
- **Test Requirements**:
  - `human-judgement` TR-4.1: 视频画面顶部可见状态栏图标"浮在"视频上，无黑色间隙
  - `human-judgement` TR-4.2: 视频画面底部可见底部系统手势条（如果设备有），无黑色间隙
  - `human-judgement` TR-4.3: 切换到网格视图时，布局保持正常（网格内容在 toolbar 下方正常显示），网格内容也延伸到状态栏下方但 toolbar 遮挡
- **Notes**: 网格视图模式下，toolbar 也使用同样的半透明叠加效果，网格内容顶部 `padding` 需要设置 `EdgeInsets.only(top: kToolbarHeight + MediaQuery.of(context).padding.top)`

## [ ] Task 5: 操作按钮和标题的动态 padding（避让工具栏）
- **Priority**: P0
- **Depends On**: Task 2, Task 4
- **Description**:
  - 修改 [video_page_item.dart](file:///workspace/frontend/lib/widgets/video_page_item.dart) 的 `_buildRightActions()`：顶部 padding 改为 `EdgeInsets.fromLTRB(0, toolbarVisible ? topPadding + kToolbarHeight : topPadding, 8, 24 + bottomPadding)`
  - 修改 `_buildBottomGradient()`：底部 padding 改为 `EdgeInsets.fromLTRB(16, topPadding + 80, 96, toolbarVisible ? 24 + bottomPadding + kBottomNavHeight : 24 + bottomPadding)`
  - 通过 `ref.watch(toolbarVisibilityProvider)` 响应式更新 padding，当 toolbar 显示/隐藏时，操作按钮和标题随之移动
- **Acceptance Criteria Addressed**: AC-4, AC-5
- **Test Requirements**:
  - `human-judgement` TR-5.1: 工具栏展开时，顶部的静音按钮不会被顶部 toolbar 遮挡
  - `human-judgement` TR-5.2: 工具栏展开时，底部的标题不会被底部导航栏遮挡
  - `human-judgement` TR-5.3: 工具栏隐藏时，操作按钮和标题立即移动到更靠近屏幕边缘的位置
  - `human-judgement` TR-5.4: 移动动画平滑，与 toolbar 的 200ms 折叠动画同步
- **Notes**: 这部分已有部分实现（根据 summary），需要调整 padding 的计算逻辑，让"可见时增加 kToolbarHeight/kBottomNavHeight，隐藏时只保留安全 padding"

## [ ] Task 6: 验证、检查与代码评审
- **Priority**: P1
- **Depends On**: Task 2, Task 3, Task 4, Task 5
- **Description**:
  - 运行 `flutter analyze lib` 确保无静态分析错误
  - 检查：所有文件的 import 列表正确，没有未使用的 import
  - 检查：没有硬编码的颜色，所有颜色都来自 colors.dart
  - 检查：Grid 视图模式不受影响
  - 检查：工具栏显隐手势仍然正常工作
  - 测试：在不同设备上（刘海屏设备、普通设备、平板）验证视觉效果
- **Acceptance Criteria Addressed**: AC-6, AC-7, AC-8, NFR-1
- **Test Requirements**:
  - `programmatic` TR-6.1: `flutter analyze` 无错误、无警告
  - `human-judgement` TR-6.2: 在竖屏模式下，整体视觉效果类似抖音/TikTok：视频占满屏幕，顶部底部工具栏半透明叠加
  - `human-judgement` TR-6.3: 所有手势（滑动切换视频、点击唤醒工具栏、双击点赞）功能正常
  - `human-judgement` TR-6.4: 横屏全屏模式下布局无异常

## 实施时间线建议
- Task 1 (常量): 5 分钟
- Task 2 (顶部工具栏): 20 分钟
- Task 3 (底部导航栏): 25 分钟（架构调整有一定复杂度）
- Task 4 (视频全屏延伸): 15 分钟
- Task 5 (动态 padding): 20 分钟
- Task 6 (验证): 20 分钟
- **总计**: ~2 小时
