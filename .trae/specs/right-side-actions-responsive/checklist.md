# 右侧操作区响应式优化 - Verification Checklist

## 响应式计算核心（Task 1）
- [ ] Checkpoint 1.1: 存在集中管理的响应式尺寸计算方法（如 `_responsiveSize`）或工具类
- [ ] Checkpoint 1.2: `screenWidth <= 480px` 时，缩放因子 = 1.0（即 `_responsiveSize(48)` 返回 48）
- [ ] Checkpoint 1.3: `screenWidth = 800px` 时，缩放因子 ≈ 1.3（即 `_responsiveSize(48)` ≈ 62.4）
- [ ] Checkpoint 1.4: `screenWidth = 1200px` 时，缩放因子 ≈ 1.6（即 `_responsiveSize(48)` ≈ 76.8）
- [ ] Checkpoint 1.5: `screenWidth >= 1920px` 时，缩放因子不超过上限（1.6-1.7，取决于实现）
- [ ] Checkpoint 1.6: 响应式计算方法有简短中文注释说明计算依据

## 主容器响应式（Task 2）
- [ ] Checkpoint 2.1: 主容器宽度不再使用硬编码的 `96`，改为响应式计算
- [ ] Checkpoint 2.2: 主容器内边距（左右、上下）改为响应式计算
- [ ] Checkpoint 2.3: 在 360px 宽屏幕上，主容器宽度视觉上与 96px 一致
- [ ] Checkpoint 2.4: 在 1200px 宽屏幕上，主容器宽度明显增大（约 150-170px）
- [ ] Checkpoint 2.5: 顶部偏移量中的 `56` 和 `40` 也改为响应式计算
- [ ] Checkpoint 2.6: 底部内边距中的 `24` 改为响应式计算

## 圆形按钮响应式（Task 3）
- [ ] Checkpoint 3.1: `_buildDeleteButton()` 中 `width: 48` 改为响应式
- [ ] Checkpoint 3.2: `_buildSpeedControlButton()` 中 `width: 48` 改为响应式
- [ ] Checkpoint 3.3: `_buildPlayModeButton()` 中 `width: 48` 改为响应式
- [ ] Checkpoint 3.4: `_buildSubtitleButton()` 中 `width: 48` 改为响应式
- [ ] Checkpoint 3.5: `_buildDiscMuteButton()` 中 `width: 48` 改为响应式
- [ ] Checkpoint 3.6: 以上按钮内部图标大小（22/24/28）也改为响应式
- [ ] Checkpoint 3.7: 以上按钮边框宽度（2）改为响应式且上限为 3
- [ ] Checkpoint 3.8: 播放模式按钮内部文字大小 10pt 改为响应式且有上限
- [ ] Checkpoint 3.9: 手机端圆形按钮视觉大小与修改前一致
- [ ] Checkpoint 3.10: 桌面端圆形按钮明显增大但不过分

## 海报头像响应式（Task 4）
- [ ] Checkpoint 4.1: `_buildPosterAvatar()` 中外层 `SizedBox(56)` 改为响应式
- [ ] Checkpoint 4.2: 内层 `Container(56)` 改为响应式
- [ ] Checkpoint 4.3: 内嵌 + 号按钮 `Container(22)` 改为响应式
- [ ] Checkpoint 4.4: + 号按钮内部 `Icon size: 14` 改为响应式且有上限
- [ ] Checkpoint 4.5: 手机端海报头像视觉上与修改前一致
- [ ] Checkpoint 4.6: 桌面端海报头像明显增大，+ 号按钮仍保持合理比例

