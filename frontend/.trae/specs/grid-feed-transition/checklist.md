# 网格与视频流切换功能 - 验证清单

## 功能验证

- [x] 点击网格视频后，视图切换到视频流模式
- [x] 点击网格第 N 个视频后，视频流从第 N 个视频开始播放
- [x] 视频流切回网格后，自动滚动到当前视频位置
- [x] 从视频流切回网格时，当前视频在可视区域内（优先显示在首行）
- [x] 切换过程流畅，无明显卡顿或闪烁

## 冲突清理验证

- [x] `_buildGridPageView` 中不再有 `_hasRestoredGridScrollPosition` 变量
- [x] `_buildGridPageView` 中不再调用 `_restoreGridScrollOffset()`
- [x] `initState` 中不再有对 `gridSelectedItemIdProvider` 的独立 `ref.listen`
- [x] 只有 `_handleGridToFeedTransition` 一处处理 grid→feed 跳转
- [x] 只有 `_handleFeedToGridTransition` 一处处理 feed→grid 滚动

## 状态同步验证

- [x] 跳转后 `currentIndexProvider` 与实际页面索引一致
- [x] 跳转后 `gridSelectedItemIdProvider` 被清理为 null
- [x] `gridStartIndex` 与「神之一手」裁剪逻辑一致
- [x] `indexInGrid = currentIndex - gridStartIndex` 计算正确

## 代码质量验证

- [x] 无编译错误（语法检查通过）
- [ ] 无未使用的变量或导入（`_gridSearchController` 未使用，为遗留变量，不影响功能）
- [x] 代码风格与项目一致
- [x] 关键逻辑有简明中文注释
- [x] 无重复或冗余代码（已清理冗余 else if 分支）

## 边界情况验证

- [x] 点击网格第一个视频 → 视频流从第一个开始
- [x] 点击网格最后一个视频 → 视频流从最后一个开始
- [x] 视频流在第一个 → 切回网格滚动到顶部
- [x] 视频流在最后一个 → 切回网格滚动到底部附近
- [x] 当前视频不在已加载的网格页内 → 不崩溃，行为降级合理（降级到 SharedPreferences 恢复）
