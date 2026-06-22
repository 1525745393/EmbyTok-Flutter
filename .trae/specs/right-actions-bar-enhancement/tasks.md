# 右侧操作栏对齐 EmbyTok React 版 - Implementation Plan (Tasks)

## Task 1: 播放模式切换按钮
- **Priority**: P1
- **Depends On**: None
- **Description**: 
  - 新增 `_buildPlayModeButton()` 方法
  - 点击循环切换播放模式：0 (DirectPlay) → 1 (Transcode) → 2 (Fallback) → 0
  - 使用 `playbackLevelProvider` 作为状态源（int）
  - 按钮显示当前模式：Direct / Transcode / Fbk
  - 非 Direct 模式时按钮高亮（靛蓝色背景）
- **Implementation Details**:
  - 修改 `playbackLevelProvider` 支持三种模式值
  - 按钮样式与现有按钮风格一致（圆形、图标 + 文本）
  - 模式切换可能需要重新初始化播放器
  - 与现有的 `_playMethodFromLevel()` 逻辑集成
- **Acceptance Criteria Addressed**: AC-1, AC-6
- **Test Requirements**:
  - `human-judgement` TR-1.1: 点击按钮切换模式
  - `human-judgement` TR-1.2: 按钮显示当前模式
  - `human-judgement` TR-1.3: 非 Direct 模式按钮高亮
- **File**: `frontend/lib/widgets/video_page_item.dart`
- **Notes**: 现有 `playbackLevelProvider` 在 `video_playback_controller.dart` 中定义

## Task 2: 字幕控制按钮
- **Priority**: P1
- **Depends On**: None
- **Description**: 
  - 新增 `_buildSubtitleButton()` 方法
  - 点击后弹出字幕选择器（复用 VideoControls 中的 `_showSubtitleMenu` 相同逻辑）
  - 使用 `selectedSubtitleProvider` 跟踪选中状态
  - 选中字幕后按钮高亮
  - 无字幕时按钮显示禁用状态
- **Implementation Details**:
  - 按钮使用 `Icons.subtitles` 图标
  - 复用 `showSubtitleSelector()` 或自定义 BottomSheet 显示字幕列表
  - 有字幕时显示文字 "字幕" / 无字幕时显示 "无字幕"
  - 字幕选择后正确应用到视频控制器
- **Acceptance Criteria Addressed**: AC-2, AC-6
- **Test Requirements**:
  - `human-judgement` TR-2.1: 点击弹出字幕选择器
  - `human-judgement` TR-2.2: 选择字幕高亮
  - `human-judgement` TR-2.3: 无字幕时按钮禁用
- **File**: `frontend/lib/widgets/video_page_item.dart`
- **Notes**: 参考 `video_controls.dart` 行 101-115 的 `_showSubtitleMenu` 实现

## Task 3: 信息按钮
- **Priority**: P1
- **Depends On**: None
- **Description**:
  - 新增 `_buildInfoButton()` 方法
  - 点击切换底部信息面板的展开/收起状态
  - 展开时按钮高亮
  - 按钮显示 "信息" 文字
- **Implementation Details**:
  - 添加本地 `_isInfoExpanded` 状态
  - 控制底部渐变信息区的显示方式（已存在的 `_buildBottomGradient()` 与 `AnimatedOpacity` 控制显示/隐藏
  - 使用 `Icons.info_outline` 图标
- **Acceptance Criteria Addressed**: AC-3
- **Test Requirements**:
  - `human-judgement` TR-3.1: 点击切换底部信息面板
  - `human-judgement` TR-3.2: 展开时按钮高亮
  - `human-judgement` TR-3.3: 收起时恢复
- **File**: `frontend/lib/widgets/video_page_item.dart`
- **Notes**: 当前底部信息区可能默认显示，信息按钮应该用来切换其可见性

## Task 4: 唱片式静音按钮（视觉增强）
- **Priority**: P2
- **Depends On**: None
- **Description**:
  - 优化现有的 `_buildActionButton(Icons.volume_off/volume_up, '静音'` 为唱片风格
  - 播放时缓慢旋转动画
  - 静音时边框变红
  - 圆形外观（disc-like）
- **Implementation Details**:
  - 使用 `AnimatedRotation` 或自定义 `RotationTransition`
  - 状态 `isPlaying` 用于动画控制
  - `isMuted` 控制边框颜色
  - 可考虑添加图片作为唱片
  - 圆形显示视频封面图
- **Acceptance Criteria Addressed**: AC-4
- **Test Requirements**:
  - `human-judgement` TR-4.1: 播放时唱片旋转
  - `human-judgement` TR-4.2: 静音时变红
  - `human-judgement` TR-4.3: 点击切换静音状态
- **File**: `frontend/lib/widgets/video_page_item.dart`
- **Notes**: 这是纯视觉增强，不改变功能逻辑不变

## Task 5: 海报/头像展示区
- **Priority**: P2
- **Depends On**: None
- **Description**:
  - 在按钮列表顶部添加圆形海报展示区
  - 使用视频封面作为图像
  - 直径约 48-56px
  - 可选：点击时播放/暂停视频
- **Implementation Details**:
  - 使用 `ClipOval` 或 `Container(BoxDecoration(shape: BoxShape.circle)`
  - 点击处理播放/暂停
  - 可考虑添加简单的动画播放装饰
- **Acceptance Criteria Addressed**: AC-5
- **Test Requirements**:
  - `human-judgement` TR-5.1: 圆形海报显示正确图像
  - `human-judgement` TR-5.2: 点击播放/暂停
- **File**: `frontend/lib/widgets/video_page_item.dart`
- **Notes**: 可选添加简单的边框和图像

## Task 6: 按钮顺序与布局调整
- **Priority**: P1
- **Depends On**: Tasks 1-5
- **Description**:
  - 调整 `_buildRightActions()` 内的按钮顺序
  - 新顺序（自上而下）：海报/头像 → 点赞 → 信息 → 删除 → 倍速 → 播放模式 → 字幕 → 唱片式静音 → 全屏 → 下一集 → 连播开关
  - 连播开关保留在按钮列表下方或靠近底部的位置
  - 确保各按钮之间有合适间距（20px）
- **Implementation Details**:
  - 重新排列 `_buildRightActions()` 内部按钮顺序
  - 调整间距和对齐
  - 更新相关按钮调用顺序
- **Acceptance Criteria Addressed**: AC-5, AC-7
- **Test Requirements**:
  - `human-judgement` TR-6.1: 按钮顺序与 React 版一致
  - `human-judgement` TR-6.2: 间距合适，视觉美观
- **File**: `frontend/lib/widgets/video_page_item.dart`
- **Notes**: 确保各种状态下（如非纯净模式和纯净模式）都正确显示

## Task 7: 验证与代码审查
- **Priority**: P1
- **Depends On**: Tasks 1-6
- **Description**:
  - 检查所有按钮状态同步
  - 检查功能行为一致性
  - 检查没有编译错误
  - 确认各种状态下按钮显示正确
  - 确认纯净模式下按钮过滤
- **Acceptance Criteria Addressed**: AC-6, AC-7
- **Test Requirements**:
  - `human-judgement` TR-7.1: 所有按钮状态与相关Provider同步
  - `human-judgement` TR-7.2: 功能正常
  - `human-judgement` TR-7.3: 编译无错误
- **File**: `frontend/lib/widgets/video_page_item.dart`
