# 网格与视频流切换功能 - Product Requirement Document

## Overview
- **Summary**: 实现网格视图与视频流视图之间的无缝切换，确保点击网格视频后从该视频开始播放，从视频流切回网格时显示当前视频位置。
- **Purpose**: 提供类似 TikTok/抖音式的浏览体验，用户可以在网格封面墙和竖屏视频流之间自由切换，切换时保持上下文连续性。
- **Target Users**: Emby/Plex 媒体库用户，使用 EmbyTok 客户端浏览视频

## Goals
- 点击网格中的视频后，切换到视频流模式并从该视频开始播放
- 从视频流切回网格时，自动滚动到当前播放视频的位置
- 移除所有与上述功能冲突的逻辑，确保切换行为确定且可预期

## Non-Goals (Out of Scope)
- 不修改网格视图的 UI 布局和样式
- 不修改视频播放逻辑和播放器组件
- 不新增功能：应用启动时从 SharedPreferences 恢复网格滚动位置（与「从视频流切回网格时显示当前视频位置」优先级更高）
- 不修改媒体库选择、搜索、排序等其他功能

## Background & Context
- 当前项目已实现网格视图（PosterGridView）和视频流视图（FeedView）
- 已存在两套可能互相冲突的滚动/跳转逻辑共存，导致行为不确定：
  1. `_handleFeedToGridTransition` 中滚动到当前视频位置
  2. `_buildGridPageView` 中从 SharedPreferences 恢复滚动位置
- 用户明确要求：保留「切换时显示当前视频位置」，删除冲突逻辑
- 参考 EmbyX 的实现方式：通过 gridSelectedItemId 传递点击项、神之一手裁剪当前页

## Functional Requirements
- **FR-1**: 点击网格视频卡片 → 切换到视频流并从点击的视频开始播放
- **FR-2**: 从视频流切回网格 → 自动滚动到当前播放视频在网格中的位置
- **FR-3**: 移除与核心功能冲突的逻辑必须删除，确保行为唯一性

## Non-Functional Requirements
- **NFR-1**: 切换响应时间 < 300ms，无明显卡顿
- **NFR-2**: 滚动位置计算准确，当前视频应在可视区域内（优先显示在首行）
- **NFR-3**: 代码简洁，无冗余监听或重复逻辑

## Constraints
- **Technical**: Flutter + Riverpod 状态管理，保持现有架构
- **Business**: 保持现有 Emby/Plex API 调用方式不变
- **Dependencies**: 依赖现有 `videoListProvider`、`viewModeProvider`、`currentIndexProvider` 等

## Assumptions
- 用户在网格视图中点击的视频 ID 对应的 item 一定存在于 `videoListProvider.items` 中（如果不存在则跳转失败）
- 视频流当前播放的索引 `currentIndex` 与 `videoListProvider.items` 的索引一一对应
- 网格视图使用 3 列布局，宽高比 0.65，间距 8px，padding 8px
- 「神之一手」裁剪逻辑（150条/页）已在 videoListProvider 中正确执行

## Acceptance Criteria

### AC-1: 网格点击 → 视频流从该视频播放
- **Given**: 用户处于网格视图，视频列表已加载
- **When**: 用户点击第 N 个视频卡片
- **Then**: 视图切换到视频流模式，且当前播放的正是第 N 个视频
- **Verification**: `programmatic`
- **Notes**: 验证 currentIndex 应等于点击视频在 items 中的索引

### AC-2: 视频流切回网格 → 滚动到当前视频位置
- **Given**: 用户在视频流模式，当前播放第 M 个视频
- **When**: 用户切换到网格视图
- **Then**: 网格视图自动滚动，使第 M 个视频在可视区域内
- **Verification**: `programmatic`
- **Notes**: 优先显示在首行位置，使用平滑滚动动画 300ms

### AC-3: 无冲突逻辑
- **Given**: 从视频流切回网格时
- **When**: 执行滚动逻辑
- **Then**: 只执行「滚动到当前视频位置」逻辑，不执行从 SharedPreferences 恢复滚动位置逻辑
- **Verification**: `programmatic`
- **Notes**: 确保不会有两次滚动互相覆盖

### AC-4: 网格滚动位置持久化移除（仅保存，不再恢复
- **Given**: 用户在网格视图中手动滚动
- **When**: 滚动停止 500ms 后
- **Then**: 滚动位置仍然保存到 SharedPreferences（供将来使用）
- **Verification**: `programmatic`
- **Notes**: 只保留保存逻辑，删除恢复逻辑

## Open Questions
- 无
