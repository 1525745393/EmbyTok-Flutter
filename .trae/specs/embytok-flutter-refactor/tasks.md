# EmbyTok Flutter 版 - 实施任务计划

**参考规格**: spec.md
**验证清单**: checklist.md
**目标**: 将 React 版 EmbyTok 的播放控制和进度条功能完整移植到 Flutter 版

---

## Task 1: 播放控制手势增强

- **优先级**: P0 (核心功能)
- **Depends On**: None
- **预计工时**: 3 小时

### 描述

在视频容器上添加完整的手势支持，与 React 版 `handleTouchStart / handleTouchMove / handleTouchEnd` 对齐。

### 关键实现点

| 手势 | 实现细节 |
|------|---------|
| **单击** | `onTap` → 切换播放/暂停 `_videoController.value.isPlaying ? pause() : play()` |
| **长按开始** | `onLongPressStart` → 500ms 后设置倍速 2.0，标记 `isLongPress=true` |
| **长按结束** | `onLongPressEnd` → 如果用户没有上下滑动调整（`isTemporarySpeed=true`），恢复到 1.0x |
| **长按+上下滑动** | `onVerticalDragUpdate` | 若 `isLongPress=true` 且 `|deltaY|>20px`，根据滑动距离调整倍速：`newRate = 2.0 + (-deltaY/100)*4.5`，范围 0.5-5.0 |
| **水平滑动开始** | `onHorizontalDragStart` → 如果不是长按，标记 `isDragging=true` |
| **水平滑动更新** | `onHorizontalDragUpdate` → `seekOffset = Math.round(deltaX / 5)` 秒，显示偏移量 |
| **水平滑动结束** | `onHorizontalDragEnd` → 执行 `seekTo(currentTime + seekOffset)`，隐藏偏移量显示 |
| **双击检测** | 在 `onTap` 中检查时间戳差 `< 300ms` → 如果是双击，触发点赞 |

### 代码结构

```dart
// 在 _VideoPageItemState 中添加以下状态
bool _isPlaying = false;
bool _isLongPress = false;
bool _isTemporarySpeed = false;
bool _isDragging = false;
int _seekOffsetSeconds = 0;
double _playbackRate = 1.0;
DateTime? _lastTapTime;

// 添加手势处理器
void _handleTap() { ... }
void _handleLongPressStart(LongPressStartDetails d) { ... }
void _handleLongPressEnd(LongPressEndDetails d) { ... }
void _handleHorizontalDragStart(DragStartDetails d) { ... }
void _handleHorizontalDragUpdate(DragUpdateDetails d) { ... }
void _handleHorizontalDragEnd(DragEndDetails d) { ... }
```

### 验收标准

- ✅ 单击播放/暂停
- ✅ 长按触发 2 倍速，释放恢复
- ✅ 长按期间上下滑动可永久设置倍速
- ✅ 水平滑动显示 ±N 秒，松手后执行跳转
- ✅ 300ms 内双击触发点赞动画
- ✅ 暂停时按钮显示播放图标，播放中显示暂停图标

---

## Task 2: 可拖拽进度条实现

- **优先级**: P0 (核心功能)
- **Depends On**: None (可与 Task 1 并行)
- **预计工时**: 4 小时

### 描述

参考 React 版 `updateSeekPosition()` 实现可点击、可拖拽的进度条，并在底部信息条下方显示。

### 关键实现点

1. **显示条件**：`duration > 180s && !isAutoPlay && _showProgress`
   - 默认 `_showProgress = true`，初始化后根据条件判断
   - 用户交互后 `_showProgress=true`，5 秒后自动隐藏（定时器）

2. **进度条组件**：新组件 `_SeekableProgressBar`（放在 `video_page_item.dart` 中作为私有类）
   - 高度：20px（点击区域，扩大可点击范围）
   - 实际显示条：6px 高
   - 背景：`Colors.black26`
   - 已播放：`primaryPink`
   - 圆角：`BorderRadius.circular(3)`
   - 使用 `Listener` 监听指针事件（比 `GestureDetector` 更精确）

3. **点击跳转**：
```dart
void _updateSeekPosition(PointerEvent event) {
  final box = _progressKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return;
  final localPosition = box.globalToLocal(event.position);
  final percent = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
  final totalDuration = _videoController?.value.duration;
  if (totalDuration == null || totalDuration.inMilliseconds <= 0) return;
  final targetMs = (percent * totalDuration.inMilliseconds).toInt();
  _videoController?.seekTo(Duration(milliseconds: targetMs));
}
```

4. **拖拽**：`onPointerDown → _isDragging=true; _dragProgress=percent;`
   - `onPointerMove → if (_isDragging) 更新 _dragProgress;`
   - `onPointerUp → _isDragging=false;`

