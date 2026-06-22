# 右侧操作区响应式优化 - The Implementation Plan

## [ ] Task 1: 添加响应式尺寸计算工具方法与常量
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 在 `_VideoPageItemState` 类中添加 `_responsiveSize(double baseSize, [double maxScale = 1.7])` 方法
  - 逻辑：根据 `MediaQuery.of(context).size.width` 计算缩放因子
    - `screenWidth <= 480` → `scale = 1.0`（保持当前）
    - `screenWidth > 480 and <= 800` → `scale = 1.0 + ((screenWidth - 480) / 320) * 0.3`（线性到 1.3）
    - `screenWidth > 800 and <= 1200` → `scale = 1.3 + ((screenWidth - 800) / 400) * 0.3`（线性到 1.6）
    - `screenWidth > 1200` → `scale = min(1.6 + ((screenWidth - 1200) / 720) * 0.1, maxScale)`（最多到 1.7）
  - 返回值：`baseSize * scale`，结果为 `double`
  - 添加便捷访问的 getter `double get _screenWidth => MediaQuery.of(context).size.width`
  - 确保在首次调用前检查 `context` 已可用（在 build 方法内使用）
- **Acceptance Criteria Addressed**: NFR-1, NFR-2, NFR-3
- **Test Requirements**:
  - `programmatic` TR-1.1: 当屏幕宽度 ≤ 480 时，`_responsiveSize(x)` 返回 `x * 1.0`
  - `programmatic` TR-1.2: 当屏幕宽度为 800 时，返回值约为 `x * 1.3`（± 5% 精度）
  - `programmatic` TR-1.3: 当屏幕宽度为 1200 时，返回值约为 `x * 1.6`
  - `programmatic` TR-1.4: 当屏幕宽度为 1920 时，返回值不超过 `x * 1.7`
  - `human-judgement` TR-1.5: 代码逻辑集中、命名清晰、有简短中文注释说明计算依据
- **Notes**: 缩放计算基于「屏幕越宽，放大比例越大」的简单线性插值，便于理解和调整。使用 `MediaQuery.of(context)` 而非 `WidgetsBinding.instance`，因前者在 widget 树中更可靠。

## [ ] Task 2: 将右侧操作区主容器改为响应式宽度
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 修改 `_buildRightActions()` 中的 `Positioned(width: 96)` 为响应式宽度：`width: _responsiveSize(96, 2.0)`（容器的最大放大比例略大于按钮，因为宽度还需容纳增大的间距）
  - 同步调整容器内 `EdgeInsets.fromLTRB(0, topPadding, 8, bottomPadding)` 中的右侧内边距 `8` → `_responsiveSize(8, 1.5)`
  - 保持顶部偏移计算逻辑不变（`topPadding + 56 + 40` vs `topPadding + 40`），但将偏移量中的 `56` 和 `40` 也改为响应式：`_responsiveSize(56, 1.5)` 和 `_responsiveSize(40, 1.5)`
  - 底部内边距中的 `24` 改为 `_responsiveSize(24, 1.3)`
- **Acceptance Criteria Addressed**: FR-1, FR-4, AC-1, AC-4, AC-7
- **Test Requirements**:
  - `programmatic` TR-2.1: 容器宽度不再使用硬编码的 `96`，改为调用 `_responsiveSize(96)`
  - `programmatic` TR-2.2: 内边距中的 `8`、`56`、`40`、`24` 不再硬编码，改为调用 `_responsiveSize`
  - `human-judgement` TR-2.3: 在 360px 宽屏幕上，容器宽度与修改前的 96px 视觉一致
  - `human-judgement` TR-2.4: 在 1200px 宽屏幕上，容器宽度明显增大但不显得过大

## [ ] Task 3: 将圆形按钮（48×48 系列）改为响应式尺寸
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 将以下方法中的固定 `width: 48, height: 48` 改为响应式：`_responsiveSize(48)` 作为 `width` 和 `height`
    - `_buildDeleteButton()`（约 line 1826）
    - `_buildSpeedControlButton()`（约 line 1675）
    - `_buildPlayModeButton()`（约 line 1437）
    - `_buildSubtitleButton()`（约 line 1472）
    - `_buildDiscMuteButton()`（约 line 1539）
  - 同步调整这些按钮内部的图标大小和边框宽度：
    - `Icon size: 22` → `_responsiveSize(22)`
    - `Icon size: 24` → `_responsiveSize(24)`
    - `Icon size: 28` → `_responsiveSize(28)`
    - `Border width: 2` → `min(_responsiveSize(2), 3)`（上限 3px）
    - `Text fontSize: 10` → `min(_responsiveSize(10), 14)`
