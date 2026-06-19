# EmbyTok Flutter 版 - 播放控制与进度条规范文档 (PRD)

## 概述

**参考项目**: EmbyTok (React/TypeScript)  main 分支)
**参考URL**: https://github.com/1525745393/EmbyTok

本规范文档目标：将 React 版 EmbyTok 的完整播放控制逻辑、底部信息条设计、进度条实现方式，移植和适配到 Flutter 版本，确保两个版本在用户体验和功能上保持一致。

## 目标

1. **完善播放控制逻辑**：单击播放/暂停、长按2倍速、左右滑动快进快退、双击点赞、键盘支持
2. **实现可拖拽进度条**：视频时长 > 3分钟 时显示可交互的进度条，支持点击跳转和拖拽调整
3. **优化信息弹窗**：点击「ℹ 信息」按钮弹出完整元信息面板，包括标题、年份、时长、类型、简介、演员等
4. **优化底部信息条**：标题 + 类型标签 + 时长 + 评分 + 简介，支持 3 秒自动隐藏
5. **整理右侧操作区**：连播按钮、演员头像、点赞、信息、删除、唱片静音按钮
6. **实现倍速菜单**：1.0x/1.25x/1.5x/1.75x/2.0x/2.5x/3.0x 倍速选择
7. **实现字幕控制**：字幕选择、字体大小、延迟调整
8. **实现播放模式切换**：Direct/Transcode/Fallback 三种播放模式切换

## 背景与当前状态

**当前 Flutter 版本状态分析**：

| 功能 | 实现状态 | 问题 |
|------|---------|-----|
| 视频播放 | ✅ 已实现 | 基于 `video_player` 插件 |
| 点赞/收藏 | ✅ 已实现 | `_buildFavoriteButton()` |
| 信息按钮 | ✅ 已实现 | `_showVideoInfoSheet()` |
| 删除按钮 | ✅ 已实现 | `_buildDeleteButton()` |
| 倍速按钮 | ✅ 已实现 | `_buildSpeedControlButton()` |
| 底部信息条 | ✅ 已实现 | `_buildBottomGradient()` |
| 播放模式切换 | ✅ 已实现 | `_buildPlayModeButton()` |
| **可拖拽进度条** | ❌ 部分实现（仅显示时间，无交互） | 需参考 EmbyTok React 版本的 `updateSeekPosition()` 实现 |
| **长按2倍速** | ❌ 未实现 | 需添加 |
| **水平滑动快进快退** | ❌ 未实现 | 需添加 |
| **双击点赞** | ❌ 未实现 | 需添加 |
| **连播按钮** | ✅ 已实现 | `_buildAutoPlayButton()` |
| **字幕控制** | ✅ 已实现 | `SubtitleControls` 组件 |
| **3秒自动隐藏信息条** | ❌ 未实现 | 需添加 |
| **唱片动画（唱片旋转）** | ❌ 未实现 | React 版本有 `animate-[spin_4s_linear_infinite]` |

## 功能需求

### FR-1：播放控制手势 (Playback Gestures)

**参考：`VideoCard.tsx` 第 `handleTouchStart / handleTouchMove / handleTouchEnd` 方法

| 手势 | 行为 |
|------|------|
| 单击 | 播放/暂停切换 |
| 长按 (500ms) | 切换到 2.0x 倍速，结束后恢复 1.0x（若长按期间上下滑动超过 20px，则永久设置该倍速） |
| 水平滑动 (> 20px & | 5px/s) | 快进快退，`seekOffset = Math.round(deltaX / 5)` 秒 |
| 双击（间隔 < 300ms） | 触发点赞动画 + 切换收藏状态 |
| 键盘 Enter/Space | 播放/暂停 |
| 键盘 ←/→ | 向前/向后 10 秒 |
| 键盘 m/M | 静音切换 |
| 键盘 f/F | 收藏切换 |

### FR-2：进度条 (Progress Bar)

**参考：`VideoCard.tsx` 第 `showProgressBar` 逻辑及 `updateSeekPosition` 方法**

1. **显示条件**：`duration > 180 秒 && !isAutoPlay && showProgress`（视频时长 > 3分钟时可显示）
2. **触发显示**：用户交互后显示 `showProgress = true`，5 秒后自动隐藏 `setShowProgress(false)`
3. **进度条结构**：
   - 背景：`bg-black/30` (Flutter: `Colors.black.withOpacity(0.3)`)
   - 已播放部分：主题色 `primaryPink`
   - 高度：`h-1.5` (约 6px)
   - 圆角：`rounded-full`
