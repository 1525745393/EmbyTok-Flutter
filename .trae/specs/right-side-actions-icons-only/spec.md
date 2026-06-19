# 右侧操作区图标化显示（保留演员名字） - Product Requirement Document

## Overview
- **Summary**: 将右侧操作区（Right-side Action Panel）中所有功能按钮从"图标+文字"格式改为纯图标格式，移除文字标签，使界面更紧凑干净。演员头像下方的演员名字保持显示，便于识别演员身份。
- **Purpose**: 简化视觉 UI，减少重复信息，让右侧操作区更简洁，降低视觉干扰，同时保留演员名字的可读性。
- **Target Users**: 所有使用 EmbyTok Flutter 应用观看视频的用户。

## Goals
- 移除右侧操作区通用按钮下的文字标签（"点赞"、"信息"、"删除"、"全屏"、"下一集"）
- 圆形按钮内部不显示文字（倍速按钮、播放模式按钮）
- **保留**演员头像下方的演员名字显示（不修改）
- 保留所有按钮的功能不变
- 状态变化通过图标/颜色等视觉元素来体现

## Non-Goals (Out of Scope)
- 不改变按钮的点击交互行为（点击仍然执行原功能）
- 不改变顶部和底部控制栏的其他 UI 元素
- 不修改中央播放按钮、倍速徽章、底部信息条等其他区域
- 不修改演员头像区域的布局和展示逻辑（保留演员名字）
- 不改变任何 API 调用或业务逻辑

## Background & Context
- 现有代码位置: `frontend/lib/widgets/video_page_item.dart`
- 右侧操作区当前有以下按钮组件：
  1. **演员头像区**: 头像 + 演员名字（需保留）
  2. **_PressableActionButton**: 通用按钮（点赞、信息、删除、全屏、下一集）
  3. **圆形按钮组**: 倍速、播放模式、字幕、唱片静音、连播等
- 历史提交：已完成响应式重构（`fcd97b2`）和尺寸缩小（`9708fed`），此次继续进行图标化简化

## Functional Requirements
- **FR-1**: `_PressableActionButton` 组件仅显示图标，不再渲染文字 `label`
- **FR-2**: 倍速按钮 (`_buildSpeedControlButton`) 内部不显示数字文字，通过图标 + 颜色区分状态
- **FR-3**: 播放模式按钮 (`_buildPlayModeButton`) 内部不显示文字，通过图标 + 颜色区分三种模式
- **FR-4**: **演员头像区域 (`_buildPosterAvatar`) 保持不变**，继续显示头像 + 收藏按钮 + 演员名字
- **FR-5**: 顶部倍速状态徽章 (`_buildSpeedBadge`) 保持不变，作为倍速状态的主提示
- **FR-6**: 所有按钮的点击回调和业务逻辑保持不变
- **FR-7**: 连播/删除等 SnackBar 状态提示保持不变

## Non-Functional Requirements
- **NFR-1**: 按钮视觉统一，不再因为文字标签产生不同尺寸
- **NFR-2**: 可识别性：每个按钮的功能应能通过图标+颜色被常用用户识别
- **NFR-3**: 演员名字保持易读，与演员头像的视觉关联清晰
- **NFR-4**: 代码改动最小化，仅修改 UI 展示部分，不触碰业务逻辑

## Constraints
- **Technical**: Flutter/Dart，代码位于 `frontend/lib/widgets/video_page_item.dart`
- **Dependencies**: Riverpod providers（`isMutedProvider`, `playbackLevelProvider`, `selectedSubtitleProvider`, `isAutoPlayProvider`, `favoritesProvider` 等）
- **Platform**: iOS/Android/桌面/Web 多端一致

## Assumptions
- 用户对常用图标有认知（❤️=点赞, ℹ️=信息, 🗑=删除, ⛶=全屏, ▶=下一集）
- 倍速、播放模式等状态变化有其他视觉提示（颜色高亮、顶部倍速徽章）
- 演员名字对识别演员身份很重要，因此保留

## Acceptance Criteria

### AC-1: 通用按钮只显示图标
- **Given**: 视频正常播放，右侧操作区可见
- **When**: 查看"点赞"、"信息"、"删除"、"全屏"、"下一集"按钮
- **Then**: 这些按钮仅显示图标，不显示下方文字标签
- **Verification**: `human-judgment`
- **Notes**: 图标颜色保持不变（点赞=红色、删除=红色、其他=白色）

### AC-2: 倍速按钮不显示数字文字
- **Given**: 视频正常播放，倍速为任意值
- **When**: 查看倍速圆形按钮
- **Then**: 圆形按钮内部无"1.0x"/"2.0x"等数字文字，仅显示图标
- **And**: 倍速 >1.0 时按钮保持橙色高亮状态
- **Verification**: `human-judgment`
- **Notes**: 顶部倍速徽章（闪电+数字）保持不变作为状态主提示

### AC-3: 播放模式按钮不显示文字
- **Given**: 视频正常播放，播放模式为 Direct/Transcode/Fallback 之一
- **When**: 查看播放模式圆形按钮
- **Then**: 圆形按钮内部无"Direct"/"Transcode"/"Fbk"等文字，仅显示图标+颜色区分
- **Verification**: `human-judgment`

### AC-4: 演员头像下方名字保持显示
- **Given**: 视频有演员信息（people 列表非空）
- **When**: 查看演员头像区
- **Then**: 继续显示圆形头像 + "+" 收藏按钮 + **演员名字**（短名），与修改前一致
- **And**: 无演员信息时，回退显示视频封面的逻辑保持不变
- **Verification**: `human-judgment`

### AC-5: 所有按钮点击行为与功能不变
- **Given**: 任何按钮处于可见状态
- **When**: 点击任意按钮
- **Then**: 触发的功能与修改前完全相同
- **Verification**: `human-judgment`

### AC-6: 按钮布局紧凑合理
- **Given**: 右侧操作区所有按钮均已图标化
- **When**: 在不同屏幕尺寸下查看
- **Then**: 按钮排列均匀，间距合理，响应式逻辑不变
- **Verification**: `human-judgment`

### AC-7: 代码仅涉及 UI 展示，无业务逻辑变化
- **Given**: 完成修改
- **When**: 审查 diff 内容
- **Then**: 改动仅涉及 widget 构建部分，不修改任何 API 调用、状态管理逻辑
- **Verification**: `programmatic`
- **Notes**: 改动应仅涉及 `video_page_item.dart` 文件

## Open Questions
- [x] 倍速状态靠什么提示？→ 顶部倍速徽章已存在（`_buildSpeedBadge`）
- [x] 播放模式如何区分？→ 通过图标+颜色区分，已实现
- [x] 演员名字是否保留？→ **保留，不修改**
