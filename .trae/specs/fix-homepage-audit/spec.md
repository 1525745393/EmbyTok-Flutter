# 首页页面问题修复 - Product Requirement Document

## Overview
- **Summary**: 修复首页页面代码审查中发现的 10 个问题，包括 2 个严重缺陷（覆盖层视频暂停逻辑矛盾、滚动监听器失效）、5 个中等问题、3 个低优先级问题。
- **Purpose**: 解决审查报告中发现的功能缺陷，提升首页在搜索/历史覆盖层、快速滑动、视图切换等场景的正确性和稳定性。
- **Target Users**: EmbyTok 最终用户（使用首页视频流和导航功能的用户）和开发者（维护首页代码的开发人员）。

## Goals
- 修复 `isFeedVisible` 逻辑矛盾，确保搜索/历史覆盖层打开时视频不被意外暂停
- 修复 `isPageScrollingProvider` 监听器注册时机错误，快速滑动时正确释放非当前页 controller 避免 OOM
- 清理代码质量问题：`build` 方法副作用、无效参数回调、magic number、冗余条件、重复常量等
- 保持所有已有测试通过，为修复的问题补充对应测试

## Non-Goals (Out of Scope)
- **不**重构首页的架构或职责划分（FeedView / FeedViewModel / PlaybackCoordinator 三层结构不变）
- **不**添加新功能（如新的浏览模式、手势、设置项等）
- **不**替换底层依赖库（如 video_player、cached_network_image 等）
- **不**修改 10 个问题清单以外的代码
- **不**处理 `withOpacity` 废弃 API 迁移（属于框架版本升级，单独处理）

## Background & Context
审查报告指出两个严重问题：

1. **isFeedVisible 矛盾**：PageNavigationState.isFeedVisible 仅判断 `currentIndex == feed`，但注释说明覆盖层（isOverlayPage=true）下 Feed 仍应视为可见。实际行为与设计意图相反——搜索/历史覆盖层打开时视频会被暂停。由于 IndexedStack 在覆盖层时仍显示 Feed（index=0），用户能看到视频画面但播放被中断。

2. **滚动监听器失效**：FeedView.initState 中在 `_pageController.hasClients` 为 true 时才注册 isScrollingNotifier 监听器，但刚创建的 PageController 还未 attach 到 PageView（尚未 build），hasClients 必为 false，监听器永远不注册。导致 video_player_widget 依赖的 `isPageScrollingProvider` 始终 false，快速滑动时 controller 不会被即时释放。

技术约束：
- 项目使用 Flutter 3.x + Riverpod 2.x
- 遵循现有代码模式：Riverpod、ConsumerWidget、ProviderSubscription.close() 生命周期管理
- 测试使用 flutter_test + mockito

## Functional Requirements
- **FR-1**: 搜索/历史覆盖层打开时，Feed 页面的视频播放状态保持不变（不因 Tab 可见性判断被暂停）
- **FR-2**: 快速垂直滑动视频流时，离开当前页的 VideoPlayerController 在滚动进行中被即时释放，而非等待 800ms 延迟
- **FR-3**: `onUpdateHelpVisibility` 回调不传递被忽略的参数，或改为无参回调
- **FR-4**: `build` 方法不执行副作用逻辑（initialItemId 跳转触发、首 item 播放状态初始化移至生命周期方法）
- **FR-5**: PlaybackCoordinator、VideoPoolService、FullscreenNavigator 中的硬编码数值提取为 `constants.dart` 中的具名常量
- **FR-6**: PopScope 返回键拦截逻辑移除 `search/history` 冗余判断
- **FR-7**: VideoPoolService maxSize 默认值引用 `constants.dart` 的 `kMaxPreloadControllers`，不再重复定义

## Non-Functional Requirements
- **NFR-1**: 所有已有测试必须通过（0 failure），不得引入回归
- **NFR-2**: 新增测试覆盖 FR-1 和 FR-2（两个严重问题），其他修复可选择添加或通过代码审查验证
- **NFR-3**: 修改后代码与现有风格一致（注释量、命名、Riverpod 使用模式）
- **NFR-4**: 不引入新的三方依赖

## Constraints
- **Technical**: Flutter 3.44+, Dart 3.x, Riverpod 2.5, video_player 2.9
- **Business**: 现有用户交互语义不变（返回键、Tab 切换、覆盖层切换的用户感知行为必须保持稳定，除非是修复错误行为）
- **Dependencies**: 依赖现有 `constants.dart`、`page_navigation_provider.dart`、`feed_view.dart`、`feed_autopause_test.dart`

