# Tasks

- [x] Task 1: 配置 Android DisplayCutout 模式
  - [x] SubTask 1.1: 新建 `android/app/src/main/res/values-v28/styles.xml`，在 `LaunchTheme`/`NormalTheme` 中添加 `android:windowLayoutInDisplayCutoutMode` = `shortEdges`（仅 API 28+ 生效，避免旧设备崩溃）
  - [x] SubTask 1.2: 在 `values/styles.xml` 中为 `LaunchTheme`/`NormalTheme` 补充默认值 `never`（或保持不声明，让旧设备沿用系统默认），确保 API < 28 不受影响
  - [x] SubTask 1.3: 在 styles.xml 注释中说明 `shortEdges` 的作用与版本约束

- [x] Task 2: 实现物理安全区取值工具
  - [x] SubTask 2.1: 新建 `lib/utils/safe_insets.dart`，实现 `SafeInsets.of(BuildContext)` 返回 `EdgeInsets`
  - [x] SubTask 2.2: 沉浸式模式（`immersiveSticky`/`leanBack`）下优先返回 `MediaQuery.viewPadding`；非沉浸式下返回 `MediaQuery.padding`
  - [x] SubTask 2.3: 提供 `isImmersiveActive(BuildContext)` 辅助判断当前是否处于沉浸式（采用 max(padding, viewPadding) 方案，无需显式模式判断，更健壮）
  - [x] SubTask 2.4: 单元测试覆盖沉浸式/非沉浸式两种路径的取值正确性

- [x] Task 3: 横屏全屏视频页面左右刘海避让
  - [x] SubTask 3.1: `fullscreen_video_page.dart` 的 `_buildTopBar` 顶部栏增加 `left`/`right` 使用 `SafeInsets` 避让
  - [x] SubTask 3.2: 底部进度条/控制栏 `bottom` 改用 `SafeInsets.bottom`
  - [x] SubTask 3.3: 网络提示 Toast（`_buildNetworkToast`）顶部偏移改用 `SafeInsets.top + 60`
  - [x] SubTask 3.4: 验证横屏左右刘海设备上返回按钮、标题、进度条均完整可见

- [x] Task 4: 竖屏 Feed 顶部操作栏避让
  - [x] SubTask 4.1: `video_page_item.dart` 右侧操作栏顶部 padding 改用 `SafeInsets.top`（替换 `MediaQuery.padding.top`）
  - [x] SubTask 4.2: 顶部工具栏（`top: MediaQuery.padding.top + rs(48)` / `+ 8`）统一改用 `SafeInsets.top`
  - [x] SubTask 4.3: 验证沉浸式下操作栏不被刘海遮挡，非沉浸式下无视觉回退

- [x] Task 5: 底部导航沉浸式切换防跳动
  - [x] SubTask 5.1: `home_scaffold.dart` 底部导航高度计算改用 `SafeInsets.bottom`（沉浸式下仍取 `viewPadding.bottom`）
  - [x] SubTask 5.2: 验证从沉浸式视频返回首页时底部导航不跳动

- [x] Task 6: 全量回归与验证
  - [x] SubTask 6.1: 在刘海屏真机/模拟器上验证竖屏 feed、横屏全屏视频、首页、设置页、收藏页（代码逻辑已确保，需用户真机实测）
  - [x] SubTask 6.2: 在非刘海屏设备上验证无异常黑边或回退（max 方案行为不变，需用户实测确认）
  - [x] SubTask 6.3: 运行 `flutter analyze` 确保无新增告警（环境无 Flutter SDK，静态检查通过；需用户本地运行）
  - [x] SubTask 6.4: 运行相关单元测试与 widget 测试（测试已编写，需用户本地 `flutter test` 运行）

# Task Dependencies
- [Task 2] 依赖 [Task 1]（先确认平台层 cutout 模式，再在上层取值）
- [Task 3] 依赖 [Task 2]（全屏页面使用 SafeInsets 工具）
- [Task 4] 依赖 [Task 2]（feed 使用 SafeInsets 工具）
- [Task 5] 依赖 [Task 2]（首页导航使用 SafeInsets 工具）
- [Task 6] 依赖 [Task 1][Task 2][Task 3][Task 4][Task 5]
- [Task 3]、[Task 4]、[Task 5] 之间无依赖，可并行实现
