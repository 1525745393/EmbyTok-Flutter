# 视频详情弹窗增强 + 底部信息条播放进度 - 产品需求文档 (PRD)

## Overview
- **Summary**: (1) 确认并完善「ℹ 信息」按钮点击后的视频详情弹窗，确保展示完整的标题、年份、时长、评分、简介、演员列表等元信息；(2) 在底部信息条（小面积渐变区域）新增播放进度显示，使用户在播放时可直观了解当前播放位置。
- **Purpose**: 当前视频详情弹窗已存在但可能需要优化视觉与信息完整性；底部信息条目前仅显示标题和评分，缺少播放进度指示。用户需要在浏览/播放视频时快速了解已观看进度和剩余时长，降低跳转到播放控制界面的操作成本。
- **Target Users**: 所有使用 EmbyTok 浏览竖屏视频（电影、剧集、音乐视频等）的用户，尤其关注观看进度的用户。

## Goals

### 目标一：视频详情弹窗的完整性与可访问性
1. 确保「ℹ 信息」按钮点击后弹出的 BottomSheet 展示完整的视频元信息：
   - 标题（含年份括号）
   - 类型标签 + 年份 + 剧集信息（如有）
   - 基本信息行：时长、评分、类型、制作公司
   - 简介（多行，支持滚动）
   - 主要演员列表（前 5-10 位）
   - 导演信息（如有）
2. 弹窗支持拖动调整大小和下滑关闭
3. 保持与现有 UI（字幕选择、速度调节面板）一致的视觉风格

### 目标二：底部信息条播放进度显示
1. 在底部小面积渐变信息条的底部新增一条播放进度条（LinearProgressIndicator）
2. 进度条显示当前播放位置占总时长的百分比（0-100%）
3. 显示当前时间 / 总时长文字（如 "12:34 / 1:30:00"）
4. 保持信息条其他元素的布局不变（类型标签、标题、评分、简介）
5. 进度实时更新（随视频播放自动刷新）

## Non-Goals (Out of Scope)
- 不在底部信息条实现进度条拖拽/跳转功能（仅显示，不作为交互控件）
- 不在此功能中修改视频播放逻辑、倍速、静音等控制
- 不修改右侧操作区的其他按钮功能（点赞、删除、全屏、倍速等）
- 不新增网络请求（播放进度数据来自 `_videoController` 或 `MediaItem.userData`）
- 不修改视频详情弹窗的样式以外的功能（不做编辑/分享等操作）

## Background & Context

### 1. 当前代码位置
**主文件**: `frontend/lib/widgets/video_page_item.dart`

| 组件 | 方法/位置 | 状态 |
|------|----------|------|
| 信息按钮 | `_buildInfoButton()` 1149-1162行 | ✅ 已实现 |
| 视频详情弹窗 | `_showVideoInfoSheet()` 1165-1294行 | ✅ 已实现 |
| 底部小面积信息条 | `_buildBottomGradient()` 817-910行 | ⚠️ 部分实现（缺少进度条）|
| 视频控制器 | `_videoController` (第53行) | ✅ 可用 |
| 当前播放位置 | `_videoController!.value.position` | ✅ 可用 |
| 总时长 | `_videoController!.value.duration` | ✅ 可用 |
| 上次播放位置 | `widget.item.userData?.playbackPositionTicks` | ✅ 可用 |

### 2. 视频详情弹窗当前实现分析
`_showVideoInfoSheet()` 使用 `showModalBottomSheet` + `DraggableScrollableSheet`，内容包括：
- **顶部小把手** (指示可下滑关闭)
- **标题**（22号字，粗体）
- **副标题**（类型标签 + 年份 + 剧集信息，如 S1E1）
- **基本信息行**（时长/评分/类型/工作室，通过 `_InfoChip` 展示）
- **简介**（多行文字，14号字，textSecondary 颜色）
- **主要演员**（5人，通过 `_buildPeopleChips` 横向展示）
- **导演**（3人）
- **关闭按钮**（可选，目前通过点击空白/下滑关闭）

