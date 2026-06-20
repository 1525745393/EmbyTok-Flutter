// 媒体库列表 & 当前选中的媒体库 ID 列表（多选）
// 功能：
// 1. libraryListProvider: 从 Emby 获取媒体库列表
// 2. visibleLibraryListProvider: 根据 hiddenLibraryIds 过滤后的可见媒体库列表
// 3. selectedLibraryIdsProvider: 当前选中的媒体库 ID 列表（多选，媒体库加载后自动全选可见的）
// 4. selectedLibrariesProvider: 当前选中的所有 Library 对象

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
      userId: auth.user?.id,
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

/// 当前选中的媒体库 ID 列表（支持多选，媒体库加载后自动全选可见的）
///
/// 在 [VideoListNotifier] 中监听此 Provider 的变化来触发对应库的视频加载。
final selectedLibraryIdsProvider =
    StateNotifierProvider<SelectedLibraryNotifier, List<String>>(
  (ref) => SelectedLibraryNotifier(ref),
);

class SelectedLibraryNotifier extends StateNotifier<List<String>> {
  final Ref _ref;

  SelectedLibraryNotifier(this._ref) : super(const <String>[]) {
    // 监听媒体库列表变化，首次加载时自动全选可见媒体库
    _ref.listen<AsyncValue<List<Library>>>(
      libraryListProvider,
      (previous, next) {
        next.whenData((libraries) {
          final hiddenIds = _ref.read(hiddenLibraryIdsProvider);
          final visible = libraries
              .where((lib) => !hiddenIds.contains(lib.id))
              .toList();
          // 如果当前没有选择，自动全选可见媒体库
          if (state.isEmpty && visible.isNotEmpty) {
            state = visible.map((lib) => lib.id).toList();
          } else if (state.isNotEmpty) {
            // 如果当前选择的媒体库中没有一个存在于可见列表中，重新全选
            final stillExists = visible.any((lib) => state.contains(lib.id));
            if (!stillExists && visible.isNotEmpty) {
              state = visible.map((lib) => lib.id).toList();
            }
          }
        });
      },
    );
  }

  /// 切换单个媒体库的选中状态
  void toggleLibrary(String libraryId) {
    if (state.contains(libraryId)) {
      // 取消选中，但至少保留一个
      final newList = state.where((id) => id != libraryId).toList();
      state = newList.isNotEmpty ? newList : const <String>[];
    } else {
      // 添加选中
      state = <String>[...state, libraryId];
    }
  }

  /// 手动设置为单个媒体库（用于 chips 单击快捷切换）
  void setLibrary(String libraryId) {
    state = <String>[libraryId];
  }

  /// 设置为指定的 ID 列表
  void setLibraries(List<String> libraryIds) {
    state = libraryIds;
  }

  /// 全选可见媒体库
  void selectAll(List<Library> visibleLibraries) {
    state = visibleLibraries.map((lib) => lib.id).toList();
  }

  /// 清空选择
  void clear() {
    state = const <String>[];
  }
}

// 当前选中的第一个 Library 对象（供 UI 显示名称等）
// 多选模式下返回第一个选中的媒体库
final selectedLibraryProvider = Provider<Library?>((ref) {
  final libraries = ref.watch(visibleLibraryListProvider);
  final selectedIds = ref.watch(selectedLibraryIdsProvider);
  if (selectedIds.isEmpty) return null;
  final firstId = selectedIds.first;
  return libraries.where((lib) => lib.id == firstId).firstOrNull;
});

// 当前选中的所有 Library 对象（供 UI 使用）
final selectedLibrariesProvider = Provider<List<Library>>((ref) {
  final libraries = ref.watch(visibleLibraryListProvider);
  final selectedIds = ref.watch(selectedLibraryIdsProvider);
  if (selectedIds.isEmpty) return const <Library>[];
  return libraries.where((lib) => selectedIds.contains(lib.id)).toList();
});
