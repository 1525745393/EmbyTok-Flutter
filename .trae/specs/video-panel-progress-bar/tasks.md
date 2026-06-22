# 视频详情弹窗增强 + 底部进度条 - 实施任务计划

## 当前代码状态速查

| 功能 | 文件/方法 | 行数 | 状态 |
|------|----------|------|------|
| 信息按钮 | `_buildInfoButton()` | video_page_item.dart:1149-1162 | ✅ 已实现 |
| 视频详情弹窗 | `_showVideoInfoSheet()` | video_page_item.dart:1165-1294 | ✅ 已实现，需审核 |
| 底部信息条 | `_buildBottomGradient()` | video_page_item.dart:817-910 | ✅ 部分实现，缺进度条 |
| 视频控制器 | `_videoController` | video_page_item.dart:53 | ✅ 可用 |
| Duration 格式化 | `MediaItem.formattedDuration` | media_item.dart:268-278 | ✅ 已实现（仅用于总时长） |

---

## [ ] Task 1: 代码全面审查 — 验证视频详情弹窗的完整性
- **Priority**: P1
- **Depends On**: None
- **Description**: 
  - 详细审查 `_showVideoInfoSheet()` 的代码实现（1165-1294行）
  - 验证弹窗是否包含：标题、年份、类型、时长、评分、简介、演员、导演等所有必需信息
  - 检查 `_buildInfoSubtitle()` 的类型标签+年份+剧集信息显示（1297-1350行）
  - 检查 `_buildInfoRowItems()` 的基本信息行（时长/评分/类型/工作室）（1386-1420行）
  - 检查 `_InfoChip` 的标签-值显示格式（2082-2095行）
  - 检查 `_buildPeopleChips()` 的演员横向展示（如有此方法）
  - 检查 `_SectionLabel` 的分节标题样式（2062-2078行）
  - 如果发现信息缺失或显示不完整，记录问题并在 Task 2 修复
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-6, AC-7
- **Test Requirements**:
  - `human-judgement` TR-1.1: 代码审查报告 — 列出弹窗中展示的所有字段及其显示方式
  - `human-judgement` TR-1.2: 在 2-3 个不同类型视频上测试弹窗（电影、剧集、音乐视频）
  - `programmatic` TR-1.3: 确认 `_showVideoInfoSheet()` 方法中没有明显的空值未处理问题

## [ ] Task 2: 视频详情弹窗增强（如 Task 1 发现问题）
- **Priority**: P0
- **Depends On**: Task 1
- **Description**: 
  - 根据 Task 1 的审查结果，修复/增强弹窗中缺失或不完整的信息展示
  - 可能的增强点：
    1. **标题格式**：确认 `_titleText()` 返回 "标题 (年份)" 格式（1935-1940行）
    2. **类型标签颜色**：确认使用 `primaryPink` 背景色（1308-1323行）
    3. **基本信息行布局**：确认 `_InfoChip` 的布局是否合理，是否需要调整间距
    4. **简介显示**：确认简介不被截断（无 `maxLines` 限制，且 `ListView` 可滚动）
    5. **演员/导演**：确认 `people` 数据被正确解析和展示
    6. **空字段处理**：确认评分、简介、演员等字段为空时的处理
    7. **视觉优化**：如需要，调整文字大小、颜色、间距等使其更易阅读
  - 确保 DraggableScrollableSheet 的 minChildSize/initialChildSize/maxChildSize 设置合理
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-6, AC-7
- **Test Requirements**:
  - `human-judgement` TR-2.1: 修复后在真机/模拟器上测试所有字段的显示效果
  - `human-judgement` TR-2.2: 测试缺少某些元信息的视频（如无简介、无评分）
  - `programmatic` TR-2.3: `flutter analyze` 无新 error
- **Notes**: Task 1 如果确认弹窗已完整实现，此任务可标记为"无需修改，跳过"