## 通用按钮 `_PressableActionButton` 响应式（Task 5）
- [ ] Checkpoint 5.1: 图标大小 `32` 改为响应式
- [ ] Checkpoint 5.2: 标签文字大小 `12` 改为响应式且有上限（约 14-16）
- [ ] Checkpoint 5.3: 标签与图标间距 `4` 改为响应式且有上限
- [ ] Checkpoint 5.4: 按钮内边距 `EdgeInsets(8, 4)` 改为响应式
- [ ] Checkpoint 5.5: 焦点高亮边框宽度 `2` 改为响应式且有上限
- [ ] Checkpoint 5.6: 圆角 `8` 改为响应式且有上限
- [ ] Checkpoint 5.7: `_PressableActionButton` 为独立 widget，自行管理响应式计算（无需依赖父类方法）
- [ ] Checkpoint 5.8: 手机端通用按钮视觉上与修改前一致
- [ ] Checkpoint 5.9: 桌面端通用按钮图标和文字明显增大，标签仍保持辅助信息的视觉层次
- [ ] Checkpoint 5.10: TV 焦点模式下焦点高亮边框随按钮大小等比放大

## 按钮间距响应式（Task 6）
- [ ] Checkpoint 6.1: `_buildRightActions` 中所有 `const SizedBox(height: 20)` 已替换
- [ ] Checkpoint 6.2: 新间距使用响应式计算，手机端保持 20px
- [ ] Checkpoint 6.3: 桌面端间距适当增大至约 28-32px
- [ ] Checkpoint 6.4: 按钮列在大屏上不拥挤也不过分松散

## 纯净模式按钮区响应式（Task 7）
- [ ] Checkpoint 7.1: `_buildCleanModeRightActions` 中 `buttonWidth: 96.0` 改为响应式
- [ ] Checkpoint 7.2: `_DraggableCleanActions` 能正确接收动态计算的宽度
- [ ] Checkpoint 7.3: 纯净模式下手机端视觉与修改前一致
- [ ] Checkpoint 7.4: 纯净模式下桌面端按钮适当放大

## 代码可维护性（Task 8）
- [ ] Checkpoint 8.1: 响应式计算逻辑集中管理、命名清晰
- [ ] Checkpoint 8.2: 代码中有简短中文注释说明响应式计算依据
- [ ] Checkpoint 8.3: 代码审查时能轻松理解响应式逻辑，无需在多个方法间跳转
- [ ] Checkpoint 8.4: `flutter analyze lib/widgets/video_page_item.dart` 不产生新的 error 或 warning

## 跨尺寸视觉验证（Task 10）
- [ ] Checkpoint 10.1: 标准手机（360×640）上视觉正常，与修改前一致或几乎一致
- [ ] Checkpoint 10.2: 大屏手机（480×800）上按钮和容器适当放大
- [ ] Checkpoint 10.3: 平板（768×1024）上按钮和容器明显放大，点击目标更舒适
- [ ] Checkpoint 10.4: 桌面横屏（1280×720）上按钮和容器显著放大，视觉平衡良好
- [ ] Checkpoint 10.5: 全高清桌面（1920×1080）上按钮和容器达到上限放大比例，视觉平衡
- [ ] Checkpoint 10.6: 使用 Widget Inspector，无布局溢出（overflow）警告
- [ ] Checkpoint 10.7: 按钮列与底部信息条、中央播放按钮之间无重叠
- [ ] Checkpoint 10.8: 所有按钮完整可见，无被裁剪或溢出情况
- [ ] Checkpoint 10.9: TV 焦点模式下，焦点移动到各按钮时边框正确显示且尺寸协调
- [ ] Checkpoint 10.10: 纯净模式（isAutoPlay=true）下连播按钮和倍速按钮正确显示

## 功能不变性验证
- [ ] Checkpoint F1: 点击按钮的行为与修改前完全一致（点赞、删除、倍速、信息等功能无变化）
- [ ] Checkpoint F2: 键盘快捷键（空格键暂停/播放、方向键等）功能正常
- [ ] Checkpoint F3: 播放状态变化时唱片旋转动画正常工作
- [ ] Checkpoint F4: 视频加载状态下骨架显示正常

## 可选增强（Task 9，如实现）
- [ ] Checkpoint 9.1: 中央播放按钮容器宽度 72 改为响应式
- [ ] Checkpoint 9.2: 中央播放按钮图标大小 48 改为响应式
- [ ] Checkpoint 9.3: 在大屏上中央按钮与右侧操作区按钮视觉上协调