- **Acceptance Criteria Addressed**: FR-2, FR-5, AC-2, AC-5, AC-6, AC-7
- **Test Requirements**:
  - `programmatic` TR-3.1: 以上 5 个方法中不再有固定的 `48`（宽高）、`22`/`24`/`28`（图标）等硬编码值，全部使用 `_responsiveSize`
  - `human-judgement` TR-3.2: 手机端（360-480px）上圆形按钮视觉大小与修改前一致
  - `human-judgement` TR-3.3: 桌面端（1200px+）上圆形按钮明显增大，图标和文字按比例放大，边框不显得过粗

## [ ] Task 4: 将海报头像按钮（56×56）改为响应式尺寸
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 修改 `_buildPosterAvatar()`（约 line 986-1110）中：
    - 外层 `SizedBox(width: 56, height: 56)` → `_responsiveSize(56)`
    - 内部 `Container(width: 56, height: 56)` → `_responsiveSize(56)`
    - 内嵌 + 号按钮 `Container(width: 22, height: 22)` → `_responsiveSize(22)`
    - + 号按钮内 `Icon size: 14` → `min(_responsiveSize(14), 18)`
  - 保持圆形外观和颜色配置不变
- **Acceptance Criteria Addressed**: FR-2, FR-5, AC-2, AC-5, AC-6
- **Test Requirements**:
  - `programmatic` TR-4.1: `56`、`22`、`14` 等硬编码值全部被 `_responsiveSize` 替代
  - `human-judgement` TR-4.2: 海报头像在手机端与修改前视觉一致
  - `human-judgement` TR-4.3: 海报头像在桌面端明显增大，内嵌的 + 号按钮与主头像保持合理比例

## [ ] Task 5: 将通用按钮 `_PressableActionButton` 改为响应式
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 修改 `_PressableActionButton` 和 `_PressableActionButtonState`（约 line 1924-2055）：
    - `Icon size: 32` → `_responsiveSize(32)`
    - `Text fontSize: 12` → `min(_responsiveSize(12), 16)`
    - 标签与图标间距 `SizedBox(height: 4)` → `min(_responsiveSize(4), 6)`
    - 内部 `EdgeInsets.symmetric(horizontal: 8, vertical: 4)` → `_responsiveSize(8)` 和 `_responsiveSize(4)`
    - 焦点高亮边框 `Border.all(width: 2)` → `min(_responsiveSize(2), 3)`
    - 圆角 `BorderRadius.circular(8)` → `min(_responsiveSize(8), 12)`
  - **注意**: `_PressableActionButton` 本身是一个独立的 `StatefulWidget`，不直接访问 `_VideoPageItemState`。有两种方案：
    - 方案 A（推荐）：将 `_PressableActionButton` 移到 `_VideoPageItemState` 内部作为内嵌 widget（或通过构造函数传入 screenWidth）
    - 方案 B：在 `_PressableActionButton` 内部使用自己的 `MediaQuery` 调用
  - 选择方案 B：保持 `_PressableActionButton` 为独立 widget，在其 `build` 方法内使用 `MediaQuery.of(context).size.width` 进行相同的响应式计算（可提取一个静态工具方法）
- **Acceptance Criteria Addressed**: FR-3, FR-5, NFR-5, AC-3, AC-5, AC-6, AC-8
- **Test Requirements**:
  - `programmatic` TR-5.1: `_PressableActionButtonState.build()` 内不再有硬编码的 `32`、`12`、`4`、`8`
  - `programmatic` TR-5.2: 在 `_PressableActionButton` 内实现了独立的响应式计算（可能是静态方法或内联计算）
  - `human-judgement` TR-5.3: 点赞/信息/全屏等通用按钮在手机端与修改前视觉一致
  - `human-judgement` TR-5.4: 在桌面端按钮图标和文字明显增大但不过分，标签仍保持「辅助信息」的视觉层次
  - `human-judgement` TR-5.5: TV 焦点模式下焦点高亮边框随按钮大小等比放大

## [ ] Task 6: 将按钮间垂直间距改为响应式
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 在 `_buildRightActions()` 内的按钮列中，将所有 `const SizedBox(height: 20)` 替换为 `SizedBox(height: _responsiveSize(20, 1.6))`
  - 最大放大比例 1.6，因此最大间距 ≈ 32px
