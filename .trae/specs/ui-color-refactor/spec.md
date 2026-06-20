# UI 界面颜色与主题一致性修复 - 产品需求文档

## 概述
- **概要**：当前 EmbyTok Flutter 应用已在 `app.dart` 和 `theme/app_theme.dart` 中实现了 Material Design 3 的动态色彩系统（通过 `ColorScheme.fromSeed()` 支持亮色/暗色切换），但 **27 个文件（包含视图和组件）仍在直接引用 `colors.dart` 中的硬编码颜色常量**。这导致亮色模式下出现严重的视觉问题（白色文字在浅灰色背景上完全不可读）、主题切换效果不一致。本次修复将全面迁移所有颜色引用至 `Theme.of(context).colorScheme` 的语义化 token。
- **目的**：解决亮色/暗色主题切换时文字不可读、组件颜色不统一的问题，确保整个应用在任意主题模式下的视觉一致性和可访问性（符合 WCAG AA 对比度要求）。
- **目标用户**：所有使用主题切换功能的用户（亮色/暗色/跟随系统）、TV 模式用户、使用分享功能的用户。

## 目标
- 将 `colors.dart` 中的 20+ 个颜色常量替换为 `colorScheme` 的语义化 token
- 将 27 个文件中直接使用 `Colors.white`、`Colors.black54`、`Color(0xFF...)` 的硬编码替换为主题色
- 将硬编码的 `fontSize` 改为响应式大小（`responsiveSize`）或使用 `TextTheme`
- 修复缺失 `maxLines` 和 `TextOverflow.ellipsis` 的长文本
- 确保 `flutter analyze` 无警告且应用构建正常

## 非目标（超出范围）
- 不引入新的主题配色（保持 seed 色 `0xFFE91E63`）
- 不重构 `TextTheme` 全局定义（仅按需要改用 `Theme.of(context).textTheme`）
- 不修改组件行为逻辑（仅颜色和尺寸相关的视觉改动）
- 不重写 widgets（如不重写 `video_page_item.dart` 的结构）

## 背景与上下文
- **技术栈**：Flutter 3.10+、Dart、flutter_riverpod、go_router
- **现有主题架构**：`app_theme.dart` 已实现 `ColorScheme.fromSeed(seedColor: Color(0xFFE91E63))`，为暗色和亮色分别生成完整的色彩方案；`app.dart` 已配置 `theme`、`darkTheme`、`themeMode`
- **问题分布**：
  - `colors.dart` 中定义了 `primaryPink`、`textPrimary`、`textSecondary`、`textTertiary`、`textPlaceholder`、`textQuaternary`、`dividerColor`、`progressBackground`、`backgroundColor`、`grey800`/`grey900`、`amberColor`、`historyPink`、`errorColor`、`surfaceColorL1/L2/L3`、`overlayBlack`/`overlayBlackDeep`、`black54`/`black87`、`durationBadgeBackground` 等暗色专用常量
  - **27 个文件**（views 11 个 + widgets 13 个 + utils/theme 3 个）仍在直接导入 `colors.dart` 并使用这些常量
  - 另有多处使用 `Colors.white`、`Colors.white70`、`Colors.black54`、`Colors.black87`、`Colors.red`、`Colors.grey[900]` 等 Material 原色
  - 更有 `Color(0xFFE91E63)`、`Color(0xFFFF9800)` 等直接硬编码的十六进制色值
  - **130+** 处 `fontSize` 硬编码未使用 `responsiveSize`
  - 多处 `Text` 组件未提供 `maxLines`/`overflow` 属性，长文本会在小屏溢出

## 功能需求
- **FR-1**：所有使用 `colors.dart` 颜色常量的文件，全部替换为 `Theme.of(context).colorScheme` 的语义 token，映射关系：
  - `primaryPink` → `colorScheme.primary`
  - `historyPink` → `colorScheme.primary`（或 `colorScheme.primaryContainer`）
  - `textPrimary` → `colorScheme.onSurface`
  - `textSecondary` → `colorScheme.onSurface.withOpacity(0.7)` 或 `colorScheme.onSurfaceVariant`
  - `textTertiary` → `colorScheme.onSurface.withOpacity(0.54)` 或 `colorScheme.onSurfaceVariant.withOpacity(0.7)`
  - `textPlaceholder` → `colorScheme.onSurface.withOpacity(0.3)`
  - `textQuaternary` → `colorScheme.onSurface.withOpacity(0.38)`
  - `dividerColor` → `colorScheme.outlineVariant`
  - `progressBackground` → `colorScheme.surfaceContainerHighest` 或 `surface.withOpacity(0.2)`
  - `backgroundColor` → `colorScheme.surface`
  - `grey800`/`grey900` → `colorScheme.surface` 或 `surfaceContainerHighest`
  - `amberColor` → `colorScheme.tertiary` 或 `colorScheme.primary`（用于强调）
  - `errorColor` → `colorScheme.error`
  - `surfaceColorL1/L2/L3` → 用 `colorScheme.surface` 不同的不透明度
  - `overlayBlack` / `overlayBlackDeep` → 用 `colorScheme.surface.withOpacity(0.6~0.8)` 或直接用渐变
  - `black54` / `black87` → `colorScheme.surface.withOpacity(0.54)` / `colorScheme.surface.withOpacity(0.87)`
  - `durationBadgeBackground` → `colorScheme.surface.withOpacity(0.7)`
