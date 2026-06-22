# TikTok 风格播放体验统一 Spec

## Why
当前 EmbyTok 的视频播放界面已具备 TikTok 风格的基础骨架（右侧操作按钮列、底部标题信息、手势交互），但存在三个关键差距：
1. **方向适配不完整**：横屏视频在竖屏设备上播放时，画面被 `BoxFit.cover` 强制裁剪，丢失内容；用户无法在播放过程中切换横屏/竖屏沉浸视图
2. **播放控制缺失**：`VideoControls` 组件已存在但未接入 `VideoPageItem`，用户无法看到播放进度条、当前时间、总时长，也无法通过点击进度条跳转
3. **UI 细节与 TikTok 不一致**：缺少底部细线进度条（TikTok 标志性元素）、播放/暂停中央按钮、自动隐藏控制层逻辑

## What Changes
- **横屏视频沉浸播放**：横屏视频点击全屏按钮 → 强制设备横屏 + 16:9 容器 + 居中显示；竖屏视频保持当前竖屏沉浸
- **接入 VideoControls**：在 `VideoPageItem` 底部叠加 `VideoControls`，显示进度条/时间/倍速
- **TikTok 风格底部进度条**：在视频画面最底部添加 2px 高的细线进度条（始终可见，非拖动状态）
- **中央播放/暂停按钮**：暂停时画面中央显示大号半透明播放图标，点击恢复播放
- **控制层自动隐藏**：3 秒无操作自动隐藏控制层（进度条+按钮），单击切换显示/隐藏
- **方向锁定按钮**：右侧操作列新增"全屏"按钮，点击切换横屏/竖屏沉浸模式

## Impact
- Affected specs: `video-player-redesign`（已完成，本次在其基础上增强）、`ux-immersion-v1`（已完成）
- Affected code:
  - `frontend/lib/widgets/video_page_item.dart`（主要修改：接入控制层、方向切换、底部进度条）
  - `frontend/lib/widgets/video_player_widget.dart`（修改：BoxFit 策略根据视频方向动态调整）
  - `frontend/lib/widgets/video_controls.dart`（修改：样式调整为 TikTok 风格半透明）
  - `frontend/lib/widgets/gesture_overlay.dart`（修改：单击逻辑改为切换控制层显示/隐藏）
  - `frontend/lib/views/feed_view.dart`（修改：横屏沉浸模式下的布局调整）

## ADDED Requirements

### Requirement: 横屏视频沉浸播放
系统 SHALL 在用户点击"全屏"按钮时，强制设备进入横屏模式，并以 16:9 容器居中显示横屏视频，避免画面被裁剪。

#### Scenario: 横屏视频全屏播放
- **WHEN** 用户点击右侧"全屏"按钮
- **THEN** 设备切换到横屏方向
- **AND** 视频以原始宽高比居中显示（黑色填充上下空白）
- **AND** 顶部工具栏和底部导航栏隐藏
- **WHEN** 用户再次点击"全屏"按钮或按返回键
- **THEN** 设备恢复竖屏方向
- **AND** 恢复正常 TikTok 风格布局

### Requirement: TikTok 风格底部进度条
系统 SHALL 在视频画面最底部显示一条 2px 高的细线进度条，始终可见（非拖动状态），颜色为品牌粉色。

#### Scenario: 进度条显示
- **WHEN** 视频开始播放
- **THEN** 画面底部显示细线进度条（高度 2px，宽度 = 视频画面宽度）
- **AND** 进度条颜色为 `primaryPink`（#E91E63）
- **AND** 背景为半透明黑色（alpha 0.3）

### Requirement: 中央播放/暂停按钮
系统 SHALL 在视频暂停时于画面中央显示大号半透明播放图标，点击恢复播放。

#### Scenario: 暂停状态显示播放按钮
- **WHEN** 视频处于暂停状态
- **THEN** 画面中央显示半透明圆形播放图标（直径 72dp，alpha 0.6）
- **WHEN** 用户点击中央播放按钮
- **THEN** 视频恢复播放
- **AND** 中央按钮淡出消失（200ms）

### Requirement: 控制层自动隐藏
系统 SHALL 在 3 秒无用户操作后自动隐藏播放控制层（进度条、时间、倍速），仅保留底部细线进度条。

#### Scenario: 自动隐藏
- **WHEN** 控制层显示且 3 秒内无任何用户操作
- **THEN** 控制层淡出隐藏（300ms）
- **WHEN** 用户单击画面
- **THEN** 控制层淡入显示（200ms）
- **AND** 重置 3 秒计时器

## MODIFIED Requirements

### Requirement: 单击手势行为
原行为：单击切换播放/暂停。
新行为：单击切换控制层显示/隐藏；控制层显示时单击隐藏，控制层隐藏时单击显示。播放/暂停改由中央按钮或控制层内的播放按钮负责。

### Requirement: 视频画面填充策略
原行为：统一使用 `BoxFit.cover` 强制裁剪填满。
新行为：
- 竖屏视频：`BoxFit.cover`（保持当前行为，填满竖屏）
- 横屏视频（竖屏模式下）：`BoxFit.contain`（完整显示，上下黑色填充）
- 横屏视频（横屏沉浸模式下）：`BoxFit.contain`（完整显示，居中）

## REMOVED Requirements
无（所有现有功能保留，仅增强）
