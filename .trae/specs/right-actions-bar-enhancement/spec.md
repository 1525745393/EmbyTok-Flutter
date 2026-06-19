# 右侧操作栏对齐 EmbyTok React 版 - Product Requirement Document

## Overview

- **Summary**: 将 Flutter 版 EmbyTok 视频播放器的右侧操作栏功能和布局与 React 版对齐，添加缺失的播放模式切换、字幕控制、信息按钮，并优化整体视觉布局。
- **Purpose**: React 版 EmbyTok 的右侧操作栏功能更加丰富和完整，用户体验更接近 TikTok。需要将 Flutter 版对齐到相同的功能水平。
- **Target Users**: EmbyTok Flutter 版用户，尤其是习惯了 TikTok 风格的竖屏视频浏览用户。

## Goals

- **Goal 1**: 添加播放模式切换按钮（DirectPlay/Transcode/Fallback）
- **Goal 2**: 添加字幕控制按钮（与现有 VideoControls 字幕选择器一致）
- **Goal 3**: 添加信息按钮（展开/收起视频详情面板）
- **Goal 4**: 优化按钮顺序和布局，更接近 React 版风格
- **Goal 5**: 唱片式静音按钮（视觉增强，播放时旋转动画）

## Non-Goals (Out of Scope)

- 不修改现有 `VideoControls` 组件的功能（它有独立的播放控制栏）
- 不引入第三方包或新的依赖项
- 不修改视频播放核心逻辑（只增加 UI 控制层）
- 不实现新的 Provider 状态（复用现有 `playbackLevelProvider`、`selectedSubtitleProvider` 等）

## Background & Context

### EmbyTok React 版右侧操作栏布局（自上而下）

1. **海报/头像展示区** - 圆形视频封面展示
2. **Heart (收藏/点赞)** - 收藏时红色填充，未收藏时白色透明
3. **Info (信息)** - 切换底部视频详情面板的显示
4. **Trash2 (删除)** - 红色图标，弹出确认对话框
5. **ChevronsRight (倍速)** - 点击弹出倍速选择菜单
6. **播放模式 SVG** - 自定义三横线 SVG，切换 direct/transcode/fallback，非 direct 时靛蓝色
7. **Subtitles (字幕)** - 有字幕时显示，启用后靛蓝色
8. **Disc/唱片静音按钮** - 底部圆形唱片，播放时旋转，静音时边框变红

**独立按钮（Infinity 连播开关）**: 在主操作栏下方更独立的位置，开启时绿色

### Flutter 版当前按钮列表（自上而下）

1. **自动连播开关（Infinity）**
2. **倍速按钮（显示当前倍速值）**
3. **下一集按钮（剧集类视频）**
4. **全屏按钮**
5. **静音按钮**
6. **点赞按钮**
7. **删除按钮**
8. **评论按钮（占位）**
9. **分享按钮（占位）**

### 功能差异分析

| 功能 | React 版 | Flutter 版当前 | 动作 |
|------|----------|----------------|------|
| 连播开关 | ✓ 独立按钮 z-40 | ✓ 已有 | 保留，调整位置 |
| 倍速控制 | ✓ ChevronsRight 图标 | ✓ 数字显示按钮 | 保持现有设计（数字显示更直观） |
| 播放模式切换 | ✓ 自定义 SVG | ❌ 缺少 | 需要添加 |
| 字幕控制 | ✓ Subtitles 图标 | ✓ VideoControls 中有 | 需要在右侧操作栏添加同款按钮 |
| 信息按钮 | ✓ Info 图标 | ❌ 缺少 | 需要添加，展开/收起底部信息 |
| 收藏/点赞 | ✓ Heart 图标 | ✓ 已有 | 调整位置，与 React 版顺序一致 |
| 删除 | ✓ Trash2 红色 | ✓ 已有 | 调整位置 |
| 唱片式静音 | ✓ 带旋转动画的 Disc | ✓ 基础静音按钮 | 优化视觉，添加旋转动画 |
| 海报/头像区 | ✓ 圆形海报 | ❌ 缺少 | 添加顶部圆形海报展示 |
| 全屏按钮 | ❌ 未在右侧栏（React 版无） | ✓ 有 | 保留在右侧栏 |
| 下一集按钮 | ❌ 未在右侧栏 | ✓ 条件显示 | 保留 |
| 评论/分享 | ❌ 未在右侧栏 | ✓ 占位 | 保留或移除 |

## Functional Requirements

- **FR-1: 播放模式切换按钮** - 在右侧操作栏添加按钮，点击可切换 DirectPlay/Transcode/Fallback 三种播放模式。当前非 DirectPlay 时按钮高亮（如靛蓝色）。按钮文本显示当前模式缩写。
- **FR-2: 字幕控制按钮** - 在右侧操作栏添加字幕按钮，点击后弹出与 `VideoControls` 相同的字幕选择器。有字幕时按钮正常显示，无字幕时禁用。选择字幕后按钮高亮。
- **FR-3: 信息按钮** - 添加 Info 图标按钮，点击切换 `isInfoExpanded` 状态，展开底部视频详情（标题、简介、类型标签等）时按钮高亮。再次点击收起。
- **FR-4: 唱片式静音按钮** - 优化静音按钮视觉，改为圆形"唱片"样式，播放时缓慢旋转动画，静音时边框变为红色。
- **FR-5: 海报/头像展示区** - 按钮列表顶部添加圆形海报展示区，使用视频封面图，直径约 48-56px，可可选点击时播放/暂停视频。
- **FR-6: 按钮顺序调整** - 调整按钮顺序更接近 React 版：海报 → 点赞 → 信息 → 删除 → 倍速 → 播放模式 → 字幕 → 唱片式静音 → 全屏 → 下一集。连播开关保留独立位置（在按钮列表下方或悬浮位置）。
- **FR-7: 状态同步** - 所有新增按钮的状态（播放模式、字幕选择、信息展开状态）与其他组件的相同状态保持一致，使用已有的 Provider。