## Assumptions
- 「搜索/历史覆盖层时视频继续播放」是正确的预期行为（与注释一致，而非与现有实现一致）
- `isPageScrollingProvider` 存在的目的就是在滚动中即时释放 controller，现有代码对该 provider 的所有使用方都期望它能在滚动时为 true
- 快速滑动（连续翻多页）场景下用户期望内存占用可控，不会累积多个已初始化 controller

## Acceptance Criteria

### AC-1: 搜索覆盖层不暂停 Feed 视频
- **Given**: 用户在首页（Feed Tab）播放一个视频
- **When**: 用户点击顶部「搜索」按钮，进入搜索覆盖层
- **Then**: 视频继续播放，不被暂停（`VideoPlayerController.pause` 不被调用）
- **Verification**: `programmatic`
- **Notes**: 同样适用于历史覆盖层

### AC-2: 搜索覆盖层返回后视频状态不变
- **Given**: 用户在 Feed 播放中打开搜索覆盖层
- **When**: 用户按返回键回到 Feed
- **Then**: 视频播放状态与进入覆盖层前一致（原本在播则仍在播，原本暂停则仍暂停）
- **Verification**: `programmatic`

### AC-3: isFeedVisible 对覆盖层返回 true
- **Given**: 构造一个 `PageNavigationState`，`currentIndex=PageIndices.search`，`isOverlayPage=true`
- **When**: 读取 `isFeedVisible`
- **Then**: 返回值为 `true`（因为覆盖层显示在 Feed 之上，Feed 仍被视为可见）
- **Verification**: `programmatic`

### AC-4: PageView 滚动时 isScrollingNotifier 监听器正确注册
- **Given**: 一个已 pump 完成的 FeedView（PageView 已挂载，PageController 有 clients）
- **When**: 手动触发 PageView 的 isScrollingNotifier 状态变化
- **Then**: `isPageScrollingProvider` 正确同步为相同值（true/false）
- **Verification**: `programmatic`

### AC-5: 快速滑动时非当前页 controller 立即释放
- **Given**: 用户在视频 1 播放中，快速滑到视频 2（仍在滚动中）
- **When**: 滚动尚未停止（isScrollingNotifier=true）
- **Then**: 视频 1 的 controller 立即被释放（_releaseCurrentController 被调用），而非等待 800ms 计时器
- **Verification**: `programmatic`（验证 isPageScrollingProvider=true 时走立即释放分支）

### AC-6: onUpdateHelpVisibility 回调语义正确
- **Given**: FeedViewModel 初始化时注入的回调
- **When**: 帮助面板显隐切换（`/` 键按下）
- **Then**: 回调接收显隐参数（若保留有参版本）或正确触发 UI 重建（若无参）
- **Verification**: `human-judgment`（代码审查：参数不被忽略 / 回调接口一致）

### AC-7: initialItemId 和首 item 初始化逻辑从 build 移出
- **Given**: 任何调用 `_buildVideoPageView` 的场景
- **When**: Widget rebuild 多次（如 setState 触发）
- **Then**: initialItemId 处理和首 item 播放初始化只执行一次，不会被 rebuild 重复触发
- **Verification**: `programmatic`（逻辑移动位置审查 + 无重复回调）

### AC-8: Magic Number 提取为常量
- **Given**: 以下硬编码数字
- **When**: 在代码中搜索它们
- **Then**: 不再作为裸数值存在，而是引用 `constants.dart` 中有注释的具名常量
- **Verification**: `human-judgment`（代码审查：5 处 magic number 均提取）

### AC-9: PopScope 冗余条件移除
- **Given**: HomeScaffold.onPopInvokedWithResult 逻辑
- **When**: 非覆盖层场景触发返回键
- **Then**: `search` 和 `history` 两种 index 的判断被移除，逻辑等价（因为 isOverlayPage=false 时这两种 index 不可能出现）
- **Verification**: `human-judgment`（代码审查 + 已有通过的 Tab 切换测试）

### AC-10: VideoPoolService maxSize 使用统一常量
- **Given**: VideoPoolService 构造和 kMaxPreloadControllers 常量
- **When**: 读取 VideoPoolService 默认 maxSize
- **Then**: 默认值引用 constants 中的常量，两处保持一致
- **Verification**: `human-judgment`（代码审查：一处定义、一处引用）

### AC-11: 已有测试全部通过
- **Given**: 项目所有测试文件（`frontend/test` 目录）
- **When**: 执行 `flutter test`
- **Then**: 0 个测试失败，无 compilation error
- **Verification**: `programmatic`

## Open Questions
- [ ] AC-1 的行为是否与产品设计一致？现有实现（覆盖层暂停）可能是有意为之（搜索时不想后台播放），但代码注释和 IndexedStack 行为表明「应继续播放」。本 PRD 以注释为准，若产品设计希望「覆盖层时暂停播放」，则 AC-1~AC-3 方向需反转，改为修复注释和测试。
