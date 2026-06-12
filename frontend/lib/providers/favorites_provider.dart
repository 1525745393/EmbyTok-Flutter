// 收藏列表 & 切换收藏状态

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import 'auth_provider.dart';

// 收藏状态
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

// 收藏 Notifier
class FavoritesNotifier extends StateNotifier<FavoritesState> {
  final Ref _ref;
  final EmbytokService _service;

  FavoritesNotifier(this._ref, {EmbytokService? service})
      : _service = service ?? EmbytokService(),
        super(const FavoritesState());

  AuthState get _auth => _ref.read(authProvider);

  // 判断是否已收藏
  bool isFavorite(String itemId) {
    return state.favoriteIds.contains(itemId);
  }

  // 加载收藏列表
  Future<void> loadFavorites() async {
    state = state.copyWith(isLoading: true, error: null);

    final auth = _auth;
    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
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
    } catch (e) {
      final message = e is String ? e : '加载收藏失败：$e';
      state = state.copyWith(isLoading: false, error: message);
    }
  }

  // 切换收藏状态
  Future<void> toggleFavorite(MediaItem item) async {
    final auth = _auth;
    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
      state = state.copyWith(error: '尚未登录');
      return;
    }

    final currentlyFavorite = isFavorite(item.id);
    final newState = currentlyFavorite ? false : true;

    // 先乐观更新 UI
    final newIds = Set<String>.from(state.favoriteIds);
    final newItems = List<MediaItem>.from(state.items);
    if (newState) {
      newIds.add(item.id);
      if (!newItems.any((e) => e.id == item.id)) newItems.insert(0, item);
    } else {
      newIds.remove(item.id);
      newItems.removeWhere((e) => e.id == item.id);
    }
    state = state.copyWith(items: newItems, favoriteIds: newIds, error: null);

    try {
      await _service.toggleFavorite(
        item.id,
        newState,
        serverUrl: auth.embyServerUrl!,
        token: auth.token!,
      );
    } catch (e) {
      // 回滚
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
    }
  }
}

// 顶层 Provider
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  return FavoritesNotifier(ref);
});