- **FR-2**：直接使用 `Colors.white`、`Colors.white70`、`Colors.black54`、`Colors.black87` 的地方替换为主题色 token
  - `Colors.white` → `colorScheme.onSurface`
  - `Colors.white70` → `colorScheme.onSurface.withOpacity(0.7)`
  - `Colors.black54` → `colorScheme.surface.withOpacity(0.54)`
  - `Colors.black87` → `colorScheme.surface.withOpacity(0.87)`
  - `Colors.red` → `colorScheme.error`
  - `Colors.grey[900]` → `colorScheme.surface`
  - `Colors.transparent` → 保留或使用 `Colors.transparent`（语义上无问题）
- **FR-3**：使用 `Color(0xFFE91E63)`、`Color(0xFFFF9800)` 等直接硬编码颜色的地方，替换为 `colorScheme.primary` 或 `colorScheme.tertiary` 等语义 token
- **FR-4**：将组件/视图文件中的硬编码 `fontSize`（如 `fontSize: 12`、`fontSize: 16`、`fontSize: 48` 等）改为响应式大小
  - 对于普通文本（非标题）：先在方法内声明 `final scheme = Theme.of(context).colorScheme;` 和 `final rs = (double base, [double max = 1.8]) => responsiveSize(context, base, max);` 然后用 `rs(14)` 替换 `fontSize: 14`
  - 对于已经在使用 `responsiveSize` 的 3 个文件（`video_page_item.dart`、`video_control_buttons.dart`、`video_action_button.dart`），保持风格一致
  - 保留 `fontSize: 48`（速度/标题大字）的硬编码但改为响应式（`rs(48, 1.2)`）
- **FR-5**：所有长文本（视频标题、演员名、简介、剧集名）的 `Text` 组件添加 `maxLines: 1~2` 和 `overflow: TextOverflow.ellipsis`，防止在小屏溢出布局
- **FR-6**：确保 `flutter analyze` 编译通过（`flutter analyze` 成功，无编译错误）

## 非功能需求
- **NFR-1（可访问性）**：在亮色模式下，所有文本与背景色的对比度不低于 4.5:1（WCAG AA）
- **NFR-2（可维护性）**：修改后不允许在 `lib/` 下（除 `colors.dart` 自身外）出现对 `colors.dart` 的引用
- **NFR-3（兼容性）**：不引入需要 Flutter 3.22+ 的 API（如 `surfaceContainerHighest` getter），需使用 `surface.withOpacity()` 降级方案
- **NFR-4（性能）**：`Theme.of(context)` 调用不会造成额外的重绘开销（缓存为局部变量即可）

## 约束
- **技术**：Flutter 3.10+、Dart 3.x，必须兼容 Android 和桌面端
- **设计**：保持现有粉色主题风格，不改变 `seedColor`
- **依赖**：必须继续使用 `flutter_riverpod`、`go_router` 等现有依赖，不引入新的第三方 UI 库

## 假设
- 用户期望主题切换后整个应用的所有界面颜色同步变化
- `colors.dart` 可以保留作为向后兼容（暂时不删除，方便回退），但 **不再被任何文件导入**

## 验收标准

### AC-1：颜色引用全面替换
- **当**：完成所有文件的颜色引用替换
- **且**：`grep -r "import.*colors.dart" lib/` 结果仅包含 `colors.dart` 自身（或为空）
- **那么**：应用内不再引用旧颜色常量
- **验证**：`programmatic`（grep 检查）

### AC-2：Material 颜色全面替换
- **当**：完成 `Colors.white`、`Colors.black54`、`Colors.grey[900]` 等原色替换
- **且**：`grep -rn "Colors\.(white|black|grey|red)" lib/` 在视图/组件文件中结果为空或仅剩合理位置
- **那么**：切换主题时所有界面颜色正确跟随变化
- **验证**：`programmatic`（grep 检查）+ `human-judgment`（手动切换主题后视觉检查）

### AC-3：硬编码色值全面替换
- **当**：完成 `Color(0xFF...)` 硬编码色值替换
- **且**：`grep -rn "Color(0x" lib/views lib/widgets` 无结果
- **那么**：应用不再包含主题无关的固定颜色
- **验证**：`programmatic`（grep 检查）

### AC-4：响应式字体大小
- **当**：完成主要视图和组件文件中硬编码 `fontSize` 的响应式改造
- **且**：在小屏手机（宽度 < 360dp）和大屏 TV（宽度 > 1000dp）上切换预览
- **那么**：文本大小随屏幕尺寸自适应，不出现过小/过大的问题
- **验证**：`human-judgment`（在不同屏幕尺寸下预览）

### AC-5：文本溢出处理
- **当**：所有长文本 `Text` 组件添加 `maxLines` 和 `overflow`
- **且**：用超长标题测试
- **那么**：文本会显示 `...` 截断，不会导致布局越界错误
- **验证**：`human-judgment`（手动测试长文本场景）

### AC-6：构建通过
- **当**：运行 `flutter analyze` 和 `flutter build apk`（或 `flutter build web`）
- **那么**：编译 100% 通过，无错误
- **验证**：`programmatic`

## 未解决的问题
- `colors.dart` 文件本身是否需要删除？暂时保留（作为可参考的历史文档），但不被任何文件导入
- `subtitle_widget.dart` 等字幕组件的颜色可能需要单独评估（字幕常在视频上方显示，可能需要独立的颜色设计）
