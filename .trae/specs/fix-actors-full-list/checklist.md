# Checklist - 演员列表显示全部演员

## 代码检查清单

- [x] getPeople 方法中 `Recursive` 参数设置为 `true`
- [x] getPeople 方法中 `Limit` 参数合理（当前50）
- [x] 分页加载逻辑正确递增 `StartIndex`
- [x] 默认不添加 `PersonTypes` 筛选条件
- [x] `_selectedPersonType` 初始值为 `null`（表示全部）
- [x] 演员总数 `_total` 正确赋值

## 功能验证清单

- [x] API 返回的 `TotalRecordCount` 正确
- [x] 演员列表加载数量与 `TotalRecordCount` 一致
- [x] 所有类型的演员（Actor/Director/Writer）都被加载
- [x] Tab 切换不影响演员总数统计
- [x] Tab 计数使用 `_actors.length` 而非 `_filteredActors.length`
- [x] 已关注/未关注列表从 `_actors` 过滤
