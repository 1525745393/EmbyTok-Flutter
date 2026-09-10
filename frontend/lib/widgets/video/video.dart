// 视频专用组件 barrel 文件
//
// 统一导出 lib/widgets/video/ 目录下的所有视频专用组件。
//
// 使用方式：
//   import 'package:embytok_flutter/widgets/video/video.dart';

// 视频播放器相关
export 'video_player_widget.dart';
export 'video_controls.dart';
export 'video_page_item.dart';
export 'video_grid_card.dart';

// 字幕相关
export 'subtitle_controls.dart';
export 'subtitle_renderer.dart';
export 'subtitle_selector.dart';
export 'subtitle_widget.dart';

// 手势与交互
export 'gesture_overlay.dart';
export 'video_gesture_mixin.dart';

// 工具栏与动画
export 'top_tool_bar.dart';
export 'heart_animation.dart';

// 视频工具
// 注意：hide showSubtitleSelector 避免与 subtitle_selector.dart 中的同名函数冲突
// video_sheet_utils.dart 中的 showSubtitleSelector 是依赖 provider 的包装版本，
// 需要使用时请直接 import 'video_sheet_utils.dart'
export 'video_sheet_utils.dart' hide showSubtitleSelector;
export 'video_action_button.dart';
export 'video_control_buttons.dart';
export 'video_draggable_clean_actions.dart';
export 'video_progress_bars.dart';
