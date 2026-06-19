# 右侧操作区图标化显示 - The Implementation Plan (Decomposed and Prioritized Task List)

## [ ] Task 1: 修改 _PressableActionButton 组件，移除 label 文字
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 修改 `_PressableActionButton` widget 的 build 方法中移除 Column 中的 Text 子节点
  - `_PressableActionButton` 的 `label` 参数可能标记为 optional，保留 label 仍需用于 TV 焦点调试标签（保留 label 用于 focus node 仅用于焦点和 debugLabel，不在 build 中显示
  - 仅保留 Icon + 点击效果（Padding 可以简化，因为没有文字了，只需要 Column 只需保留 Icon
  - 调整 padding 和圆角，使按钮更紧凑
- **Acceptance Criteria Addressed**: AC-1, AC-5
- **Test Requirements**:
  - `human-judgement` TR-1.1: "点赞"按钮仅有❤图标，点击触发点赞切换，无文字
  - `human-judgement` TR-1.2: "信息"按钮仅显示ℹ图标，点击打开信息面板
  - `human-judgement` TR-1.3: "删除"按钮仅显示🗑图标，点击打开删除确认
  - `human-judgement` TR-1.4: "全屏"按钮仅显示⛶图标，点击切换全屏
  - `human-judgement` TR-1.5: "下一集"按钮仅显示⏭图标，点击切换下一集
  - `human-judgement` TR-1.6: 按下缩放效果仍然工作（_pressed 状态仍然有效）
  - `human-judgement` TR-1.7: TV 焦点高亮效果仍然工作（焦点边框仍然有效
- **Notes**: 点赞、信息、删除、全屏、下一集五个按钮共用此组件，一次修改即可全部生效

## [ ] Task 2: 倍速按钮移除内部数字文字，保留颜色状态
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 倍速按钮 _buildSpeedControlButton 的 Center-> child: 移除 child: Text("1.0x")部分
  - 改为显示一个简单的图标的图标替换为 Icon(Icons.speed 或其他合适图标（如 play_arrow 的箭头）
  - 保留颜色区分：默认灰色（>1.0 时橙色高亮
  - 保留 onTap 打开倍速选择面板逻辑不变
- **Acceptance Criteria Addressed**: AC-2, AC-5
- **Test Requirements**:
  - `human-judgement` TR-2.1: 倍速按钮仅显示图标，无 "1.0x/2.0x" 等数字文字
  - `human-judgement` TR-2.2: 倍速 > 1.0 时按钮仍然橙色高亮，按钮仍能点击可用于按钮仍可触发倍速设置面板打开
- **Notes**: 顶部 _buildSpeedBadge 倍速徽章保持不变，作为倍速状态的主提示，保持不变

## [ ] Task 3: 播放模式按钮移除内部文字，改用图标区分状态
- **Priority**: P0
- **Depends On**: Task 2
- **Description**:
  - `_buildPlayModeButton 的 Text('Direct'/'Transcode'/'Fbk')改为 Icon
  - 三种状态用不同图标或颜色区分：
    - Direct (level==0): 默认灰色背景 + 播放图标 (Icons.play_circle_outline 或 Icons.ondemand_video
    - Transcode (level==1): 紫色高亮背景 + 转换图标 (Icons.swap_horiz 或 Icons.transform)
    - Fallback (level==2): 黄色/另一颜色背景 + ⚠ 图标 (Icons.error 或 Icons.warning)
  - 点击仍然在切换播放模式切换逻辑（cycle through 3 种模式）逻辑不变
- **Acceptance Criteria Addressed**: AC-3, AC-5
- **Test Requirements**:
  - `human-judgement` TR-3.1: 播放模式按钮仅显示图标，无 "Direct"/"Transcode"/"Fbk" 文字
  - `human-judgement` TR-3.2: 三种模式可通过颜色+ 颜色+颜色可区分
  - `human-judgement` TR-3.3: 点击仍然切换模式切换状态 Provider (playbackLevelProvider 更新不变
  - `human-judgement` TR-3.4: 第一次切换时按钮时，在 SnackBar 提示当前播放模式名称（如果需要可以保留切换后显示提示

## [ ] Task 4: 海报头像移除演员名字
- **Priority**: P0
- **Depends On**: Task 3
- **Description**:
  - `_buildPosterAvatar` 中移除 Column 的 SizedBox 高度 responsiveSize(4) + Text() 文本部分的 Text 完全删除
  - 保留圆形头像 + "+" 收藏按钮不变
  - 保留头像点击跳转到 PersonDetailView 跳转逻辑不变
- **Acceptance Criteria Addressed**: AC-4, AC-5
- **Test Requirements**:
  - `human-judgement` TR-4.1: 有演员信息时显示仅有圆形头像，不显示名字
  - `human-judgement` TR-4.2: 无演员信息时显示视频封面，不显示名字
  - `human-judgement` TR-4.3: 点击头像仍然跳转到演员详情页
  - `human-judgement` TR-4.4: "+" 收藏按钮仍可点击切换收藏
- **Notes**: 这可以在 Task 2 3 同时实施

## [ ] Task 5: 优化按钮间距和布局紧凑性
- **Priority**: P1
- **Depends On**: Task 1-4
- **Description**:
  - 由于移除文字后，按钮高度降低，适度减小按钮之间的垂直间距（当前 responsiveSize(16, 1.5)可调整），但不是必要
  - 确保按钮高度减小，按钮间按钮高度减小，适当调整按钮的 padding 等，使布局更紧凑
  - 保持响应式缩放逻辑保持不变
- **Acceptance Criteria Addressed**: AC-6
- **Test Requirements**:
  - `human-judgement` TR-5.1: 所有按钮在各屏幕尺寸下布局均匀、不拥挤也不过散
  - `human-judgement` TR-5.2: 响应式缩放仍然工作（手机、平板、桌面均有合理的尺寸）
- **Notes**: 此任务较灵活，可视实际观感调整。间距微调为主，可以省略

## [ ] Task 6: 添加播放模式切换 SnackBar 提示提高可识别性（如果没有，则省略
- **Priority**: P2
- **Depends On**: Task 3
- **Description**:
  - 在播放模式切换时，显示 SnackBar 提示"播放模式: Direct Play" 等状态名称（中文化
  - 仅在播放模式按钮内的 onTap 中添加 SnackBar 提示代码
- **Acceptance Criteria Addressed**: AC-3
- **Test Requirements**:
  - `human-judgement` TR-6.1: 点击播放模式按钮切换模式切换时显示播放模式名称提示
- **Notes**: 由于播放模式按钮移除文字后，为了提高可识别性，添加简短提示 SnackBar 提示以文字状态文字

## [ ] Task 7: 代码审查与提交推送
- **Priority**: P0
- **Depends On**: Task 1-6（至少 Task 1-4（Task 5-6 可选

## [ ] Task 7: 代码审查与提交推送
- **Priority**: P0
- **Depends On**: Task 1-4（Task 5-6 是可选增强
- **Description**:
  - 审查代码，确保没有语法正确，没有遗漏
  - 提交到 GitHub main 分支
- **Acceptance Criteria Addressed**: AC-7
- **Test Requirements**:
  - `programmatic` TR-7.1: `git diff --stat` 仅显示 `video_page_item.dart` 文件修改
  - `programmatic` TR-7.2: 代码可编译通过，无语法错误
  - `human-judgement` TR-7.3: 代码风格与项目现有代码一致
