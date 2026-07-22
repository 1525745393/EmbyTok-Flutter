# 观看统计 Bug 修复 - Product Requirement Document

## Overview
- **Summary**: 修复观看统计（完播率统计）模块中发现的 3 个中等严重程度 Bug，包括数据准确性问题和 Riverpod 规范违反问题。
- **Purpose**: 确保完播率统计数据准确可靠，避免非当前页误记录导致推荐系统误判；确保用户切换时数据隔离；确保代码符合 Riverpod 最佳实践。
- **Target Users**: 所有使用观看统计和推荐系统的用户

## Goals
- Goal 1: 修复 dispose 中调用 ref.read() 的 Riverpod 规范违反问题
- Goal 2: 修复非当前页也记录观看统计导致数据失真问题
- Goal 3: 修复用户切换后内存 state 未重置导致数据串用户问题

## Non-Goals (Out of Scope)
- 不重构完播率统计的整体架构
- 不修改推荐系统的门控逻辑
- 不增加新的统计指标
- 不处理低严重程度问题（copyWith 全量重算、注释不一致、精度问题等）

## Background & Context
- 完播率统计（watch_stats_provider）是推荐系统门控的核心数据来源
- 统计数据不准确会直接影响推荐质量（黑名单误判、源权重失真）
- 当前存在 3 个中等严重程度问题：
  1. dispose 中 ref.read() 违反 Riverpod 规范，可能导致异常
  2. 非当前页（预加载页）也记录统计，拉低完播率并误触黑名单
  3. 用户切换后内存 state 不清空，数据串用户

## Functional Requirements
- **FR-1**: 观看统计记录必须在 deactivate() 中调用，而非 dispose() 中
- **FR-2**: 只有当前页（isCurrentPage=true）的视频才记录观看统计
- **FR-3**: 用户登录/登出/切换时，watchStatsProvider 的内存 state 必须重置并重新加载对应用户数据
- **FR-4**: 清除统计时必须清除内存 state 和本地存储两部分

## Non-Functional Requirements
- **NFR-1**: 不得引入新的 Riverpod 规范违反
- **NFR-2**: 统计记录延迟 < 10ms（同步操作）
- **NFR-3**: 用户切换后 state 重置在 1 帧内完成

## Constraints
- **Technical**: Flutter + Riverpod，遵循项目，必须符合 Riverpod 最佳实践
- **Business**: 向后兼容，不破坏现有数据格式
- **Dependencies**: authProvider、watchStatsProvider

## Assumptions
- 假设 deactivate() 在 widget 生命周期中先于 dispose() 调用（Flutter 规范）
- 假设用户切换时 authProvider 状态会变化
- 假设现有 SharedPreferences 中已有多用户数据隔离（按 userId 分键）

## Acceptance Criteria

### AC-1: 统计记录不违反 Riverpod 规范
- **Given**: VideoPageItem 被销毁
- **When**: 触发统计记录
- **Then**: 记录操作在 deactivate() 中通过 ref.read() 执行，而非在 dispose() 中
- **Verification**: `programmatic`
- **Notes**: dispose() 中不应有任何 ref.read() 调用

### AC-2: 非当前页不记录统计
- **Given**: PageView 中有多个页面，仅当前页 isCurrentPage=true
- **When**: 非当前页的 VideoPageItem 被销毁
- **Then**: 不调用 watchStatsProvider.recordWatch()
- **Verification**: `programmatic`

### AC-3: 用户登出后统计 state 重置
- **Given**: 用户 A 已登录且有完播率记录
- **When**: 用户 A 登出
- **Then**: watchStatsProvider 的 state 变为空状态（records 空，totalCount=0）
- **Verification**: `programmatic`

### AC-4: 用户切换后加载新用户数据
- **Given**: 用户 A 已登出
- **When**: 用户 B 登录
- **Then**: watchStatsProvider 加载用户 B 的完播率记录
- **Verification**: `programmatic`

### AC-5: 同一用户重新登录不重复初始化
- **Given**: 用户 A 登出后重新登录
- **When**: 重新初始化
- **Then**: 正确加载用户 A 的记录，不会报错
- **Verification**: `programmatic`

### AC-6: 代码可读性
- **Given**: 修复后的代码
- **When**: 审查
- **Then**: 符合项目代码规范，逻辑清晰
- **Verification**: `human-judgment`

## Open Questions
- 无
