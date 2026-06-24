# 应用状态恢复 - Verification Checklist

- [ ] Checkpoint 1: constants.dart 中定义了 kStorageKeyLastPageIndex 常量
- [ ] Checkpoint 2: PageNavigationNotifier 构造函数中从存储加载上次页面索引
- [ ] Checkpoint 3: 切换主页面（首页/收藏/演员/设置）时自动保存到存储
- [ ] Checkpoint 4: 覆盖层页面（搜索/历史）切换时不保存
- [ ] Checkpoint 5: 如果上次是覆盖层页面，恢复到底层主页面（feed）
- [ ] Checkpoint 6: 应用重启后自动恢复到上次访问的主页面
- [ ] Checkpoint 7: 不影响已有的持久化设置（浏览模式、视图模式、方向过滤等）
- [ ] Checkpoint 8: 状态恢复不影响应用启动性能
