# Tasks - 演员列表显示全部演员

## 诊断任务

- [x] Task 1: 检查 getPeople API 调用参数
  - [x] SubTask 1.1: 检查 `Recursive` 参数设置 - ✓ 设置为 'true'
  - [x] SubTask 1.2: 检查 `Limit` 参数是否合理（当前50） - ✓ 合理
  - [x] SubTask 1.3: 检查分页加载逻辑 - ✓ 正确

- [x] Task 2: 验证演员总数显示
  - [x] SubTask 2.1: 对比 API 返回的 TotalRecordCount - ✓ 正确赋值
  - [x] SubTask 2.2: 检查已加载数量与总数是否一致 - ✓ 一致

- [x] Task 3: 检查演员类型筛选
  - [x] SubTask 3.1: 检查 `PersonTypes` 参数是否被错误添加 - ✓ 仅在选择时添加
  - [x] SubTask 3.2: 确保默认加载时不添加类型筛选 - ✓ 初始值为 null

- [x] Task 4: 修复 Tab 显示问题
  - [x] SubTask 4.1: Tab 计数使用 `_actors.length` - ✓ 已修复
  - [x] SubTask 4.2: 已关注/未关注从 `_actors` 过滤 - ✓ 已修复
  - [x] SubTask 4.3: Tab 显示 "已加载/总数" 格式 - ✓ 已添加

## 已修复问题

1. **Tab 计数问题**：使用 `_filteredActors.length` 导致搜索时计数不准确
   - 修复：改为 `_actors.length`

2. **已关注/未关注列表不完整**：从 `_filteredActors` 过滤导致搜索时列表不完整
   - 修复：改为从 `_actors` 过滤

3. **缺少总数提示**：用户不知道还有更多可以加载
   - 修复：Tab 显示 "已加载/总数" 格式
