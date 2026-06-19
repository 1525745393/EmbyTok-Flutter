# 右侧操作区图标化显示 - Product Requirement Document

## Overview
- **Summary**: 将右侧操作区（Right-side Action Panel）中所有按钮从"图标+文字"格式改为纯图标格式，移除文字标签，使界面更紧凑干净，减少视觉噪声。文字信息通过长按或点击的 SnackBar/Toast 提示保留可发现性。
- **Purpose**: 简化视觉 UI，减少重复信息，让右侧操作区更简洁，降低视觉干扰。
- **Target Users**: 所有使用 EmbyTok Flutter 应用观看视频的用户，特别是对简洁 UI 有偏好的用户。

## Goals
- 移除右侧操作区按钮下的文字标签（"点赞"、"信息"、"删除"、"全屏"、"下一集"）
- 移除圆形按钮内部的文字（倍速数字"1.0x"、播放模式"Direct/Transcode/Fbk"）
- 移除海报头像下方的演员名字
- 保留所有按钮的功能不变
- 状态变化通过图标/颜色等视觉元素来体现，保留可识别性

## Non-Goals (Out of Scope)
- 不改变按钮的点击交互行为（点击仍然执行原功能）
- 不改变顶部和底部控制栏的其他 UI 元素
- 不修改中央播放按钮、倍速徽章、底部信息条等其他区域
- 不改变任何 API 调用或业务逻辑
- 不新增功能（如 tooltip、长按菜单等，仅保留 SnackBar 作为状态提示）

## Background & Context
- 现有代码位置: `frontend/lib/widgets/video_page_item.dart`
- 右侧操作区当前有 10+ 个按钮，分为三类：
  1. **_PressableActionButton**: 图标 + 文字标签（点赞、信息、删除、全屏、下一集）
  2. **圆形按钮**: 显示文字状态（倍速按钮"1.0x"、播放模式按钮"Direct/Transcode/Fbk"）
  3. **海报头像**: 演员头像 + 名字（短名）
- 前几次提交已对右侧操作区做了响应式重构（`fcd97b2`）和尺寸缩小（`9708fed`），此次继续在视觉上进行简化

## Functional Requirements
- **FR-1**: `_PressableActionButton` 组件不再显示文字 `label`，只显示图标
- **FR-2**: 倍速按钮 (`_buildSpeedControlButton`) 不再在圆形按钮内部显示倍速数字（如 "1.0x"），改为：倍速为 1.0 时不高亮，>1.0 时高亮（已有实现），状态通过图标或颜色区分
- **FR-3**: 播放模式按钮 (`_buildPlayModeButton`) 不再在圆形按钮内部显示 "Direct/Transcode/Fbk" 文字，改为使用图标区分：DirectPlay=默认图标/颜色，Transcode=高亮紫色/转换图标，Fallback=另一种颜色/图标
- **FR-4**: 海报头像 (`_buildPosterAvatar`) 不再显示下方的演员名字，仅显示圆形头像 + "+" 收藏按钮
- **FR-5**: 倍速状态徽章 (`_buildSpeedBadge`) 保持不变（显示在视频画面顶部中央，不属于按钮本身的文字）
- **FR-6**: 所有按钮的点击回调保持不变
- **FR-7**: SnackBar 状态提示保持不变（如连播模式开启/关闭提示）

## Non-Functional Requirements
- **NFR-1**: 所有按钮高度应统一或协调，不再因为文字标签产生不同高度
- **NFR-2**: 整体视觉空间减少约 30-40%（移除文字后节省竖向空间）
- **NFR-3**: 可识别性：每个按钮的功能应能通过图标+颜色被常用用户识别
- **NFR-4**: 代码改动应保持最小化，仅修改 UI 展示部分，不触碰业务逻辑

## Constraints
- **Technical**: Flutter/Dart，项目代码位于 `frontend/lib/widgets/video_page_item.dart`
- **Dependencies**: Riverpod providers（`isMutedProvider`, `playbackLevelProvider`, `selectedSubtitleProvider`, `isAutoPlayProvider` 等）
- **Platform**: iOS/Android/桌面/Web 多端，须保持一致行为

