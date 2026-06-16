# EmbyTok 沉浸式交互设计 - Product Requirement Document

## Overview
- **Summary**: 在竖屏视频流模式下实现手势驱动的沉浸式全屏体验：竖向滑动时顶部工具栏和底部导航栏自动平滑隐藏/显示；进入全屏横屏模式时系统 UI 完全隐藏，视频画面延伸至屏幕全部边缘。
- **Purpose**: 当前工具栏始终占据 ~120px 垂直空间（顶栏 56px + 底栏 ~64px），在 6.5" 手机上占用约 10% 可视区域。动画切换"硬切"不跟手，缺少控制感和层级感。需要让用户在进入浏览状态后，全部视觉焦点集中在视频内容本身。
- **Target Users**: 日常使用 EmbyTok 浏览竖屏视频的用户，尤其是在通勤、休闲场景下的短视频消费用户。

## Goals
- **G1 — 手势驱动 UI 消隐**：竖屏视频流模式下，向上滑动浏览时自动隐藏顶部 `TopToolBar` 和底部 `BottomNavigationBar`，下滑到顶部或停顿时重新显示。
- **G2 — 工具栏跟随动画**：隐藏/显示必须是跟随手指的平滑过渡（`AnimatedContainer` + `Opacity`），而非立即跳变。
- **G3 — 沉浸式模式切换**：进入横屏全屏时，系统状态栏、导航栏全部隐藏（`SystemUiMode.immersiveSticky`），退出时恢复（`SystemUiMode.edgeToEdge`）。
- **G4 — 页面边缘适配**：视频画面必须延伸到屏幕所有边缘；标题/字幕/收藏按钮等叠加 UI 必须有正确的 `EdgeInsets` 适配 notch 和系统手势区域。

## Non-Goals (Out of Scope)
- 不在网格视图（`VideoGridView`）下应用工具栏消隐动画——网格需要持续可见工具栏。
- 不修改视频播放器本身的播放/暂停行为，只改变 UI 覆盖层的可见性。
- 不引入任何外部动画库（如 `flutter_animate`、`simple_animations`），使用 Flutter 内置动画。
- 不对横屏模式做复杂的"手势滑动切换视频"改造——横屏只做沉浸式 UI 模式切换。
- 不处理 iOS Home Indicator 的持久移除（使用系统默认的 `immersiveSticky` 行为即可）。

## Background & Context

当前代码库结构：
- `lib/views/feed_view.dart`: `Scaffold → Stack → [VideoPageView, TopToolBar(Positioned)]`，工具栏始终可见
- `lib/views/home_scaffold.dart`: `Scaffold → IndexedStack + BottomNavigationBar`，底部导航栏为 App 级全局组件
- `lib/widgets/top_tool_bar.dart`: 固定高度 56px，内部含 `SafeArea(bottom: false)`
- `lib/widgets/video_page_item.dart`: 标题/描述叠层使用硬编码 `EdgeInsets.fromLTRB(16, 80, 96, 24)`（左 16 + 顶部安全 80 + 右侧按钮区 96 + 底部 24）
- `lib/providers/`: 使用 Riverpod 2.6.1 (`StateNotifierProvider` / `StateProvider`)
- `flutter/services.dart`: 已在 `_toggleFullscreen()` 中使用 `SystemChrome.setEnabledSystemUIMode()`

关键的系统 UI 知识：
- `SystemUiMode.immersiveSticky`: Android 沉浸式，滑动屏幕边缘时系统 UI 短暂出现后自动消失
- `SystemUiMode.edgeToEdge`: 应用绘制到状态栏/导航栏后方，但 UI 仍然可见（需要手动设置透明）
- `MediaQuery.of(context).padding`: 获取 notch / 动态岛 / 底部手势条的安全 padding
- `MediaQuery.of(context).viewInsets`: 获取键盘等临时 UI insets

## Functional Requirements

### FR-1: 工具栏自动隐藏/显示 Provider
- 创建 `toolbarVisibilityProvider`（`StateNotifier<bool>`），管理工具栏"是否可见"的全局状态
- Provider 暴露 `hide()`、`show()`、`toggle()` 三个方法
- Provider 内部维护 `_debounceTimer`，避免频繁状态抖动（每次状态变化后 200ms 防抖）
- Provider 在 `FeedView.dispose()` 中被清理，不泄露到其他页面

