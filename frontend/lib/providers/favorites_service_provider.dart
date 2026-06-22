/// 基于 Emby Playlist 的收藏服务
///
/// 替代方案：将每个媒体库的收藏项目保存在名为 `Tok-{libraryName}` 的 Playlist 中。
/// 注意：当前项目默认使用基于 UserData（favorite=true）的方式管理收藏，
/// 本模块目前未集成到 UI，保留供后续扩展使用。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import 'auth_provider.dart';

/// 基于 Emby Playlist 的收藏服务：管理媒体库级别的收藏列表
class FavoritesService {
  final EmbytokService _service;
  final AuthState _auth;

  FavoritesService(this._service, this._auth);

  bool get isAuthenticated =>
      _auth.isAuthenticated &&
      _auth.embyServerUrl != null &&
      _auth.token != null;

  /// 构造指定媒体库的 Playlist 名称
  String _playlistName(String libraryName) => 'Tok-$libraryName';

  /// 获取指定库的收藏项 ID 集合
  Future<Set<String>> getFavoriteIds(String libraryName) async {
    if (!isAuthenticated) return <String>{};
    final playlist = _playlistName(libraryName);
    final results = await _service.searchItems(
      playlist,
      includeTypes: ['Playlist'],
      serverUrl: _auth.embyServerUrl!,
      token: _auth.token!,
      userId: _auth.user?.id,
      limit: 10,
    );
    if (results.items.isEmpty) return <String>{};
    final playlistItem = results.items.first;
    final children = await _service.getChildren(
      playlistItem.id,
      serverUrl: _auth.embyServerUrl!,
      token: _auth.token!,
    );
    return children.map((e) => e.id).toSet();
  }

  /// 创建一个新的 Playlist 并返回其 ID
  Future<String> _createPlaylist(String libraryName) async {
    final name = Uri.encodeQueryComponent(_playlistName(libraryName));
    final userId = _auth.user?.id ?? '';
    final response = await _service.postRaw(
      '/Playlists',
      queryParameters: {'Name': name, 'UserId': userId},
      serverUrl: _auth.embyServerUrl!,
      token: _auth.token!,
    );
    if (response is Map<String, dynamic>) {
      return (response['Id'] as String?) ?? '';
    }
    return '';
  }

  /// 将指定 item 加入指定库的收藏
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

  /// 将指定 item 从收藏中移除
  Future<void> removeFromFavorites(String itemId, String libraryName) async {
    if (!isAuthenticated) return;
    final playlistId = await _getOrCreatePlaylistId(libraryName);
    if (playlistId.isEmpty) return;

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
    String? entryId;
    if (raw != null && raw['PlaylistItemId'] is String) {
      entryId = raw['PlaylistItemId'] as String;
    } else if (raw != null && raw['Id'] is String) {
      entryId = raw['Id'] as String;
    }
    if (entryId == null || entryId.isEmpty) entryId = entry.id;
    final userId = _auth.user?.id ?? '';
    await _service.deleteRaw(
      '/Playlists/$playlistId/Items',
      queryParameters: {'EntryIds': entryId, 'UserId': userId},
      serverUrl: _auth.embyServerUrl!,
      token: _auth.token!,
    );
  }

  /// 获取或创建指定媒体库对应的 Playlist ID
  Future<String> _getOrCreatePlaylistId(String libraryName) async {
    if (!isAuthenticated) return '';
    final results = await _service.searchItems(
      _playlistName(libraryName),
      includeTypes: ['Playlist'],
      serverUrl: _auth.embyServerUrl!,
      token: _auth.token!,
      userId: _auth.user?.id,
      limit: 5,
    );
    if (results.items.isNotEmpty) {
      return results.items.first.id;
    }
    return _createPlaylist(libraryName);
  }

  /// 切换某 item 的收藏状态
  Future<void> toggle(String itemId, bool isCurrentlyFavorite, String libraryName) async {
    if (isCurrentlyFavorite) {
      await removeFromFavorites(itemId, libraryName);
    } else {
      await addToFavorites(itemId, libraryName);
    }
  }
}

/// 顶层收藏服务 Provider
final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  final auth = ref.watch(authProvider);
  return FavoritesService(EmbytokService(), auth);
});
