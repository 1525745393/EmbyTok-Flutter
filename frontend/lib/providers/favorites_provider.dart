// 收藏列表与状态管理（三栏：影片 / 合集 / 人物）

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import 'auth_provider.dart';

class FavoritesState {
  final List<MediaItem> movies;
  final List<MediaItem> boxSets;
  final List<MediaItem> people;
  final bool isLoading;
  final String? error;
  final Set<String> favoriteIds;

  const FavoritesState({
    this.movies = const <MediaItem>[],
    this.boxSets = const <MediaItem>[],
    this.people = const <MediaItem>[],
    this.isLoading = false,
    this.error,
    this.favoriteIds = const <String>{},
  });

  FavoritesState copyWith({
    List<MediaItem>? movies,
    List<MediaItem>? boxSets,
    List<MediaItem>? people,
    bool? isLoading,
    String? error,
    Set<String>? favoriteIds,
  }) {
    return FavoritesState(
      movies: movies ?? this.movies,
      boxSets: boxSets ?? this.boxSets,
      people: people ?? this.people,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      favoriteIds: favoriteIds ?? this.favoriteIds,
    );
  }
}

Set<String> _mergeIds(List<MediaItem> a, List<MediaItem> b, List<MediaItem> c) {
  final ids = <String>{};
  for (final item in a) ids.add(item.id);
  for (final item in b) ids.add(item.id);
  for (final item in c) ids.add(item.id);
  return ids;
}

class FavoritesNotifier extends StateNotifier<FavoritesState> {
  final Ref _ref;
  final EmbytokService _service;

  FavoritesNotifier(this._ref, {EmbytokService? service})
      : _service = service ?? EmbytokService(),
        super(const FavoritesState());

  AuthState get _auth => _ref.read(authProvider);

  bool isFavorite(String itemId) => state.favoriteIds.contains(itemId);

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
      final serverUrl = auth.embyServerUrl!;
      final token = auth.token!;
      // 获取全部收藏，然后按类型分组
      final allFavorites = await _service.getFavorites(
        serverUrl: serverUrl,
        token: token,
      );

      final movies = allFavorites.where((item) {
        final type = item.type.toLowerCase();
        return type == 'movie' || type == 'series' || type == 'episode' || type == 'musicvideo';
      }).toList();
      final boxSets = allFavorites.where((item) => item.type.toLowerCase() == 'boxset').toList();
      final people = allFavorites.where((item) => item.type.toLowerCase() == 'person').toList();
      final ids = _mergeIds(movies, boxSets, people);

      state = FavoritesState(
        movies: movies,
        boxSets: boxSets,
        people: people,
        isLoading: false,
        favoriteIds: ids,
      );
    } catch (e) {
      final message = e is String ? e : '加载收藏失败：$e';
      state = state.copyWith(isLoading: false, error: message);
    }
  }

  Future<void> toggleFavorite(MediaItem item) async {
    final auth = _auth;
    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) {
      return;
    }

    final currentlyFavorite = isFavorite(item.id);
    final newIsFavorite = !currentlyFavorite;

    // 乐观更新
    final newMovies = List<MediaItem>.from(state.movies);
    final newBoxSets = List<MediaItem>.from(state.boxSets);
    final newPeople = List<MediaItem>.from(state.people);
    final newIds = Set<String>.from(state.favoriteIds);

    if (newIsFavorite) {
      newIds.add(item.id);
      final type = item.type.toLowerCase();
      if (type == 'boxset') {
        if (!newBoxSets.any((e) => e.id == item.id)) newBoxSets.insert(0, item);
      } else if (type == 'person') {
        if (!newPeople.any((e) => e.id == item.id)) newPeople.insert(0, item);
      } else {
        if (!newMovies.any((e) => e.id == item.id)) newMovies.insert(0, item);
      }
    } else {
      newIds.remove(item.id);
      newMovies.removeWhere((e) => e.id == item.id);
      newBoxSets.removeWhere((e) => e.id == item.id);
      newPeople.removeWhere((e) => e.id == item.id);
    }

    state = state.copyWith(
      movies: newMovies,
      boxSets: newBoxSets,
      people: newPeople,
      favoriteIds: newIds,
      error: null,
    );

    try {
      await _service.toggleFavorite(
        item.id,
        isFavorite: newIsFavorite,
        serverUrl: auth.embyServerUrl!,
        token: auth.token!,
      );
    } catch (e) {
      // 回滚
      if (currentlyFavorite) {
        final rollbackIds = Set<String>.from(state.favoriteIds)..add(item.id);
        final type = item.type.toLowerCase();
        if (type == 'boxset') {
          state = state.copyWith(
            boxSets: List.from(state.boxSets)..insert(0, item),
            favoriteIds: rollbackIds,
          );
        } else if (type == 'person') {
          state = state.copyWith(
            people: List.from(state.people)..insert(0, item),
            favoriteIds: rollbackIds,
          );
        } else {
          state = state.copyWith(
            movies: List.from(state.movies)..insert(0, item),
            favoriteIds: rollbackIds,
          );
        }
      } else {
        final rollbackIds = Set<String>.from(state.favoriteIds)..remove(item.id);
        state = state.copyWith(
          movies: state.movies.where((e) => e.id != item.id).toList(),
          boxSets: state.boxSets.where((e) => e.id != item.id).toList(),
          people: state.people.where((e) => e.id != item.id).toList(),
          favoriteIds: rollbackIds,
        );
      }
    }
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  return FavoritesNotifier(ref);
});
