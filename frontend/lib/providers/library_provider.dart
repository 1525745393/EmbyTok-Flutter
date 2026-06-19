// 媒体库列表 & 当前选中的媒体库 ID
// 功能：
// 1. libraryListProvider: 从 Emby 获取媒体库列表（FutureProvider）
// 2. visibleLibraryListProvider: 根据 hiddenLibraryIds 过滤后的可见媒体库列表
// 3. selectedLibraryIdProvider: 当前选中的媒体库 ID（自动选择第一个可见）
// 4. selectedLibraryProvider: 当前选中的 Library 对象（供 UI 显示名称）

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/logger.dart';
import 'app_preferences_providers.dart';
import 'auth_provider.dart';

// ==================== 基础数据 Provider ====================

/// 媒体库列表：从 Emby 服务器获取全部媒体库（电影 / 剧集 / 音乐等）
///
/// 登录后自动加载，未登录返回空列表。
final libraryListProvider = FutureProvider<List<Library>>((ref) async {
  final auth = ref.watch(authProvider);
  final serverUrl = auth.embyServerUrl;
  final token = auth.token;

  if (!auth.isAuthenticated || serverUrl == null || token == null) {
    return const <Library>[];
  }

  final service = EmbytokService();
  try {
    AppLogger.info('开始加载媒体库列表');
    final libraries = await service.getLibraries(
      serverUrl: serverUrl,
      token: token,
    );
    AppLogger.info('媒体库列表加载成功', data: {'count': libraries.length});
    return libraries;
  } catch (e) {
    AppLogger.error('加载媒体库失败', error: e);
    final message = e is String ? e : '获取媒体库失败：$e';
    throw message;
  }
});

/// 过滤后的可见媒体库列表（排除用户在设置中隐藏的媒体库）
final visibleLibraryListProvider = Provider<List<Library>>((ref) {
  final librariesAsync = ref.watch(libraryListProvider);
  final hiddenIds = ref.watch(hiddenLibraryIdsProvider);
  return librariesAsync.when(
    data: (libraries) =>
        libraries.where((lib) => !hiddenIds.contains(lib.id)).toList(),
    loading: () => const <Library>[],
    error: (_, __) => const <Library>[],
  );
});

// ==================== 选择状态 Provider ====================

/// 当前选中的媒体库 ID（媒体库列表加载后自动选择第一个可见的）
///
/// 在 [VideoListNotifier] 中监听此 Provider 的变化来触发对应库的视频加载。
final selectedLibraryIdProvider =
    StateNotifierProvider<SelectedLibraryNotifier, String?>(
  (ref) => SelectedLibraryNotifier(ref),
);

class SelectedLibraryNotifier extends StateNotifier<String?> {
  final Ref _ref;

  SelectedLibraryNotifier(this._ref) : super(null) {
    // 监听媒体库列表变化，自动选择第一个可见的媒体库
    _ref.listen<AsyncValue<List<Library>>>(
      libraryListProvider,
      (previous, next) {
        next.whenData((libraries) {
          final hiddenIds = _ref.read(hiddenLibraryIdsProvider);
          final visible = libraries
              .where((lib) => !hiddenIds.contains(lib.id))
              .toList();
          // 如果当前没有选择，自动选择第一个可见的
          if (state == null && visible.isNotEmpty) {
            state = visible.first.id;
          } else if (state != null) {
            // 如果当前选择的媒体库不存在于可见列表中，重新选择第一个
            final stillExists = visible.any((lib) => lib.id == state);
            if (!stillExists && visible.isNotEmpty) {
              state = visible.first.id;
            }
          }
        });
      },
    );
  }

  // 手动设置媒体库
  void setLibrary(String libraryId) {
    state = libraryId;
  }
}

// 当前选中的 Library 对象（用于 UI 显示名称）
final selectedLibraryProvider = Provider<Library?>((ref) {
  final libraries = ref.watch(visibleLibraryListProvider);
  final selectedId = ref.watch(selectedLibraryIdProvider);
  if (selectedId == null) return null;
  try {
    return libraries.firstWhere((lib) => lib.id == selectedId);
  } catch (_) {
    return null;
  }
});
