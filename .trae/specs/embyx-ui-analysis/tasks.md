# Tasks

本 spec 主要是分析和参考文档，不涉及代码实现。以下是基于分析结果的建议实施任务（供后续开发参考）：

- [ ] Task 1: 实现键盘快捷键系统
  - [ ] SubTask 1.1: 创建 `KeyboardShortcuts` 类，定义所有快捷键映射
  - [ ] SubTask 1.2: 在 `FeedView` 中添加 `HardwareKeyboard` 监听
  - [ ] SubTask 1.3: 实现视频切换快捷键 (W/S/↑/↓)
  - [ ] SubTask 1.4: 实现播放控制快捷键 (Space/A/D/←/→)
  - [ ] SubTask 1.5: 添加快捷键帮助面板 (按 ? 显示)

- [ ] Task 2: 实现视图切换功能
  - [ ] SubTask 2.1: 创建 `ViewMode` 枚举 (feed/poster)
  - [ ] SubTask 2.2: 实现海报墙视图 `PosterGridView`
  - [ ] SubTask 2.3: 添加视图切换动画
  - [ ] SubTask 2.4: 支持快捷键 E 切换视图

- [ ] Task 3: 优化媒体库选择器
  - [ ] SubTask 3.1: 创建 `LibrarySelector` 底部弹窗组件
  - [ ] SubTask 3.2: 支持搜索和过滤功能
  - [ ] SubTask 3.3: 添加快捷键 G 打开选择器

- [ ] Task 4: 添加播放模式切换
  - [ ] SubTask 4.1: 创建 `PlaybackMode` 枚举 (sequential/random)
  - [ ] SubTask 4.2: 实现随机播放算法
  - [ ] SubTask 4.3: 添加快捷键 R 切换模式

- [ ] Task 5: PWA 优化
  - [ ] SubTask 5.1: 完善 `manifest.json` 配置
  - [ ] SubTask 5.2: 添加 Service Worker 离线支持
  - [ ] SubTask 5.3: 实现安装提示弹窗

# Task Dependencies

- [Task 2] 依赖 [Task 1]（视图切换需要快捷键支持）
- [Task 3] 依赖 [Task 1]（媒体库选择器需要快捷键支持）
- [Task 4] 依赖 [Task 1]（播放模式切换需要快捷键支持）
- [Task 5] 独立任务，可并行实施
