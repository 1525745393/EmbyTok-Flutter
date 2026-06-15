// 基于 Emby Playlist 的收藏服务（Task 2 新增）
// 实现参考：migumigu/EmbyTok 的 Favorites 逻辑。
// 将每个媒体库的收藏项目保存在名为 `Tok-{libraryName}` 的 Playlist 中。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import 'auth_provider.dart';

class FavoritesService {
  final EmbytokService _service;
  final AuthState _auth;

  FavoritesService(this._service, this._auth);

  bool get isAuthenticated =>
      _auth.isAuthenticated &&
      _auth.embyServerUrl != null &&
      _auth.token != null;

  // 获取当前播放列表名（按媒体库名）
  String _playlistName(String libraryName) => 'Tok-$libraryName';

  // 获取指定库的收藏项 ID 集合
  Future<Set<String>> getFavoriteIds(String libraryName) async {
    if (!isAuthenticated) return <String>{};
    final playlist = _playlistName(libraryName);
    final results = await _service.searchItems(
      playlist,
      includeTypes: ['Playlist'],
      serverUrl: _auth.embyServerUrl!,
      token: _auth.token!,
      limit: 10,
    );
    if (results.items.isEmpty) return <String>{};
    // 在 Emby 中 Playlist 下的子项 ID 集合即为收藏
    final playlistItem = results.items.first;
    final children = await _service.getChildren(
      playlistItem.id,
      serverUrl: _auth.embyServerUrl!,
      token: _auth.token!,
    );
    return children.map((e) => e.id).toSet();
  }

  // 创建一个新的 Playlist 并返回其 ID
  Future<String> _createPlaylist(String libraryName) async {
    final name = Uri.encodeQueryComponent(_playlistName(libraryName));
    final userId = _auth.user?.id ?? '';
    final response = await _service.postRaw(
      '/Playlists',
      queryParameters: {'Name': name, 'UserId': userId},
      serverUrl: _auth.embyServerUrl!,
      token: _auth.token!,
    );
    // Emby 返回的响应体为 {"Id":"..."} 或类似结构
    if (response is Map<String, dynamic>) {
      return (response['Id'] as String?) ?? '';
    }
    return '';
  }

  // 将指定 item 加入指定库的收藏
  Future<void> addToFavorites(String itemId, String libraryName) async {
    if (!isAuthenticated) return;
    final id = await _getOrCreatePlaylistId(libraryName);
    if (id.isEmpty) return;
    final userId = _auth.user?.id ?? '';
    await _service.postRaw(
      '/Playlists/$id/Items',
      queryParameters: {'Ids': itemId, 'UserId': userId},
      serverUrl: _auth.embyServerUrl!,
      token: _auth.token!,
    );
  }

  // 将指定 item 从收藏中移除
  Future<void> removeFromFavorites(String itemId, String libraryName) async {
    if (!isAuthenticated) return;
    final playlistId = await _getOrCreatePlaylistId(libraryName);
    if (playlistId.isEmpty) return;

    // 首先需要获取该 item 在 Playlist 中的 EntryId
    // Emby Playlist 中的每个子项都有一个 PlaylistItemId（不同于 Item.Id）
    final children = await _service.getChildren(
      playlistId,
      serverUrl: _auth.embyServerUrl!,
      token: _auth.token!,
    );
    final entry = children.firstWhere(
      (e) => e.id == itemId,
      orElse: () => MediaItem(id: itemId, title: '', type: 'PlaylistEntry'),
    );
    final raw = entry.rawJson;
    // 尝试从 rawJson 中获取 PlaylistItemId
    String? entryId;
    if (raw != null && raw['PlaylistItemId'] is String) {
      entryId = raw['PlaylistItemId'] as String;
    } else if (raw != null && raw['Id'] is String) {
      entryId = raw['Id'] as String;
    }
    if (entryId == null || entryId.isEmpty) {
      // fallback：尝试用 entry.id
      entryId = entry.id;
    }
    final userId = _auth.user?.id ?? '';
    await _service.deleteRaw(
      '/Playlists/$playlistId/Items',
      queryParameters: {'EntryIds': entryId, 'UserId': userId},
      serverUrl: _auth.embyServerUrl!,
      token: _auth.token!,
    );
  }

  // 获取或创建 Playlist 的 ID
  Future<String> _getOrCreatePlaylistId(String libraryName) async {
    if (!isAuthenticated) return '';
    final results = await _service.searchItems(
      _playlistName(libraryName),
      includeTypes: ['Playlist'],
      serverUrl: _auth.embyServerUrl!,
      token: _auth.token!,
      limit: 5,
    );
    if (results.items.isNotEmpty) {
      return results.items.first.id;
    }
    return _createPlaylist(libraryName);
  }

  // 切换某 item 的收藏状态（最常用接口）
  Future<void> toggle(String itemId, bool isCurrentlyFavorite, String libraryName) async {
    if (isCurrentlyFavorite) {
      await removeFromFavorites(itemId, libraryName);
    } else {
      await addToFavorites(itemId, libraryName);
    }
  }
}

final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  final auth = ref.watch(authProvider);
  return FavoritesService(EmbytokService(), auth);
});