**相关辅助组件**：
- `_buildInfoSubtitle()` (1297行) - 副标题组件，包含类型标签、年份、剧集信息
- `_buildInfoRowItems()` (1386行) - 基本信息行，使用 `_InfoChip` 展示多个数据项
- `_InfoChip` (2082行) - 信息卡片组件，label:value 形式
- `_SectionLabel` (2062行) - 分节标题组件

### 3. 底部信息条当前实现分析
`_buildBottomGradient()` 位于底部 Positioned 组件，内容：
- 黑色 → 透明的竖直渐变背景
- **类型标签**（顶部，粉色背景）
- **标题行**（标题 + 评分 `★ X.X`）
- **简介**（单行，可选）
- 无进度条 ❌

### 4. 数据模型
**MediaItem** (`frontend/lib/models/media_item.dart`):
- `title` - 视频标题
- `type` - 类型 (Movie/Series/Episode/MusicVideo)
- `productionYear` / `year` - 制作年份
- `runtimeTicks` / `durationSeconds` - 时长（秒或 tick 单位，1 tick = 100ns）
- `formattedDuration` - 格式化时长（如 "1h 30m"，已有 getter）
- `overview` - 简介
- `communityRating` / `rating` - 社区评分（1-10 范围）
- `displayRating` - 便捷 getter（已有）
- `displayGenres` - 类型列表（已有）
- `studioNames` - 工作室/制作公司
- `people` - 演员/导演等人员列表
- `seriesName` - 所属剧集名（Episode 特有）
- `parentIndexNumber` - 季序号（Episode 特有）
- `indexNumber` - 集序号（Episode 特有）

**UserData** (`frontend/lib/models/user_data.dart`):
- `playbackPositionTicks` - 已播放时长（tick 单位，1 tick = 100ns）
- `played` - 是否已完整观看
- `playCount` - 观看次数

**VideoPlayerValue** (video_player 插件):
- `position` - 当前播放位置（Duration 类型）
- `duration` - 视频总时长（Duration 类型）
- `isPlaying` - 是否正在播放

### 5. 技术参考
- **进度条 Widget**: Flutter 内置 `LinearProgressIndicator` 或自定义 `Container`
- **状态更新**: 使用 `_videoController` 的 `addListener` 监听播放位置变化，或使用 `State` + `setState` 在播放时定时刷新
- **Duration 格式化**: 需要将 `Duration` 格式化为 `mm:ss` 或 `hh:mm:ss` 格式
  - 已有的 `_formatDuration` 方法可参考（如果存在），或新增一个局部格式化函数

## Functional Requirements

### FR-1: 视频详情弹窗完整性验证与增强
- **FR-1.1**: 点击「ℹ 信息」按钮触发 `_showVideoInfoSheet()`，弹出 BottomSheet
- **FR-1.2**: 弹窗展示标题（含年份括号，如 "电影名 (2023)"）
- **FR-1.3**: 展示类型标签（如 "电影"）+ 年份数字 + 剧集信息（如 "S1 · E1"）
- **FR-1.4**: 展示基本信息行（时长、评分、类型、工作室），每个字段有独立的小卡片
- **FR-1.5**: 展示完整简介（多行文本，不截断，支持滚动）
- **FR-1.6**: 展示主要演员（姓名 + 角色，如 "张三 · 饰 角色A"），前 5-10 人
- **FR-1.7**: 展示导演信息（如有）
- **FR-1.8**: 弹窗支持拖动调整高度（最小30%，最大90%），下滑关闭
- **FR-1.9**: 弹窗背景为半透明黑色（`Color(0xE6000000)`），与字幕/速度面板一致
- **FR-1.10**: 空字段处理：某些视频可能缺少简介、评分、演员等，对应区域应优雅隐藏或显示「暂无」

