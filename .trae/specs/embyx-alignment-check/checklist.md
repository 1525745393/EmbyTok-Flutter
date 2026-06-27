# EmbyX 功能对齐验证 - 验证清单

## 媒体库选择器验证

- [x] 媒体库选择器为居中弹窗 Dialog
- [x] 2列网格布局
- [x] 包含收藏夹入口（快捷入口）
- [x] 媒体库列表正确显示
- [x] 单选模式：点击即切换并关闭弹窗
- [x] 选中状态有视觉反馈（边框高亮）
- [x] 修复：初始只选中第一个可见媒体库（之前是全选，与单选模式矛盾）

## 网格视图验证

- [ ] 3列网格布局
- [ ] 顶部 Header 显示媒体库名
- [ ] 显示视频总数
- [ ] 「换一批」按钮正常工作
- [ ] 分页控件正常显示（单库多页时）
- [ ] 上一页/下一页按钮正常工作

## 网格→视频流切换验证

- [x] 点击网格视频后，视图切换到视频流模式
- [x] 点击网格第 N 个视频后，视频流从第 N 个视频开始播放
- [x] 统一通过 viewModeProvider 监听器处理
- [x] 没有独立的 gridSelectedItemIdProvider 监听器
- [x] 跳转后 gridSelectedItemIdProvider 被清理为 null
- [x] 跳转后 currentIndexProvider 与实际页面索引一致

## 视频流→网格切换验证

- [x] 视频流切回网格后，自动滚动到当前视频位置
- [x] 从视频流切回网格时，当前视频在可视区域内垂直居中
- [x] 使用垂直居中公式：elTop - (areaHeight / 2) + (elHeight / 2)
- [x] 使用 animateTo 平滑滚动（300ms，Curves.easeOut）
- [x] 滚动偏移使用 clamp 限制在有效范围内

## 「神之一手」裁剪验证

- [x] 从 feed 切到 grid 时，执行裁剪逻辑
- [x] 根据 currentIndex 计算页码（pageIndex = currentIndex ~/ 150）
- [x] gridStartIndex = pageIndex * 150
- [x] gridItems 为当前页的 150 条数据
- [x] indexInGrid = currentIndex - gridStartIndex 计算正确

## 滚动位置持久化验证

- [x] _buildGridPageView 中没有恢复滚动位置的逻辑
- [x] 没有 _hasRestoredGridScrollPosition 变量
- [x] _saveGridScrollOffset 保留（保存逻辑）
- [x] _onGridScrollChanged 保留（防抖保存）
- [x] _restoreGridScrollOffset 保留（供降级使用）
- [x] 滚动失败时降级调用 _restoreGridScrollOffset

## 代码质量验证

- [x] 无编译错误（语法检查通过）
- [x] 无未使用的变量或导入
- [x] 代码风格与项目一致
- [x] 关键逻辑有简明中文注释
- [x] 无重复或冗余代码
- [x] 无多个监听器导致的时序问题

## 边界情况验证

- [x] 点击网格第一个视频 → 视频流从第一个开始
- [x] 点击网格最后一个视频 → 视频流从最后一个开始
- [x] 视频流在第一个 → 切回网格滚动到顶部附近
- [x] 视频流在最后一个 → 切回网格滚动到底部附近
- [x] 当前视频不在已加载的网格页内 → 不崩溃，降级到 SharedPreferences 恢复
