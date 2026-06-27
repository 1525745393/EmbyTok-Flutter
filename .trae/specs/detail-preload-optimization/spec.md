# 视频详情页优化 & 预加载优化 - 产品需求文档

## Overview
- **Summary**: 优化视频详情页的信息展示和相关推荐功能，同时优化视频预加载策略，提升用户浏览体验，对齐 EmbyX 的用户体验标准。
- **Purpose**: 让用户在详情页获取更丰富的视频信息，发现更多相关内容；通过优化预加载提升视频切换的流畅度，减少等待时间。
- **Target Users**: EmbyTok 的所有用户，尤其是深度使用视频流和详情页的用户。

## Goals
- 视频详情页增加「相关推荐」模块，帮助用户发现更多相似内容
- 详情页展示更丰富的元信息（导演、时长、清晰度等）
- 优化预加载策略，提升视频切换流畅度
- 预加载下一个视频的封面图，减少视觉等待

## Non-Goals (Out of Scope)
- 不重构详情页的整体布局架构
- 不修改视频播放器内核
- 不增加新的视频源/转码逻辑
- 不实现评论、社交功能

## Background & Context
- 当前详情页已有：海报、标题、评分、简介、演员、季集列表
- 当前已有预加载：基于 VideoPoolService 的相邻视频预加载
- EmbyX 有更丰富的详情页展示和更智能的预加载策略
- 已有 API 支持：`getSimilarItems` 可获取相似推荐

## Functional Requirements

### FR-1: 详情页 - 相关推荐模块
- 在详情页底部增加「相关推荐」横向滚动列表
- 点击推荐项可跳转到对应视频的详情页
- 支持电影/剧集等不同类型的推荐
- 加载状态：加载中显示骨架屏，加载失败不阻塞页面

### FR-2: 详情页 - 元信息增强
- 显示导演信息（如有）
- 显示视频时长（格式化显示）
- 显示视频清晰度/分辨率（如有）
- 优化信息布局，保持简洁美观

### FR-3: 预加载 - 封面图预加载
- 切换到当前视频时，预加载下一个视频的封面图
- 使用 CachedNetworkImage 的 precache 机制
- 减少滑动到下一个视频时的封面图即时显示

### FR-4: 预加载 - 策略优化
- 默认预加载下 1 个视频（当前实现），可配置
- 图片预加载：预加载下 2 个视频的封面图
- 在网络差时自动降级：减少预加载数量

## Non-Functional Requirements

- **NFR-1**: 详情页首屏加载时间不增加超过 200ms（相关推荐异步加载）
- **NFR-2**: 预加载不影响当前视频播放性能
- **NFR-3**: 内存使用合理，预加载缓存有上限控制
- **NFR-4**: 代码风格与现有项目保持一致

## Constraints
- **Technical**: Flutter + Riverpod + video_player
- **Business**: 对齐 EmbyX 的交互体验
- **Dependencies**: 依赖 Emby API（已有的 getSimilarItems）

## Assumptions
- `getSimilarItems` API 可正常返回相关推荐数据
- 用户希望在详情页发现更多相关内容
- 预加载下一个视频可以显著提升流畅感

## Acceptance Criteria

### AC-1: 详情页相关推荐
- **Given**: 用户打开任意视频详情页
- **When**: 页面滚动到底部
- **Then**: 显示「相关推荐」标题，下方是横向滚动的推荐卡片列表
- **Verification**: `human-judgment`

### AC-2: 推荐项点击跳转
- **Given**: 用户在详情页看到相关推荐
- **When**: 点击任意推荐卡片
- **Then**: 跳转到该视频的详情页
- **Verification**: `human-judgment`

### AC-3: 详情页元信息增强
- **Given**: 视频有导演、时长等信息
- **When**: 用户查看详情页
- **Then**: 能看到导演、时长等信息展示
- **Verification**: `human-judgment`

### AC-4: 封面图预加载
- **Given**: 用户正在观看第 N 个视频
- **When**: 滑动到第 N+1 个视频
- **Then**: 封面图（如果视频未加载完时显示）已缓存，无闪烁
- **Verification**: `human-judgment`

### AC-5: 预加载不影响当前播放
- **Given**: 预加载正在进行
- **When**: 当前视频播放
- **Then**: 当前视频播放流畅，无卡顿
- **Verification**: `human-judgment`

### AC-6: 内存控制
- **Given**: 快速滑动多个视频后
- **When**: 检查内存使用
- **Then**: 预加载缓存数量在合理范围内，不无限增长
- **Verification**: `programmatic`

## Open Questions
- [ ] 相关推荐显示数量上限是多少？（建议 10-12 条）
- [ ] 图片预加载数量？（建议预加载下 2 个）
