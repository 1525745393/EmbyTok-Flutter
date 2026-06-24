# 性能优化 v2 Spec

## Why
第一波性能优化已完成（局部重建、图片缓存、请求去重等），仍有几项用户感知明显的优化空间：搜索输入防抖、双向预加载、列表过滤缓存。

## What Changes
- 搜索输入防抖：搜索框输入时延迟 300ms 再发起请求，避免频繁网络调用
- 双向视频预加载：预加载上一条 + 下一条视频，向前/向后滑动都能秒开
- 过滤列表计算缓存：`filteredVideoListProvider` 使用 memoization，方向不变时不重复计算
- EmbytokService 单例化：避免多处新建实例，复用单例减少对象创建开销

## Impact
- Affected specs: 搜索体验、视频流滑动流畅度、列表性能
- Affected code: search_provider.dart、feed_view.dart、video_pool_service.dart、video_list_provider.dart、embbytok_service.dart

## ADDED Requirements

### Requirement: 搜索输入防抖
搜索输入框内容变化时，等待 300ms 防抖时间后再发起搜索请求。防抖期间如果输入继续变化，重置计时器。

#### Scenario: 用户快速输入搜索关键词
- **WHEN** 用户在搜索框中快速输入文字
- **THEN** 系统等待输入停止 300ms 后才发起搜索请求
- **AND** 防抖期间输入变化会重置计时器

#### Scenario: 用户停止输入
- **WHEN** 用户停止输入超过 300ms
- **THEN** 系统发起搜索请求并显示结果

### Requirement: 双向视频预加载
视频流预加载同时预加载上一条和下一条视频，支持向前滑动也能秒开。

#### Scenario: 向下滑动到新视频
- **WHEN** 用户滑动到第 N 条视频
- **THEN** 系统预加载第 N+1 条视频（下一条）
- **AND** 系统预加载第 N-1 条视频（上一条，如存在）

#### Scenario: 缓存清理策略
- **WHEN** 当前视频索引变化
- **THEN** 只保留当前条目前后各 1 条预加载会话，其余清理

### Requirement: 过滤列表计算缓存
`filteredVideoListProvider` 在方向模式不变、列表数据不变时返回缓存结果，避免重复遍历。

#### Scenario: 视频列表更新但方向模式不变
- **WHEN** 视频列表分页加载追加新数据
- **THEN** 过滤计算只对新增数据进行，不重复过滤已有数据

### Requirement: EmbytokService 单例化
将 EmbytokService 改为单例模式，全局复用同一个实例。

#### Scenario: 多处使用 EmbytokService
- **WHEN** 不同页面/Provider 都需要调用 Emby API
- **THEN** 它们使用同一个 EmbytokService 实例
- **AND** 认证信息通过 setupAuth 设置后全局生效
