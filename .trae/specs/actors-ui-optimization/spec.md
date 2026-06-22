# 演员界面优化建议 - 产品需求文档

## Overview
- **Summary**: 优化演员列表页面，添加分类显示、搜索、分页加载等功能，提升用户体验
- **Purpose**: 解决当前演员界面功能单一的问题，提供更好的演员浏览和管理体验
- **Target Users**: EmbyTok 应用用户

## Why
当前演员界面虽然基本功能已实现（显示演员列表、关注功能），但存在以下问题：
- 所有演员混在一起显示，无法快速找到已关注的演员
- 没有搜索功能，演员多时难以浏览
- 没有分页加载，大数据量时性能差
- 缺少分类筛选功能

## What Changes
- **增强分类显示**：区分"已关注"和"未关注"两个 Tab
- **添加搜索功能**：支持按演员名称搜索
- **添加分页加载**：支持下拉刷新和上拉加载更多
- **添加类型筛选**：支持按演员/导演/编剧类型筛选
- **优化布局体验**：改进卡片布局和视觉效果

## Impact
- Affected specs: actors-list-page
- Affected code: `/workspace/frontend/lib/views/actors_view.dart`

## ADDED Requirements

### Requirement: Tab 分类显示
系统 SHALL 提供"已关注"和"未关注"两个 Tab，用于分类显示演员

#### Scenario: 已关注 Tab
- **WHEN** 用户点击"已关注" Tab
- **THEN** 只显示已关注的演员列表

#### Scenario: 未关注 Tab
- **WHEN** 用户点击"未关注" Tab
- **THEN** 只显示未关注的演员列表

#### Scenario: 全部 Tab
- **WHEN** 用户点击"全部" Tab
- **THEN** 显示所有演员

### Requirement: 演员搜索
系统 SHALL 支持按演员名称搜索

#### Scenario: 搜索成功
- **WHEN** 用户输入演员名称
- **THEN** 显示匹配搜索条件的演员列表

#### Scenario: 搜索无结果
- **WHEN** 用户输入不存在的演员名称
- **THEN** 显示"未找到相关演员"提示

### Requirement: 分页加载
系统 SHALL 支持分页加载演员列表

#### Scenario: 下拉刷新
- **WHEN** 用户下拉刷新列表
- **THEN** 重新加载演员列表

#### Scenario: 上拉加载更多
- **WHEN** 用户滚动到列表底部
- **THEN** 加载更多演员

### Requirement: 类型筛选
系统 SHALL 支持按类型筛选演员

#### Scenario: 筛选演员
- **WHEN** 用户选择"演员"类型
- **THEN** 显示所有演员

#### Scenario: 筛选导演
- **WHEN** 用户选择"导演"类型
- **THEN** 显示所有导演

### Requirement: 关注数量统计
系统 SHALL 在 Tab 上显示关注数量

#### Scenario: 显示数量
- **WHEN** 演员列表加载完成
- **THEN** 在"已关注" Tab 上显示关注人数

## MODIFIED Requirements

### Requirement: 演员卡片优化
演员卡片 SHALL 优化显示效果：
- 头像使用圆形裁剪
- 关注按钮点击区域增大
- 添加演员出演作品数量显示

## REMOVED Requirements
- 无

## Acceptance Criteria

### AC-1: Tab 分类显示
- **Given**: 用户进入演员列表页面
- **When**: 查看页面
- **Then**: 看到"全部"、"已关注"、"未关注"三个 Tab
- **Verification**: `human-judgment`

### AC-2: Tab 切换功能
- **Given**: 用户在演员列表页面
- **When**: 点击不同 Tab
- **Then**: 显示对应分类的演员列表
- **Verification**: `programmatic`

### AC-3: 搜索功能
- **Given**: 用户在演员列表页面
- **When**: 在搜索框输入内容
- **Then**: 实时显示搜索结果
- **Verification**: `programmatic`

### AC-4: 分页加载
- **Given**: 用户在演员列表页面
- **When**: 滚动到列表底部
- **Then**: 自动加载更多演员
- **Verification**: `programmatic`

### AC-5: 类型筛选
- **Given**: 用户在演员列表页面
- **When**: 选择类型筛选器
- **Then**: 显示对应类型的演员
- **Verification**: `programmatic`

### AC-6: 关注数量显示
- **Given**: 用户在演员列表页面
- **When**: 查看"已关注" Tab
- **Then**: 显示关注人数（如"已关注(12)"）
- **Verification**: `human-judgment`

## Open Questions
- [ ] 是否需要显示每个演员的代表作/出演作品数量？
- [ ] 是否需要按关注时间排序已关注列表？
- [ ] 搜索是否需要防抖处理？
