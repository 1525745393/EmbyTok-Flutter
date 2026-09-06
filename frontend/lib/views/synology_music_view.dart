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
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.library_music, color: Color(0xFF2C8EF4), size: 22),
            SizedBox(width: 8),
            Text('群晖音乐'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '退出群晖账号',
            onPressed: () => _confirmLogout(scheme),
          ),
        ],
      ),
      body: !auth.isLoggedIn
          ? _buildNotLoggedIn(scheme)
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  _buildSearchBar(scheme),
                  _buildTabBar(scheme),
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

  Widget _buildSearchBar(ColorScheme scheme) {
    final state = ref.watch(synologyMusicProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: '搜索歌曲 / 专辑 / 歌手',
          hintStyle: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          prefixIcon: Icon(Icons.search, size: 20, color: scheme.primary),
          suffixIcon: state.isSearching
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: '清空',
                  onPressed: () {
                    _searchController.clear();
                    ref.read(synologyMusicProvider.notifier).clearSearch();
                  },
                )
              : null,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(ColorScheme scheme) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      child: TabBar(
        controller: _tabController,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
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
        return ListTile(
          leading: _SongCover(songId: song.id, size: 44),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: isCurrent ? scheme.primary : scheme.onSurface,
            ),
          ),
          subtitle: Text(
            [
              if (song.artistDisplay.isNotEmpty) song.artistDisplay,
              if (song.albumDisplay.isNotEmpty) song.albumDisplay,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCurrent && playback.isPlaying)
                Icon(Icons.graphic_eq, size: 18, color: scheme.primary)
              else if (isCurrent)
                Icon(Icons.pause_circle_outline,
                    size: 18, color: scheme.primary),
              const SizedBox(width: 4),
              Text(
                song.durationText,
                style:
                    TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          onTap: () {
            ref.read(synologyPlaybackProvider.notifier).playQueue(songs, index);
          },
        );
      },
    );
  }

  // ============================
  // 专辑网格
  // ============================

  Widget _buildAlbumGrid(List<AudioAlbum> albums, ColorScheme scheme) {
    if (albums.isEmpty) {
      return _buildEmpty('暂无专辑', scheme);
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.72,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showAlbumSongs(album),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _AlbumCover(album: album),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface),
              ),
              Text(
                album.artistDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
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

  Widget _buildArtistList(List<AudioArtist> artists, ColorScheme scheme) {
    if (artists.isEmpty) {
      return _buildEmpty('暂无歌手', scheme);
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: scheme.primaryContainer.withValues(alpha: 0.5),
            child: Icon(Icons.person, color: scheme.primary, size: 22),
          ),
          title: Text(
            artist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface),
          ),
          trailing:
              Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
          onTap: () => _showArtistSongs(artist),
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.queue_music, color: scheme.primary, size: 22),
          ),
          title: Text(
            playlist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface),
          ),
          subtitle: Text(
            playlist.type == 'smart' ? '智能歌单' : '普通歌单',
            style:
                TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          trailing:
              Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
          onTap: () => _showPlaylistSongs(playlist),
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
          _buildAlbumGrid(result.albums, scheme),
        ],
        if (result.artists.isNotEmpty) ...[
          _buildSectionHeader('歌手 (${result.artists.length})', scheme),
          _buildArtistList(result.artists, scheme),
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
      borderRadius: BorderRadius.circular(8),
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
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              const SizedBox(height: 6),
              Row(
                children: [
                  _SongCover(songId: song.id, size: 40),
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
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    color: scheme.onSurface,
                    tooltip: '上一首',
                    onPressed:
                        state.currentIndex > 0 ? notifier.previous : null,
                  ),
                  IconButton(
                    icon: Icon(
                      state.isLoading
                          ? Icons.hourglass_top
                          : state.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                      size: 36,
                    ),
                    color: scheme.primary,
                    tooltip: state.isPlaying ? '暂停' : '播放',
                    onPressed: state.isLoading ? null : notifier.togglePlay,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    color: scheme.onSurface,
                    tooltip: '下一首',
                    onPressed: state.currentIndex < state.queue.length - 1
                        ? notifier.next
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
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
}
