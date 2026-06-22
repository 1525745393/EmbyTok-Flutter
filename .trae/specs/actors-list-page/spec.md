# EmbyTok 演员列表页面 - 产品需求文档

## Overview
- **Summary**: 在底部导航栏添加演员按钮，创建演员列表页面显示 Emby 服务器上的所有演员，并区分已关注和未关注状态
- **Purpose**: 让用户能够浏览和管理关注的演员，增强用户体验
- **Target Users**: EmbyTok 应用用户

## Goals
- 在底部导航栏添加演员按钮
- 创建演员列表页面，展示所有演员
- 支持关注/取消关注演员功能
- 区分显示已关注和未关注的演员

## Non-Goals (Out of Scope)
- 演员搜索功能（后续迭代）
- 演员分类筛选（后续迭代）
- 演员详情页的其他扩展功能

## Background & Context
- 当前底部导航栏有三个标签：首页、收藏、设置
- 演员详情页 `PersonDetailView` 已存在
- `EmbytokService.getPeople()` 可获取所有演员
- `EmbytokService.getFavoritePeople()` 可获取收藏的演员

## Functional Requirements
- **FR-1**: 在底部导航栏添加演员按钮，点击跳转到演员列表页面
- **FR-2**: 演员列表页面显示 Emby 服务器上的所有演员
- **FR-3**: 支持关注/取消关注演员
- **FR-4**: 区分显示已关注和未关注的演员

## Non-Functional Requirements
- **NFR-1**: 演员列表加载性能优化，支持分页加载
- **NFR-2**: 关注状态实时同步

## Constraints
- **Technical**: Flutter + GoRouter + Riverpod
- **Dependencies**: Emby API `/Persons` 和 `/Users/{userId}/FavoriteItems`

## Assumptions
- 用户已登录 Emby 服务器
- Emby 服务器支持 `/Persons` 端点

## Acceptance Criteria

### AC-1: 底部导航栏添加演员按钮
- **Given**: 用户在首页
- **When**: 查看底部导航栏
- **Then**: 看到演员按钮（位于收藏和设置之间）
- **Verification**: `human-judgment`

### AC-2: 演员按钮点击跳转
- **Given**: 底部导航栏显示演员按钮
- **When**: 点击演员按钮
- **Then**: 跳转到演员列表页面
- **Verification**: `programmatic`

### AC-3: 演员列表页面显示所有演员
- **Given**: 用户进入演员列表页面
- **When**: 页面加载完成
- **Then**: 显示 Emby 服务器上的所有演员头像和姓名
- **Verification**: `human-judgment`

### AC-4: 演员关注状态显示
- **Given**: 演员列表页面加载完成
- **When**: 查看演员卡片
- **Then**: 已关注的演员显示已关注标记，未关注的显示关注按钮
- **Verification**: `human-judgment`

### AC-5: 关注/取消关注功能
- **Given**: 演员列表页面显示演员
- **When**: 点击关注/取消关注按钮
- **Then**: 演员的关注状态切换，UI 即时更新
- **Verification**: `programmatic`

## Open Questions
- [ ] 是否需要演员列表的搜索功能？
- [ ] 是否需要按类型筛选（演员/导演/编剧）？