5. **时间显示**：在进度条右侧或下方显示 `mm:ss / mm:ss`（如 `12:34 / 45:00`）
   - 字体大小：11px
   - 颜色：`textSecondary`

6. **隐藏定时器**：
```dart
Timer? _progressHideTimer;
void _showProgressAndReset() {
  if (!mounted) return;
  setState(() {
    _showProgress = true;
  });
  _progressHideTimer?.cancel();
  _progressHideTimer = Timer(Duration(seconds: 5), () {
    if (mounted) setState(() => _showProgress = false);
  });
}
```

### 验收标准

- ✅ 视频时长 > 3分钟时显示进度条
- ✅ 点击进度条任意位置，视频跳转到对应位置
- ✅ 水平拖拽进度条指针，实时更新播放位置
- ✅ 显示当前时间 / 总时长
- ✅ 进度条颜色：已播放为粉色，未播放为半透明黑色
- ✅ 5 秒无操作后自动隐藏进度条（与底部信息条同步）

---

## Task 3: 信息弹窗完善

- **优先级**: P1 (次要功能)
- **Depends On**: None
- **预计工时**: 3 小时

### 描述

增强 `_showVideoInfoSheet()`，使信息弹窗包含完整的视频元信息，与 React 版 `VideoInfo.tsx` + `VideoCard.tsx` 的 showInfo 逻辑对齐。

### 关键实现点

1. **弹窗结构**：
```
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
        color: Color(0xE6000000),  // 87% 黑色
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ListView(
        children: [
          // 1. 顶部小把手
          // 2. 标题（大号，粗体）
          // 3. 类型标签 + 年份 + 时长 + 评分
          // 4. 简介（多行，不截断，支持滚动）
          // 5. 演员列表（前 10 人）
          // 6. 导演信息（如有）
          // 7. 剧集信息（如 Season 1 · Episode 5）
        ],
      ),
    ),
  ),
)
```

2. **类型标签**：
   - 电影：`"电影"`（粉色背景白色文字）
   - 剧集：`"剧集"`（蓝色背景白色文字）
   - 其他：`widget.item.type ?? "视频"`（默认背景）

3. **评分显示**：
   - 如 `communityRating` 存在，显示 `★ 8.5`（10分制）
   - 粉色星星图标（`Icons.star`，`color: primaryPink`）

4. **演员/导演**：
   - 使用 `widget.item.people`（如果存在）
   - 横向滚动，每个演员项：圆形头像 + 姓名
   - 头像失败时显示：`Icons.person` fallback

5. **空字段处理**：
   - 简介为空 → "暂无简介"
   - 演员为空 → 不显示演员区域
   - 无评分 → 隐藏评分项

### 验收标准

- ✅ 点击 ℹ️ 信息按钮后弹出底部面板
- ✅ 显示标题、类型标签、年份、时长、评分、简介、演员、导演
- ✅ 可上下滑动调整面板高度（min 30%, max 90%）
- ✅ 下滑可关闭面板
- ✅ 空字段优雅处理

---

## Task 4: 底部信息条优化（3秒自动隐藏）

- **优先级**: P1 (次要功能)
- **Depends On**: None
- **预计工时**: 2 小时

### 描述

优化 `_buildBottomGradient()`，添加 3 秒自动隐藏逻辑，渐变背景优化，显示信息更完整。

### 关键实现点

1. **3 秒自动隐藏**：
```dart
Timer? _infoHideTimer;
bool _isInfoVisible = true;

void _resetInfoHideTimer() {
  _infoHideTimer?.cancel();
  if (mounted) setState(() => _isInfoVisible = true);
  if (_isPlaying) {
    _infoHideTimer = Timer(Duration(seconds: 3), () {
      if (mounted) setState(() => _isInfoVisible = false);
    });
  }
}
```

2. **在播放状态变化时调用**：
   - `_videoController?.addListener(() {`
     - `if (mounted && _isPlaying != _videoController.value.isPlaying)`
     - `setState(() { _isPlaying = _videoController.value.isPlaying; });`
     - `_resetInfoHideTimer();`
   - `});`

3. **渐变背景优化**：
   - `LinearGradient(colors: [Color(0xE6000000), Color(0x66000000), Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter)`

4. **信息条内容**：
   - 标题（粗体，2行）
   - 类型标签（粉色背景，圆角）
   - 年份
   - 时长（`formattedDuration`）
   - 评分（`★ X.X`）
   - 简介（2行截断，点击展开完整内容）

5. **动画**：
   - `AnimatedOpacity` + `AnimatedContainer`，300ms 平滑动画
   - `opacity: _isInfoVisible ? 1.0 : 0.0, duration: Duration(milliseconds: 300)`

