# Tasks

- [x] Task 1: 修复 source 标签在 `/play/:itemId` 跳转链路丢失
  - [x] SubTask 1.1: `app.dart` 的 `_buildPlayback` 读取 `extra['source']` 并传给 `PlaybackShell`
  - [x] SubTask 1.2: `PlaybackShell` 新增 `source` 字段，构造 `VideoPageItem` 时透传
  - [x] SubTask 1.3: 验证从推荐页进入播放后，`recordWatch` 的 source 不再是默认 'feed'

- [x] Task 2: 修复反疲劳天数偏好未实际生效
  - [x] SubTask 2.1: `RecentlyShownItemIdsNotifier` 改为存储 `(itemId, shownAt)` 元组（持久化为 JSON）
  - [x] SubTask 2.2: 加载时按 `recommendAntiFatigueDays` 过滤过期项
  - [x] SubTask 2.3: `_shouldSkipItem` 中的反疲劳检查增加时间判定
  - [x] SubTask 2.4: 验证超过天数的 item 不再被屏蔽

- [x] Task 3: 优化冷启动判定逻辑
  - [x] SubTask 3.1: `isColdStart` 判定增加 Suggestions 数据源检查

- [x] Task 4: 优化 hasMore 分页判定
  - [x] SubTask 4.1: 区分"本轮去重后不足"和"服务器端无更多数据"两种情况

- [x] Task 5: 补齐 RecommendNotifier 集成测试
  - [x] SubTask 5.1: 新建 `test/providers/recommend_provider_test.dart`
  - [x] SubTask 5.2: 验证 `_loadPage`/`_mergeRoundRobin`/`_shouldSkipItem` 端到端行为

# Task Dependencies
- [Task 5] 依赖 [Task 1] 和 [Task 2] 完成（测试需覆盖修复后的行为）
- [Task 3] 和 [Task 4] 相互独立，可与 [Task 1]/[Task 2] 并行
