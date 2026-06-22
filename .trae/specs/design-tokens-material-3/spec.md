# Design Tokens + Material Design 3 统一主题系统

## 概述

当前项目的样式管理存在以下问题：
- [colors.dart](file:///workspace/frontend/lib/utils/colors.dart) 虽然定义了约 40 个颜色常量，但大量组件代码中仍然直接硬编码 `Color(0x...)` 和 `Colors.white` 等
- 间距 (EdgeInsets)、字号 (fontSize)、圆角 (BorderRadius) 完全没有 token 化，全部是魔法数字
- 没有亮色主题，当前只有深色模式
- 组件样式不统一，类似的卡片/按钮/信息条有各自独立的 padding/fontSize/color 写法

**本 spec 的目标：引入 Material Design 3 (MD3) 的 `ColorScheme.fromSeed()` 动态色彩系统 + 间距/字号/圆角 token，为整个项目提供统一的样式入口。**

核心原则：**3 阶段渐进式迁移**，每个阶段都能独立通过 CI。

---

## 1. Seed Color 选择

| Token | 值 | 说明 |
|-------|-----|------|
| `seedColor` | `Color(0xFFE91E63)` | 保留现有粉色 (`primaryPink`)，视觉体验无突变 |

Flutter 的 `ColorScheme.fromSeed(seedColor: ...)` 会基于这一个颜色自动派生完整的色彩系统。

---

## 2. 文件结构变更

### 新增文件

```
frontend/lib/theme/
├── app_theme.dart           # ThemeData 构建器（亮/暗主题）
└── theme_extensions.dart    # 自定义主题扩展（如 BrandColor）
```

### 修改文件

| 文件 | 变更内容 |
|------|---------|
| [app.dart](file:///workspace/frontend/lib/app.dart) | 接入新主题系统，`MaterialApp.router` 的 `theme` / `darkTheme` / `themeMode` 从新入口读取 |
| [theme_provider.dart](file:///workspace/frontend/lib/providers/theme_provider.dart) | 从仅管理 themeMode 字符串扩展为返回完整的 ThemeData |
| [utils/constants.dart](file:///workspace/frontend/lib/utils/constants.dart) | 补充间距/圆角/字号 token 类 |
| [utils/colors.dart](file:///workspace/frontend/lib/utils/colors.dart) | 保留为兼容层（不删除，避免编译错误），新增 `// TODO: migrate to colorScheme` 注释 |

---

## 3. 3 阶段迁移策略

### 阶段 1：搭建主题框架（本阶段实施）

**目标：** 新主题系统就绪，零代码改动到现有组件

**工作内容：**
- ✅ 新建 `lib/theme/app_theme.dart`
- ✅ 新建 `lib/theme/theme_extensions.dart`
- ✅ 修改 `app.dart` 接入新主题
- ✅ 扩展 `theme_provider.dart` 管理主题模式
- ✅ 补充 `constants.dart` 中的 token 类
- ❌ **不动** 任何 widget / view 代码
- ✅ CI 全绿（现有行为 100% 不变）

**验证方式：**
- `flutter analyze` 无 error
- `flutter build apk --debug` 成功
- 视觉效果与当前版本一致（因为仍走 Material 的 colorScheme，组件仍读取旧的颜色常量）

---

### 阶段 2：核心组件迁移（后续阶段）

**目标：** 视频流相关核心组件改用新主题系统

**工作内容：**
- [video_page_item.dart](file:///workspace/frontend/lib/widgets/video_page_item.dart) 逐步替换
- [video_controls.dart](file:///workspace/frontend/lib/widgets/video_controls.dart) 替换
- [video_grid_card.dart](file:///workspace/frontend/lib/widgets/video_grid_card.dart) 替换
- 每个文件替换后独立验证

---

### 阶段 3：全面替换硬编码（后续阶段）

**目标：** 消除 views 和 widgets 中的硬编码 Color(0x...) / EdgeInsets / fontSize

**工作内容：**
- 替换剩余 views 文件中的硬编码样式
- 运行 `flutter analyze` 验证无 error
- 保留 `colors.dart` 作为兼容层（删除需全项目检查无引用后再做）

---

## 4. Token 定义规范

### 4.1 颜色 Tokens（通过 ColorScheme，无需手动定义）

| 语义 Token | Flutter colorScheme 属性 | 用途示例 |
|-----------|--------------------------|---------|
| 主色 | `.primary` | 按钮、强调色、进度条 |
| 主色上的文字 | `.onPrimary` | 粉色按钮上的白色文字 |
| 主色容器 | `.primaryContainer` | 粉色背景的卡片/标签 |
| 表面色 | `.surface` | 卡片、Scaffold 背景 |
| 表面上的文字 | `.onSurface` | 普通文字 |
| 表面上的次要文字 | `.onSurfaceVariant` | 说明文字、灰色信息 |
| 边框/分隔线 | `.outline` / `.outlineVariant` | Divider、卡片边框 |
| 错误色 | `.error` | 错误提示、红色图标 |

使用方式（组件内）：

```dart
final scheme = Theme.of(context).colorScheme;
final text = Theme.of(context).textTheme;

Container(
  color: scheme.primary,                    // 代替 primaryPink
  child: Text('标题', style: text.bodyMedium), // 代替 TextStyle(fontSize: 14)
)
```

### 4.2 间距 Tokens

```dart
class AppSpacing {
  static const double xs = 4.0;    // 小分隔
  static const double sm = 8.0;    // 标准内边距
  static const double md = 12.0;   // 中等内边距
  static const double lg = 16.0;   // 页面边距
  static const double xl = 24.0;   // 大间距
  static const double xxl = 32.0;  // 页面上下边距
}
```

### 4.3 圆角 Tokens

```dart
class AppRadius {
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double pill = 9999.0;  // 胶囊形
}
```

### 4.4 字号 Tokens（直接用 Flutter 的 TextTheme）

Flutter Material Design 3 自带完整的 `TextTheme`：

| textTheme 属性 | 字号 | 用途 |
|---------------|------|------|
| `.bodySmall` | 12px | 标签、次要信息 |
| `.bodyMedium` | 14px | 正文、默认 |
| `.bodyLarge` | 16px | 大正文 |
| `.titleSmall` | 14px | 小标题（粗） |
| `.titleMedium` | 16px | 中标题 |
| `.titleLarge` | 22px | 大标题 |
| `.headlineSmall` | 24px | 页面标题 |
| `.labelSmall` | 11px | 小标签 |
| `.labelMedium` | 12px | 按钮文字 |
| `.labelLarge` | 14px | 大按钮文字 |

使用方式：

```dart
Text('标题', style: Theme.of(context).textTheme.bodyMedium)
```

---

## 5. 颜色映射表（旧 → 新）

| 旧代码 | 新代码 | 迁移阶段 |
|--------|--------|---------|
| `primaryPink` | `Theme.of(context).colorScheme.primary` | 阶段 2 |
| `backgroundColor` | `Theme.of(context).colorScheme.surface` | 阶段 2 |
| `textPrimary` | `Theme.of(context).colorScheme.onSurface` | 阶段 2 |
| `textSecondary` | `Theme.of(context).colorScheme.onSurfaceVariant` | 阶段 2 |
| `Color(0xFFFF2D55)` | `Theme.of(context).colorScheme.primary` | 阶段 2 |
| `Color(0xFF000000)` | `Theme.of(context).colorScheme.surface` | 阶段 2 |
| `Colors.white` | `Theme.of(context).colorScheme.onSurface` | 阶段 2 |
| `Colors.black87` | `Theme.of(context).colorScheme.onSurface.withOpacity(0.87)` | 阶段 2 |
| `Colors.white54` | `Theme.of(context).colorScheme.onSurface.withOpacity(0.54)` | 阶段 2 |
| `errorColor` | `Theme.of(context).colorScheme.error` | 阶段 2 |
| `progressBackground` | `Theme.of(context).colorScheme.surfaceContainerHighest` | 阶段 2 |

**注意**：以上映射在阶段 1 不执行，阶段 2 开始实施。

---

## 6. 主题模式选择 UI

当前 [settings_view.dart](file:///workspace/frontend/lib/views/settings_view.dart) 中的主题切换：
- 3 个选项：深色 / 浅色 / 跟随系统
- 存储键：`embbytok_theme_mode`
- Provider：`themeModeProvider`（String）

阶段 1 保持不变，只需确保 `theme_provider.dart` 返回正确的 `ThemeMode` 枚举和对应的 `ThemeData`。

---

## 7. 无障碍/对比度要求

MD3 的 `ColorScheme.fromSeed()` 自动满足 WCAG AA 对比度要求：
- 普通文字：4.5:1 对比度
- 大号文字：3:1 对比度

自动生成的 `onPrimary` / `onSurface` / `onError` 等自动为高对比度的黑色或白色。

---

## 8. 非目标（Out of Scope）

- ❌ 引入多主题色切换（用户可自选种子色）→ 阶段 2/3 之后再考虑
- ❌ 引入 Material Design 3 完整组件库（flutter_solid 等）→ 保持现有 UI 风格
- ❌ 删除 `colors.dart` → 作为兼容层保留，避免编译错误
- ❌ 引入国际化（i18n）→ 独立 spec

---

## 9. 验收标准

| # | 验证项 | 方式 |
|---|--------|------|
| 1 | 新增文件存在，无语法错误 | `flutter analyze` |
| 2 | 现有组件代码 0 改动 | git diff |
| 3 | CI 全绿 | GitHub Actions |
| 4 | App 启动后视觉效果与当前版本一致 | 人工对比截图 |
| 5 | 亮色主题可切换且无明显样式问题 | 设置页切换验证 |
