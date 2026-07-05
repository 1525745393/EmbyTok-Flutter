/// 统一导出所有 Provider
///
/// 导入此文件即可访问整个项目的全局状态：
/// ```dart
/// import 'package:embbytok/providers/providers.dart';
/// ```

// ---- 认证与媒体库 ----
export 'auth_provider.dart';
export 'library_provider.dart';

// ---- 列表与播放控制 ----
export 'video_list_provider.dart';
export 'video_playback_controller.dart';
export 'item_detail_provider.dart';
export 'recommend_provider.dart';

// ---- 收藏与历史 ----
export 'favorites_provider.dart';
export 'favorites_service_provider.dart';
export 'watch_history_provider.dart';
// PR #81：完播率统计
export 'watch_stats_provider.dart';

// ---- 搜索 ----
export 'search_provider.dart';
export 'search_history_provider.dart';
export 'search_hints_provider.dart';

// ---- 主题与偏好 ----
export 'theme_provider.dart';
export 'app_preferences_providers.dart';
export 'user_preferences_provider.dart';
export 'subtitle_settings_provider.dart';
export 'toolbar_visibility_provider.dart';

// ---- 页面导航 ----
export 'page_navigation_provider.dart';

// ---- 演员 ----
export 'actors_provider.dart';