4. **点击跳转**：`onTapDown` 时计算百分比跳转
5. **水平滑动**：`onHorizontalDragStart/Update/End` 实时更新位置
6. **时间显示**：`currentTime / totalTime`（如 `12:34 / 45:00`）
7. **Seek 逻辑**：
```
void updateSeekPosition(e) {
  if (!progressBarRef || !duration) return;
  final rect = progressBarRef.getBoundingClientRect();
  double percent = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width));
  double newTime = percent * duration;
  setCurrentTime(newTime);
  if (videoRef.current) videoRef.current.currentTime = newTime;
}
```

### FR-3：信息弹窗 (Video Info Modal)

**参考：`VideoInfo.tsx` + `VideoCard.tsx` 中的 showInfo 逻辑**

1. **触发**：点击右侧「ℹ 信息」按钮 (`_showVideoInfoSheet())
2. **内容**：
   - 标题 (text-white font-bold text-lg)
   - 类型标签 + 年份 + 时长 + 评分
   - 简介（支持滚动，不截断）
3. **交互**：
   - 可拖动调整高度（min 30%，初始 50%，max 90%）
   - 下滑关闭
   - 点击空白区域关闭
4. **完整信息包含**：
   - 标题 + 类型 + 年份 + 时长 + 评分 + 工作室/制作公司
   - 简介（多行，不截断）
   - 演员列表（前 10 人）
   - 导演信息（如有）
   - 剧集信息（Season/Episode 信息）

### FR-4：底部信息条 (Bottom Info Bar)

**参考：`VideoInfo.tsx` 完整组件**

1. **结构**：
   - 渐变背景：`bg-gradient-to-t from-black/90 via-black/40 to-transparent`
   - 标题：`text-white font-bold text-lg`，最多 2 行
   - 副标题：类型标签 `bg-white/20 px-1.5 py-0.5 rounded`（粉色背景？不，React版本用白色半透明），年份、时长、评分
   - 简介：`text-white/80 text-sm`，2 行截断，点击展开
2. **3秒自动隐藏**：播放中 3 秒后淡出，暂停时保持显示
3. **支持点击交互**：
   - 点击简介区域 → 展开/收起简介完整显示
   - 点击其他区域 → 播放/暂停

### FR-5：右侧操作区 (Right Side Actions)

**参考：`VideoControls.tsx`**

| 按钮 | 功能 |
|------|------|
| 连播 (Infinity) | 切换连播模式，连播模式下 `isAutoPlay = true`，所有 UI 自动隐藏 |
| 演员头像 | 圆形头像/封面，支持显示演员姓名下方 |
| 点赞 (Heart) | 切换点赞/收藏状态，心形动画 |
| 信息 (Info) | 弹出信息弹窗 showInfoModal |
| 删除 (Trash2) | 弹出确认删除对话框 |
| 唱片静音 (Disc/mute) | 切换静音/取消静音，播放中播放动画 `spin_4s_linear_infinite |

**React 版结构**（从上至下）：

```
┌────────────┐
│ ∞ 连播   │  (独立于右上角，可移动)
├────────────┤
│   头像    │  (12x12，圆形)
│   John    │
├────────────┤
│ ❤️  点赞  │
│ ℹ️  信息  │
│ 🗑️  删除  │
│ 💿  唱片  │
└────────────┘
```

### FR-6：倍速菜单 (Playback Speed Menu)

**参考：`VideoCard.tsx` 中的 `showSpeedMenu` + playbackRate` 逻辑**

1. **触发**：点击倍速按钮（1.0x）→ 弹出菜单
2. **可选值**：0.5x, 1.0x, 1.25x, 1.5x, 1.75x, 2.0x, 2.5x, 3.0x
3. **临时倍速**（长按触发）vs **永久倍速**（长按+上下滑动调整后设置）
4. **倍速徽章**：在倍速按钮旁显示当前速度（如 1.5x）

### FR-7：字幕控制 (Subtitle Controls)

**参考：`SubtitleControls.tsx`**

1. **触发**：点击字幕按钮 → 弹出字幕选择面板
2. **内容**：可用字幕轨道列表，支持切换字幕，支持设置（字体大小、颜色、延迟）
3. **字幕渲染**：使用 `SubtitleRenderer.tsx` 中 vtt/srt/webvtt 渲染

### FR-8：播放模式切换 (Play Mode Switch)

**参考：`VideoCard.tsx` `playMode` 状态**

| 模式 | 说明 |
|------|------|
| Direct | 直接播放原始视频（默认） |
| Transcode | 服务器转码播放（适合慢速网络） |
| Fallback | 备用播放模式（当 Direct 和 Transcode 均失败） |

切换逻辑：
- 点击模式切换按钮 → cycle 切换（Direct → Transcode → Fallback → Direct）
- 错误处理：当播放失败时自动尝试下一个模式，最多重试 MAX_RETRIES=3 次
- 模式菜单显示：显示当前模式文字，如"DIRECT"/"TRANSCODE"/"FALLBACK"，颜色区分：
  - Direct：默认
  - Transcode：黄色背景
  - Fallback：红色背景

### FR-9：自动播放通知 (Auto-Play Notification)

**参考：`VideoCard.tsx` 中 autoPlayOn 显示逻辑**

当启用连播（isAutoPlay=true）时：
1. 在屏幕中央显示"自动连播已开启"通知
2. 文字：黄色闪电图标 + "Auto-Play"
3. 样式：`bg-black/60 backdrop-blur-sm px-4 py-2 rounded-full
4. 消失时机：连播关闭后消失

## 非功能需求

### NFR-1：性能与动画

1. 所有动画流畅、过渡自然，无卡顿
2. 进度条更新频率每 100ms 一次（不频繁 setState）
3. 动画时长：`duration-300` (300ms)
4. 使用 `AnimatedBuilder`/`Ticker` 管理动画，避免全组件重绘
5. 视频资源使用 `preload` 机制预加载下一个视频

### NFR-2：代码组织与规范

1. 所有组件采用 `StatelessWidget` / `StatefulWidget` 分组件化设计
2. 常量、颜色常量统一在 `theme/app_theme.dart` 中定义
3. 关键逻辑提取为私有方法（`_formatDuration`, `_updateSeekPosition` 等）
4. 使用 `const` 构造函数优化性能
5. 组件布局逻辑清晰，易维护

### NFR-3：空安全与错误处理

1. 所有 `_videoController` 使用前检查 null
2. 视频加载错误时显示错误 UI 并提供重试
3. duration 为 0 或 null 的处理
4. setState 前检查 `mounted`

## 数据模型扩展

**MediaItem 模型（已存在）：

```dart
class MediaItem {
  final String id;              // 视频 ID (Emby ItemId)
  final String title;          // 标题
  final String? type;          // MediaType (Video/Movie/Episode/MusicVideo)
  final int? productionYear;   // 年份
  final int? runTimeTicks;    // 时长 (ticks, 1 tick = 100ns)
  final Duration? duration;    // 时长（Duration 类型，Flutter 专用）
  final double? communityRating; // 评分 (0-10 范围)
  final String? overview;    // 简介
  final List<PersonInfo>? people; // 演员/导演等
  final String? seriesName;   // 剧集名（Episode 类型）
  final int? parentIndexNumber; // 季数
  final int? indexNumber;    // 集数
  final String? imageUrl;     // 封面图 URL
  final String? studioNames;   // 工作室/制作公司
  // ... 其他字段
}

class PersonInfo {
  final String name;
  final String role;   // Actor/Director/Writer 等
  final String? imageUrl;
}
```

## 实现细节规范

### 组件结构设计

```
lib/widgets/
├── video_page_item.dart         ← 主要文件（已存在）
│   ├── _VideoPageItemState ← 修改
│   │   ├── _buildVideoPlayer()    ← 视频播放器
│   │   ├── _buildBottomGradient() ← 底部信息条 + 进度条（需增强）
│   │   ├── _buildRightActions()   ← 右侧操作按钮区（需调整顺序）
│   │   ├── _buildSpeedMenu()     ← 倍速菜单（新增）
│   │   ├── _buildSubtitleControls() ← 字幕控制（需增强）
│   │   ├── _buildPlayModeBadge()   ← 播放模式徽章
│   │   ├── _showInfoSheet() ← 信息弹窗（增强）
│   │   └── _formatDuration()  ← Duration 格式化工具
│   └── _SeekableProgressBar   ← 可拖拽进度条组件（新增）
│
├── video_info_sheet.dart       ← 视频信息弹窗（独立组件，可独立文件）
├── speed_menu.dart              ← 倍速菜单（可独立）
└── subtitle_controls.dart    ← 字幕控制组件（已有）
```

### 关键状态变量

```dart
// 播放状态
bool isPlaying = false;      // 播放中？
bool hasStarted = false;       // 是否已开始播放？
bool isLoading = true;          // 加载中？
bool isUserPaused = false;    // 用户主动暂停？

// 倍速状态
double playbackRate = 1.0;   // 当前倍速
bool isTemporarySpeed = false; // 临时倍速（长按触发）
bool isSpeedAdjusting = false;// 正在调整速度？
double speedStartRate = 2.0;  // 长按起始倍速

// 进度条状态
double currentTime = 0.0;     // 当前播放位置（秒）
double duration = 0.0;         // 总时长（秒）
bool showProgress = false;    // 是否显示进度条
bool isSeeking = false;       // 正在 seek 中

// 信息条状态
bool showInfo = false;         // 信息弹窗是否显示
bool isInfoVisible = true;   // 底部信息条是否可见（3秒自动隐藏）

// 手势状态
int? lastTapTime;              // 上次点击时间戳（毫秒）
int seekOffset = null;         // seek 偏移量（秒）
bool isDragging = false;    // 是否正在拖拽水平滑动
bool isLongPress = false;     // 是否正在长按

// 播放模式
PlayMode playMode = PlayMode.direct;
```

### 颜色规范

```dart
// 主题色
const primaryPink = Color(0xFFE91E63);   // 粉色主色
const textPrimary = Colors.white;         // 主文字
const textSecondary = Colors.white70;    // 次文字
const Color bgBlack80 = Color(0xCC000000);   // 80% 黑色
const Color bgBlack60 = Color(0x99000000);   // 60% 黑色
const Color bgBlack40 = Color(0x66000000);   // 40% 黑色
```

## 关键实现参考

### 参考 1：播放控制手势

```dart
// 在视频容器上添加 GestureDetector
GestureDetector(
  onTap: () => _handleTap(),
  onTapDown: (_) => _showProgressAndResetTimer(),
  onLongPressStart: (_) => _handleLongPressStart(),
  onLongPressEnd: (_) => _handleLongPressEnd(),
  onHorizontalDragStart: _handleHorizontalDragStart,
  onHorizontalDragUpdate: _handleHorizontalDragUpdate,
  onHorizontalDragEnd: _handleHorizontalDragEnd,
  child: VideoPlayer(_videoController),
)
```

**_handleTap():

```dart
void _handleTap() {
  // 双击判断逻辑：
  // if (DateTime.now().millisecondsSinceEpoch - lastTapTime < 300ms?
  //  → 双击：双击点赞动画
  // else: 单击 → 播放/暂停
}
```

### 参考 2：可拖拽进度条

```dart
// 进度条组件 (lib/widgets/_SeekableProgressBar.dart
class _SeekableProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  final bool enabled;

  _SeekableProgressBar({required this.controller, this.enabled = true});

  @override
  State<_SeekableProgressBar> createState() => _SeekableProgressBarState();
}

class _SeekableProgressBarState extends State<_SeekableProgressBar> {
  final GlobalKey _progressKey = GlobalKey();
  double _dragProgress = 0.0;
  bool _isDragging = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  double get _progress {
    if (!widget.controller.value.isInitialized) return 0.0;
    final duration = widget.controller.value.duration.inMilliseconds;
    final position = widget.controller.value.position.inMilliseconds;
    if (duration <= 0) return 0.0;
    return position / duration;
  }

  void _updatePosition(PointerDownEvent event) {
    if (!_progressKey.currentContext == null) return;
    final box = _progressKey.currentContext!.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(event.position);
    final percent = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
    setState(() {
      _dragProgress = percent;
      _isDragging = true;
    });
    final duration = widget.controller.value.duration;
    final seekPosition = Duration(milliseconds: (percent * duration.inMilliseconds).toInt());
    widget.controller.seekTo(seekPosition);
    _restartHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: _progressKey,
      onPointerDown: (event) {
        if (!widget.enabled) return;
        _updatePosition(event);
      },
      onPointerMove: (event) {
        if (!widget.enabled || !_isDragging) return;
        _updatePosition(event);
      },
      onPointerUp: (event) {
        if (!widget.enabled) return;
        setState(() => _isDragging = false);
      },
      child: Container(
        height: 20,  // 扩大点击区域
        width: double.infinity,
        alignment: Alignment.center,
        child: Container(
          height: 6, // 实际显示高度
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _isDragging ? _dragProgress : _progress,
            child: Container(
              decoration: BoxDecoration(
                color: primaryPink,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

### 参考 3：信息弹窗（DraggableScrollableSheet）

```dart
// 参考 _showVideoInfoSheet() 修改方案
void _showVideoInfoSheet() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: bgBlack90,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: ListView(
          children: [
            // 顶部小把手
            Center(child: Container(width: 40, height: 4, margin: EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: Colors.white24)),
            // 标题
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(widget.item.title, style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            // 类型标签 + 年份 + 时长 + 评分
            // ...
          ],
        ),
      ),
    ),
  );
}
```

### 参考 4：3 秒自动隐藏

```dart
Timer? _infoHideTimer;

