// 统一导出所有 Provider

import '../services/embbytok_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// EmbytokService 全局 Provider
final embytokServiceProvider = Provider<EmbytokService>((ref) {
  return EmbytokService();
});

export 'auth_provider.dart';
export 'library_provider.dart';
export 'video_list_provider.dart';
export 'favorites_provider.dart';
export 'search_provider.dart';
export 'theme_provider.dart';
export 'watch_history_provider.dart';
export 'video_playback_controller.dart';
export 'subtitle_settings_provider.dart';
export 'user_preferences_provider.dart';
export 'search_history_provider.dart';
export 'item_detail_provider.dart';