- **Acceptance Criteria Addressed**: FR-4, AC-4
- **Test Requirements**:
  - `programmatic` TR-6.1: `_buildRightActions` 中不再有 `const SizedBox(height: 20)`
  - `human-judgement` TR-6.2: 手机端间距与修改前一致
  - `human-judgement` TR-6.3: 桌面端按钮列间距适当增大，视觉上不拥挤也不过分松散

## [ ] Task 7: 将纯净模式右侧操作区改为响应式
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 修改 `_buildCleanModeRightActions()`（约 line 1607-1627）中的：
    - `buttonWidth: 96.0` → `_responsiveSize(96, 2.0)`
  - 确保 `_DraggableCleanActions` 能正确接收动态计算的宽度值（应该已经是 `double` 类型，无需修改）
- **Acceptance Criteria Addressed**: FR-6, AC-9, AC-5, AC-6
- **Test Requirements**:
  - `programmatic` TR-7.1: `_buildCleanModeRightActions` 中不再有硬编码的 `96.0`
  - `human-judgement` TR-7.2: 纯净模式下按钮在手机端与修改前视觉一致
  - `human-judgement` TR-7.3: 纯净模式下按钮在桌面端适当放大，与主操作区风格一致

## [ ] Task 8: 优化响应式计算方法（代码审查与可维护性增强）
- **Priority**: P1
- **Depends On**: Task 1-7
- **Description**:
  - 审查 Task 1-7 实现的代码，确保响应式计算逻辑集中且命名清晰
  - 如果 `_responsiveSize` 调用散落在太多方法中，考虑将其提取为一个独立的 `_RightActionSizes` 类或在 `_buildRightActions` 顶部一次性计算所有尺寸，然后作为参数传入子方法
  - 确保每个方法都有简短的中文注释说明其功能和响应式计算依据
- **Acceptance Criteria Addressed**: NFR-2, AC-10
- **Test Requirements**:
  - `human-judgement` TR-8.1: 代码审查时能轻松理解响应式计算逻辑，无需在多个方法间跳转
  - `human-judgement` TR-8.2: 方法/类命名清晰、有简短中文注释
  - `programmatic` TR-8.3: `flutter analyze` 不产生新的 warning/error

## [ ] Task 9: 中央播放按钮响应式增强（可选）
- **Priority**: P2
- **Depends On**: Task 1
- **Description**:
  - 将中央播放/暂停按钮容器（约 line 622 `width: 72, height: 72`）改为 `_responsiveSize(72, 1.5)`
  - 将中央播放按钮图标（`size: 48`）改为 `_responsiveSize(48, 1.5)`
  - 这是可选增强项，主要目的是使中央播放按钮与右侧操作区保持视觉协调
- **Acceptance Criteria Addressed**: FR-7, AC-6
- **Test Requirements**:
  - `human-judgement` TR-9.1: 中央播放按钮在大屏上与右侧操作区按钮大小协调
  - `human-judgement` TR-9.2: 在小屏上中央播放按钮不显得过大或遮挡视频画面

## [ ] Task 10: 综合验证与测试
- **Priority**: P0
- **Depends On**: Task 1-8（Task 9 可选）
- **Description**:
  - 在以下模拟/真实尺寸下验证：360×640（标准手机）、480×800（大屏手机）、768×1024（平板）、1280×720（桌面横屏）、1920×1080（全高清桌面）
  - 使用 Flutter DevTools Widget Inspector 确认无布局溢出
  - 使用 Android Studio / Xcode 模拟器或 Chrome DevTools 设备模拟进行跨尺寸验证
  - 使用键盘方向键模拟 TV 遥控器焦点，验证焦点高亮随按钮尺寸变化
  - 测试纯净模式（isAutoPlay=true）下按钮区显示
- **Acceptance Criteria Addressed**: AC-1 至 AC-10
- **Test Requirements**:
  - `programmatic` TR-10.1: `flutter analyze lib/widgets/video_page_item.dart` 不产生 error 级别问题
  - `human-judgement` TR-10.2: 在至少 3 种不同屏幕尺寸（手机/平板/桌面）上视觉检查通过
  - `human-judgement` TR-10.3: TV 焦点模式下焦点高亮边框正确跟随按钮大小变化
  - `human-judgement` TR-10.4: 纯净模式下按钮区正确响应式显示
