// 通用组件 barrel 文件
//
// 统一导出 lib/widgets/ 目录下的所有通用组件，
// 避免业务代码中大量分散的 import 语句。
//
// 使用方式：
//   import 'package:embytok_flutter/widgets/widgets.dart';
//
// 视频专用组件请使用：
//   import 'package:embytok_flutter/widgets/video/video.dart';

// 通用状态组件
export 'empty_state_card.dart';
export 'error_state_card.dart';
export 'loading_state_card.dart';

// 通用业务组件
export 'library_selector.dart';
export 'person_avatar_image.dart';
export 'poster_grid_view.dart';
export 'tv_focusable.dart';