### FR-2: PageView 滑动方向识别
- 在 `FeedView` 的 `PageView.builder` 中通过 `_pageController.addListener()` 监听滚动位移
- 比较当前 `offset` 与上一次记录的 offset，判定方向：`delta > 0` 为向下/向上（需要区分"正在向下翻页"和"正在向上回滚"）
- 更准确的触发点是 `onPageChanged` 回调：切换到下一条时触发 `hide()`，回到顶部（index 减小）时触发 `show()`
- 另一条触发路径：双击点赞/长按倍速时不改变工具栏状态（避免打断手势体验）

### FR-3: 工具栏跟随动画
- `TopToolBar`: 用 `AnimatedContainer(height: visible ? 56 : 0)` + `AnimatedOpacity(opacity: visible ? 1.0 : 0.0)` 包装；动画时长 200ms，`Curves.easeOut`
- `BottomNavigationBar`: 使用 `AnimatedContainer(height: visible ? kBottomNavHeight : 0)`，保持与顶栏动画同步
- 动画参数统一放在 `utils/constants.dart`: `kToolbarAnimMs = 200`, `kToolbarHeight = 56`, `kBottomNavHeight = 64`

### FR-4: 横屏沉浸式系统 UI 切换
- 进入横屏全屏时调用 `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`
- 退出横屏/返回竖屏时调用 `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)`
- `SystemUiOverlayStyle` 设置：状态栏/导航栏背景透明，图标根据主题色自适应
- 监听 `WidgetsBindingObserver.didChangeMetrics()` 应对旋转后重建
- 在 `initState()` 注册，`dispose()` 恢复默认 `SystemUiMode.edgeToEdge`

### FR-5: 边缘安全 padding 适配
- 顶栏叠加层改为 `SafeArea(top: true, bottom: false)` 确保不被 notch 遮挡
- `video_page_item.dart` 的右侧收藏按钮区：改为 `EdgeInsets.only(right: max(16, MediaQuery.padding.right) + 16, bottom: max(24, MediaQuery.padding.bottom) + 16)`
- 底部标题/描述区：保留 `top: 80` 顶部偏移（为了给工具栏让路），但在沉浸式模式下动态减少到 `top: 24`

### FR-6: 沉浸式模式下工具栏点击恢复
- 在工具栏隐藏状态下，用户点击视频画面任意位置（非手势区域），工具栏短暂显示 3 秒，然后自动重新隐藏
- 使用 `_restoreTimer`：点击时 `show()` 并启动 Timer，到期后 `hide()`
- 如果在倒计时期间用户已经发起了新的滑动交互，取消 Timer 并按 FR-2 规则处理

## Non-Functional Requirements

### NFR-1: 性能
- 滚动监听中不做任何 `setState`，仅通过 Riverpod 通知 UI 重建
- 每次滚动回调不超过 1 次 Provider 状态写入（通过 `_lastState` 缓存去重）
- `flutter analyze lib` 必须 0 error，0 warning

### NFR-2: 动画流畅度
- 所有动画在 120Hz 设备上稳定运行（`AnimatedContainer` 默认支持）
- 工具栏隐藏动画期间，视频画面不重新布局——只改 overlay 的高度和透明度

### NFR-3: 兼容性
- Android API 26+（`SystemUiMode.immersiveSticky` 最低要求）
- iOS 13+（通过 Flutter 的平台适配层自动处理）
- 在不支持沉浸式模式的平台上，降级为"edge-to-edge + 透明状态栏"

### NFR-4: 可维护性
- 所有动画时长、高度阈值以常量形式集中在 `utils/constants.dart`
- 工具栏可见性状态单一来源：`toolbarVisibilityProvider`
- 避免跨组件直接调用 setState；所有状态变更通过 Provider 进行

## Constraints

- **技术**: Flutter 3.x / Dart 3.x / Riverpod 2.6.1；禁止引入新的第三方动画或状态管理库
- **平台**: 优先 Android（主发布平台），iOS 作为次要目标；Web/桌面不支持沉浸式模式
- **时间**: 单次发布周期，修改预计 3-5 个文件，代码变更 < 300 行
- **依赖**: `flutter/services.dart`（已存在）、`flutter_riverpod`（已存在）、`dart:async`（已存在）