void _resetInfoHideTimer() {
  _infoHideTimer?.cancel();
  if (mounted) setState(() => isInfoVisible = true);
  if (isPlaying) {
    _infoHideTimer = Timer(Duration(seconds: 3), () {
      if (mounted) setState(() => isInfoVisible = false);
    });
  }
}
```

## 任务计划

本规格文档涵盖以下改进任务（详细任务列表见 `tasks.md`）：

1. **Task 1**: 播放控制手势增强（单击、长按2倍速、水平滑动快进快退、双击点赞）
2. **Task 2**: 可拖拽进度条实现（显示条件、点击跳转、水平滑动调整）
3. **Task 3**: 信息弹窗完善（标题、年份、时长、类型、评分、简介、演员）
4. **Task 4**: 底部信息条优化（3秒自动隐藏、渐变背景、演员头像显示）
5. **Task 5**: 右侧操作区整理（连播、演员头像、点赞、信息、删除、唱片按钮顺序）
6. **Task 6**: 倍速菜单实现（0.5x~3.0x 倍速选择、临时倍速 vs 永久倍速）
7. **Task 7**: 字幕控制增强（多语言选择、字体大小、颜色调整）
8. **Task 8**: 播放模式切换完善（Direct/Transcode/Fallback）
9. **Task 9**: 代码整理与提交同步

## 验收标准

| 标准 | 要求 |
|------|------|
| 播放控制 | 所有手势交互行为与 React 版一致 |
| 进度条 | 可点击跳转、可水平滑动调整、显示/隐藏逻辑一致 |
| 信息弹窗 | 点击 ℹ️ 信息按钮后可弹出完整信息 |
| 底部信息条 | 显示标题+类型标签+年份+时长+评分+简介，播放中 3 秒自动隐藏 |
| 倍速菜单 | 点击倍速按钮弹出 0.5x-3.0x 选择菜单 |
| 字幕控制 | 字幕按钮弹出字幕选择面板 |
| 播放模式 | 三种模式切换按钮显示当前模式文字 |
| 空安全 | 所有 _videoController 访问前检查 null |
| 动画流畅度 | 过渡动画流畅，无卡顿 |
| 代码规范 | 符合 Dart 3.x 规范，无 lint 警告 |
| 兼容性 | Flutter 3.x+ 兼容 |
| 同步 | 所有改动已提交并推送至 GitHub 仓库 |

## 兼容性注意事项

1. **Flutter 版本**：确保使用 Flutter 3.x+ 和 Dart 3.x+
2. **插件依赖**：
   - video_player: ^2.8.0
   - chewie: ^1.7.0 (可选，当前项目可能用的是 video_player 原生)
3. **资源管理**：确保 `_videoController` 在 dispose 时正确释放，避免内存泄漏
4. **性能优化**：进度条更新应使用 `AnimatedBuilder`/`ValueListenableBuilder`，而非频繁 `setState`
5. **Android 权限**：确保网络权限配置（`android.permission.INTERNET`）
6. **TV 适配**：确保大电视模式下按钮大小合适（响应式设计）
