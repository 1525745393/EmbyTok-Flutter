# 视频详情页优化 & 预加载优化 - 实施计划（任务列表）

## [ ] Task 1: 详情页增加相关推荐模块
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 在 ItemDetailView 中增加「相关推荐」模块
  - 调用 getSimilarItems API 获取相似视频
  - 横向滚动卡片列表，显示封面图 + 标题
  - 加载中显示骨架屏，加载失败不阻塞页面
  - 点击跳转到对应详情页
- **Acceptance Criteria Addressed**: AC-1, AC-2
- **Test Requirements**:
  - `human-judgement` TR-1.1: 详情页底部显示「相关推荐」标题和横向滚动列表
  - `human-judgement` TR-1.2: 点击推荐卡片跳转到对应详情页
  - `human-judgement` TR-1.3: 加载中显示骨架屏，加载失败不影响其他内容
- **Notes**: 使用已有的 getSimilarItems API，最多显示 12 条

## [ ] Task 2: 详情页元信息增强
- **Priority**: medium
- **Depends On**: None
- **Description**: 
  - 在详情页信息区增加导演、时长等信息
  - 检查 MediaItem 模型是否有这些字段
  - 优化信息标签布局，保持简洁
- **Acceptance Criteria Addressed**: AC-3
- **Test Requirements**:
  - `human-judgement` TR-2.1: 详情页显示导演信息（如有）
  - `human-judgement` TR-2.2: 详情页显示视频时长（格式化）
  - `human-judgement` TR-2.3: 信息布局美观，不拥挤
- **Notes**: 先检查 MediaItem 模型有哪些可用字段

## [ ] Task 3: 封面图预加载优化
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 在 feed_view 的页面切换回调中，预加载下一个视频的封面图
  - 使用 precacheImage 或 CachedNetworkImage 的机制
  - 预加载下 1-2 个视频的封面图
- **Acceptance Criteria Addressed**: AC-4, AC-5
- **Test Requirements**:
  - `human-judgement` TR-3.1: 滑动到下一个视频时，封面图无明显加载闪烁
  - `human-judgement` TR-3.2: 当前视频播放不受预加载影响
- **Notes**: 注意内存控制，不要预加载过多

## [ ] Task 4: 预加载策略优化
- **Priority**: medium
- **Depends On**: Task 3
- **Description**: 
  - 检查现有 VideoPoolService 的预加载逻辑
  - 确保预加载缓存有上限控制
  - 清理远离当前位置的预加载缓存
- **Acceptance Criteria Addressed**: AC-5, AC-6
- **Test Requirements**:
  - `programmatic` TR-4.1: 预加载缓存数量有上限，快速滑动后不无限增长
  - `human-judgement` TR-4.2: 远离当前位置的预加载被及时清理
- **Notes**: 保持现有逻辑，只做优化和边界检查
