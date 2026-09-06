// 群晖 Audio Station 音乐浏览页面（独立路由 /music）
//
// 功能：
// - 分类浏览：歌曲 / 专辑 / 歌手 / 歌单（按需加载）
// - 顶部搜索：SYNO.AudioStation.Search（歌曲 + 专辑 + 歌手）
// - 点击歌曲即播，底部 mini player 常驻控制
// - 专辑 / 歌单 / 歌手点击展开歌曲列表（底部弹层）
//
// 交互参考主流音乐 App：列表 + 底部播放条 + 分类 Tab。

import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/audio_models.dart';
import '../providers/providers.dart';
import '../utils/image_cache_manager.dart';
import '../utils/logger.dart';

class SynologyMusicView extends ConsumerStatefulWidget {
  const SynologyMusicView({super.key});

  @override
  ConsumerState<SynologyMusicView> createState() => _SynologyMusicViewState();
}

class _SynologyMusicViewState extends ConsumerState<SynologyMusicView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    // 首个 Tab（歌曲）自动加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(synologyMusicProvider.notifier)
            .loadTab(SynologyMusicTab.songs);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    final tab = SynologyMusicTab.values[_tabController.index];
    ref.read(synologyMusicProvider.notifier).loadTab(tab);
  }

  /// 搜索输入（300ms 防抖，与项目搜索页一致）
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(synologyMusicProvider.notifier).search(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(synologyAuthProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: !auth.isLoggedIn
          ? _buildNotLoggedIn(scheme)
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  // 渐变头部：顶栏 + 搜索框 + 分类 Tab（QQ音乐/酷狗风格）
                  _buildGradientHeader(scheme),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => ref
                          .read(synologyMusicProvider.notifier)
                          .loadTab(
                            SynologyMusicTab.values[_tabController.index],
                            force: true,
                          ),
                      child: _buildTabContent(scheme),
                    ),
                  ),
                  // 底部迷你播放条
                  const _MiniPlayerBar(),
                ],
              ),
            ),
    );
  }

  // ============================
  // 渐变头部（品牌色 + 搜索 + Tab）
  // ============================

  Widget _buildGradientHeader(ColorScheme scheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [Color(0xFF16324F), Color(0xFF1E6FB8)]
          : const [Color(0xFF2C8EF4), Color(0xFF63B3F8)],
    );
    // 渐变上文字统一白色（深色模式同样适用）
    final onGradient = Colors.white;

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 顶栏：返回 + 标题 + 退出
          SizedBox(
            height: kToolbarHeight,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: onGradient),
                  tooltip: '返回',
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                ),
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.library_music, color: onGradient, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        '群晖音乐',
                        style: TextStyle(
                          color: onGradient,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.logout, color: onGradient),
                  tooltip: '退出群晖账号',
                  onPressed: () => _confirmLogout(scheme),
                ),
              ],
            ),
          ),
          _buildSearchBar(scheme, onGradient),
          _buildTabBar(scheme, onGradient),
        ],
      ),
    );
  }

  // ============================
  // 未登录态
  // ============================

  Widget _buildNotLoggedIn(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.library_music_outlined,
              size: 64, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            '尚未连接群晖 Audio Station',
            style: TextStyle(fontSize: 16, color: scheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            '登录后可浏览和播放 NAS 上的音乐',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('去登录'),
          ),
        ],
      ),
    );
  }

  // ============================
  // 搜索 / Tab
  // ============================

  Widget _buildSearchBar(ColorScheme scheme, Color onGradient) {
    final state = ref.watch(synologyMusicProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 渐变上的搜索框：浅色模式白底、深色模式深底
    final fieldColor =
        isDark ? const Color(0xFF1E2F45) : Colors.white.withValues(alpha: 0.95);
    final textColor =
        isDark ? Colors.white : const Color(0xFF1F2937);
    final hintColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : const Color(0xFF7A8BA0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: TextStyle(fontSize: 14, color: textColor),
        decoration: InputDecoration(
          hintText: '搜索歌曲 / 专辑 / 歌手',
          hintStyle: TextStyle(fontSize: 14, color: hintColor),
          prefixIcon: Icon(Icons.search, size: 20, color: hintColor),
          suffixIcon: state.isSearching
              ? IconButton(
                  icon: Icon(Icons.clear, size: 18, color: hintColor),
                  tooltip: '清空',
                  onPressed: () {
                    _searchController.clear();
                    ref.read(synologyMusicProvider.notifier).clearSearch();
                  },
                )
              : null,
          filled: true,
          fillColor: fieldColor,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide(color: onGradient.withValues(alpha: 0.8)),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(ColorScheme scheme, Color onGradient) {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 2),
      child: TabBar(
        controller: _tabController,
        indicatorColor: onGradient,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 3,
        labelColor: onGradient,
        unselectedLabelColor: onGradient.withValues(alpha: 0.65),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        tabs: [
          for (final tab in SynologyMusicTab.values) Tab(text: tab.label),
        ],
      ),
    );
  }

  // ============================
  // Tab 内容
  // ============================

  Widget _buildTabContent(ColorScheme scheme) {
    final state = ref.watch(synologyMusicProvider);

    // 搜索态优先展示搜索结果
    if (state.isSearching) {
      return _buildSearchResult(state, scheme);
    }

    if (state.isLoading && _isEmptyForTab(state)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && _isEmptyForTab(state)) {
      return _buildError(state.error!, scheme);
    }

    switch (SynologyMusicTab.values[_tabController.index]) {
      case SynologyMusicTab.songs:
        return _buildSongList(state.songs, scheme);
      case SynologyMusicTab.albums:
        return _buildAlbumGrid(state.albums, scheme);
      case SynologyMusicTab.artists:
        return _buildArtistList(state.artists, scheme);
      case SynologyMusicTab.playlists:
        return _buildPlaylistList(state.playlists, scheme);
    }
  }

  bool _isEmptyForTab(SynologyMusicState state) {
    switch (SynologyMusicTab.values[_tabController.index]) {
      case SynologyMusicTab.songs:
        return state.songs.isEmpty;
      case SynologyMusicTab.albums:
        return state.albums.isEmpty;
      case SynologyMusicTab.artists:
        return state.artists.isEmpty;
      case SynologyMusicTab.playlists:
        return state.playlists.isEmpty;
    }
  }

  Widget _buildError(String error, ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: scheme.error),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ref
                .read(synologyMusicProvider.notifier)
                .loadTab(SynologyMusicTab.values[_tabController.index],
                    force: true),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  // ============================
  // 歌曲列表
  // ============================

  Widget _buildSongList(List<AudioSong> songs, ColorScheme scheme) {
    if (songs.isEmpty) {
      return _buildEmpty('暂无歌曲', scheme);
    }
    final playback = ref.watch(synologyPlaybackProvider);
    final musicState = ref.watch(synologyMusicProvider);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: songs.length + (musicState.hasMoreSongs ? 1 : 0),
      itemBuilder: (context, index) {
        // 触底加载更多
        if (index >= songs.length) {
          if (!musicState.isLoadingMoreSongs) {
            // 延迟到下一帧触发，避免 build 中副作用
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref.read(synologyMusicProvider.notifier).loadMoreSongs();
              }
            });
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              ),
            ),
          );
        }
        final song = songs[index];
        final isCurrent = playback.currentSong?.id == song.id;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              ref.read(synologyPlaybackProvider.notifier).playQueue(songs, index);
            },
            child: Row(
              children: [
                _SongCover(songId: song.id, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isCurrent && playback.isPlaying)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _EqualizerBars(
                                color: scheme.primary,
                                size: 12,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    isCurrent ? FontWeight.w700 : FontWeight.w500,
                                color: isCurrent
                                    ? scheme.primary
                                    : scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (song.artistDisplay.isNotEmpty) song.artistDisplay,
                          if (song.albumDisplay.isNotEmpty) song.albumDisplay,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  song.durationText,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================
  // 专辑网格
  // ============================

  Widget _buildAlbumGrid(List<AudioAlbum> albums, ColorScheme scheme,
      {bool paginated = true}) {
    if (albums.isEmpty) {
      return _buildEmpty('暂无专辑', scheme);
    }
    final musicState = ref.watch(synologyMusicProvider);
    final showLoadingCell = paginated && musicState.hasMoreAlbums;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.78,
        mainAxisSpacing: 16,
        crossAxisSpacing: 14,
      ),
      itemCount: albums.length + (showLoadingCell ? 1 : 0),
      itemBuilder: (context, index) {
        // 触底加载更多
        if (index >= albums.length) {
          if (!musicState.isLoadingMoreAlbums && paginated) {
            // 延迟到下一帧触发，避免 build 中副作用
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref.read(synologyMusicProvider.notifier).loadMoreAlbums();
              }
            });
          }
          return Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
          );
        }
        final album = albums[index];
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showAlbumSongs(album),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 大封面卡片（QQ音乐/酷狗专辑风格）
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _AlbumCover(album: album),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface),
              ),
              const SizedBox(height: 2),
              Text(
                album.artistDisplay.isEmpty ? '未知歌手' : album.artistDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================
  // 歌手列表
  // ============================

  Widget _buildArtistList(List<AudioArtist> artists, ColorScheme scheme,
      {bool paginated = true}) {
    if (artists.isEmpty) {
      return _buildEmpty('暂无歌手', scheme);
    }
    final musicState = ref.watch(synologyMusicProvider);
    final showLoadingCell = paginated && musicState.hasMoreArtists;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.82,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
      ),
      itemCount: artists.length + (showLoadingCell ? 1 : 0),
      itemBuilder: (context, index) {
        // 触底加载更多
        if (index >= artists.length) {
          if (!musicState.isLoadingMoreArtists && paginated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref.read(synologyMusicProvider.notifier).loadMoreArtists();
              }
            });
          }
          return Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
          );
        }
        final artist = artists[index];
        // 圆形头像网格（QQ音乐/酷狗歌手风格）
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showArtistSongs(artist),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary.withValues(alpha: 0.85),
                      scheme.primary.withValues(alpha: 0.45),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.person,
                  color: scheme.onPrimary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================
  // 歌单列表
  // ============================

  Widget _buildPlaylistList(List<AudioPlaylist> playlists, ColorScheme scheme) {
    if (playlists.isEmpty) {
      return _buildEmpty('暂无歌单', scheme);
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.95,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        // 歌单封面渐变取色（QQ音乐/酷狗歌单卡风格）
        const palettes = [
          [Color(0xFF5B8DEF), Color(0xFF8E6BF0)],
          [Color(0xFF26B8A0), Color(0xFF3F9DE0)],
          [Color(0xFFF07B5B), Color(0xFFF0A94F)],
          [Color(0xFFE05B8D), Color(0xFF8E5BF0)],
          [Color(0xFF3FA7D8), Color(0xFF6B8FE0)],
          [Color(0xFF6BC75B), Color(0xFF3FA7A0)],
        ];
        final colors = palettes[index % palettes.length];
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showPlaylistSongs(playlist),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.last.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.queue_music,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 40,
                        ),
                      ),
                      // 右上角类型角标
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            playlist.type == 'smart' ? '智能' : '普通',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================
  // 搜索结果
  // ============================

  Widget _buildSearchResult(SynologyMusicState state, ColorScheme scheme) {
    if (state.isLoading && state.searchResult == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final result = state.searchResult;
    if (result == null ||
        (result.songs.isEmpty &&
            result.albums.isEmpty &&
            result.artists.isEmpty)) {
      return _buildEmpty('未找到「${state.searchKeyword}」相关内容', scheme);
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        if (result.songs.isNotEmpty) ...[
          _buildSectionHeader('歌曲 (${result.songs.length})', scheme),
          _buildSongList(result.songs, scheme),
        ],
        if (result.albums.isNotEmpty) ...[
          _buildSectionHeader('专辑 (${result.albums.length})', scheme),
          _buildAlbumGrid(result.albums, scheme, paginated: false),
        ],
        if (result.artists.isNotEmpty) ...[
          _buildSectionHeader('歌手 (${result.artists.length})', scheme),
          _buildArtistList(result.artists, scheme, paginated: false),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildEmpty(String text, ColorScheme scheme) {
    // 使用可滚动容器保证下拉刷新可用
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.music_off_outlined,
                    size: 48, color: scheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  text,
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================
  // 弹层：专辑 / 歌手 / 歌单 歌曲
  // ============================

  Future<void> _showAlbumSongs(AudioAlbum album) async {
    final songs = await ref
        .read(synologyMusicProvider.notifier)
        .loadAlbumSongs(album);
    if (!mounted) return;
    await _showSongsSheet(
      title: album.name,
      subtitle: album.artistDisplay,
      songs: songs,
      emptyText: '专辑内暂无歌曲',
      cover: _albumCoverUrl(album),
    );
  }

  Future<void> _showArtistSongs(AudioArtist artist) async {
    // 通过 API 按歌手名过滤歌曲
    final api = ref.read(synologyAuthProvider.notifier).api;
    List<AudioSong> songs;
    try {
      songs = await api.getSongs(artist: artist.name);
    } catch (e) {
      AppLogger.warn('加载歌手歌曲失败', data: {'artist': artist.name, 'error': e.toString()});
      songs = const [];
    }
    if (!mounted) return;
    await _showSongsSheet(
      title: artist.name,
      songs: songs,
      emptyText: '该歌手暂无歌曲',
    );
  }

  Future<void> _showPlaylistSongs(AudioPlaylist playlist) async {
    final songs = await ref
        .read(synologyMusicProvider.notifier)
        .loadPlaylistSongs(playlist.id);
    if (!mounted) return;
    await _showSongsSheet(
      title: playlist.name,
      songs: songs,
      emptyText: '歌单内暂无歌曲',
    );
  }

  Future<void> _showSongsSheet({
    required String title,
    String? subtitle,
    required List<AudioSong> songs,
    required String emptyText,
    String? cover,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  if (cover != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          cacheManager: AppImageCacheManager.thumbnail,
                          errorWidget: (_, __, ___) => Container(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(Icons.album,
                                color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill, size: 32),
                    color: scheme.primary,
                    tooltip: '播放全部',
                    onPressed: songs.isEmpty
                        ? null
                        : () {
                            ref
                                .read(synologyPlaybackProvider.notifier)
                                .playQueue(songs, 0);
                            Navigator.pop(ctx);
                          },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: songs.isEmpty
                  ? Center(
                      child: Text(
                        emptyText,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: songs.length,
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        final isCurrent = ref
                                .watch(synologyPlaybackProvider)
                                .currentSong
                                ?.id ==
                            song.id;
                        return ListTile(
                          dense: true,
                          leading: _SongCover(songId: song.id, size: 40),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isCurrent ? FontWeight.w700 : FontWeight.w500,
                              color: isCurrent
                                  ? scheme.primary
                                  : scheme.onSurface,
                            ),
                          ),
                          subtitle: song.artistDisplay.isNotEmpty
                              ? Text(
                                  song.artistDisplay,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant),
                                )
                              : null,
                          trailing: Text(
                            song.durationText,
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant),
                          ),
                          onTap: () {
                            ref
                                .read(synologyPlaybackProvider.notifier)
                                .playQueue(songs, index);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String? _albumCoverUrl(AudioAlbum album) {
    return ref
        .read(synologyAuthProvider.notifier)
        .api
        .getAlbumCoverUrl(
          albumName: album.name,
          albumArtistName: album.albumArtist,
        );
  }

  // ============================
  // 退出登录
  // ============================

  Future<void> _confirmLogout(ColorScheme scheme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surface,
        title: const Text('退出群晖账号'),
        content: const Text('确定要退出群晖 Audio Station 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      // 停止播放并退出
      await ref.read(synologyPlaybackProvider.notifier).stop();
      await ref.read(synologyAuthProvider.notifier).logout();
      ref.read(synologyMusicProvider.notifier).clearSearch();
    }
  }
}

// ============================
// 歌曲封面组件
// ============================

class _SongCover extends ConsumerWidget {
  final String songId;
  final double size;

  const _SongCover({required this.songId, required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final url = ref
        .read(synologyAuthProvider.notifier)
        .api
        .getSongCoverUrl(songId);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                cacheManager: AppImageCacheManager.thumbnail,
                errorWidget: (_, __, ___) => _coverFallback(scheme),
              )
            : _coverFallback(scheme),
      ),
    );
  }

  Widget _coverFallback(ColorScheme scheme) {
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.music_note, color: scheme.onSurfaceVariant, size: 20),
    );
  }
}

/// 专辑封面组件
class _AlbumCover extends ConsumerWidget {
  final AudioAlbum album;

  const _AlbumCover({required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final url = ref
        .read(synologyAuthProvider.notifier)
        .api
        .getAlbumCoverUrl(
          albumName: album.name,
          albumArtistName: album.albumArtist,
        );
    return url != null
        ? CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            cacheManager: AppImageCacheManager.thumbnail,
            errorWidget: (_, __, ___) => Container(
              color: scheme.surfaceContainerHighest,
              child: Icon(Icons.album, color: scheme.onSurfaceVariant, size: 28),
            ),
          )
        : Container(
            color: scheme.surfaceContainerHighest,
            child: Icon(Icons.album, color: scheme.onSurfaceVariant, size: 28),
          );
  }
}

// ============================
// 底部迷你播放条
// ============================

class _MiniPlayerBar extends ConsumerWidget {
  const _MiniPlayerBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(synologyPlaybackProvider);
    final song = state.currentSong;
    if (song == null) return const SizedBox.shrink();

    final notifier = ref.read(synologyPlaybackProvider.notifier);

    return Material(
      color: scheme.surfaceContainerHighest,
      elevation: 10,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 4, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 进度条
              LinearProgressIndicator(
                value: state.duration.inMilliseconds > 0
                    ? (state.position.inMilliseconds /
                            state.duration.inMilliseconds)
                        .clamp(0.0, 1.0)
                    : 0,
                minHeight: 2,
                backgroundColor: scheme.outlineVariant.withValues(alpha: 0.4),
                color: scheme.primary,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _SongCover(songId: song.id, size: 44),
                  const SizedBox(width: 10),
                  // 标题 + 歌手
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (song.artistDisplay.isNotEmpty)
                          Text(
                            song.artistDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  // 播放控制（紧凑布局，防窄屏溢出）
                  _compactButton(
                    scheme: scheme,
                    icon: Icon(
                      switch (state.mode) {
                        SynologyPlaybackMode.listLoop => Icons.repeat,
                        SynologyPlaybackMode.singleLoop => Icons.repeat_one,
                        SynologyPlaybackMode.shuffle => Icons.shuffle,
                      },
                      size: 17,
                    ),
                    color: state.mode == SynologyPlaybackMode.listLoop
                        ? scheme.onSurfaceVariant
                        : scheme.primary,
                    tooltip: '播放模式：${state.mode.label}',
                    onPressed: notifier.cycleMode,
                  ),
                  _compactButton(
                    scheme: scheme,
                    icon: const Icon(Icons.skip_previous, size: 22),
                    color: scheme.onSurface,
                    tooltip: '上一首',
                    onPressed:
                        state.currentIndex > 0 ? notifier.previous : null,
                  ),
                  _compactButton(
                    scheme: scheme,
                    icon: Icon(
                      state.isLoading
                          ? Icons.hourglass_top
                          : state.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                      size: 34,
                    ),
                    color: scheme.primary,
                    tooltip: state.isPlaying ? '暂停' : '播放',
                    onPressed: state.isLoading ? null : notifier.togglePlay,
                  ),
                  _compactButton(
                    scheme: scheme,
                    icon: const Icon(Icons.skip_next, size: 22),
                    color: scheme.onSurface,
                    tooltip: '下一首',
                    onPressed: state.currentIndex < state.queue.length - 1
                        ? notifier.next
                        : null,
                  ),
                  _compactButton(
                    scheme: scheme,
                    icon: const Icon(Icons.close, size: 17),
                    color: scheme.onSurfaceVariant,
                    tooltip: '停止',
                    onPressed: notifier.stop,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 紧凑播放控制按钮（压缩点击热区，避免窄屏溢出）
  Widget _compactButton({
    required ColorScheme scheme,
    required Widget icon,
    required Color color,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: icon,
      color: color,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }
}

// ============================
// 动态均衡器（当前播放歌曲指示）
// ============================

/// 三根跳动柱子的动态均衡器动画，参考主流音乐 App 的"正在播放"指示
class _EqualizerBars extends StatefulWidget {
  final Color color;
  final double size;

  const _EqualizerBars({required this.color, required this.size});

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<double> _phases = [0.0, 2.1, 4.2];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * 3.1415926;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final phase in _phases)
                Container(
                  width: widget.size / 4,
                  height: widget.size *
                      (0.35 + 0.55 * (0.5 + 0.5 * math.sin(t + phase))),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

}
