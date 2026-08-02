# Checklist

## P0 修复验证
- [x] 从推荐页（追剧/续看/为你推荐/相似/高分任一标签）点击视频进入播放页，完播后 `recordWatch` 的 source 字段与推荐来源一致（非 'feed'）
- [x] `PlaybackShell` 构造函数包含 `source` 参数且透传到 `VideoPageItem`
- [x] `app.dart` 的 `_buildPlayback` 从 `extra` 读取 `source` 并传递
- [x] `RecentlyShownItemIdsNotifier` 存储带时间戳的记录（非纯 StringList）
- [x] 设置反疲劳天数为 7 天后，8 天前展示过的 item 不再被屏蔽
- [x] `recommendAntiFatigueDays` 偏好变更后，已展示记录按新天数过滤

## P1 优化验证
- [x] 冷启动判定同时检查 NextUp + Resume + Suggestions 三个数据源
- [x] `hasMore` 在服务器端确实无更多数据时才为 false（而非仅因本轮去重后不足 30 条）

## 测试覆盖
- [x] `recommend_provider_test.dart` 覆盖 `_loadPage` 正常加载场景
- [x] `recommend_provider_test.dart` 覆盖 `_mergeRoundRobin` 多源合并 + 去重
- [x] `recommend_provider_test.dart` 覆盖 `_shouldSkipItem` 黑名单/反疲劳/用户评分过滤
- [x] 所有修改后的现有测试仍然通过
