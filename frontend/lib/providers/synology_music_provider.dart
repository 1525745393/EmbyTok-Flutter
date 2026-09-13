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
  home('首页'),
  songs('歌曲'),
  albums('专辑'),
  artists('歌手'),
  playlists('歌单');
  const SynologyMusicTab(this.label);

  final String label;
}

/// 音乐库状态
class SynologyMusicState {

  const SynologyMusicState({
    this.isLoading = false,
    this.error,
    this.songs = const [],
    this.albums = const [],
    this.artists = const [],
    this.playlists = const [],
    this.recentAlbums = const [],
    this.topArtists = const [],
    this.genres = const [],
    this.pins = const [],
    this.isHomeLoaded = false,
    this.hasMoreSongs = false,
    this.isLoadingMoreSongs = false,
    this.hasMoreAlbums = false,
    this.isLoadingMoreAlbums = false,
    this.hasMoreArtists = false,
    this.isLoadingMoreArtists = false,
    this.isSearching = false,
    this.searchKeyword = '',
    this.searchResult,
  });
  final bool isLoading;
  final String? error;

  final List<AudioSong> songs;
  final List<AudioAlbum> albums;
  final List<AudioArtist> artists;
  final List<AudioPlaylist> playlists;

  /// 首页专用数据（PRD 模块）
  final List<AudioAlbum> recentAlbums; // 最近添加（time_add 倒序）
  final List<AudioArtist> topArtists; // 热门艺术家（song_count 倒序）
  final List<AudioGenre> genres; // 音乐流派
  final List<AudioPin> pins; // 我的锁定（用户收藏的歌曲）
  final bool isHomeLoaded; // 首页数据是否已加载

  /// 歌曲分页状态
  final bool hasMoreSongs;
  final bool isLoadingMoreSongs;

  /// 专辑分页状态
  final bool hasMoreAlbums;
  final bool isLoadingMoreAlbums;

  /// 歌手分页状态
  final bool hasMoreArtists;
  final bool isLoadingMoreArtists;

  /// 搜索状态
  final bool isSearching;
  final String searchKeyword;
  final AudioSearchResult? searchResult;

  SynologyMusicState copyWith({
    bool? isLoading,
    String? error,
    List<AudioSong>? songs,
    List<AudioAlbum>? albums,
    List<AudioArtist>? artists,
    List<AudioPlaylist>? playlists,
    List<AudioAlbum>? recentAlbums,
    List<AudioArtist>? topArtists,
    List<AudioGenre>? genres,
    List<AudioPin>? pins,
    bool? isHomeLoaded,
    bool? hasMoreSongs,
    bool? isLoadingMoreSongs,
    bool? hasMoreAlbums,
    bool? isLoadingMoreAlbums,
    bool? hasMoreArtists,
    bool? isLoadingMoreArtists,
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
      recentAlbums: recentAlbums ?? this.recentAlbums,
      topArtists: topArtists ?? this.topArtists,
      genres: genres ?? this.genres,
      pins: pins ?? this.pins,
      isHomeLoaded: isHomeLoaded ?? this.isHomeLoaded,
      hasMoreSongs: hasMoreSongs ?? this.hasMoreSongs,
      isLoadingMoreSongs: isLoadingMoreSongs ?? this.isLoadingMoreSongs,
      hasMoreAlbums: hasMoreAlbums ?? this.hasMoreAlbums,
      isLoadingMoreAlbums: isLoadingMoreAlbums ?? this.isLoadingMoreAlbums,
      hasMoreArtists: hasMoreArtists ?? this.hasMoreArtists,
      isLoadingMoreArtists: isLoadingMoreArtists ?? this.isLoadingMoreArtists,
      isSearching: isSearching ?? this.isSearching,
      searchKeyword: searchKeyword ?? this.searchKeyword,
      searchResult: searchResult ?? this.searchResult,
    );
  }
}

/// 单页大小（与 DSM 默认一致）
const int _pageSize = 200;

class SynologyMusicNotifier extends StateNotifier<SynologyMusicState> {

  SynologyMusicNotifier(this._ref) : super(const SynologyMusicState());
  final Ref _ref;
  final Map<SynologyMusicTab, bool> _loaded = {};

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
        case SynologyMusicTab.home:
          // 首页复用其他 Tab 数据，无需单独加载
          state = state.copyWith(isLoading: false);
          break;
        case SynologyMusicTab.songs:
          final songs = await _api.getSongs(offset: 0, limit: _pageSize);
          state = state.copyWith(
            isLoading: false,
            songs: songs,
            hasMoreSongs: songs.length >= _pageSize,
            isLoadingMoreSongs: false,
          );
        case SynologyMusicTab.albums:
          final albums = await _api.getAlbums(offset: 0, limit: _pageSize);
          state = state.copyWith(
            isLoading: false,
            albums: albums,
            hasMoreAlbums: albums.length >= _pageSize,
            isLoadingMoreAlbums: false,
          );
        case SynologyMusicTab.artists:
          final artists = await _api.getArtists(offset: 0, limit: _pageSize);
          state = state.copyWith(
            isLoading: false,
            artists: artists,
            hasMoreArtists: artists.length >= _pageSize,
            isLoadingMoreArtists: false,
          );
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