### FR-2: 底部信息条播放进度条
- **FR-2.1**: 在底部渐变信息条的最底部（简介下方），新增一条播放进度条
- **FR-2.2**: 进度条使用 `LinearProgressIndicator` 或自定义实现，高度 3-4dp
- **FR-2.3**: 进度条显示当前播放进度百分比（0-100%），基于 `_videoController.value.position` / `_videoController.value.duration`
- **FR-2.4**: 进度条右侧或下方显示时间文字：`当前时间 / 总时间`（如 "12:34 / 1:30:00"）
- **FR-2.5**: 进度随播放自动更新（每 500ms 或更频繁刷新），无需用户操作
- **FR-2.6**: 当视频未开始播放（`_videoController` 为 null 或无 duration），进度条隐藏或显示为 0%
- **FR-2.7**: 如视频有历史播放进度（`userData.playbackPositionTicks > 0`），可在进度条上标记上次观看位置（可选增强）
- **FR-2.8**: 进度条颜色使用主题色（`primaryPink` 或自定义），未播放部分使用深灰色

### FR-3: Duration 格式化工具
- **FR-3.1**: 新增一个辅助方法（私有函数或在 `media_item.dart` 中）用于将 `Duration` 格式化为字符串
- **FR-3.2**: 格式一：`mm:ss`（短时长，如 12:34）
- **FR-3.3**: 格式二：`hh:mm:ss`（长时长，如 1:30:00）
- **FR-3.4**: 处理 null/零值情况，显示 `0:00` 或不显示

## Non-Functional Requirements

### NFR-1: 性能
- 播放进度刷新频率应平衡：每 250ms-500ms 刷新一次（不影响视频播放流畅度）
- 避免频繁 `setState` 导致全组件重建，使用 `StatefulWidget` 的局部刷新（如单独封装进度条 widget 或使用 `ValueListenableBuilder`）
- 弹窗打开延迟 < 100ms（数据全部在内存中）

### NFR-2: 视觉一致性
- 进度条颜色：已播放部分使用 `primaryPink`（主题粉色），未播放部分使用 `Colors.white12` 或深灰色
- 进度条圆角：`BorderRadius.circular(2)` 或类似的轻微圆角
- 时间文字：12号字，`textSecondary` 颜色，右侧对齐
- 文字格式：`mm:ss / h:mm:ss` 或 `mm:ss / mm:ss`（根据总时长自动选择）
- 间距：进度条与简介之间保持 `SizedBox(height: 10)`

### NFR-3: 可维护性
- 播放进度条相关代码放在 `_buildBottomGradient()` 内部或相邻位置
- Duration 格式化函数独立抽取，不与 UI 代码耦合
- 代码风格与现有代码保持一致（使用 const 构造函数、颜色常量、响应式尺寸等）

### NFR-4: 健壮性
- `_videoController` 为 null 时不崩溃（空安全处理）
- `duration` 为 zero/null 时不显示进度条（避免除零错误）
- `position` 为 zero 时正常显示 0%
- 长标题与评分共存时，进度条仍可正常显示在最底部

## Constraints
- **技术栈**: Flutter/Dart，仅修改 `frontend/lib/widgets/video_page_item.dart`（如有需要可在 `media_item.dart` 新增 getter）
- **依赖**: 仅使用现有 `video_player` 插件，无新增第三方依赖
- **平台**: Android/iOS/桌面/Web 多端一致
- **设计**: 深色主题，与现有 UI 风格一致（`primaryPink`、`textPrimary`、`textSecondary` 等颜色常量）
- **空间限制**: 底部信息条高度不得超过屏幕高度的 15-20%，需保证按钮和操作区不被遮挡

## Assumptions
- `_videoController` 已正确初始化并在视频播放过程中更新 `position`
- `MediaItem.userData?.playbackPositionTicks` 可用于判断视频是否有观看历史
- `MediaItem.formattedDuration` 已正确实现并返回 "1h 30m" 等格式
- 播放进度条是**纯显示**组件，不支持用户点击或拖拽跳转
- 用户在浏览视频时会关注进度条（尤其是长视频或中断后继续观看的场景）

## Acceptance Criteria

### AC-1: 视频详情弹窗显示完整元信息
- **Given**: 用户正在播放任意视频（电影/剧集/音乐视频）
- **When**: 点击右侧操作区的「ℹ 信息」按钮
- **Then**: 从底部弹出信息面板
- **And**: 面板顶部显示视频标题（如 "电影名 (2023)"）
- **And**: 标题下方显示类型标签、年份、剧集信息（如有）
- **And**: 基本信息行显示时长、评分、类型、工作室
- **And**: 简介区域显示完整简介文本（不截断）
- **And**: 演员区域显示主要演员姓名
- **And**: 导演区域显示导演姓名（如有）
- **Verification**: `human-judgment`

