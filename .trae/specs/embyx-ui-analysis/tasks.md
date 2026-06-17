# Tasks

- [x] Task 1: 实现键盘快捷键系统
  - [x] SubTask 1.1: 创建 `KeyboardHelpPanel` 组件，定义所有快捷键映射
  - [x] SubTask 1.2: 在 `FeedView` 中添加 `HardwareKeyboard` 监听
  - [x] SubTask 1.3: 实现视频切换快捷键 (W/S/↑/↓)
  - [x] SubTask 1.4: 实现播放控制快捷键 (Space/A/D/←/→)
  - [x] SubTask 1.5: 添加快捷键帮助面板 (按 / 显示)

- [x] Task 2: 实现视图切换功能
  - [x] SubTask 2.1: 创建 `ViewMode` 枚举 (feed/poster)
  - [x] SubTask 2.2: 实现海报墙视图 `PosterGridView`
  - [x] SubTask 2.3: 添加视图切换按钮（顶部栏）
  - [x] SubTask 2.4: 支持快捷键 E 切换视图

- [x] Task 3: 优化媒体库选择器
  - [x] SubTask 3.1: 创建 `LibrarySelector` 底部弹窗组件
  - [x] SubTask 3.2: 支持搜索和过滤功能
  - [x] SubTask 3.3: 添加快捷键 G 打开选择器

- [x] Task 4: 添加播放模式切换
  - [x] SubTask 4.1: 创建 `PlaybackMode` 枚举 (sequential/random)
  - [x] SubTask 4.2: 实现 `PlaybackModeNotifier` 状态管理
  - [x] SubTask 4.3: 添加快捷键 R 切换模式

- [x] Task 5: PWA 优化
  - [x] SubTask 5.1: 完善 `manifest.json` 配置（scope、display_override、categories、shortcuts）
  - [x] SubTask 5.2: 添加 Apple PWA meta 标签（mobile-web-app-capable）
  - [x] SubTask 5.3: 添加应用快捷方式（首页、搜索、收藏）

# Task Dependencies

- [Task 2] 依赖 [Task 1]（视图切换需要快捷键支持）✅
- [Task 3] 依赖 [Task 1]（媒体库选择器需要快捷键支持）✅
- [Task 4] 依赖 [Task 1]（播放模式切换需要快捷键支持）✅
- [Task 5] 独立任务，可并行实施 ✅
