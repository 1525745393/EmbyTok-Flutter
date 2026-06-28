// 媒体库列表 & 当前选中的媒体库 ID 列表（多选）
// 功能：
// 1. libraryListProvider: 从 Emby 获取媒体库列表
// 2. visibleLibraryListProvider: 根据 hiddenLibraryIds 过滤后的可见媒体库列表
// 3. selectedLibraryIdsProvider: 当前选中的媒体库 ID 列表（多选，媒体库加载后自动全选可见的）
// 4. selectedLibrariesProvider: 当前选中的所有 Library 对象

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/constants.dart';
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
  // 持久化 key：默认视频流用原 key；推荐页传自定义 key（PR #66）
  final String _storageKey;

  SelectedLibraryNotifier(this._ref, {String? storageKey})
      : _storageKey = storageKey ?? kStorageKeySelectedLibraryId,
        super(const <String>[]) {
    // 从 SharedPreferences 恢复上次选中的媒体库
    _loadSaved();
    // 监听媒体库列表变化，首次加载时自动选中（优先恢复上次选择）
    _ref.listen<AsyncValue<List<Library>>>(
      libraryListProvider,
      (previous, next) {
        next.whenData((libraries) {
          final hiddenIds = _ref.read(hiddenLibraryIdsProvider);
          final visible = libraries
              .where((lib) => !hiddenIds.contains(lib.id))
              .toList();
          if (visible.isEmpty) return;
          // 如果当前没有选择，优先恢复上次保存的，否则选第一个
          if (state.isEmpty) {
            final savedId = _savedLibraryId;
            if (savedId != null && visible.any((lib) => lib.id == savedId)) {
              state = <String>[savedId];
            } else {
              state = <String>[visible.first.id];
            }
          } else {
            // 如果当前选择的媒体库中没有一个存在于可见列表中，重新选择
            final stillExists = visible.any((lib) => state.contains(lib.id));
            if (!stillExists) {
              final savedId = _savedLibraryId;
              if (savedId != null && visible.any((lib) => lib.id == savedId)) {
                state = <String>[savedId];
              } else {
                state = <String>[visible.first.id];
              }
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
    _saveLibraryId(libraryId);
  }

  /// 设置为指定的 ID 列表
  void setLibraries(List<String> libraryIds) {
    state = libraryIds;
    if (libraryIds.isNotEmpty) _saveLibraryId(libraryIds.first);
  }

  // ========== 持久化 ==========

  String? _savedLibraryId;

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedLibraryId = prefs.getString(_storageKey);
    } catch (_) {}
  }

  Future<void> _saveLibraryId(String id) async {
    _savedLibraryId = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, id);
    } catch (_) {}
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

// ==================== 推荐独立媒体库（PR #66 新增）====================
//
// 背景：之前视频流和推荐共用 selectedLibraryIdsProvider，
//       但用户希望两者可以分别选媒体库（例如视频流用「电影」库，
//       推荐用「全部」库混合评分推荐）。
//
// 设计：复用 SelectedLibraryNotifier，单独持久化 key。

/// 推荐页选中的媒体库 ID 列表
final recommendLibraryIdsProvider =
    StateNotifierProvider<SelectedLibraryNotifier, List<String>>(
  (ref) => SelectedLibraryNotifier(
    ref,
    storageKey: kStorageKeySelectedLibraryIdForRecommend,
  ),
);

/// 推荐选中的所有 Library 对象
final recommendLibrariesProvider = Provider<List<Library>>((ref) {
  final libraries = ref.watch(visibleLibraryListProvider);
  final selectedIds = ref.watch(recommendLibraryIdsProvider);
  if (selectedIds.isEmpty) return const <Library>[];
  return libraries.where((lib) => selectedIds.contains(lib.id)).toList();
});

// ==================== 首次配置标记（PR #66 新增）====================
//
// 设计：用户首次进入「视频流」/「推荐」页面时，如果对应媒体库还没配置过，
//       自动弹 LibrarySelector 让用户必须选一次。点过「确认」就标记为已配置。
//
// 持久化：SharedPreferences bool 字段。
//         - 老用户已用过视频流：feedLibraryConfigured = true（不弹）
//         - 老用户可能没用过推荐：recommendLibraryConfigured = false（首次进推荐页会弹）

class _BoolConfigNotifier extends StateNotifier<bool> {
  _BoolConfigNotifier(this._storageKey) : super(false) {
    _load();
  }

  final String _storageKey;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_storageKey) ?? false;
    } catch (_) {}
  }

  Future<void> set(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, value);
    } catch (_) {}
  }
}

/// 视频流媒体库是否已配置（首次进入 /recommend /feed 前检测）
final feedLibraryConfiguredProvider =
    StateNotifierProvider<_BoolConfigNotifier, bool>(
  (ref) => _BoolConfigNotifier(kStorageKeyFeedLibraryConfigured),
);

/// 推荐页媒体库是否已配置
final recommendLibraryConfiguredProvider =
    StateNotifierProvider<_BoolConfigNotifier, bool>(
  (ref) => _BoolConfigNotifier(kStorageKeyRecommendLibraryConfigured),
);