### 验收标准

- ✅ 播放中 3 秒后信息条淡出
- ✅ 用户交互（点击、滑动）后重新显示信息条
- ✅ 暂停时信息条保持显示
- ✅ 渐变背景从底部到顶部从深到浅
- ✅ 信息条显示标题、类型、评分、简介

---

## Task 5: 右侧操作区整理与优化

- **优先级**: P1 (次要功能)
- **Depends On**: None
- **预计工时**: 2 小时

### 描述

调整右侧操作区按钮顺序和样式，与 React 版 `VideoControls.tsx` 对齐。

### 关键实现点

1. **按钮顺序（从上至下）**：
   - 连播按钮（∞）：`_buildAutoPlayButton()`
   - 演员头像（`_buildPosterAvatar()`）：显示主要演员信息
   - 点赞按钮（❤️）：`_buildFavoriteButton()`
   - 信息按钮（ℹ️）：`_buildInfoButton()`
   - 删除按钮（🗑️）：`_buildDeleteButton()`
   - 唱片/静音按钮（💿）：`_buildMuteButton()` 或 `_buildPosterButton()`

2. **唱片旋转动画**：
   - 播放中时，唱片按钮显示动画旋转
   - `AnimatedRotation(turns: Tween(begin: 0, end: 1.0).animate(_rotationController), duration: Duration(seconds: 4), child: Icon(...) 或 Image.network(...)`
   - 静音时唱片变红，不旋转

3. **演员头像显示**：
   - 如果 `widget.item.people` 中有演员信息
   - 显示第一个演员的头像（圆形，边框 2px 白色）
   - 下方显示演员姓名（小字，10px）

4. **连播状态**：
   - `isAutoPlay=true` 时：连播按钮高亮（绿色背景）
   - `isAutoPlay=false` 时：默认样式

### 验收标准

- ✅ 按钮顺序与 React 版一致：连播 → 演员头像 → 点赞 → 信息 → 删除 → 唱片
- ✅ 唱片播放中旋转，静音时不旋转并变红
- ✅ 演员头像显示主要演员信息（如有）
- ✅ 连播开启时按钮为绿色背景

---

## Task 6: 倍速菜单实现

- **优先级**: P2 (可选功能)
- **Depends On**: None
- **预计工时**: 2 小时

### 描述

实现倍速菜单，支持 0.5x 到 3.0x 的倍速选择，区分临时倍速（长按触发）和永久倍速（菜单选择）。

### 关键实现点

1. **倍速菜单**：
   - 点击倍速按钮弹出 `showModalBottomSheet`
   - 可选倍速：`[0.5, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]`
   - 每个倍速项：`ListTile(title: Text("1.5x"), onTap: () { _setPlaybackRate(1.5); Navigator.pop(context); })`
   - 当前倍速高亮（粉色文字）

2. **倍速徽章**：
   - 在倍速按钮旁显示当前倍速（如 `1.5x`）
   - 或按钮本身直接显示倍速文字（如 `_buildSpeedControlButton()` 显示 "1.5x"）

3. **临时倍速 vs 永久倍速**：
   - 临时倍速：长按触发 → 结束后恢复 1.0x（Task 1 已处理）
   - 永久倍速：通过菜单选择 → 持续生效，直到下次更改

4. **倍速设置**：
```dart
void _setPlaybackRate(double rate) {
  _videoController?.setPlaybackSpeed(rate);
  setState(() => _playbackRate = rate);
}
```

### 验收标准

- ✅ 点击倍速按钮弹出倍速选择菜单
- ✅ 支持 0.5x, 1.0x, 1.25x, 1.5x, 1.75x, 2.0x, 2.5x, 3.0x
- ✅ 选择倍速后视频立即以新速度播放
- ✅ 当前倍速在菜单中高亮显示
- ✅ 倍速按钮显示当前倍速文字

---

## Task 7: 字幕控制增强

- **优先级**: P2 (可选功能)
- **Depends On**: None
- **预计工时**: 2 小时

### 描述

增强字幕控制，支持多语言字幕切换、字体大小和颜色调整、延迟设置。

### 关键实现点

1. **字幕按钮**：
   - 点击弹出字幕选择面板
   - 无字幕时显示 "无字幕" 图标
   - 有字幕时显示 "CC" 图标

2. **字幕轨道信息**：
   - 从 `MediaItem` 或 `MediaSource` 中获取可用字幕轨道
   - 每个轨道包含：语言、格式（vtt/srt）、URL

3. **字幕设置**：
   - 字体大小：`small/medium/large`
   - 字体颜色：`white/yellow`
   - 背景：`none/black/transparent`
   - 延迟：`-5s to +5s`