## Assumptions

- 假设用户在视频流模式下的主要交互是"向上滑动切换下一条"，因此隐藏工具栏的默认行为就是跟随向上滑动
- 假设横屏全屏模式下用户不会频繁切换回竖屏——因此状态恢复可以有 200ms 延迟
- 假设系统 UI 透明化由 AndroidManifest.xml 中 `android:windowEnableSplitTouch=true` 等属性启用（非本次 scope）
- 假设当前 `isFullscreenProvider` 可以扩展为承载更多沉浸式状态（如 "top bar visible"）

## Acceptance Criteria

### AC-1: 向上滑动时工具栏消失
- **Given**: 用户处于视频流（feed）视图模式下，并且工具栏当前可见
- **When**: 用户向上滑动屏幕触发 `PageView` 切换到下一条视频
- **Then**: `TopToolBar` 高度从 56px → 0px 平滑过渡；`BottomNavigationBar` 从 64px → 0px 平滑过渡；动画时长为 200ms，使用 `Curves.easeOut`
- **Verification**: `human-judgment`
- **Notes**: 可通过 `debugPrint` 或日志确认 Provider 接收到状态变更

### AC-2: 下滑回顶时工具栏重新出现
- **Given**: 工具栏当前处于隐藏状态，用户已浏览多条视频
- **When**: 用户向下滑动回到前一条视频，或点击视频画面的非手势区域
- **Then**: 工具栏从 0 → 56/64 px 重新展开；点击画面触发时工具栏显示 3 秒后再次自动隐藏
- **Verification**: `human-judgment`

### AC-3: Provider 防抖无抖动
- **Given**: 快速连续上下滑动（轻微滚动 10 次以上）
- **When**: `PageView` page controller 发出多次 offset 变化
- **Then**: `toolbarVisibilityProvider` 的状态变更次数不超过实际方向切换次数的 2 倍（去重生效），不会发生"闪"动画
- **Verification**: `human-judgment` + 日志验证

### AC-4: 横屏全屏切换系统 UI
- **Given**: 用户在竖屏视频流模式下点击"全屏按钮"
- **When**: Flutter 的 `build` 完成后应用 `SystemUiMode.immersiveSticky`
- **Then**: 系统状态栏和导航栏消失；视频画面延伸到屏幕顶部和底部边缘；`MediaQuery.padding.top > 0` 时标题区自动下移避免被 notch 遮挡
- **Verification**: `human-judgment`

### AC-5: 竖屏恢复系统 UI
- **Given**: 用户在横屏全屏模式下再次点击"退出全屏"按钮
- **When**: Flutter orientation 切换回 portrait 后
- **Then**: 系统状态栏和导航栏重新可见（`SystemUiMode.edgeToEdge`）；顶栏和底栏工具条恢复初始展开状态
- **Verification**: `human-judgment`

### AC-6: 静态分析通过
- **Given**: 完成所有代码变更并提交
- **When**: 运行 `flutter analyze --no-pub lib`
- **Then**: 输出 "No issues found!" — 0 error, 0 warning, 0 info
- **Verification**: `programmatic`

### AC-7: 其他页面不受影响
- **Given**: 用户从视频流视图切换到搜索、收藏、历史、设置页面
- **When**: `BottomNavigationBar` 切换 index
- **Then**: 这些页面的工具栏（如果有）始终可见；不发生误隐藏；Provider 在 `dispose()` 时正确重置状态
- **Verification**: `human-judgment`

## Open Questions

- [ ] **Q1**: 横屏沉浸式模式下右侧收藏/播放按钮是否也需要隐藏？还是保持始终可见？（默认：保持始终可见，因为是核心操作按钮）
- [ ] **Q2**: 工具栏隐藏动画 200ms 是否过快？是否需要根据设备帧率动态调整？（默认：固定 200ms，中高端设备视觉流畅）
- [ ] **Q3**: "点击画面唤醒工具栏" 的交互是否会与现有的"单击播放/暂停"冲突？（默认：单击播放/暂停时也触发 show；双击点赞时不触发 show，以避免动画冲突）
- [ ] **Q4**: iOS 设备上的 Home Indicator（底部横条）在沉浸式模式下是否需要进一步处理？（默认：使用 `SystemUiMode.immersiveSticky`，由 Flutter 自动适配 iOS）
