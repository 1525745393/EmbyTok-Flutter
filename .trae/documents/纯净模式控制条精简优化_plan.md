# 纯净模式 VideoControls 控制条精简优化

## 摘要

纯净模式下 VideoControls 控制条横向排列 7 个控件，竖屏手机上显得拥挤。优化方案：**进度条移到按钮行下方**（单独一行），按钮行移除上一集+收纳字幕到三点菜单+压缩尺寸，进度条行格式为「当前时间 | 进度条 | 总时长」。仅纯净模式生效，非纯净模式和全屏页保持不变。

## 当前状态分析

### VideoControls 控制条现有元素

[video_controls.dart#L170-L292](file:///workspace/frontend/lib/widgets/video_controls.dart#L170-L292) 单行横向排列（从左到右）：

| 序号 | 控件 | 类型 | 优先级 |
|------|------|------|--------|
| 1 | 上一集 | IconButton | 低（仅剧集类内容有意义） |
| 2 | 播放/暂停 | IconButton | 高 |
| 3 | 时间文字 + 进度条 | Text + Slider | 高 |
| 4 | 字幕 | IconButton | 中（不是所有视频都有字幕） |
| 5 | 倍速（如 1.0x） | TextButton | 中高 |
| 6 | 全屏 | IconButton | 中高 |

### 拥挤原因

- 竖屏手机宽度有限（约 360-430dp）
- 6 个按钮 + 进度条 + 时间文字全部挤在一行
- `IconButton` 默认尺寸 48dp，水平空间紧张

## 提议变更

### 核心方案：双层布局 + 按钮精简

**按钮行（上层）**：播放/暂停 | 倍速 | 全屏 | ⋮（三点菜单-字幕）

**进度条行（下层）**：当前时间 | ———进度条——— | 总时长

### 变更 1：VideoControls 新增 `compact` 参数

**文件**：[video_controls.dart](file:///workspace/frontend/lib/widgets/video_controls.dart)

**新增参数**：

```dart
/// 是否为紧凑模式（纯净模式使用，双层布局+精简按钮）
final bool compact;
```

构造函数默认 `compact = false`，保持向后兼容。

### 变更 2：compact 模式下改为双层布局

**文件**：[video_controls.dart](file:///workspace/frontend/lib/widgets/video_controls.dart)

**布局结构**（compact=true 时）：

```
Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    // 第一行：按钮
    Row(
      children: [
        播放/暂停按钮,
        Spacer(),
        倍速按钮,
        全屏按钮,
        三点菜单按钮(字幕),
      ],
    ),
    SizedBox(height: 4),
    // 第二行：进度条 + 时间
    Row(
      children: [
        Text(当前时间),
        SizedBox(width: 8),
        Expanded(child: Slider(...)),
        SizedBox(width: 8),
        Text(总时长),
      ],
    ),
  ],
)
```

非 compact 模式保持原有单行布局不变。

### 变更 3：compact 模式下移除上一集按钮

**文件**：[video_controls.dart](file:///workspace/frontend/lib/widgets/video_controls.dart)

**逻辑**：compact 模式不渲染上一集按钮（纯净模式用户通过滑动切换视频，上一集按钮冗余）。

### 变更 4：compact 模式下字幕收纳到三点菜单

**文件**：[video_controls.dart](file:///workspace/frontend/lib/widgets/video_controls.dart)

**实现**：
- compact 模式下，字幕按钮不常驻显示
- 新增 `PopupMenuButton`（三点图标）
- 菜单项：「字幕」
- 点击「字幕」调用现有 `_showSubtitleMenu()` 方法

### 变更 5：compact 模式下压缩按钮尺寸

**文件**：[video_controls.dart](file:///workspace/frontend/lib/widgets/video_controls.dart)

**调整项**（仅 compact=true 时生效）：
- 外层水平 padding：`12 → 8`
- 外层垂直 padding：`8 → 6`
- IconButton 图标尺寸：`24 → 20`（播放按钮 `28 → 24`）
- 按钮水平间距：`SizedBox(width: 8) → 4`
- 倍速文字大小：`14 → 12`
- 时间文字大小：`13 → 12`

### 变更 6：纯净模式 VideoControls 启用 compact

**文件**：[video_page_item.dart](file:///workspace/frontend/lib/widgets/video_page_item.dart)

找到 VideoControls 使用位置（约 L790-832），添加 `compact: true` 参数。

```dart
VideoControls(
  controller: _videoController!,
  subtitleTracks: _subtitleTracks,
  onPrevEpisode: widget.onPrevEpisode,
  onToggleFullscreen: _openFullscreenPage,
  isInFullscreen: false,
  compact: true, // 新增：纯净模式使用紧凑双层布局
  onSeekStart: () { ... },
  onSeekEnd: () { ... },
),
```

## 假设与决策

### 假设

1. **上一集按钮在纯净模式下冗余**：纯净模式是沉浸式短视频浏览，用户通过滑动切换视频
2. **字幕使用频率低于倍速/全屏**：可以收纳到三点菜单
3. **进度条单独一行更清晰**：时间+进度条单独一行，按钮单独一行，各司其职
4. **非纯净模式和全屏页不受影响**：保持原有布局

### 决策

1. **通过 `compact` 参数实现**：不破坏现有 API，调用方按需选择模式
2. **三点菜单用 `PopupMenuButton`**：轻量，与三点图标语义一致
3. **时间文字保留完整格式**：当前时间 + 总时长都显示，不简化
4. **进度条单独占一行**：比挤在按钮行中间更易读、易拖动

## 影响范围

| 文件 | 修改类型 | 影响范围 |
|------|---------|---------|
| `frontend/lib/widgets/video_controls.dart` | 修改 | 新增 `compact` 参数，条件渲染双层布局 |
| `frontend/lib/widgets/video_page_item.dart` | 修改 | 纯净模式 VideoControls 添加 `compact: true` |

不影响非纯净模式、全屏页、其他使用 VideoControls 的地方。

## 验证步骤

### 手动验证

1. **纯净模式**：
   - 单击屏幕 → 控制条显示为双层布局（按钮行在上，进度条行在下）
   - 按钮行：播放/暂停 + 倍速 + 全屏 + 三点菜单
   - 进度条行：当前时间 | ———进度条——— | 总时长
   - 点击三点菜单 → 弹出「字幕」选项 → 点击正常打开字幕选择器
   - 播放/暂停、进度条拖动、倍速、全屏功能正常
2. **非纯净模式**：
   - 底部信息条正常显示，不受影响
3. **全屏页**：
   - 控制条正常显示（非 compact 模式，原有单行布局），不受影响