## [ ] Task 3: 新增底部播放进度条 — 核心实现
- **Priority**: P0
- **Depends On**: Task 1 (Task 2 可选)
- **Description**: 
  - 在 `_buildBottomGradient()` 方法的底部（简介文本之后）新增播放进度条
  - 结构布局（从顶到底）：
    1. 类型标签（Container + Text，现有的）
    2. 标题行（Row: Expanded Text + 评分，现有的）
    3. 简介文本（可选，现有的）
    4. **【新增】** 播放进度行（Row: LinearProgressIndicator + 时间文本）
  - 具体实现：
    - **3.1**: 新增 `_buildPlaybackProgress()` 方法（或直接在 `_buildBottomGradient()` 内添加）
    - **3.2**: 进度条 UI：
      - `LinearProgressIndicator` 或自定义实现
      - 高度：3-4（如 `height: 3`）
      - 已播放颜色：`primaryPink`
      - 未播放颜色：`Colors.white12` 或 `Color(0x33FFFFFF)`
      - 背景色：透明（不需要单独背景色，使用渐变背景即可）
      - 圆角：`BorderRadius.circular(2)`
      - 占宽度：左侧 60-70%（右侧留空给时间文本）
    - **3.3**: 时间文本 UI：
      - 位于进度条右侧，同一行
      - 格式：`当前时间 / 总时间`，如 `12:34 / 1:30:00`
      - 字体大小：11-12，颜色 `textSecondary`
      - 右侧对齐
    - **3.4**: Progress 值计算：
      - 总时长：`_videoController?.value.duration ?? Duration.zero`
      - 当前位置：`_videoController?.value.position ?? Duration.zero`
      - 进度百分比：`position.inSeconds / duration.inSeconds`（当 duration > 0 时）
      - duration <= 0 时，进度条不显示
    - **3.5**: Duration 格式化（新增私有方法）：
      - 短时长（< 1小时）：`mm:ss` 格式，如 `12:34`
      - 长时长（>= 1小时）：`h:mm:ss` 格式，如 `1:30:00`
      - 方法签名：`String _formatDuration(Duration duration)`
    - **3.6**: 进度条刷新机制：
      - 使用 `_videoController?.addListener` + `State` 更新
      - 或使用 `AnimatedBuilder` / `ValueListenableBuilder` 监听 `_videoController` 的变化
      - 刷新延迟：让 Flutter 自然刷新即可，不需要额外定时器
      - 注意：`_videoController` 为 null 时不添加 listener
- **Acceptance Criteria Addressed**: AC-3, AC-4, AC-5, AC-9
- **Test Requirements**:
  - `human-judgement` TR-3.1: 在至少 2 个不同时长的视频上测试进度条的显示和刷新效果
  - `human-judgement` TR-3.2: 测试视频未加载时进度条是否隐藏
  - `human-judgement` TR-3.3: 测试长标题视频的进度条布局是否正确
  - `programmatic` TR-3.4: `flutter analyze` 无新 error
- **Notes**: 
  - 参考 `flutter` 的 `LinearProgressIndicator` 文档：需要传入 `value: double`，范围 0.0-1.0
  - 如果 `LinearProgressIndicator` 在深色背景下表现不佳，可以用自定义的 `Stack` + `Container` 实现纯色进度条
  - 注意 `_videoController` 可能为 null，需空安全处理
  - 注意 `_videoController.value.duration` 可能为 `Duration.zero`（如视频尚未初始化）
  - 进度条应该只在 `_videoController` 不为 null 且有有效 duration 时才显示
  - **关于刷新机制的建议**: 如果 `_videoController` 已经被用于其他地方的刷新（如中央播放按钮、底部信息条的显示隐藏等），现有的 listener 可能已经在调用 `setState`，此时只需在 `_buildBottomGradient()` 内直接读取 `_videoController!.value.position` 即可

## [ ] Task 4: Duration 格式化辅助方法
- **Priority**: P1
- **Depends On**: None（与 Task 3 并行实现）
- **Description**: 
  - 实现 `_formatDuration(Duration duration)` 私有方法，将 Duration 转换为字符串
  - 逻辑：
    - `if (duration.inHours >= 1)` → 使用 `h:mm:ss` 格式
      - `hours = duration.inHours`
      - `minutes = duration.inMinutes.remainder(60)`
      - `seconds = duration.inSeconds.remainder(60)`
      - 返回 `'$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'`
    - `else` → 使用 `mm:ss` 格式
      - `minutes = duration.inMinutes`
      - `seconds = duration.inSeconds.remainder(60)`
      - 返回 `'${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'`
    - 处理 `duration == null` 或 `duration.inSeconds <= 0` → 返回 `'0:00'`（可选）
  - 放置位置：放在 `video_page_item.dart` 中 `_VideoPageItemState` 类内的私有方法区
  - 可选：如果这个方法可以在其他地方复用，可以考虑移到 `media_item.dart` 作为静态方法或 extension
