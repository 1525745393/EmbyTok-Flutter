# 视频详情信息按钮 - 产品需求文档 (PRD)

## Overview
- **Summary**: 增强视频播放页面右侧操作区的「ℹ️ 信息」按钮，点击后弹出一个信息面板（BottomSheet），展示当前视频的完整元信息（标题、年份、类型、时长、简介、类型、评分、演员等）。
- **Purpose**: 当前的信息按钮只切换了底部的小面积渐变信息条（显示标题、类型、1 行简介），用户无法查看完整的简介、时长、类型、导演、演员等核心信息。
- **Target Users**: 使用 EmbyTok 浏览个人媒体库（电影、剧集、音乐视频等）的用户。

## Goals
- 用户点击右侧「ℹ️ 信息」按钮，能看到一个结构清晰的视频详情信息面板
- 信息面板展示完整的元信息：标题、年份、类型、时长、评分、类型、制作公司、简介、主要演员/导演
- 支持关闭面板（点击空白处 / 下滑 / 关闭按钮）
- 保持与现有按钮样式的一致性（使用 `_PressableActionButton`）

## Non-Goals (Out of Scope)
- 不修改视频播放逻辑
- 不修改其他右侧按钮的行为
- 不在此面板中做编辑/修改元数据的操作
- 不在此面板中播放视频或切换播放源
- 不创建新的路由/页面

## Background & Context

### Current State
**位置**: `frontend/lib/widgets/video_page_item.dart`

- **第 75 行** 定义 `bool _isInfoExpanded = false;`
- **第 572 行** 根据 `_isInfoExpanded` 控制底部小面积渐变信息条的显示
- **第 923-924 行** 右侧操作区第 3 个按钮是 `_buildInfoButton()`
- **第 1111-1135 行** `_buildInfoButton()` 当前实现：
  - 仅切换 `_isInfoExpanded` 状态
  - 按钮样式是自定义圆形容器（`GestureDetector` + `Container`），与其他按钮（使用 `_PressableActionButton` 第 1601-1613 行）不一致
  - 按下状态显示靛蓝色高亮（`0xCC4F46E5`），与倍速、播放模式等按钮高亮风格一致

**可用的元信息** (`MediaItem` 模型, `media_item.dart`):
- `title` - 标题
- `type` - 类型 (Movie/Series/Episode/MusicVideo 等)
- `year` / `productionYear` - 年份
- `runtimeTicks` / `durationSeconds` - 时长（需转换为 mm:ss 或 h:mm:ss 格式）
- `overview` - 简介（支持多行）
- `communityRating` / `rating` - 评分（1-10）
- `genres` / `genreNames` - 类型列表
- `studioNames` - 制作公司
- `people` - 人员（演员/导演/编剧）
- `seriesName` - 所属剧集（仅 Episode 有）
- `indexNumber` / `parentIndexNumber` - 集数/季数（仅 Episode 有）

**现有的模态框模式**:
- `showModalBottomSheet` (第 1203 行 - 字幕选择; 第 1408 行 - 速度调节)
  - 背景色: `Color(0xE6000000)`
  - padding: `EdgeInsets.fromLTRB(24, 16, 24, 40)`
  - 已形成稳定的视觉规范
- `showDialog` + `AlertDialog` (第 1538 行 - 删除确认)

## Functional Requirements

### FR-1: 信息按钮交互
- 点击右侧「ℹ️ 信息」按钮，弹出底部信息面板（BottomSheet）
- 点击面板外区域或下拉可以关闭面板
- 按钮使用项目现有的 `_PressableActionButton` 样式（与点赞/删除按钮一致），保留原按下高亮状态
- 按钮被点击时将按钮图标改为 `Icons.info_outline`，标签为「信息」

### FR-2: 信息面板内容
信息面板以列表形式展示视频元数据：
1. **标题区域**（面板最顶部）：
   - 视频标题（大字体、粗体）
   - 类型标签 + 年份（右上角小字或标题下方）
2. **基本信息**（以 label-value 形式）：
   - 时长（格式：如 `1h 30m` 或 `90 分钟`）
   - 评分（格式：如 `★ 8.5`，若无则隐藏）
   - 类型（如 `剧情 / 动作 / 科幻`）
   - 制作公司（如有）
