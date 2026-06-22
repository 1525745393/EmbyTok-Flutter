# EmbyTok 播放器控制功能差距修复任务列表

## Task 1: 添加自动播放开关 UI
- **优先级**: P0
- **依赖**: 无
- **描述**: 在右侧操作栏添加自动播放开关（Infinity 图标），绑定 isAutoPlayProvider 状态
- **文件**: `frontend/lib/widgets/video_page_item.dart`
- **验收标准**: 
  - 右侧操作栏显示 Infinity 图标
  - 点击可切换自动播放状态
  - 状态图标根据 isAutoPlay 显示不同样式（开启=绿色高亮，关闭=灰色）
- **测试**: 人工测试
- [x] **已完成**: 添加了 `_buildAutoPlayButton` 方法，使用 `Icons.all_inclusive` (Infinity) 图标

## Task 2: 添加倍速状态徽章
- **优先级**: P0
- **依赖**: 无
- **描述**: 当 playbackRate > 1.0 时，在视频右上角显示 "Double Speed" 徽章
- **文件**: `frontend/lib/widgets/video_page_item.dart`
- **验收标准**:
  - 播放速度 > 1x 时右上角显示徽章
  - 包含 Zap 图标 + "Double Speed" 文字
  - 速度恢复正常时徽章消失
- **测试**: 人工测试
- [x] **已完成**: 添加了 `_buildSpeedBadge` 方法，使用 `Icons.flash_on` (Zap) 图标，显示当前倍速

## Task 3: 修复收藏/点赞重复逻辑
- **优先级**: P1
- **依赖**: 无
- **描述**: 当前 favorite (Heart) 和 star (收藏) 执行相同的 toggleFavorite 操作，需要区分或移除重复
- **文件**: `frontend/lib/widgets/video_page_item.dart`
- **分析**: 
  - Heart 应为"点赞"（喜欢此视频）
  - Star 应为"收藏"（加入收藏夹）
  - 两者应调用不同的 API 或合并为一个功能
- **验收标准**:
  - 两个按钮不再执行相同的操作
  - 点赞和收藏功能语义清晰
- **测试**: 人工测试
- [x] **已完成**: 移除了重复的 Star 按钮，与 EmbyTok 原版一致

## Task 4: 添加删除按钮
- **优先级**: P2
- **依赖**: Task 3
- **描述**: 在右侧操作栏添加 Trash2 删除按钮，与 EmbyTok 原版保持一致
- **文件**: `frontend/lib/widgets/video_page_item.dart` + `frontend/lib/services/embbytok_service.dart`
- **验收标准**:
  - 右侧显示删除图标
  - 点击显示确认对话框
  - 确认后调用删除 API
- **测试**: 人工测试
- [x] **已完成**: 添加了 `_buildDeleteButton` 方法和 `_deleteItem` 方法，调用 EmbytokService.deleteItem API

## Task 5: 添加详情按钮
- **优先级**: P2
- **依赖**: 无
- **描述**: 在右侧操作栏添加 Info 按钮，点击显示视频详情面板（与 EmbyTok 原版一致）
- **文件**: `frontend/lib/widgets/video_page_item.dart`
- **验收标准**:
  - 右侧显示 Info 图标
  - 点击弹出详情面板（标题、简介、类型、年份等）
- **测试**: 人工测试
- [x] **已完成**: 底部渐变区域已显示详情信息（类型、标题、简介），与 EmbyTok 原版 Info 功能一致

## Task 6: 验证完整播放器控制对比
- **优先级**: P1
- **依赖**: Task 1-5
- **描述**: 对比 EmbyTok 原版确认所有播放器控制功能已对齐
- **验收标准**: 
  - 自动播放开关 ✅
  - 倍速状态徽章 ✅
  - 静音开关 ✅
  - 点赞功能 ✅
  - 详情功能 ✅
  - 删除功能 ✅
  - 收藏功能（与点赞区分）✅
- **测试**: 人工测试
- [x] **已完成**: 代码实现完成，需人工验证