## Non-Functional Requirements

- **NFR-1**: 所有按钮的点击交互应响应迅速（< 100ms 视觉反馈）
- **NFR-2**: 不引入新的状态管理 Provider，复用现有 Provider
- **NFR-3**: 代码风格与现有 `_buildRightActions` 保持一致，每个按钮方法约 10-30 行
- **NFR-4**: 非纯净模式下按钮完整显示，纯净模式下仍然显示简化按钮（连播开关 + 倍速）

## Constraints

- **Technical**: Flutter / Dart，基于 Riverpod 2.x Provider 状态管理
- **Dependencies**: 不引入新的 pub 包
- **Layout**: 按钮栏位于屏幕右侧，垂直列表布局，宽度约 96px

## Assumptions

- 现有的 `playbackLevelProvider`（int 值，0/1 为 DirectPlay，>= 2 为 Transcode）可以扩展以支持三种模式：0 = DirectPlay, 1 = Transcode, 2 = Fallback
- 现有的 `selectedSubtitleProvider`（String?，选中的字幕轨道 ID）可直接复用
- 信息按钮的 `isInfoExpanded` 状态可以用新的本地 state 或者复用现有的面板显示状态
- 唱片式静音按钮的旋转动画可以使用 Flutter 内置 `AnimatedRotation` 或 `RotationTransition`

## Acceptance Criteria

### AC-1: 播放模式切换按钮
- **Given**: 用户正在观看视频
- **When**: 用户点击右侧播放模式按钮
- **Then**: 播放模式在 DirectPlay → Transcode → Fallback → DirectPlay 之间循环切换
- **Then**: 按钮显示当前模式文本（Direct / Transcode / Fbk）
- **Then**: 非 DirectPlay 模式时，按钮背景变为靛蓝色
- **Verification**: `human-judgment`
- **Notes**: 切换后应重新初始化视频控制器以生效（如果需要）

### AC-2: 字幕控制按钮
- **Given**: 用户正在观看有字幕的视频
- **When**: 用户点击右侧字幕按钮
- **Then**: 弹出字幕选择菜单（与 VideoControls 中的相同）
- **When**: 用户选择了字幕
- **Then**: 按钮背景变为靛蓝色，显示当前选中的字幕语言缩写
- **Verification**: `human-judgment`
- **Notes**: 无字幕时按钮应显示禁用状态

### AC-3: 信息按钮
- **Given**: 用户正在观看视频，底部信息区默认收起
- **When**: 用户点击信息按钮
- **Then**: 底部视频详情面板展开，显示标题、简介、类型标签
- **Then**: 按钮高亮（如靛蓝色背景）
- **When**: 用户再次点击
- **Then**: 底部面板收起
- **Verification**: `human-judgment`

### AC-4: 唱片式静音按钮
- **Given**: 视频正在播放（未静音）
- **Then**: 按钮显示唱片样式，带有缓慢旋转动画
- **When**: 用户点击按钮
- **Then**: 视频静音，按钮边框/图标变为红色
- **When**: 用户再次点击
- **Then**: 取消静音，恢复正常样式
- **Verification**: `human-judgment`
- **Notes**: 这是一个 UI/UX 增强，功能逻辑与原静音按钮一致

### AC-5: 按钮顺序与布局
- **Given**: 视频在竖屏模式播放
- **Then**: 右侧按钮按从上到下顺序显示：
  1. 海报/头像（圆形）
  2. 点赞（Heart）
  3. 信息（Info）
  4. 删除（Trash2，红色）
  5. 倍速（显示当前倍速值）
  6. 播放模式（Direct/Transcode/Fbk）
  7. 字幕（Subtitles）
  8. 唱片式静音
  9. 全屏
  10. 下一集（仅剧集类视频）
- **Then**: 连播开关按钮在按钮列表下方（更靠近底部）独立显示
- **Verification**: `human-judgment`

### AC-6: 状态同步
- **Given**: 用户通过 VideoControls 控制栏选择了字幕
- **When**: 用户观察右侧操作栏的字幕按钮
- **Then**: 字幕按钮的高亮状态与 VideoControls 中的选择状态一致
- **Verification**: `human-judgment`

### AC-7: 非纯净模式与纯净模式
- **Given**: 用户未开启连播（非纯净模式）
- **Then**: 右侧操作栏显示完整按钮列表
- **When**: 用户开启连播（纯净模式）
- **Then**: 右侧操作栏只显示连播开关、倍速按钮（如已实现的纯净模式逻辑）
- **Verification**: `human-judgment`

## Open Questions

- [ ] **Q1**: 评论和分享按钮是保留（占位）还是直接移除？（建议：保留，未来填充功能）
- [ ] **Q2**: 播放模式切换后是否需要重新加载视频？React 版是切换后直接重建 video URL，需要确认 Flutter 版的实现方式。
- [ ] **Q3**: 信息按钮需要控制底部信息区的显示/隐藏，当前底部信息区是否已经有这个功能？如果有，需要复用；如果没有，需要新增相关状态管理。
