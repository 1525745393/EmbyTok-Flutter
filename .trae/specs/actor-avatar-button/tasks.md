# 演员头像按钮（TikTok 风格） - Implementation Plan (Tasks)

## [x] Task 1: 修改 `_buildPosterAvatar()` 方法，重构为演员头像
- **Priority**: P1
- **Depends On**: None
- **Description**: 
  - 从 `widget.item.people` 中获取第一个 Actor 类型的人员
  - 如果有演员：显示演员头像，点击跳转到 `PersonDetailView`
  - 如果没有演员：回退显示视频封面图，点击播放/暂停
  - 演员头像大小：56x56px（从 48px 增大）
  - 添加演员名字（短名）在头像下方
- **关键实现细节**:
  - 从 `people` 列表过滤 `type == 'Actor'`
  - 将 `Person` 对象转换为 `MediaItem`（用于导航和收藏）：`id = person.id`, `title = person.name`, `type = 'Person'`, `imageTags = {'Primary': person.imageUrl ?? ''}`
  - 头像 URL：类似 `widget.item.imageUrl()` 的方式构建演员头像 URL
  - 需要从 `authProvider` 获取服务器 URL 和 token
- **Acceptance Criteria Addressed**: AC-1, AC-5, AC-6
- **Test Requirements**:
  - `human-judgement` TR-1.1: 有演员时显示演员头像
  - `human-judgement` TR-1.2: 无演员时回退显示视频封面
  - `human-judgement` TR-1.3: 演员头像大小合适
- **File**: `frontend/lib/widgets/video_page_item.dart`
- **Notes**: 需要在方法中读取 `ref.watch(authProvider)` 和 `ref.watch(favoritesProvider)`

## [x] Task 2: 添加 TikTok 风格的 "+" 收藏按钮
- **Priority**: P1
- **Depends On**: Task 1
- **Description**: 
  - 在头像右下角添加 "+" 圆形按钮（20-24px）
  - 青色背景（`Color(0xFF00D9FF)` 或类似 TikTok 青色）
  - 点击切换演员收藏状态
  - 已收藏：按钮变为"✓"或动画缩小消失
  - 未收藏：显示"+"
  - 无演员时不显示"+"按钮
- **关键实现细节**:
  - 使用 `Stack` 布局，在 `ClipOval` 外部叠加一个 `Positioned` 的"+"按钮
  - 点击时调用 `ref.read(favoritesProvider.notifier).toggleFavorite(actorMediaItem)`
  - 通过 `ref.watch(favoritesProvider).favoriteIds.contains(person.id)` 判断收藏状态
  - "+"按钮需要独立的 `GestureDetector`，与头像点击分离
  - 动画效果：使用 `AnimatedSwitcher` 或简单的条件渲染
- **Acceptance Criteria Addressed**: AC-3, AC-4
- **Test Requirements**:
  - `human-judgement` TR-2.1: 有演员时显示"+"按钮
  - `human-judgement` TR-2.2: 点击"+"切换为已收藏状态
  - `human-judgement` TR-2.3: 再次点击变回未收藏
  - `human-judgement` TR-2.4: 按钮位置正确（头像右下角）
- **File**: `frontend/lib/widgets/video_page_item.dart`
- **Notes**: 需要确保点击事件分离：头像跳转到详情页，"+"切换收藏

## [x] Task 3: 点击头像跳转到演员详情页
- **Priority**: P1
- **Depends On**: Task 1
- **Description**: 
  - 点击演员头像（不是"+"按钮区域）导航到 `PersonDetailView`
  - 将 `Person` 转换为 `MediaItem`（type='Person'）后传递给 `PersonDetailView`
  - 使用 `Navigator.push(context, MaterialPageRoute(builder: (_) => PersonDetailView(person: mediaItem)))`
- **关键实现细节**:
  - 需要构造一个临时的 `MediaItem`，带有：
    - `id`: `person.id ?? ''`
    - `title`: `person.name`
    - `type`: `'Person'`
    - `imageTags`: `{'Primary': person.imageUrl ?? ''}` 或类似方式让 `primaryUrl()` 工作
  - 检查 `PersonDetailView` 的构造参数要求，确保兼容
  - 检查 `primaryUrl()` 方法，确保演员头像能正确显示
- **Acceptance Criteria Addressed**: AC-2, AC-7
- **Test Requirements**:
  - `human-judgement` TR-3.1: 点击头像正确跳转到详情页
  - `human-judgement` TR-3.2: 详情页正确显示演员名字和作品列表
  - `human-judgement` TR-3.3: 返回按钮工作正常
- **File**: `frontend/lib/widgets/video_page_item.dart`
- **Notes**: 确保从视频页面返回时视频继续正常播放

## [x] Task 4: 确保收藏功能与现有系统兼容
- **Priority**: P1
- **Depends On**: Task 2, Task 3
- **Description**: 
  - 确保收藏的演员可以在收藏页的"人物"标签中看到
  - 确保 `toggleFavorite` 能够正确处理 `type = 'Person'` 的 MediaItem
  - 确保 `getFavoritePeople` 服务返回的数据与我们构造的 `MediaItem` 兼容
- **关键实现细节**:
  - 检查 `favorites_provider.dart` 中 `toggleFavorite` 的 `type == 'person'` 判断
  - 确认我们构造的 `MediaItem` 的 `type` 是 `'Person'`（会被 `toLowerCase()` 变成 `'person'`）
  - 检查 Emby API 对 `person` 类型项目的收藏支持
- **Acceptance Criteria Addressed**: AC-7
- **Test Requirements**:
  - `human-judgement` TR-4.1: 收藏演员后，收藏页能看到
  - `human-judgement` TR-4.2: 取消收藏后，收藏页不再显示
  - `human-judgement` TR-4.3: 收藏状态在应用重启后保持
- **File**: `frontend/lib/widgets/video_page_item.dart`

## [x] Task 5: 验证并提交
- **Priority**: P1
- **Depends On**: Tasks 1-4
- **Description**: 
  - 代码语法检查
  - UI 检查
  - 提交代码并推送
- **Test Requirements**:
  - `human-judgement` TR-5.1: 代码编译无错误
  - `human-judgement` TR-5.2: 运行无崩溃

## Task Dependencies
- Task 2 depends on Task 1
- Task 3 depends on Task 1
- Task 4 depends on Tasks 2, 3
- Task 5 depends on Tasks 1-4