### AC-2: 视频详情弹窗交互
- **Given**: 信息弹窗已打开
- **When**: 用户向上/向下拖动面板
- **Then**: 面板高度跟随拖动变化（最小30%，最大90%）
- **When**: 用户点击面板外区域或向下快速滑动
- **Then**: 面板关闭，返回到视频播放界面
- **Verification**: `human-judgment`

### AC-3: 底部信息条显示播放进度条
- **Given**: 用户正在播放视频，视频已开始播放且有有效 duration
- **When**: 查看底部渐变信息条
- **Then**: 在简介下方显示一条横向进度条
- **And**: 进度条显示当前播放位置的百分比（已播放部分高亮）
- **And**: 进度条右侧或下方显示 `当前时间 / 总时长` 文本
- **Verification**: `human-judgment`

### AC-4: 进度条实时更新
- **Given**: 视频正在播放
- **When**: 观察进度条
- **Then**: 进度条随播放持续增长（每 500ms 内可见变化）
- **And**: 时间文本从 `0:00 / X:XX` 逐渐增长到 `X:XX / X:XX`
- **Verification**: `human-judgment`

### AC-5: 无有效时长时进度条隐藏
- **Given**: 视频尚未加载（`_videoController` 为 null 或 duration 为零）
- **When**: 查看底部信息条
- **Then**: 进度条不显示，仅显示标题/评分/简介
- **Verification**: `human-judgment`

### AC-6: 空字段优雅处理
- **Given**: 视频缺少某些元信息（如无简介、无评分、无演员）
- **When**: 打开详情弹窗
- **Then**: 对应区域隐藏或显示「暂无数据」，UI 不因空值崩溃
- **Verification**: `human-judgment`

### AC-7: 剧集信息正确显示
- **Given**: 当前播放的是剧集（Episode 类型，有 seriesName、parentIndexNumber、indexNumber）
- **When**: 打开详情弹窗
- **Then**: 标题下显示剧集名及 "第 X 季 · 第 Y 集"
- **Verification**: `human-judgment`

### AC-8: 代码编译无错误
- **Given**: 修改完成
- **When**: 执行 `flutter analyze`
- **Then**: 不产生新的 error 级别问题
- **Verification**: `programmatic`

### AC-9: 进度条与现有信息条元素布局正确
- **Given**: 底部信息条同时显示类型标签、标题、评分、简介和进度条
- **When**: 在竖屏模式下查看
- **Then**: 所有元素按从上到下顺序排列，布局合理，无重叠或挤压
- **Verification**: `human-judgment`

### AC-10: 不影响其他按钮和控件功能
- **Given**: 修改完成
- **When**: 测试所有右侧操作区按钮（点赞、删除、倍速、播放模式、字幕、唱片静音、全屏、连播）
- **Then**: 所有原有功能正常工作，无回归问题
- **Verification**: `human-judgment`

## Open Questions

1. **[x] 进度条时间显示位置**：进度条右侧一行显示（紧凑）还是进度条下方单独一行（更清晰）？→ 选择：时间文本显示在进度条的右侧（同一行）。
2. **[x] 历史播放位置标记**：如果视频有 `playbackPositionTicks`，是否需要在进度条上用小圆点或不同颜色标记上次观看位置？→ 选择：不实现此功能，仅显示当前播放进度，避免过度复杂。
3. **[x] 进度条高度**：多高合适？→ 选择 3-4dp（如 `SizedBox(height: 3)` 或 `height: 4`）。
4. **[x] 长标题时进度条是否会被挤压？** → 进度条在底部独立一行，不受标题高度影响。
5. **[x] 是否显示百分比数字？**（如 "45%"）→ 选择：不显示百分比数字，时间文本已足够清晰。
6. **[x] 进度条刷新频率？** → 选择 250ms-500ms，平衡性能和视觉流畅度。
7. **[x] 是否需要在视频暂停时冻结进度条刷新？** → 选择：仍然显示当前位置，不刷新即可（`_videoController.value.position` 返回当前值，不需要定时器）。
