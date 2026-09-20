// 从 synology_music_view.dart 拆分（part 文件，无行为变化）

part of '../synology_music_view.dart';

// ==================== _MusicListBuilders ====================

extension _MusicListBuilders on _SynologyMusicViewState {
  Widget _buildLoadingIndicator(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: _kLoadingIndicatorSize,
          height: _kLoadingIndicatorSize,
          child: CircularProgressIndicator(
            strokeWidth: _kLoadingIndicatorStrokeWidth,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildError(String error, ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: scheme.error),
          const SizedBox(height: _kSpacingXXLarge),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: _kFontSizeBody),
            ),
          ),
          const SizedBox(height: _kSpacingXXXLarge),
          OutlinedButton.icon(
            onPressed: () => ref.read(synologyMusicProvider.notifier).loadTab(
                SynologyMusicTab.values[_tabController.index],
                force: true),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

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
          return _buildLoadingIndicator(scheme);
        }
        final song = songs[index];
        final isCurrent = playback.currentSong?.id == song.id;
        return Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: _kSongListHorizontalPadding,
              vertical: _kSongListVerticalPadding),
          child: InkWell(
            borderRadius: BorderRadius.circular(_kSongListBorderRadius),
            onTap: () {
              ref
                  .read(synologyPlaybackProvider.notifier)
                  .playQueue(songs, index);
            },
            onLongPress: () => _showSongOptions(context, scheme, song),
            child: Row(
              children: [
                SongCover(songId: song.id, size: _kSongCoverSize),
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
                              child: EqualizerBars(
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
                                fontSize: _kFontSizeMedium,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500,
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
                            fontSize: _kFontSizeSmall,
                            color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  song.durationText,
                  style: TextStyle(
                      fontSize: _kFontSizeSmall,
                      color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
        crossAxisCount: _kAlbumGridCrossAxisCount,
        childAspectRatio: _kAlbumGridChildAspectRatio,
        mainAxisSpacing: _kAlbumGridMainAxisSpacing,
        crossAxisSpacing: _kAlbumGridCrossAxisSpacing,
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
          return _buildLoadingIndicator(scheme);
        }
        final album = albums[index];
        return InkWell(
          borderRadius: BorderRadius.circular(_kAlbumGridBorderRadius),
          onTap: () => _showAlbumSongs(album),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 大封面卡片（QQ音乐/酷狗专辑风格）
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(_kAlbumGridBorderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(_kAlbumGridBorderRadius),
                    child: AlbumCover(album: album),
                  ),
                ),
              ),
              const SizedBox(height: _kSpacingLarge),
              Text(
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: _kFontSizeBody,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface),
              ),
              const SizedBox(height: _kSpacingXSmall),
              Text(
                album.artistDisplay.isEmpty ? '未知歌手' : album.artistDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtistList(List<AudioArtist> artists, ColorScheme scheme,
      {bool paginated = true}) {
    if (artists.isEmpty) {
      return _buildEmpty('暂无歌手', scheme);
    }
    final musicState = ref.watch(synologyMusicProvider);
    final showLoadingCell = paginated && musicState.hasMoreArtists;
    final grid = GridView.builder(
      controller: _artistScrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 32, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _kArtistGridCrossAxisCount,
        childAspectRatio: _kArtistGridChildAspectRatio,
        mainAxisSpacing: _kArtistGridMainAxisSpacing,
        crossAxisSpacing: _kArtistGridCrossAxisSpacing,
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
          return _buildLoadingIndicator(scheme);
        }
        final artist = artists[index];
        // 圆形头像网格（QQ音乐/酷狗歌手风格）：优先显示 NAS 歌手图，
        // 无图时回退为首字母渐变头像
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showArtistSongs(artist),
          child: Column(
            children: [
              ArtistAvatar(artistName: artist.name, size: 72),
              const SizedBox(height: _kSpacingLarge),
              Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: _kFontSizeBody,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface),
              ),
            ],
          ),
        );
      },
    );

    // 右侧 A-Z 字母索引
    final letters = <String>{};
    for (final a in artists) {
      final ch =
          a.name.trim().isNotEmpty ? a.name.trim()[0].toUpperCase() : '#';
      letters.add(RegExp(r'[A-Z]').hasMatch(ch) ? ch : '#');
    }
    final sortedLetters = letters.toList()..sort();
    if (sortedLetters.length < 2) return grid;
    return Stack(
      children: [
        grid,
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: sortedLetters.map((ch) {
                return GestureDetector(
                  onTap: () {
                    final idx = artists.indexWhere((a) {
                      final first = a.name.trim().isNotEmpty
                          ? a.name.trim()[0].toUpperCase()
                          : '#';
                      final key =
                          RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
                      return key == ch;
                    });
                    if (idx < 0 || !_artistScrollController.hasClients) return;
                    const rowH = 96.0;
                    final row = idx ~/ _kArtistGridCrossAxisCount;
                    _artistScrollController.animateTo(
                      (row * rowH).toDouble(),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 1.5, horizontal: 4),
                    child: Text(ch,
                        style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurface.withValues(alpha: 0.7))),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistList(List<AudioPlaylist> playlists, ColorScheme scheme) {
    if (playlists.isEmpty) {
      return _buildEmpty('暂无歌单', scheme);
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _kPlaylistGridCrossAxisCount,
        childAspectRatio: _kPlaylistGridChildAspectRatio,
        mainAxisSpacing: _kPlaylistGridMainAxisSpacing,
        crossAxisSpacing: _kPlaylistGridCrossAxisSpacing,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        // 歌单封面渐变取色（QQ音乐/酷狗歌单卡风格）
        final colors = _kPlaylistGradients[index % _kPlaylistGradients.length];
        return InkWell(
          borderRadius: BorderRadius.circular(_kPlaylistGridBorderRadius),
          onTap: () => _showPlaylistSongs(playlist),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(_kPlaylistGridBorderRadius),
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
                          size: _kPlaylistCoverIconSize,
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
                              fontSize: _kFontSizeTiny,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: _kSpacingLarge),
              Text(
                playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: _kFontSizeBody,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface),
              ),
            ],
          ),
        );
      },
    );
  }

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
          // 搜索结果：头像 + 简介 + 出处 列表（供用户选择）
          _buildArtistSearchList(result.artists, scheme),
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
          fontSize: _kFontSizeBody,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildArtistSearchList(List<AudioArtist> artists, ColorScheme scheme) {
    return Column(
      children: [
        for (final artist in artists)
          ArtistSearchTile(
            artist: artist,
            // 顶部全局搜索只查群晖本地库
            hitSource: ArtistInfoSource.synology,
            onTap: () => _showArtistSongs(artist),
          ),
      ],
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
                const SizedBox(height: _kSpacingXXLarge),
                Text(
                  text,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: _kFontSizeMedium),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
