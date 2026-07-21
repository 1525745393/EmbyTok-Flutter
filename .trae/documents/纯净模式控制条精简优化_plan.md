# 纯净模式 VideoControls 控制条精简优化

## 摘要

纯净模式下 VideoControls 控制条横向排列 7 个控件（上一集、播放/暂停、时间+进度条、字幕、倍速、全屏），在竖屏手机上显得拥挤。通过**精简按钮 + 压缩尺寸 + 收纳次要功能**三种手段组合优化，保持核心功能可达性的同时减少视觉负担。

## 当前状态分析

### VideoControls 控制条现有元素

[video_controls.dart#L170-L292](file:///workspace/frontend/lib/widgets/video_controls.dart#L170-L292) 横向排列（从左到右）：

| 序号 | 控件 | 类型 | 优先级 |
|------|------|------|--------|
| 1 | 上一集 | IconButton | 低（仅剧集类内容有意义） |
| 2 | 播放/暂停 | IconButton | 高 |
| 3 | 时间文字 + 进度条 | Text + Slider | 高 |
| 4 | 字幕 | IconButton | 中（不是所有视频都有字幕） |
| 5 | 倍速（如 1.0x） | TextButton | 中高 |
| 6 | 全屏 | IconButton | 中高 |

### 调用位置

- **纯净模式**：[video_page_item.dart#L790-L832](file:///workspace/frontend/lib/widgets/video_page_item.dart#L790-L832) — 单击屏幕时显示，3 秒后自动隐藏
- **非纯净模式**：底部信息条内置 `SeekableProgressBar`，**不使用** VideoControls
- **全屏页**：[fullscreen_video_page.dart](file:///workspace/frontend/lib/views/fullscreen_video_page.dart) — 也使用 VideoControls

### 拥挤原因

- 竖屏手机宽度有限（约 360-430dp）
- 6 个按钮 + 1 个进度条 + 时间文字，水平空间紧张
- `IconButton` 默认尺寸 48dp，6 个就是 288dp，加上间距和进度条空间不足
- 上一集和字幕按钮使用率低，占用宝贵空间

## 提议变更

### 决策

组合优化方案：
1. **移除上一集按钮**：纯净模式下用户滑动切换视频，上一集按钮冗余
2. **收纳字幕按钮到三点菜单**：使用率低于倍速/全屏，收纳后减少常驻按钮
3. **压缩按钮尺寸和间距**：`IconButton` 改小、间距缩小
4. **时间文字简化**：只显示当前时间，移除总时长（总时长可从进度条感知）

仅应用于**纯净模式**的 VideoControls，非纯净模式和全屏页保持不变。

### 变更 1：VideoControls 新增 `compact` 参数

**文件**：[video_controls.dart](file:///workspace/frontend/lib/widgets/video_controls.dart)

**新增参数**：

```dart
/// 是否为紧凑模式（纯净模式使用，减少按钮、压缩尺寸）
final bool compact;
```

构造函数默认 `compact = false`，保持向后兼容。

### 变更 2：compact 模式下移除上一集按钮

**文件**：[video_controls.dart](file:///workspace/frontend/lib/widgets/video_controls.dart#L172-L176)

**逻辑**：

```dart
// 上一集（紧凑模式下隐藏，纯净模式用户滑动切换视频）
if (!widget.compact)
  IconButton(
    icon: Icon(Icons.skip_previous, color: scheme.onSurface),
    onPressed: widget.onPrevEpisode,
  ),
```

### 变更 3：compact 模式下字幕按钮收纳到三点菜单

**文件**：[video_controls.dart](file:///workspace/frontend/lib/widgets/video_controls.dart)

**修改**：
- compact 模式下，字幕按钮不常驻显示
- 新增 `IconButton(Icons.more_vert)` 三点菜单按钮
- 点击弹出底部菜单，包含「字幕」选项
- 同时可将未来其他低频功能也收纳到此菜单

**实现方式**：复用现有 `_showSubtitleMenu()` 方法，三点菜单点击后调用。

### 变更 4：compact 模式下压缩尺寸

**文件**：[video_controls.dart](file:///workspace/frontend/lib/widgets/video_controls.dart)

**调整项**（仅 compact=true 时生效）：
- 水平 padding：`12 → 8`
- 垂直 padding：`8 → 6`
- IconButton 图标尺寸：`24 → 20`（播放按钮 `28 → 24`）
- 按钮间距：`SizedBox(width: 8) → 4`
- 倍速文字大小：`14 → 12`
- 时间文字大小：`13 → 11`

### 变更 5：compact 模式下简化时间显示

**文件**：[video_controls.dart](file:///workspace/frontend/lib/widgets/video_controls.dart#L208-L212)

**修改前**：

```dart
Text(
  '${_formatDuration(position)} / ${_formatDuration(duration)}',
  style: TextStyle(color: scheme.onSurface, fontSize: 13),
),
```

**修改后**（compact 模式）：

```dart
Text(
  _formatDuration(position), // 只显示当前时间，总时长从进度条感知
  style: TextStyle(color: scheme.onSurface, fontSize: 11),
),
```

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
  compact: true, // 新增：纯净模式使用紧凑布局
  onSeekStart: () { ... },
  onSeekEnd: () { ... },
),
```

## 假设与决策

### 假设

1. **上一集按钮在纯净模式下冗余**：纯净模式是沉浸式短视频浏览，用户通过滑动切换视频，不需要上一集按钮
2. **字幕使用频率低于倍速/全屏**：倍速和全屏是更常用的操作，字幕可以收纳到菜单
3. **非纯净模式和全屏页不受影响**：非纯净模式底部信息条已有自己的进度条，全屏页空间充裕不需要精简

### 决策

1. **通过 `compact` 参数实现**：不破坏现有 API，调用方按需选择模式
2. **三点菜单用 `showModalBottomSheet` 或 `PopupMenuButton`**：推荐 `PopupMenuButton`（轻量，与三点图标语义一致）
3. **总时长移除依据**：进度条本身已传达总时长信息，文字重复

## 影响范围

| 文件 | 修改类型 | 影响范围 |
|------|---------|---------|
| `frontend/lib/widgets/video_controls.dart` | 修改 | 新增 `compact` 参数，条件渲染不同布局 |
| `frontend/lib/widgets/video_page_item.dart` | 修改 | 纯净模式 VideoControls 添加 `compact: true` |

不影响非纯净模式、全屏页、其他使用 VideoControls 的地方。

## 验证步骤

### 手动验证

1. **纯净模式**：
   - 单击屏幕 → 控制条显示，按钮更少更紧凑
   - 点击三点菜单 → 弹出字幕选项
   - 播放/暂停、进度条、倍速、全屏功能正常
2. **非纯净模式**：
   - 底部信息条正常显示，不受影响
3. **全屏页**：
   - 控制条正常显示（非 compact 模式），不受影响
4. **字幕功能**：
   - 三点菜单中选择字幕 → 正常弹出字幕选择器
