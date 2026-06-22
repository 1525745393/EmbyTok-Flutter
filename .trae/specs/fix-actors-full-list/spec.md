# 演员列表显示全部演员 - 问题诊断规格

## Why
用户报告演员界面没有显示媒体库的全部演员，可能是 API 调用问题或数据过滤问题。

## What Changes
- 检查 `/Persons` API 调用参数是否正确
- 检查演员列表是否正确加载所有数据
- 检查是否存在过滤条件导致演员被排除

## Impact
- Affected specs: actors-ui-optimization
- Affected code:
  - `/workspace/frontend/lib/views/actors_view.dart`
  - `/workspace/frontend/lib/services/embbytok_service.dart`

## ADDED Requirements

### Requirement: 演员列表完整加载
系统 SHALL 从 Emby 服务器加载所有演员，不遗漏任何演员

#### Scenario: 加载全部演员
- **WHEN** 用户进入演员列表页面
- **THEN** 显示 Emby 媒体库中的所有演员（包括演员、导演、编剧等）

#### Scenario: 分页加载不遗漏
- **WHEN** 演员数量超过单页限制
- **THEN** 通过分页加载获取所有演员，不遗漏

## 诊断检查项

1. **API 参数检查**
   - [ ] `Recursive` 参数是否设置为 `true`
   - [ ] `Limit` 参数是否合理
   - [ ] `StartIndex` 分页是否正确递增

2. **数据完整性检查**
   - [ ] API 返回的 `TotalRecordCount` 与实际加载数量一致
   - [ ] 所有类型的演员（Actor/Director/Writer）都被加载

3. **过滤条件检查**
   - [ ] Tab 切换不应影响演员总数
   - [ ] 搜索条件应仅影响显示，不影响数据加载