3. **剧集信息**（仅 Episode 类型时显示）：
   - 所属剧集 `系列名`
   - `第 X 季 · 第 Y 集`
4. **简介**：完整的 overview 文本（多行显示，支持滚动）
5. **主要演员/导演**（如有 people 数据）：
   - 横向展示头像卡片（姓名 + 角色）
   - 或者以文字列表形式展示

### FR-3: 底部小信息条保留
当前底部小面积渐变信息条（`_buildBottomGradient`）保留原有行为：
- 连播模式下（isAutoPlay=true）作为仅有的信息展示方式，由 `_isInfoExpanded` 控制显示/隐藏
- 普通模式下始终可见

## Non-Functional Requirements

### NFR-1: 性能
- 面板打开延迟 < 100ms（所有数据都在内存中，无网络请求）
- 大数据量（如 people > 20）时仍能流畅滚动

### NFR-2: 视觉一致性
- 使用现有 BottomSheet 背景色 `Color(0xE6000000)`
- 文字颜色使用现有常量 `textPrimary` / `textSecondary` / `primaryPink`
- 标签/按钮风格与字幕选择、速度调节面板一致

### NFR-3: 可维护性
- 新增的 `_showVideoInfoSheet()` 方法放在 `_buildInfoButton()` 附近
- 如有需要抽取的辅助方法（如时长格式化），放在 `media_item.dart` 或 `utils/formatters.dart` 中

## Constraints
- **技术栈**: Flutter/Dart，仅修改 `video_page_item.dart`
- **平台**: Android 移动设备为主，兼容 iOS（无需特殊处理）
- **依赖**: 无新增第三方依赖，使用现有 `MediaItem` 模型和 `showModalBottomSheet`
- **设计**: 深色主题，与现有 UI 风格一致

## Assumptions
- `MediaItem` 模型中所有元信息在进入 `VideoPageItem` 时已加载完成（无需异步获取）
- 用户点击信息按钮时视频可以继续播放（不暂停）
- 信息面板打开时不打断任何播放状态（播放位置、音量等）

## Acceptance Criteria

### AC-1: 按钮交互
- **Given**: 用户正在播放视频
- **When**: 点击右侧「ℹ️ 信息」按钮
- **Then**: 从底部弹出信息面板，显示视频元信息
- **Verification**: `human-judgment`

### AC-2: 面板内容完整性
- **Given**: 视频含有完整元信息（标题、年份、时长、简介、类型、评分、演员）
- **When**: 打开信息面板
- **Then**: 所有元信息按 FR-2 中定义的结构清晰展示
- **Verification**: `human-judgment`

### AC-3: 空字段优雅处理
- **Given**: 视频缺少某些元信息（如无简介、无评分、无演员）
- **When**: 打开信息面板
- **Then**: 对应区域隐藏或显示「暂无数据」，UI 不因空值崩溃
- **Verification**: `human-judgment`

### AC-4: 剧集信息展示
- **Given**: 当前播放的是一集剧集（Episode 类型，有 seriesName、parentIndexNumber、indexNumber）
- **When**: 打开信息面板
- **Then**: 顶部标题下显示「系列名」及「第 X 季 · 第 Y 集」
- **Verification**: `human-judgment`

### AC-5: 关闭面板
- **Given**: 信息面板已打开
- **When**: 用户点击面板外区域，或向下滑动面板
- **Then**: 面板关闭，返回播放界面
- **Verification**: `human-judgment`

### AC-6: 代码编译无错误
- **Given**: 修改完成
- **When**: 执行 `flutter analyze`
- **Then**: 不产生新的 error 级别问题
- **Verification**: `programmatic`

## Open Questions

1. **[ ] 演员展示方式**: 横向滚动头像卡片 vs 简单文字列表？当前倾向：先实现简单文字列表，后续如有需要再升级为头像卡片。
2. **[ ] 是否保留现有 `_isInfoExpanded` 对底部小面积信息条的控制？** 当前已在普通模式下始终可见、连播模式下由按钮控制。保留此行为不变。
3. **[ ] 评分展示格式**: `★ 8.5` / `8.5 / 10` / `85%`？倾向 `★ 8.5`。