## Assumptions
- 常用用户对图标含义已有认知（如 ❤️=点赞，ℹ️=信息，🗑=删除等）
- 新用户可以通过点击触发行为来学习按钮功能（功能 discoverability 通过实际使用获得）
- 倍速、播放模式等状态变化有其他视觉提示（如颜色高亮、顶部倍速徽章），不再依赖按钮内部文字

## Acceptance Criteria

### AC-1: 通用按钮只显示图标
- **Given**: 视频正常播放，右侧操作区可见
- **When**: 查看"点赞"、"信息"、"删除"、"全屏"、"下一集"按钮
- **Then**: 这些按钮仅显示图标，不显示下方文字标签
- **Verification**: `human-judgment`
- **Notes**: 图标颜色保持不变（点赞=红色、删除=红色、其他=白色）

### AC-2: 倍速按钮不显示数字文字
- **Given**: 视频正常播放，倍速为 1.0x 或其他倍速
- **When**: 查看倍速圆形按钮
- **Then**: 圆形按钮内部无"1.0x"/"2.0x"等数字文字
- **And**: 倍速 >1.0 时按钮保持橙色高亮状态
- **Verification**: `human-judgment`
- **Notes**: 顶部倍速徽章（显示"1.5x"+闪电图标）保持不变，作为倍速状态的主提示

### AC-3: 播放模式按钮不显示文字
- **Given**: 视频正常播放，播放模式为 Direct、Transcode 或 Fallback
- **When**: 查看播放模式圆形按钮
- **Then**: 圆形按钮内部无"Direct"/"Transcode"/"Fbk"等文字
- **And**: 通过不同图标或颜色区分状态（Direct=默认灰、Transcode=紫色高亮+🎬、Fallback=黄色/另一种颜色+⚠️）
- **Verification**: `human-judgment`
- **Notes**: 状态切换时通过 SnackBar 提示"播放模式: Direct/Transcode/Fallback"，提高可识别性

### AC-4: 海报头像不显示演员名字
- **Given**: 视频有演员信息（people 列表非空）
- **When**: 查看海报头像区
- **Then**: 仅显示圆形演员头像 + "+" 收藏按钮，不显示下方演员名字
- **And**: 头像点击仍可跳转到演员详情页，"+" 点击仍可收藏
- **Verification**: `human-judgment`
- **Notes**: 如果无演员信息，回退显示视频封面的逻辑保持不变

### AC-5: 点击行为和状态不变
- **Given**: 任何按钮处于可见状态
- **When**: 点击任意按钮
- **Then**: 触发的功能与修改前完全相同（点赞切换/信息面板/删除确认/全屏切换/倍速面板/播放模式切换/字幕选择/静音切换/下一集/连播切换）
- **Verification**: `human-judgment`

### AC-6: 按钮间距和布局保持紧凑合理
- **Given**: 右侧操作区所有按钮均已图标化
- **When**: 在竖屏手机、平板、桌面等不同尺寸下查看
- **Then**: 所有按钮排列均匀，间距合理，不拥挤也不过散
- **And**: 按钮容器宽度保持 80px（响应式逻辑不变），因移除文字后垂直空间可以略微优化
- **Verification**: `human-judgment`

### AC-7: 代码仅涉及 UI 展示，无业务逻辑变化
- **Given**: 完成修改
- **When**: 审查 diff 内容
- **Then**: 改动仅涉及 widget 构建部分，不修改任何 API 调用、状态管理逻辑
- **Verification**: `programmatic`
- **Notes**: `git diff --stat` 应仅显示 `video_page_item.dart` 一个文件的修改

## Open Questions
- [x] 倍速按钮移除文字后，倍速状态靠什么提示？→ 顶部倍速徽章已存在（_buildSpeedBadge），可作为主提示
- [x] 播放模式按钮移除文字后，如何区分三种模式？→ 通过图标（🎬/转换图标）和颜色（默认紫/高亮紫）来区分，第一次切换时显示 SnackBar
- [x] 海报头像移除演员名字后，是否影响识别演员？→ 演员头像点击仍可跳转到详情页查看完整信息
