# 推荐系统审查与修复 Spec

## Why
推荐系统是 EmbyTok 的核心体验差异化能力，但代码审查发现 2 个 P0 级数据断链问题导致核心门控策略实际失效：source 标签在播放跳转链路丢失（source 权重永远为默认值）、反疲劳天数偏好未被实际使用（已展示 item 永久屏蔽）。这些问题不会让推荐"不工作"，但会让"基于完播率的智能门控"这个核心卖点大打折扣。

## What Changes
- 修复 source 标签在 `/play/:itemId` 跳转链路丢失问题，使完播率数据正确标记来源
- 修复反疲劳天数偏好未实际生效问题，使 `recentlyShownItemIds` 按时间过期
- 优化冷启动判定逻辑，避免误判老用户为冷启动
- 优化 `hasMore` 判定，避免因去重后不足 30 条而提前终止加载
- 补齐 `RecommendNotifier` 集成测试覆盖

## Impact
- Affected specs: 无（推荐系统此前无独立 spec）
- Affected code:
  - `frontend/lib/app.dart`（`_buildPlayback` 读取 source）
  - `frontend/lib/widgets/video_page_item.dart`（`PlaybackShell` 加 source 字段）
  - `frontend/lib/providers/app_preferences_providers.dart`（`RecentlyShownItemIdsNotifier` 改为带时间戳）
  - `frontend/lib/providers/recommend_provider.dart`（冷启动判定 + hasMore + _shouldSkipItem 时间过滤）
  - `frontend/test/providers/recommend_provider_test.dart`（新增集成测试）

## ADDED Requirements

### Requirement: Source 标签端到端透传
推荐系统 SHALL 在用户从推荐页点击视频进入播放页时，将 `source` 标签（nextUp/resume/suggestions/similar/recommendations）透传到 `VideoPageItem`，使完播率记录能正确标记推荐来源。

#### Scenario: 从推荐页进入播放
- **WHEN** 用户在推荐页点击视频卡片
- **AND** 通过 `/play/:itemId` 路由跳转到 `PlaybackShell`
- **THEN** `PlaybackShell` 接收到 `source` 参数
- **AND** 构造 `VideoPageItem` 时透传 `source`
- **AND** 视频完播/暂停时 `recordWatch` 记录的 `source` 字段与推荐来源一致

### Requirement: 反疲劳时间过期
推荐系统 SHALL 按用户配置的 `recommendAntiFatigueDays` 天数过滤已展示记录，超过天数的 item 不再被屏蔽。

#### Scenario: 反疲劳天数生效
- **WHEN** 用户设置反疲劳天数为 7 天
- **AND** 某个 item 在 8 天前被展示过
- **THEN** 该 item 不在 `recentlyShownItemIds` 过滤范围内
- **AND** 可以再次出现在推荐结果中

## MODIFIED Requirements

### Requirement: 冷启动判定
推荐系统 SHALL 在判定冷启动时同时检查 NextUp、Resume 和 Suggestions 三个数据源是否都为空，避免仅有 Suggestions 数据的老用户被误判为冷启动。

### Requirement: hasMore 分页判定
推荐系统 SHALL 在 `hasMore` 判定时区分"本轮去重后不足"和"服务器端无更多数据"两种情况，仅在后者为真时终止分页。

## REMOVED Requirements
无
