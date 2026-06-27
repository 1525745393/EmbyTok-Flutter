# EmbyX 功能对齐验证 - Product Requirement Document

## Overview
- **Summary**: 验证并确保 EmbyTok 的媒体库选择、网格视图与视频流切换功能与 EmbyX 项目的实现方式完全一致，包括交互逻辑、状态管理和用户体验。
- **Purpose**: 确保核心浏览体验与 EmbyX 保持一致，为用户提供熟悉且可靠的操作方式。
- **Target Users**: Emby/Plex 媒体库用户，使用 EmbyTok 客户端浏览视频

## Goals
- 媒体库选择功能与 EmbyX 行为一致
- 点击网格视频后，切换到视频流并从该视频开始播放（对齐 EmbyX）
- 从视频流切回网格时，自动滚动到当前播放视频的位置（对齐 EmbyX）
- 「神之一手」裁剪逻辑与 EmbyX 一致
- 统一的视图切换入口，无冲突逻辑

## Non-Goals (Out of Scope)
- 不修改视频播放逻辑和播放器组件
- 不修改搜索、排序等其他网格功能
- 不修改 UI 样式（除非影响功能对齐）
- 不修改 Emby/Plex API 调用方式

## Background & Context
- 当前 main 分支已实现大部分功能，需要验证是否与 EmbyX 完全一致
- 之前的 trae/agent-TdlKkL 分支因历史不相关无法直接合并
- 需要系统性地检查每个功能点，确保与 EmbyX 的实现方式一致

## Functional Requirements
- **FR-1**: 媒体库选择器：2列网格布局、收藏夹入口、单选模式、点击即切换并关闭
- **FR-2**: 网格视图（封面墙）：3列布局、显示媒体库名/总数/换一批/分页
- **FR-3**: 网格→视频流：点击网格视频 → 设置 gridSelectedItemId → 切换 viewMode → viewModeProvider 监听器统一处理跳转
- **FR-4**: 视频流→网格：触发「神之一手」裁剪 → 滚动到当前视频位置（垂直居中）
- **FR-5**: 「神之一手」：从 feed 切到 grid 时，根据 currentIndex 计算页码，裁剪 items 到当前页（150条）
- **FR-6**: 滚动位置持久化：网格滚动位置保存到 SharedPreferences，但不从 SharedPreferences 恢复（只存不恢复）

## Non-Functional Requirements
- **NFR-1**: 切换响应时间 < 300ms，无明显卡顿
- **NFR-2**: 滚动位置计算准确，当前视频在可视区域内垂直居中
- **NFR-3**: 代码简洁，无冗余监听或重复逻辑
- **NFR-4**: 完全对齐 EmbyX 的切换逻辑和时序

## Constraints
- **Technical**: Flutter + Riverpod 状态管理，保持现有架构
- **Business**: 保持现有 Emby/Plex API 调用方式不变
- **Dependencies**: 依赖现有 videoListProvider、viewModeProvider、currentIndexProvider 等

## Assumptions
- 「神之一手」裁剪逻辑已在 videoListProvider 中正确执行
- 网格视图使用 3 列布局，宽高比 0.65，间距 8px
- gridStartIndex 正确反映了当前页在完整列表中的起始偏移
- 用户点击的视频 ID 对应的 item 一定存在于 videoListProvider.items 中

## Acceptance Criteria

### AC-1: 媒体库选择器行为正确
- **Given**: 用户点击媒体库按钮
- **When**: 弹出媒体库选择器
- **Then**: 显示2列网格布局，包含收藏夹入口和媒体库列表，单选模式，点击即切换并关闭弹窗
- **Verification**: `human-judgment`
- **Notes**: 与 EmbyX 的媒体库选择器交互一致

### AC-2: 网格点击 → 视频流从该视频播放
- **Given**: 用户处于网格视图，视频列表已加载
- **When**: 用户点击第 N 个视频卡片
- **Then**: 视图切换到视频流模式，且当前播放的正是第 N 个视频
- **Verification**: `programmatic`
- **Notes**: 验证 currentIndex 应等于点击视频在 items 中的索引

### AC-3: 视频流切回网格 → 滚动到当前视频位置（垂直居中）
- **Given**: 用户在视频流模式，当前播放第 M 个视频
- **When**: 用户切换到网格视图
- **Then**: 网格视图自动滚动，使第 M 个视频在可视区域内垂直居中显示
- **Verification**: `programmatic`
- **Notes**: 使用 animateTo 平滑滚动，对齐 EmbyX 的垂直居中逻辑

### AC-4: 「神之一手」裁剪正确执行
- **Given**: 从视频流切到网格时
- **When**: 执行裁剪逻辑
- **Then**: 根据 currentIndex 计算页码，裁剪 items 到当前页（150条），gridStartIndex 正确设置
- **Verification**: `programmatic`
- **Notes**: 与 EmbyX 的 PAGE_SIZE = 150 一致

### AC-5: 统一切换入口，无冲突逻辑
- **Given**: 视图切换时
- **When**: 执行切换逻辑
- **Then**: 只通过 viewModeProvider 监听器统一处理，不通过独立的 gridSelectedItemIdProvider 监听器
- **Verification**: `programmatic`
- **Notes**: 确保不会有两次跳转互相覆盖

### AC-6: 网格滚动只滚动到当前视频，不从 SharedPreferences 恢复
- **Given**: 从视频流切回网格时
- **When**: 执行滚动逻辑
- **Then**: 只执行「滚动到当前视频位置」逻辑，不执行从 SharedPreferences 恢复滚动位置逻辑
- **Verification**: `programmatic`
- **Notes**: 保留保存逻辑（只存不恢复）

## Open Questions
- [ ] 是否还有其他功能需要与 EmbyX 对齐？
- [ ] 媒体库选择是否需要支持多选？（当前为单选模式）
