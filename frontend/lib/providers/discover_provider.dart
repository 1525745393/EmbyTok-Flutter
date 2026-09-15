// 发现数据源 Provider（PRD：视频库首页顶栏「发现」）
//
// 对接 Emby 标签（Genres）：用户可在设置中自行选择感兴趣的标签，
// 发现页按所选标签逐个拉取影片并合并去重展示。
//
// - 数据源：Emby /Genres（类型列表）+ /Items?Genres=<名>（类型下影片）
// - 存储：SharedPreferences，按当前账号分桶（accountScopedKey）
// - 未配置标签时：返回空列表，页面展示引导用户去设置

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';
import 'cache_providers.dart';
import 'syno_accounts_provider.dart';

/// 发现页状态
class DiscoverState {
  const DiscoverState({
    this.genres = const [],
    this.selectedGenreIds = const [],
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Library> genres; // 服务器全量类型（供设置多选）
  final List<String> selectedGenreIds; // 用户已选类型 id
  final List<MediaItem> items; // 合并后的发现内容
  final bool isLoading;
  final String? error;

  DiscoverState copyWith({
    List<Library>? genres,
    List<String>? selectedGenreIds,
    List<MediaItem>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return DiscoverState(
      genres: genres ?? this.genres,
      selectedGenreIds: selectedGenreIds ?? this.selectedGenreIds,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 发现 Notifier
class DiscoverNotifier extends StateNotifier<DiscoverState> {
  DiscoverNotifier(this._ref) : super(const DiscoverState()) {
    _init();
  }
  final Ref _ref;

  static const String _kStorageKey = kStorageKeyDiscoverGenres;
  static const int _kPerGenreLimit = 30;

  AuthState get _auth => _ref.read(authProvider);

  Future<void> _init() async {
    // 读取用户已选标签
    await _loadSelection();
    // 拉取服务器类型列表（供设置页展示 + 名称解析）
    await refreshGenres();
    // 自动加载已选标签内容
    if (state.selectedGenreIds.isNotEmpty) {
      await load();
    }
  }

  Future<void> _loadSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await accountScopedKey(_kStorageKey);
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        state = state.copyWith(
          selectedGenreIds: decoded.whereType<String>().toList(),
        );
      }
    } catch (e) {
      AppLogger.error('读取发现标签配置失败', error: e);
    }
  }

  /// 拉取服务器类型列表
  Future<void> refreshGenres() async {
    final auth = _auth;
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    if (!auth.isAuthenticated || serverUrl == null || token == null) {
      return;
    }
    try {
      final repo = _ref.read(cachedMediaRepositoryProvider);
      final genres = await repo.getGenres(
        serverUrl: serverUrl,
        token: token,
      );
      state = state.copyWith(genres: genres);
    } catch (e) {
      AppLogger.error('发现：加载类型列表失败', error: e);
    }
  }

  /// 保存用户选择的标签（id 列表）并加载内容
  Future<void> saveSelection(List<String> genreIds) async {
    state = state.copyWith(selectedGenreIds: genreIds);
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await accountScopedKey(_kStorageKey);
      await prefs.setString(key, jsonEncode(genreIds));
    } catch (e) {
      AppLogger.error('保存发现标签配置失败', error: e);
    }
    await load();
  }

  /// 按已选标签拉取影片，合并去重
  Future<void> load() async {
    final auth = _auth;
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    if (!auth.isAuthenticated || serverUrl == null || token == null) {
      state = state.copyWith(isLoading: false, error: '尚未登录');
      return;
    }
    final selectedIds = state.selectedGenreIds;
    if (selectedIds.isEmpty) {
      state = state.copyWith(isLoading: false, items: const []);
      return;
    }
    // 用已拉到的类型列表把 id 解析成名称（getItemsByGenre 按名称查询）
    // 若类型列表还没拉到，先用 id 兜底（部分服务器 id 即名称）
    final idToName = <String, String>{
      for (final g in state.genres) g.id: g.name,
    };
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _ref.read(cachedMediaRepositoryProvider);
      final merged = <String, MediaItem>{};
      for (final id in selectedIds) {
        final name = idToName[id] ?? id;
        try {
          final page = await repo.getItemsByGenre(
            name,
            limit: _kPerGenreLimit,
            offset: 0,
            serverUrl: serverUrl,
            token: token,
          );
          for (final item in page.items) {
            merged[item.id] = item;
          }
        } catch (e) {
          AppLogger.error('发现：拉取类型内容失败',
              data: {'genre': name}, error: e);
        }
      }
      final items = merged.values.toList();
      // 按生产年份倒序，新片在前
      items.sort((a, b) => (b.productionYear ?? 0).compareTo(a.productionYear ?? 0));
      state = state.copyWith(items: items, isLoading: false, error: null);
    } catch (e) {
      AppLogger.error('发现：加载失败', error: e);
      state = state.copyWith(isLoading: false, error: '加载失败：$e');
    }
  }

  /// 清除错误
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null, clearError: true);
    }
  }
}

final discoverProvider =
    StateNotifierProvider<DiscoverNotifier, DiscoverState>(
        (ref) => DiscoverNotifier(ref));
