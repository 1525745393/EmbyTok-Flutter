// 群晖 Audio Station 音乐库状态管理
//
// 管理歌曲/专辑/歌手/歌单列表的加载状态与错误处理。
// 数据按需加载（进入 Tab 才请求），支持下拉刷新。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audio_models.dart';
import '../services/synology_audio_api.dart';
import '../utils/logger.dart';
import 'synology_auth_provider.dart';

/// 音乐库分类
enum SynologyMusicTab {
  songs('歌曲'),
  albums('专辑'),
  artists('歌手'),
  playlists('歌单');

  final String label;
  const SynologyMusicTab(this.label);
}

/// 音乐库状态
class SynologyMusicState {
  final bool isLoading;
  final String? error;

  final List<AudioSong> songs;
  final List<AudioAlbum> albums;
  final List<AudioArtist> artists;
  final List<AudioPlaylist> playlists;

  /// 搜索状态
  final bool isSearching;
  final String searchKeyword;
  final AudioSearchResult? searchResult;

  const SynologyMusicState({
    this.isLoading = false,
    this.error,
    this.songs = const [],
    this.albums = const [],
    this.artists = const [],
    this.playlists = const [],
    this.isSearching = false,
    this.searchKeyword = '',
    this.searchResult,
  });

  SynologyMusicState copyWith({
    bool? isLoading,
    String? error,
    List<AudioSong>? songs,
    List<AudioAlbum>? albums,
    List<AudioArtist>? artists,
    List<AudioPlaylist>? playlists,
    bool? isSearching,
    String? searchKeyword,
    AudioSearchResult? searchResult,
  }) {
    return SynologyMusicState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      songs: songs ?? this.songs,
      albums: albums ?? this.albums,
      artists: artists ?? this.artists,
      playlists: playlists ?? this.playlists,
      isSearching: isSearching ?? this.isSearching,
      searchKeyword: searchKeyword ?? this.searchKeyword,
      searchResult: searchResult ?? this.searchResult,
    );
  }
}

class SynologyMusicNotifier extends StateNotifier<SynologyMusicState> {
  final Ref _ref;
  final Map<SynologyMusicTab, bool> _loaded = {};

  SynologyMusicNotifier(this._ref) : super(const SynologyMusicState());

  SynologyAudioApi get _api =>
      _ref.read(synologyAuthProvider.notifier).api;

  bool get _isLoggedIn => _ref.read(synologyAuthProvider).isLoggedIn;

  /// 按需加载指定分类数据（已加载则跳过；下拉刷新时 force=true）
  Future<void> loadTab(SynologyMusicTab tab, {bool force = false}) async {
    if (!_isLoggedIn) return;
    if (!force && _loaded[tab] == true) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      switch (tab) {
        case SynologyMusicTab.songs:
          final songs = await _api.getSongs();
          state = state.copyWith(isLoading: false, songs: songs);
        case SynologyMusicTab.albums:
          final albums = await _api.getAlbums();
          state = state.copyWith(isLoading: false, albums: albums);
        case SynologyMusicTab.artists:
          final artists = await _api.getArtists();
          state = state.copyWith(isLoading: false, artists: artists);
        case SynologyMusicTab.playlists:
          final playlists = await _api.getPlaylists();
          state = state.copyWith(isLoading: false, playlists: playlists);
      }
      _loaded[tab] = true;
    } catch (e, st) {
      AppLogger.error('加载音乐库失败', data: {'tab': tab.name}, error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 加载专辑内的歌曲
  Future<List<AudioSong>> loadAlbumSongs(AudioAlbum album) async {
    if (!_isLoggedIn) return const [];
    try {
      return await _api.getSongs(album: album.name);
    } catch (e, st) {
      AppLogger.error('加载专辑歌曲失败', data: {'album': album.name}, error: e, stackTrace: st);
      return const [];
    }
  }

  /// 加载歌单内的歌曲
  Future<List<AudioSong>> loadPlaylistSongs(String playlistId) async {
    if (!_isLoggedIn) return const [];
    try {
      return await _api.getPlaylistSongs(playlistId);
    } catch (e, st) {
      AppLogger.error('加载歌单歌曲失败', error: e, stackTrace: st);
      return const [];
    }
  }

  /// 搜索（keyword 为空则退出搜索态）
  Future<void> search(String keyword) async {
    final kw = keyword.trim();
    if (!_isLoggedIn) return;
    if (kw.isEmpty) {
      state = state.copyWith(isSearching: false, searchKeyword: '', searchResult: null);
      return;
    }
    state = state.copyWith(isSearching: true, searchKeyword: kw, isLoading: true, error: null);
    try {
      final result = await _api.search(kw);
      state = state.copyWith(isLoading: false, searchResult: result);
    } catch (e, st) {
      AppLogger.error('搜索音乐失败', data: {'keyword': kw}, error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 退出搜索态（清空关键词与结果）
  void clearSearch() {
    state = state.copyWith(isSearching: false, searchKeyword: '', searchResult: null);
  }

  /// 清空错误
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }
}

/// 音乐库 Provider
final synologyMusicProvider =
    StateNotifierProvider<SynologyMusicNotifier, SynologyMusicState>(
  (ref) => SynologyMusicNotifier(ref),
);
