# 右侧操作区图标化显示（保留演员名字） - 实施任务计划

## 重要提示：当前代码状态
根据对 `frontend/lib/widgets/video_page_item.dart` 的完整代码审查：
- `_PressableActionButton` 已只渲染 Icon（无 Text）
- 倍速/播放模式/字幕/唱片静音/连播按钮已只显示图标
- 演员头像下方保留演员名字显示
- **当前代码大概率已满足需求**。以下任务为**验证+确保**，如果验证发现问题则修复。

---

## [ ] Task 1: 代码全面审查 — 确认所有按钮组件无文字标签
- **Priority**: P0
- **Depends On**: None
- **Description**: 
  - 全面审查 `video_page_item.dart` 中所有右侧操作区按钮组件的渲染逻辑
  - 检查每个组件的 `build` 方法是否仅渲染 Icon，无 Text 标签
  - 特别检查 `_PressableActionButton`、`_buildSpeedControlButton`、`_buildPlayModeButton`、`_buildPosterAvatar` 等
  - 确认演员名字仅在头像下方显示（不涉及按钮组件）
  - 如果发现任何按钮仍有文字标签，记录并在 Task 3 中修复
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3, AC-4
- **Test Requirements**:
  - `programmatic` TR-1.1: 在 `video_page_item.dart` 中搜索 Text 组件是否出现在右侧操作区按钮内部（关键词：Text、label、style、fontSize、"点赞"、"信息"、"删除"、"全屏"、"下一集"、"Direct"、"Transcode"、"Fbk"、"1.0x"）
  - `programmatic` TR-1.2: `_PressableActionButton.build` 方法中仅包含 Icon 组件，不包含 Text 组件
  - `human-judgment` TR-1.3: 代码审查报告 — 列出每个审查过的按钮组件及其渲染内容
- **Notes**: 这是**验证为主**的任务，不一定需要代码修改

## [ ] Task 2: 演员名字保留 — 确认不修改演员头像区域
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 确认 `_buildPosterAvatar` 方法中的演员名字 Text 保留不变
  - 确认演员头像的点击跳转到详情页的逻辑不变
  - 确认"+"收藏按钮逻辑不变
  - 如无演员信息，回退显示视频封面的逻辑不变
- **Acceptance Criteria Addressed**: AC-4
- **Test Requirements**:
  - `programmatic` TR-2.1: `_buildPosterAvatar` 方法中包含 `Text(演员名字)` 组件，不被删除
  - `human-judgment` TR-2.2: 演员头像视觉效果审查 — 头像+收藏按钮+名字布局合理
- **Notes**: 此任务是**确保不修改**演员头像区域

## [ ] Task 3: 问题修复（如 Task 1/2 发现问题）
- **Priority**: P0
- **Depends On**: Task 1, Task 2
- **Description**:
  - 如 Task 1 发现某个按钮仍有文字标签，修改为纯图标
  - 修改原则：仅移除 Text 组件，保持 Icon、颜色、点击回调不变
  - 如果发现演员名字被意外移除，恢复该 Text 组件
  - 任何修改都应保持响应式尺寸逻辑不变
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3, AC-4
- **Test Requirements**:
  - `programmatic` TR-3.1: 修改后的代码中相关按钮无 Text 组件
  - `human-judgment` TR-3.2: 修改后的按钮视觉效果自然，图标尺寸合适
- **Notes**: 仅在 Task 1/2 发现问题时才需要执行此任务

## [ ] Task 4: 功能验证 — 所有按钮点击行为正常
- **Priority**: P0
- **Depends On**: Task 1, Task 2, Task 3（如需要）
- **Description**:
  - 验证所有按钮的点击回调与修改前一致
  - 点赞切换、信息面板弹出、删除确认、全屏切换、倍速面板、播放模式切换、字幕选择、静音切换、下一集、连播切换
  - 验证按钮的状态视觉反馈（颜色/图标的变化）正常
- **Acceptance Criteria Addressed**: AC-5
- **Test Requirements**:
  - `human-judgment` TR-4.1: 所有按钮点击后行为符合预期
  - `human-judgment` TR-4.2: 状态变化有正确的视觉反馈

## [ ] Task 5: 代码提交与同步
- **Priority**: P0
- **Depends On**: Task 1-4
- **Description**:
  - 如发现问题并修复，提交修改到 main 分支
  - 提交信息格式：`fix(ui): 确保右侧操作区按钮仅显示图标，保留演员名字`
  - 如代码已满足需求无需修改，提交一条验证确认信息或不提交
- **Acceptance Criteria Addressed**: AC-7
- **Test Requirements**:
  - `programmatic` TR-5.1: 仅 `video_page_item.dart` 有修改（如需修改）
  - `programmatic` TR-5.2: 修改不涉及业务逻辑和 API 调用
- **Notes**: 如果代码审查确认当前状态已满足需求，此任务可以"无代码变更，标记完成"结束