  /// 加载首页专用数据（PRD 模块）：最近添加专辑 + 热门艺术家 + 音乐流派
  ///
  /// 并发请求 3 个接口，单个失败不影响其他模块。已加载则跳过（force 时强制刷新）。
  Future<void> loadHomeData({bool force = false}) async {
    if (!_isLoggedIn) return;
    if (!force && state.isHomeLoaded) return;

    try {
      // 并发加载四个首页模块（最近添加/热门艺术家/流派/我的锁定）
      final results = await Future.wait([
        _api.getAlbums(sort: 'time_add', direction: 'desc', limit: 10),
        _api.getArtists(sort: 'song_count', direction: 'desc', limit: 15),
        _api.getGenres(limit: 50),
        _api.getPins(),
      ], eagerError: false);

      state = state.copyWith(
        recentAlbums: results[0] as List<AudioAlbum>,
        topArtists: results[1] as List<AudioArtist>,
        genres: results[2] as List<AudioGenre>,
        pins: results[3] as List<AudioPin>,
        isHomeLoaded: true,
        error: null,
      );
    } catch (e, st) {
      AppLogger.error('加载首页数据失败', error: e, stackTrace: st);
      // 单个接口失败不阻断，标记已加载避免重复请求
      state = state.copyWith(isHomeLoaded: true, error: e.toString());
    }
  }

  /// 加载歌曲列表下一页（滚动到底部触发）
  Future<void> loadMoreSongs() async {
    if (!_isLoggedIn) return;
    if (state.isLoading || state.isLoadingMoreSongs || !state.hasMoreSongs) {
      return;
    }
    state = state.copyWith(isLoadingMoreSongs: true, error: null);
    try {
      final more = await _api.getSongs(
        offset: state.songs.length,
        limit: _pageSize,
      );
      if (more.isEmpty) {
        state = state.copyWith(isLoadingMoreSongs: false, hasMoreSongs: false);
        return;
      }
      state = state.copyWith(
        isLoadingMoreSongs: false,
        songs: [...state.songs, ...more],
        hasMoreSongs: more.length >= _pageSize,
      );
    } catch (e, st) {
      AppLogger.error('加载更多歌曲失败', error: e, stackTrace: st);
      state = state.copyWith(isLoadingMoreSongs: false);
    }
  }

  /// 加载专辑下一页（滚动到底部触发）
  Future<void> loadMoreAlbums() async {
    if (!_isLoggedIn) return;
    if (state.isLoading || state.isLoadingMoreAlbums || !state.hasMoreAlbums) {
      return;
    }
    state = state.copyWith(isLoadingMoreAlbums: true, error: null);
    try {
      final more = await _api.getAlbums(
        offset: state.albums.length,
        limit: _pageSize,
      );
      if (more.isEmpty) {
        state = state.copyWith(isLoadingMoreAlbums: false, hasMoreAlbums: false);
        return;
      }
      state = state.copyWith(
        isLoadingMoreAlbums: false,
        albums: [...state.albums, ...more],
        hasMoreAlbums: more.length >= _pageSize,
      );
    } catch (e, st) {
      AppLogger.error('加载更多专辑失败', error: e, stackTrace: st);
      state = state.copyWith(isLoadingMoreAlbums: false);
    }
  }

  /// 加载歌手下一页（滚动到底部触发）
  Future<void> loadMoreArtists() async {
    if (!_isLoggedIn) return;
    if (state.isLoading || state.isLoadingMoreArtists || !state.hasMoreArtists) {
      return;
    }
    state = state.copyWith(isLoadingMoreArtists: true, error: null);
    try {
      final more = await _api.getArtists(
        offset: state.artists.length,
        limit: _pageSize,
      );
      if (more.isEmpty) {
        state = state.copyWith(isLoadingMoreArtists: false, hasMoreArtists: false);
        return;
      }
      state = state.copyWith(
        isLoadingMoreArtists: false,
        artists: [...state.artists, ...more],
        hasMoreArtists: more.length >= _pageSize,
      );
    } catch (e, st) {
      AppLogger.error('加载更多歌手失败', error: e, stackTrace: st);
      state = state.copyWith(isLoadingMoreArtists: false);
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

  /// 搜索请求序号：快速连续搜索时丢弃过期响应，避免乱序覆盖
  int _searchSeq = 0;

  /// 搜索（keyword 为空则退出搜索态）
  Future<void> search(String keyword) async {
    final kw = keyword.trim();
    if (!_isLoggedIn) return;
    if (kw.isEmpty) {
      // 退出搜索态：递增序号使在途搜索请求失效（过期响应不复活结果）
      _searchSeq++;
      state = state.copyWith(isSearching: false, searchKeyword: '', searchResult: null);
      return;
    }
    final seq = ++_searchSeq;
    state = state.copyWith(isSearching: true, searchKeyword: kw, isLoading: true, error: null);
    try {
      final result = await _api.search(kw);
      // 期间用户又输入了新的关键词：本响应已过期，丢弃
      if (seq != _searchSeq) return;
      state = state.copyWith(isLoading: false, searchResult: result);
    } catch (e, st) {
      if (seq != _searchSeq) return;
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
