# UI 界面颜色与主题一致性修复 - 任务分解

## [ ] 任务 1：用户认证与设置界面颜色修复
- **优先级**：P0
- **依赖**：无
- **描述**：
  - `views/login_view.dart`（登录界面）：替换 `colors.dart` 引用，修复 `Colors.white70`、`Colors.grey[900]` 等
  - `views/settings_view.dart`（设置界面）：替换 `backgroundColor`、`textPrimary`、`historyPink`、`textSecondary` 等，为长文本添加 `maxLines`/`ellipsis`
  - 为两个文件中的硬编码 `fontSize` 改为响应式
- **验收标准覆盖**：FR-1, FR-2, FR-3, FR-4, FR-5, FR-6
- **测试要求**：
  - `programmatic` TR-1.1：`flutter analyze` 对修改文件无错误
  - `human-judgment` TR-1.2：在设置中切换为亮色主题，检查登录/设置界面文字是否可读
- **说明**：登录/设置是用户必经之路，优先修复可以最早暴露主题切换问题

## [ ] 任务 2：首页与搜索界面颜色修复
- **优先级**：P0
- **依赖**：无
- **描述**：
  - `views/home_scaffold.dart`（首页外壳）：替换 `backgroundColor`、`textPrimary`、`textTertiary`
  - `views/search_view.dart`（搜索界面）：替换 `colors.dart` 引用、`Colors.white`、`Colors.white70`、`Colors.black54`；添加响应式字体
  - `views/feed_view.dart`（视频流）：替换 `Colors.white`、`Colors.white70`、`Colors.black54`、`Colors.black87`、`Color(0xFF...)`；为视频标题、简介添加 `maxLines`/`ellipsis`；改用响应式字号
- **验收标准覆盖**：FR-1, FR-2, FR-3, FR-4, FR-5
- **测试要求**：
  - `programmatic` TR-2.1：`flutter analyze` 通过，无 `Colors.white` 等残留
  - `human-judgment` TR-2.2：首页/搜索/视频流在亮色主题下文字可读，视频流长标题不溢出
- **说明**：首页是用户核心浏览路径，`Colors.black54` 在亮色模式下会导致阴影消失

## [ ] 任务 3：媒体库与视频列表视图颜色修复
- **优先级**：P0
- **依赖**：无
- **描述**：
  - `views/video_grid_view.dart`：替换颜色常量、硬编码 `fontSize`
  - `widgets/video_grid_card.dart`：替换颜色常量；添加响应式字号；为视频标题添加 `maxLines`
  - `widgets/poster_grid_view.dart`：替换 `Colors.white`、`Colors.transparent`、`Colors.black.withOpacity()`；为文本添加溢出处理
  - `widgets/library_selector.dart`：替换 `Colors.white54`、`Color(0xFFE91E63)`、`Colors.white38`、`Colors.white`；统一为 colorScheme
- **验收标准覆盖**：FR-1, FR-2, FR-3, FR-4, FR-5
- **测试要求**：
  - `programmatic` TR-3.1：`flutter analyze` 通过，`grep -c "Color(0x"` 结果为 0
  - `human-judgment` TR-3.2：列表视图在亮色主题下文字可读，卡片视觉风格与整体一致

## [ ] 任务 4：详情页颜色修复（3 个视图）
- **优先级**：P0
- **依赖**：无
- **描述**：
  - `views/item_detail_view.dart`：替换全部 `colors.dart` 常量（`primaryPink`、`textPrimary`、`textSecondary`、`textTertiary`、`dividerColor`、`grey800`、`Color(0x1AFFFFFF)` 等），为简介/标签/标题添加 `maxLines`/`ellipsis`；硬编码 `fontSize` 改为响应式
  - `views/boxset_detail_view.dart`：替换颜色常量、`Colors.white`，为长文本添加溢出处理，响应式字号
  - `views/person_detail_view.dart`：替换颜色常量、`Colors.white`，为长文本添加溢出处理，响应式字号
- **验收标准覆盖**：FR-1, FR-2, FR-3, FR-4, FR-5
- **测试要求**：
  - `programmatic` TR-4.1：`flutter analyze` 通过
  - `human-judgment` TR-4.2：3 种详情页在亮色主题下标题、简介、标签等全部可读

## [ ] 任务 5：历史与收藏视图颜色修复
- **优先级**：P1
- **依赖**：无
- **描述**：
  - `views/history_view.dart`：替换颜色常量、`Colors.white`、硬编码 `fontSize`；为标题添加 `maxLines`/`ellipsis`
  - `views/favorites_view.dart`：替换颜色常量、`Colors.white`、硬编码 `fontSize`；为标题添加 `maxLines`/`ellipsis`
- **验收标准覆盖**：FR-1, FR-2, FR-3, FR-4, FR-5
- **测试要求**：
  - `programmatic` TR-5.1：`flutter analyze` 通过
  - `human-judgment` TR-5.2：历史/收藏列表在亮色主题下文字可读

