// 发现数据源 Provider（PRD：视频库首页顶栏「发现」）
//
// 对接 Emby 合集（BoxSet Collections）+ 类型（Genres）+ 标签（Tags）：用户可在设置中
// 分别选择感兴趣的合集、类型与标签，发现页按所选条目逐个拉取影片并合并去重展示。
//
// - 数据源：
//   · 合集：/Items?IncludeItemTypes=BoxSet（合集列表）+ /Items?ParentId=<合集id>（合集内视频）
//   · 类型：/Genres（类型列表）+ /Items?Genres=<名>（类型下影片）
//   · 标签：/Tags（标签列表）+ /Items?Tags=<名>（标签下影片）
// - 存储：SharedPreferences，按当前账号分桶（accountScopedKey），类型/标签/合集分开保存
// - 未配置任何条目时：返回空列表，页面展示引导用户去设置

import 'dart:async';
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
    this.tags = const [],
    this.selectedTagIds = const [],
    this.collections = const [],
    this.selectedCollectionIds = const [],
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Library> genres; // 服务器全量类型（供设置多选）
  final List<String> selectedGenreIds; // 用户已选类型 id
  final List<Library> tags; // 服务器全量标签（供设置多选）
  final List<String> selectedTagIds; // 用户已选标签 id
  final List<Library> collections; // 服务器全量合集（供设置多选）
  final List<String> selectedCollectionIds; // 用户已选合集 id
  final List<MediaItem> items; // 合并后的发现内容
  final bool isLoading;
  final String? error;

  /// 是否已配置任何发现来源（类型、标签或合集）
  bool get hasSelection =>
      selectedGenreIds.isNotEmpty ||
      selectedTagIds.isNotEmpty ||
      selectedCollectionIds.isNotEmpty;

  DiscoverState copyWith({
    List<Library>? genres,
    List<String>? selectedGenreIds,
    List<Library>? tags,
    List<String>? selectedTagIds,
    List<Library>? collections,
    List<String>? selectedCollectionIds,
    List<MediaItem>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return DiscoverState(
      genres: genres ?? this.genres,
      selectedGenreIds: selectedGenreIds ?? this.selectedGenreIds,
      tags: tags ?? this.tags,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      collections: collections ?? this.collections,
      selectedCollectionIds:
          selectedCollectionIds ?? this.selectedCollectionIds,
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

  static const String _kStorageGenresKey = kStorageKeyDiscoverGenres;
  static const String _kStorageTagsKey = kStorageKeyDiscoverTags;
  static const String _kStorageCollectionsKey = kStorageKeyDiscoverCollections;
  static const int _kPerSourceLimit = 30;

  Timer? _loadDebounce;

  AuthState get _auth => _ref.read(authProvider);

  Future<void> _init() async {
    // 读取用户已选类型、标签与合集
    await _loadSelection();
    // 拉取服务器类型/标签/合集列表（供设置页展示 + 名称解析）
    await Future.wait([refreshGenres(), refreshTags(), refreshCollections()]);
    // 自动加载已选条目内容
    if (state.hasSelection) {
      await load();
    }
  }

  Future<void> _loadSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final genreKey = await accountScopedKey(_kStorageGenresKey);
      final rawGenres = prefs.getString(genreKey);
      if (rawGenres != null && rawGenres.isNotEmpty) {
        final decoded = jsonDecode(rawGenres);
        if (decoded is List<dynamic>) {
          state = state.copyWith(
            selectedGenreIds: decoded.whereType<String>().toList(),
          );
        }
      }
      final tagKey = await accountScopedKey(_kStorageTagsKey);
      final rawTags = prefs.getString(tagKey);
      if (rawTags != null && rawTags.isNotEmpty) {
        final decoded = jsonDecode(rawTags);
        if (decoded is List<dynamic>) {
          state = state.copyWith(
            selectedTagIds: decoded.whereType<String>().toList(),
          );
        }
      }
      final collectionKey = await accountScopedKey(_kStorageCollectionsKey);
      final rawCollections = prefs.getString(collectionKey);
      if (rawCollections != null && rawCollections.isNotEmpty) {
        final decoded = jsonDecode(rawCollections);
        if (decoded is List<dynamic>) {
          state = state.copyWith(
            selectedCollectionIds: decoded.whereType<String>().toList(),
          );
        }
      }
    } catch (e) {
      AppLogger.error('读取发现配置失败', error: e);
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

  /// 拉取服务器标签列表
  Future<void> refreshTags() async {
    final auth = _auth;
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    if (!auth.isAuthenticated || serverUrl == null || token == null) {
      return;
    }
    try {
      final repo = _ref.read(cachedMediaRepositoryProvider);
      final tags = await repo.getTags(
        serverUrl: serverUrl,
        token: token,
      );
      state = state.copyWith(tags: tags);
    } catch (e) {
      AppLogger.error('发现：加载标签列表失败', error: e);
    }
  }

  /// 拉取服务器合集列表
  Future<void> refreshCollections() async {
    final auth = _auth;
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    if (!auth.isAuthenticated || serverUrl == null || token == null) {
      return;
    }
    try {
      final repo = _ref.read(cachedMediaRepositoryProvider);
      final collections = await repo.getCollections(
        serverUrl: serverUrl,
        token: token,
      );
      state = state.copyWith(collections: collections);
    } catch (e) {
      AppLogger.error('发现：加载合集列表失败', error: e);
    }
  }

  /// 保存用户选择的类型（id 列表）并加载内容
  Future<void> saveSelection(List<String> genreIds) async {
    state = state.copyWith(selectedGenreIds: genreIds);
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await accountScopedKey(_kStorageGenresKey);
      await prefs.setString(key, jsonEncode(genreIds));
    } catch (e) {
      AppLogger.error('保存发现类型配置失败', error: e);
    }
    await load();
  }

  /// 追加一个类型到现有筛选（去重），避免外部读取 state 的竞态
  Future<bool> addGenre(String genre) async {
    final current = List<String>.from(state.selectedGenreIds);
    if (current.contains(genre)) return false;
    current.add(genre);
    state = state.copyWith(selectedGenreIds: current);
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await accountScopedKey(_kStorageGenresKey);
      await prefs.setString(key, jsonEncode(current));
    } catch (e) {
      AppLogger.error('追加发现类型失败', error: e);
    }
    _scheduleLoad();
    return true;
  }

  /// 移除一个发现类型
  Future<bool> removeGenre(String genre) async {
    final current = List<String>.from(state.selectedGenreIds);
    if (!current.remove(genre)) return false;
    state = state.copyWith(selectedGenreIds: current);
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await accountScopedKey(_kStorageGenresKey);
      await prefs.setString(key, jsonEncode(current));
    } catch (e) {
      AppLogger.error('移除发现类型失败', error: e);
    }
    _scheduleLoad();
    return true;
  }

  /// 防抖加载：连续多次添加/修改筛选时合并为一次 load
  void _scheduleLoad() {
    _loadDebounce?.cancel();
    _loadDebounce = Timer(const Duration(milliseconds: 300), () {
      load();
    });
  }

  /// 保存用户选择的标签（id 列表）并加载内容
  Future<void> saveTags(List<String> tagIds) async {
    state = state.copyWith(selectedTagIds: tagIds);
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await accountScopedKey(_kStorageTagsKey);
      await prefs.setString(key, jsonEncode(tagIds));
    } catch (e) {
      AppLogger.error('保存发现标签配置失败', error: e);
    }
    await load();
  }

  /// 保存用户选择的合集（id 列表）并加载内容
  Future<void> saveCollections(List<String> collectionIds) async {
    state = state.copyWith(selectedCollectionIds: collectionIds);
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await accountScopedKey(_kStorageCollectionsKey);
      await prefs.setString(key, jsonEncode(collectionIds));
    } catch (e) {
      AppLogger.error('保存发现合集配置失败', error: e);
    }
    await load();
  }

  /// 按已选类型 + 合集拉取影片，合并去重
  Future<void> load() async {
    final auth = _auth;
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    if (!auth.isAuthenticated || serverUrl == null || token == null) {
      state = state.copyWith(isLoading: false, error: '尚未登录');
      return;
    }
    if (!state.hasSelection) {
      state = state.copyWith(isLoading: false, items: const []);
      return;
    }
    // 用已拉到的类型列表把 id 解析成名称（getItemsByGenre 按名称查询）
    // 若类型列表还没拉到，先用 id 兜底（部分服务器 id 即名称）
    final idToName = <String, String>{
      for (final g in state.genres) g.id: g.name,
    };
    // 标签 id 即名称（Emby /Tags 返回字符串），直接使用
    final tagIdToName = <String, String>{
      for (final t in state.tags) t.id: t.name,
    };
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _ref.read(cachedMediaRepositoryProvider);
      final merged = <String, MediaItem>{};
      // 类型内容
      for (final id in state.selectedGenreIds) {
        final name = idToName[id] ?? id;
        try {
          final page = await repo.getItemsByGenre(
            name,
            limit: _kPerSourceLimit,
            offset: 0,
            serverUrl: serverUrl,
            token: token,
          );
          for (final item in page.items) {
            merged[item.id] = item;
          }
        } catch (e) {
          AppLogger.error('发现：拉取类型内容失败', data: {'genre': name}, error: e);
        }
      }
      // 标签内容
      for (final id in state.selectedTagIds) {
        final name = tagIdToName[id] ?? id;
        try {
          final page = await repo.getItemsByTag(
            name,
            limit: _kPerSourceLimit,
            offset: 0,
            serverUrl: serverUrl,
            token: token,
          );
          for (final item in page.items) {
            merged[item.id] = item;
          }
        } catch (e) {
          AppLogger.error('发现：拉取标签内容失败', data: {'tag': name}, error: e);
        }
      }
      // 合集内容
      for (final id in state.selectedCollectionIds) {
        try {
          final page = await repo.getBoxSetItems(
            id,
            limit: _kPerSourceLimit,
            offset: 0,
            serverUrl: serverUrl,
            token: token,
          );
          for (final item in page.items) {
            merged[item.id] = item;
          }
        } catch (e) {
          AppLogger.error('发现：拉取合集内容失败', data: {'collectionId': id}, error: e);
        }
      }
      final items = merged.values.toList();
      // 按生产年份倒序，新片在前
      items.sort(
          (a, b) => (b.productionYear ?? 0).compareTo(a.productionYear ?? 0));
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

final discoverProvider = StateNotifierProvider<DiscoverNotifier, DiscoverState>(
    (ref) => DiscoverNotifier(ref));