- **Acceptance Criteria Addressed**: AC-3
- **Test Requirements**:
  - `human-judgement` TR-4.1: 测试不同 Duration 值的格式化输出
  - `programmatic` TR-4.2: 代码审查通过，格式逻辑正确

## [ ] Task 5: 功能验证与回归测试
- **Priority**: P0
- **Depends On**: Task 1, Task 2, Task 3, Task 4
- **Description**: 
  - 手动测试以下场景，确保所有功能正常工作：
    1. **测试场景 A**: 电影类型视频（有评分、简介、演员）
       - 点击信息按钮 → 弹窗显示完整
       - 底部信息条显示标题、评分、进度条
       - 进度条随播放增长
    2. **测试场景 B**: 剧集类型视频（有 seriesName、season、episode）
       - 弹窗显示剧集信息
       - 进度条正常工作
    3. **测试场景 C**: 缺少元信息的视频（无简介、无评分）
       - 弹窗中对应字段优雅处理
       - 进度条仍正常显示
    4. **测试场景 D**: 未播放视频（`_videoController` 为 null）
       - 进度条隐藏或显示 0%
    5. **测试场景 E**: 暂停播放
       - 进度条停在当前位置，不继续增长
    6. **测试场景 F**: 长时间视频（>1小时）
       - 时间格式显示为 `h:mm:ss`
  - 回归测试：验证所有原有按钮和控件功能不变
- **Acceptance Criteria Addressed**: AC-3, AC-4, AC-5, AC-6, AC-10
- **Test Requirements**:
  - `human-judgement` TR-5.1: 在真机/模拟器上完成 A-F 测试场景
  - `human-judgement` TR-5.2: 验证按钮点击功能、倍速/播放模式切换等不受到影响
  - `programmatic` TR-5.3: `flutter analyze` 无新 error
  - `programmatic` TR-5.4: 检查内存使用，确认没有 listener 泄漏

## [ ] Task 6: 代码整理与提交
- **Priority**: P1
- **Depends On**: Task 5
- **Description**: 
  - 确认代码格式规范（使用 `flutter format`）
  - 确保代码注释清晰，特别是新增的 `_formatDuration` 方法和 `_buildPlaybackProgress` 部分
  - 提交到 Git：message 格式如 `feat(ui): 增强视频详情弹窗，底部信息条新增播放进度条`
  - 同步到远程仓库
- **Acceptance Criteria Addressed**: AC-8
- **Test Requirements**:
  - `programmatic` TR-6.1: `flutter analyze` 无 error
  - `programmatic` TR-6.2: 代码已提交并推送到远程
  - `human-judgement` TR-6.3: 代码审查通过，风格一致

---

## 任务依赖图

```
Task 1 (代码审查) ─┬─→ Task 2 (弹窗增强, 如有问题) ─┐
                    │                                  ├─→ Task 5 (验证) ─→ Task 6 (提交)
                    └─→ Task 3 (进度条核心) ──────────┘
                           ↑
                           │
                    Task 4 (Duration格式)  ←── 并行实现
```

## 关键实现细节提醒

### 关于进度条刷新机制的选择

在 `_VideoPageItemState` 的 `initState` 或其他位置中，如果 `_videoController` 已经被 listener 覆盖：
- 已有 listener 的情况：直接读取 `_videoController!.value.position`，无需新增 listener
- 没有 listener 的情况：需要在 `initState` 中添加，`dispose` 中移除

检查现有代码中 `_videoController` 的监听使用情况（见 515 行附近）。

### 避免过度刷新的建议

- **推荐方案**: 使用 `ValueListenableBuilder<VideoPlayerValue>` 包裹进度条和时间文本，只监听 `_videoController` 的变化
  - 优点：无需手动管理 listener，仅在 `_videoController` 变化时重建进度条区域
  - 缺点：`VideoPlayerValue` 不是传统的 `ValueListenable`，需要额外处理

- **备选方案 A**: 在 `_VideoPageItemState` 中维护一个 `_currentPosition` 的 `Duration` 状态变量，通过 listener + `setState` 更新
  - 优点：简单直观
  - 缺点：可能触发全组件重建，但对性能影响不大

- **备选方案 B**: 直接读取 `_videoController!.value.position`（不监听），依赖播放过程中 Flutter 的自然刷新
  - 优点：最简实现
  - 缺点：进度条可能不会实时更新（需测试确认）

**推荐使用 "备选方案 A"**：简单可靠，改动最小。
