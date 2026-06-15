// 收藏列表 & 切换收藏状态
// - 自动监听登录状态：登录后自动从 Emby 拉取收藏，登出后清除本地缓存
// - toggleFavorite 采用乐观更新 + 失败回滚，提供即时 UI 反馈
// - 同一 itemId 的并发 toggleFavorite 自动合并（_pendingToggles 去重）
// - 网络层去重：_isLoading 标志避免重复 loadFavorites

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';

/// 收藏状态：items 为完整媒体对象，favoriteIds 提供 O(1) 快速查询
class FavoritesState {
  final List<MediaItem> items;
  final bool isLoading;
  final String? error;
  final Set<String> favoriteIds;

  const FavoritesState({
    this.items = const <MediaItem>[],
    this.isLoading = false,
    this.error,
    this.favoriteIds = const <String>{},
  });

  FavoritesState copyWith({
    List<MediaItem>? items,
    bool? isLoading,
    String? error,
    Set<String>? favoriteIds,
  }) {
    return FavoritesState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      favoriteIds: favoriteIds ?? this.favoriteIds,
    );
  }
}

/// 收藏 Notifier：管理整个 app 的收藏状态
class FavoritesNotifier extends StateNotifier<FavoritesState> {
  final Ref _ref;
  final EmbytokService _service;

  bool _hasLoaded = false;
  bool _isLoading = false;
  final Set<String> _pendingToggles = <String>{};

  FavoritesNotifier(this._ref, {EmbytokService? service})
      : _service = service ?? EmbytokService(),
        super(const FavoritesState()) {
    // 监听认证状态变化：登录 → 自动加载；登出 → 清除缓存
    _ref.listen<AuthState>(authProvider, (previous, next) {
      final wasAuthenticated = previous?.isAuthenticated ?? false;
      final isNowAuthenticated = next.isAuthenticated;

      if (wasAuthenticated && !isNowAuthenticated) {
        // 用户登出：清空本地缓存，避免展示上一账号的数据
        reset();
      } else if (!wasAuthenticated && isNowAuthenticated) {
        // 用户登录：自动拉取当前账号的收藏
        loadFavorites();
      }
    });
  }

  AuthState get _auth => _ref.read(authProvider);

  /// 快速查询：某个 item 是否已收藏（纯同步，不触发网络）
  bool isFavorite(String itemId) {
    return state.favoriteIds.contains(itemId);
  }

  /// 确保至少加载过一次（幂等，并发安全）
  Future<void> ensureLoaded() async {
    if (_hasLoaded || _isLoading) return;
    await loadFavorites();
  }

  /// 从 Emby 服务器拉取当前用户的全部收藏
  Future<void> loadFavorites() async {
    if (_isLoading) return;
    _isLoading = true;
    state = state.copyWith(isLoading: true, error: null);
    AppLogger.info('加载收藏列表');

    final auth = _auth;
    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
      _isLoading = false;
      state = state.copyWith(isLoading: false, error: '尚未登录');
      return;
    }

    try {
      final items = await _service.getFavorites(
        serverUrl: auth.embyServerUrl!,
        token: auth.token!,
      );
      final ids = items.map((e) => e.id).toSet();
      state = FavoritesState(
        items: items,
        isLoading: false,
        favoriteIds: ids,
      );
      _hasLoaded = true;
      AppLogger.info('收藏列表加载成功', data: {'count': items.length});
    } catch (e) {
      final message = e is String ? e : '加载收藏失败：$e';
      state = state.copyWith(isLoading: false, error: message);
      AppLogger.error('加载收藏失败', error: e);
    } finally {
      _isLoading = false;
    }
  }

  /// 切换某条目的收藏状态
  ///
  /// 乐观更新 UI → 发送网络请求 → 成功则保留，失败则回滚
  /// 同一 itemId 的并发调用会自动合并为一次，避免重复请求与状态抖动
  Future<void> toggleFavorite(MediaItem item) async {
    final auth = _auth;
    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
      state = state.copyWith(error: '尚未登录');
      return;
    }

    // 去重：防止快速连点产生重复请求
    if (_pendingToggles.contains(item.id)) return;
    _pendingToggles.add(item.id);

    // 1. 读取当前状态（乐观更新的基准）
    final currentlyFavorite = isFavorite(item.id);
    final newIsFavorite = !currentlyFavorite;

    AppLogger.info('切换收藏状态',
        data: {'itemId': item.id, 'newState': newIsFavorite});

    // 2. 乐观更新 UI：先按目标状态渲染，给用户即时反馈
    final newIds = Set<String>.from(state.favoriteIds);
    final newItems = List<MediaItem>.from(state.items);
    if (newIsFavorite) {
      newIds.add(item.id);
      if (!newItems.any((e) => e.id == item.id)) {
        newItems.insert(0, item);
      }
    } else {
      newIds.remove(item.id);
      newItems.removeWhere((e) => e.id == item.id);
    }
    state = state.copyWith(
      items: newItems,
      favoriteIds: newIds,
      error: null,
    );

    // 3. 真正同步到服务器
    try {
      await _service.toggleFavorite(
        itemId: item.id,
        isFavorite: newIsFavorite,
        serverUrl: auth.embyServerUrl!,
        token: auth.token!,
      );
    } catch (e) {
      // 4. 失败回滚：恢复到乐观更新前的状态
      final rollbackIds = Set<String>.from(state.favoriteIds);
      final rollbackItems = List<MediaItem>.from(state.items);
      if (currentlyFavorite) {
        rollbackIds.add(item.id);
        if (!rollbackItems.any((el) => el.id == item.id)) {
          rollbackItems.insert(0, item);
        }
      } else {
        rollbackIds.remove(item.id);
        rollbackItems.removeWhere((el) => el.id == item.id);
      }
      final message = e is String ? e : '切换收藏失败：$e';
      state = state.copyWith(
        items: rollbackItems,
        favoriteIds: rollbackIds,
        error: message,
      );
      AppLogger.error('切换收藏失败', error: e);
    } finally {
      _pendingToggles.remove(item.id);
    }
  }

  /// 登出/切换账号时清除所有本地缓存（下一次使用会重新拉取）
  void reset() {
    _hasLoaded = false;
    _pendingToggles.clear();
    state = const FavoritesState();
  }
}

/// 顶层 Provider：整个 app 共享同一份收藏状态
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  return FavoritesNotifier(ref);
});
