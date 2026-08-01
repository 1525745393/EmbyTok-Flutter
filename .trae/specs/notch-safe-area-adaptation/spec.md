# 刘海屏/挖孔屏安全区适配 Spec

## Why
当前 App 已启用 edge-to-edge 并用 `SafeArea`/`MediaQuery.padding` 处理顶部底部留白，但在全面屏（刘海屏/水滴屏/挖孔屏）设备上存在两类系统性缺口：
1. `android:windowLayoutInDisplayCutoutMode` 未配置，横屏全屏视频默认不延伸到刘海区，导致两侧黑边或控件被刘海物理遮挡；
2. 沉浸式模式（`SystemUiMode.immersiveSticky`）下 `MediaQuery.padding` 被系统置 0，但物理刘海/挖孔依然存在，顶部/左右控件失去避让依据（`viewPadding` 才是始终反映物理 inset 的字段）。

这会导致横屏全屏观看时返回按钮、标题、进度条等被刘海遮挡，竖屏 feed 顶部右侧操作栏在沉浸式下贴到刘海背后。

## What Changes
- 在 `styles.xml` 的 `LaunchTheme` 与 `NormalTheme` 中声明 `android:windowLayoutInDisplayCutoutMode` 为 `shortEdges`，让内容延伸到刘海区，再由 Flutter 层避让（**BREAKING**：改变横屏全屏视频的渲染区域）。
- 新增统一的"物理安全区"取值工具：在沉浸式模式下优先使用 `MediaQuery.viewPadding`，非沉浸式下回退 `MediaQuery.padding`，确保刘海/挖孔始终被避让。
- 横屏全屏视频页面（`fullscreen_video_page.dart`）顶部栏与底部控件增加左右 `viewPadding` 避让；竖屏 feed（`video_page_item.dart`）顶部右侧操作栏改用物理安全区顶部值。
- 统一底部导航栏/手势条区域处理，避免沉浸式切换时 `padding` 变 0 导致底部控件跳动。

## Impact
- Affected specs: `responsive_design`、`fullscreen-black-screen`、`fullscreen-button-to-top`、`view-mode-fullscreen-impl`、`video-panel-progress-bar`、`ui-optimization-v1`
- Affected code:
  - `android/app/src/main/res/values/styles.xml`（新增 `windowLayoutInDisplayCutoutMode`）
  - `android/app/src/main/res/values-v28/styles.xml`（新建，Android 9+ 才支持该属性）
  - `lib/widgets/video_page_item.dart`（顶部右侧操作栏 padding 数据源）
  - `lib/views/fullscreen_video_page.dart`（横屏左右刘海避让）
  - `lib/views/home_scaffold.dart`（底部导航沉浸式切换防跳动）
  - 新增 `lib/utils/safe_insets.dart`（物理安全区取值工具）

## ADDED Requirements

### Requirement: 物理安全区取值工具
系统 SHALL 提供一个 `SafeInsets` 工具，在任意 `SystemUiMode` 下都能返回设备物理刘海/挖孔/系统栏的避让值。

- 优先级：沉浸式（`immersiveSticky`/`leanBack`）下使用 `MediaQuery.viewPadding`；非沉浸式下使用 `MediaQuery.padding`。
- 接口：`SafeInsets.of(context)` 返回 `EdgeInsets`，并提供 `top`/`bottom`/`left`/`right` 单值访问。

#### Scenario: 沉浸式模式下顶部刘海被正确避让
- **WHEN** 视频页面进入 `SystemUiMode.immersiveSticky` 且设备有顶部刘海
- **THEN** `SafeInsets.of(context).top` 返回非零的物理刘海高度
- **AND** 顶部控件（返回按钮/标题）不被刘海遮挡

#### Scenario: 非沉浸式模式下使用系统栏 padding
- **WHEN** 页面处于 `SystemUiMode.edgeToEdge` 且状态栏可见
- **THEN** `SafeInsets.of(context).top` 等于 `MediaQuery.padding.top`
- **AND** 行为与当前 `SafeArea` 一致，无视觉回退

### Requirement: Android DisplayCutout 模式配置
系统 SHALL 在 Android 9（API 28）及以上设备声明 `windowLayoutInDisplayCutoutMode = shortEdges`，使横屏全屏内容延伸到刘海区。

#### Scenario: 横屏全屏视频内容延伸到刘海区
- **GIVEN** Android 9+ 刘海屏设备，处于横屏全屏视频
- **WHEN** 渲染视频画面
- **THEN** 视频画面延伸至刘海区后方（不出现两侧黑边）
- **AND** 交互控件通过物理安全区避让刘海，不被遮挡

#### Scenario: Android 8 及以下设备正常显示
- **GIVEN** 不支持 DisplayCutout API 的旧设备
- **WHEN** 渲染页面
- **THEN** 不因新增配置崩溃或产生异常黑边

## MODIFIED Requirements

### Requirement: 横屏全屏视频控件避让
横屏全屏视频页面顶部栏、底部进度条、左右侧交互区域 SHALL 根据当前方向的物理安全区进行避让。

- 顶部栏：`top` 使用 `SafeInsets.of(context).top`。
- 底部进度条：`bottom` 使用 `SafeInsets.of(context).bottom`。
- 横屏左右两侧：`left`/`right` 使用 `SafeInsets.of(context).left`/`.right`，确保返回按钮与右侧操作不被侧边刘海/挖孔遮挡。

#### Scenario: 横屏刘海在左侧时返回按钮不被遮挡
- **GIVEN** 竖屏刘海手机转横屏，刘海位于左侧
- **WHEN** 全屏视频顶部栏渲染
- **THEN** 返回按钮左侧留出 `SafeInsets.left` 的间距
- **AND** 按钮完整可见可点

### Requirement: 竖屏 Feed 顶部操作栏避让
竖屏 feed（`video_page_item.dart`）右侧操作栏顶部 padding SHALL 使用物理安全区顶部值，保证沉浸式下不被刘海遮挡。

#### Scenario: 沉浸式 feed 下顶部操作栏避开刘海
- **WHEN** feed 进入 `immersiveSticky` 且设备有顶部刘海
- **THEN** 右侧操作栏顶部起始位置为 `SafeInsets.top + 预留间距`
- **AND** 操作按钮不被刘海遮挡

### Requirement: 底部导航沉浸式切换防跳动
`home_scaffold.dart` 底部导航栏 SHALL 在沉浸式/非沉浸式切换时保持稳定高度，不因 `padding` 归零产生跳动。

#### Scenario: 退出沉浸式视频返回首页底部导航不跳动
- **WHEN** 从沉浸式视频页面返回首页
- **THEN** 底部导航栏高度保持一致
- **AND** 不出现底部控件向下/向上跳动

## REMOVED Requirements
（本次无移除项）