## [ ] 任务 6：TV 模式根视图与工具栏颜色修复
- **优先级**：P1
- **依赖**：无
- **描述**：
  - `views/tv_root_view.dart`：替换颜色常量、硬编码 `fontSize`
  - `widgets/top_tool_bar.dart`：替换颜色常量、硬编码 `fontSize`
  - `widgets/tv_focusable.dart`：替换 `Colors.transparent` 等
- **验收标准覆盖**：FR-1, FR-2, FR-4
- **测试要求**：
  - `programmatic` TR-6.1：`flutter analyze` 通过
  - `human-judgment` TR-6.2：TV 焦点高亮在亮色/暗色主题下都清晰可见

## [ ] 任务 7：视频播放组件颜色修复（核心复杂）
- **优先级**：P0
- **依赖**：无
- **描述**：
  - `widgets/video_page_item.dart`：替换 `colors.dart` 常量、`Colors.transparent`、`Colors.red` 等；保持已有 `responsiveSize` 模式，补充缺失的响应式调用
  - `widgets/video_player_widget.dart`：替换 `Colors.white70`、`Colors.black54`、`Colors.grey[900]` 等
  - `widgets/video_controls.dart`：替换颜色常量、`Colors.transparent`、硬编码 `fontSize`
  - `widgets/gesture_overlay.dart`：替换 `Colors.white`、`Colors.black54`、`Colors.transparent` 等
  - `widgets/video/video_action_button.dart`：替换 `Colors.transparent`
  - `widgets/video/video_control_buttons.dart`：替换颜色常量、`Colors.transparent`；保持 `responsiveSize` 风格
  - `widgets/video/video_progress_bars.dart`：替换颜色常量；响应式字号
  - `widgets/video/video_sheet_utils.dart`：替换颜色常量、`Colors.transparent`；响应式字号
  - `widgets/video/video_draggable_clean_actions.dart`：替换颜色常量
- **验收标准覆盖**：FR-1, FR-2, FR-3, FR-4
- **测试要求**：
  - `programmatic` TR-7.1：`flutter analyze` 通过
  - `human-judgment` TR-7.2：播放界面在亮色/暗色主题下按钮、进度条、速度提示、字幕等全部正确显示
- **说明**：这是最复杂的一组，包含文件最多；`video_page_item.dart` 已部分使用 `colorScheme`，需要全面检查

## [ ] 任务 8：字幕组件与工具类颜色修复
- **优先级**：P1
- **依赖**：无
- **描述**：
  - `widgets/subtitle_widget.dart`：替换 `Colors.black.withOpacity()`；注意字幕在视频上方的特殊视觉需求（可能需要独立策略，但暂先用主题色）
  - `widgets/subtitle_renderer.dart`：替换 `Colors.black54`、`Colors.black87`
  - `widgets/subtitle_selector.dart`：替换颜色常量、`Colors.transparent`；响应式字号
  - `widgets/subtitle_controls.dart`：替换颜色常量、硬编码 `fontSize`
  - `utils/keyboard_shortcuts.dart`：替换 `Color(0xFFE91E63)`、`Colors.white`、`Colors.white70`、`Colors.black87` 等
- **验收标准覆盖**：FR-1, FR-2, FR-3, FR-4, FR-5
- **测试要求**：
  - `programmatic` TR-8.1：`flutter analyze` 通过
  - `human-judgment` TR-8.2：字幕在亮色/暗色下与视频背景对比度足够

## [ ] 任务 9：状态卡与动画组件颜色修复
- **优先级**：P2
- **依赖**：无
- **描述**：
  - `widgets/error_state_card.dart`：替换颜色常量、硬编码 `fontSize`
  - `widgets/empty_state_card.dart`：替换颜色常量、硬编码 `fontSize`
  - `widgets/heart_animation.dart`：检查主题色使用
- **验收标准覆盖**：FR-1, FR-2, FR-4
- **测试要求**：
  - `programmatic` TR-9.1：`flutter analyze` 通过
  - `human-judgment` TR-9.2：错误/空状态卡片在亮色主题下可读

## [ ] 任务 10：最终清理与构建验证
- **优先级**：P0
- **依赖**：任务 1-9
- **描述**：
  - 全面检查 `grep -rn "colors.dart" lib/`，确保没有遗漏
  - 全面检查 `grep -rn "Colors\.\(white\|black\|grey\|red\)" lib/views lib/widgets`
  - 全面检查 `grep -rn "Color(0x" lib/views lib/widgets`
  - 运行 `flutter analyze` 全量分析
  - 运行一次 `flutter build apk --debug`（或 `flutter build web`）验证构建
- **验收标准覆盖**：AC-1, AC-2, AC-3, AC-6
- **测试要求**：
  - `programmatic` TR-10.1：上述三个 grep 命令在目标目录下无结果（或仅剩合理使用）
  - `programmatic` TR-10.2：`flutter analyze` 返回 0 errors
  - `programmatic` TR-10.3：`flutter build` 成功
- **说明**：此任务是全局验证，需在其他所有任务完成后执行
