# 修复网格→视频流跳转竞争条件 - 验证清单

## 修复验证
- [x] _handleGridToFeedTransition 在 gridSelectedItemIdProvider 非空时设置 _hasRestoredScrollPosition = true
- [x] _buildVideoPageView 在 gridSelectedItemIdProvider 非空时跳过 SharedPreferences 恢复
- [x] 点击网格视频后，视频流从该视频开始播放（不被 SharedPreferences 覆盖）
- [x] 正常进入视频流时仍从 SharedPreferences 恢复上次位置
- [x] 从视频流切回网格时，滚动到当前视频位置
- [x] 无编译错误