### 验收标准

- ✅ 字幕按钮可弹出字幕选择面板
- ✅ 可切换不同语言字幕
- ✅ 可选择关闭字幕
- ✅ 字幕显示在视频底部中央
- ✅ 字幕设置（大小、颜色）可调整并保存

---

## Task 8: 播放模式切换完善

- **优先级**: P2 (可选功能)
- **Depends On**: None
- **预计工时**: 2 小时

### 描述

实现 Direct/Transcode/Fallback 三种播放模式切换，与 React 版 `playMode` 逻辑对齐。

### 关键实现点

1. **模式定义**：
```dart
enum PlayMode { direct, transcode, fallback }
PlayMode _playMode = PlayMode.direct;
```

2. **模式切换**：
   - 点击模式按钮 → cycle：direct → transcode → fallback → direct
   - `_playMode = PlayMode.values[(_playMode.index + 1) % PlayMode.values.length];`

3. **模式显示**：
   - Direct：圆形白色背景，显示 "D" 或播放图标
   - Transcode：黄色背景，显示 "T" 或转码图标
   - Fallback：红色背景，显示 "F" 或备用图标

4. **错误处理**：
   - 如果当前模式加载失败，自动尝试下个模式
   - 最多重试 MAX_RETRIES=3 次

### 验收标准

- ✅ 三种模式可循环切换
- ✅ 模式按钮显示当前模式文字和颜色
- ✅ 切换模式后视频以新方式加载
- ✅ 错误时自动降级到下一个模式

---

## Task 9: 代码整理、审查与提交同步

- **优先级**: P0 (必须)
- **Depends On**: Task 1, 2, 3, 4, 5, 6, 7, 8
- **预计工时**: 2 小时

### 描述

整理所有改动代码，进行代码审查，修复 lint 警告，提交到 Git 并同步到 GitHub 仓库。

### 关键实现点

1. **代码规范**：
   - 确保变量、方法命名规范（snake_case 变量，camelCase 方法）
   - 删除无用 import、注释
   - 确保 null 安全（`_videoController?.xxx`）

2. **代码审查清单**：
   - ✅ `flutter analyze` 无 error 级别问题
   - ✅ 所有 `setState` 前检查 `mounted`
   - ✅ 所有 Timer 在 `dispose` 中 cancel
   - ✅ 所有 listener 在 `dispose` 中 remove
   - ✅ 无明显性能问题（避免频繁 setState）

3. **提交信息**（使用 semantic-release 格式）：
```
feat(ui): 完整播放控制和可拖拽进度条实现

- 添加播放控制手势（单击、长按、水平滑动、双击）
- 实现可拖拽进度条，支持点击跳转和拖拽调整
- 优化信息弹窗，包含完整视频元信息
- 底部信息条 3 秒自动隐藏，渐变背景优化
- 右侧操作区调整顺序，添加唱片旋转动画
- 倍速菜单支持 0.5x-3.0x
- 字幕控制增强，多语言选择
- 播放模式切换（Direct/Transcode/Fallback）
```

4. **同步**：
   - `git commit -am "feat: ..."`
   - `git pull --rebase origin main`
   - `git push origin main`

### 验收标准

- ✅ 代码提交至本地 Git
- ✅ 成功推送至 GitHub 远程仓库 main 分支
- ✅ `git status` 显示 clean
- ✅ 无冲突或已解决冲突

---

## 实施顺序建议

```
Phase 1 (核心功能):
  ├── Task 1 (播放控制手势)      ← 可开始
  └── Task 2 (可拖拽进度条)        ← 可开始

Phase 2 (显示优化):
  ├── Task 3 (信息弹窗)
  ├── Task 4 (底部信息条优化)
  └── Task 5 (右侧操作区)

Phase 3 (增强功能 - 可选):
  ├── Task 6 (倍速菜单)
  ├── Task 7 (字幕控制)
  └── Task 8 (播放模式)

Final:
  └── Task 9 (代码整理与提交)
```

---

## 时间估算汇总

| Task | 工时(小时) | 说明 |
|------|-----------|------|
| Task 1 | 3h | 播放控制手势 |
| Task 2 | 4h | 可拖拽进度条 |
| Task 3 | 3h | 信息弹窗 |
| Task 4 | 2h | 底部信息条优化 |
| Task 5 | 2h | 右侧操作区整理 |
| Task 6 | 2h | 倍速菜单 |
| Task 7 | 2h | 字幕控制 |
| Task 8 | 2h | 播放模式 |
| Task 9 | 2h | 代码整理 |
| **Total** | **22h** | ≈ 3 个工作日 |
