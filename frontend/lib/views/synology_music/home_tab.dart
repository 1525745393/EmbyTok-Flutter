// 从 synology_music_view.dart 拆分（part 文件，无行为变化）

part of '../synology_music_view.dart';

// ==================== _MusicHomeTabBuilders ====================

extension _MusicHomeTabBuilders on _SynologyMusicViewState {
  Widget _buildHomeTab(SynologyMusicState state, ColorScheme scheme) {
    // 最近播放记录（客户端本地存储，PRD 首屏核心模块）
    final recentPlaybacks = ref.watch(recentPlaybacksProvider);

    // 精选专辑：从全量专辑中随机抽样，与最近添加去重（name+artist 组合，避免同名不同艺术家被错误去重）
    // 首次计算后缓存，避免每次 build 重新 shuffle 导致内容频繁跳变
    // 注意：仅当 state.albums 非空时才缓存，避免异步数据未加载时缓存空列表导致模块永远不显示
    // 优化：当专辑数量变化时（如分页加载更多），清除缓存重新抽样
    if (_cachedFeaturedAlbums != null &&
        _cachedAlbumsLength != state.albums.length) {
      _cachedFeaturedAlbums = null;
      _cachedAlbumsLength = null;
    }
    final featured = _cachedFeaturedAlbums ??
        (state.albums.isNotEmpty
            ? _cachedFeaturedAlbums = () {
                _cachedAlbumsLength = state.albums.length;
                final recentKeys = state.recentAlbums
                    .map(
                        (e) => '${e.name}||${e.displayArtist ?? e.albumArtist}')
                    .toSet();
                final candidates = state.albums
                    .where((a) => !recentKeys.contains(
                        '${a.name}||${a.displayArtist ?? a.albumArtist}'))
                    .toList()
                  ..shuffle();
                return candidates.take(_kFeaturedAlbumsCount).toList();
              }()
            : const <AudioAlbum>[]);

    return RefreshIndicator(
      onRefresh: () => ref
          .read(synologyMusicProvider.notifier)
          .loadTab(SynologyMusicTab.values[_tabController.index], force: true),
      child: ListView(
        controller: _homeScrollController,
        padding: const EdgeInsets.only(
            top: _kSectionTitleTopPadding, bottom: _kSectionTitleBottomPadding),
        children: [
          // 快捷入口
          _buildQuickEntries(scheme),
          const SizedBox(height: _kSpacingXXXXLarge),
          // 最近播放（无记录时整个模块隐藏，PRD 要求）
          if (recentPlaybacks.isNotEmpty) ...[
            _buildHomeSectionHeader(
                _kHomeSectionRecentPlaybacks, SynologyMusicTab.songs, scheme),
            const SizedBox(height: _kSpacingXLarge),
            _buildRecentPlaybacksList(recentPlaybacks, scheme),
            const SizedBox(height: _kSpacingXXXXLarge),
          ],
          // 最近添加（time_add 倒序，NAS 原生接口）
          if (state.recentAlbums.isNotEmpty) ...[
            _buildHomeSectionHeader(
                _kHomeSectionRecentAlbums, SynologyMusicTab.albums, scheme),
            const SizedBox(height: _kSpacingXLarge),
            AlbumHorizontalList(
                albums: state.recentAlbums,
                scheme: scheme,
                onAlbumTap: _showAlbumSongs),
            const SizedBox(height: _kSpacingXXXXLarge),
          ],
          // 我的锁定（My Pins / 用户收藏，SYNO.AudioStation.Pin）
          if (state.pins.isNotEmpty) ...[
            _buildHomeSectionHeader(_kHomeSectionPins, null, scheme),
            const SizedBox(height: _kSpacingXLarge),
            _buildPinsList(state.pins, scheme),
            const SizedBox(height: _kSpacingXXXXLarge),
          ],
          // 我的歌单
          if (state.playlists.isNotEmpty) ...[
            _buildHomeSectionHeader(
                _kHomeSectionPlaylists, SynologyMusicTab.playlists, scheme),
            const SizedBox(height: _kSpacingXLarge),
            PlaylistHorizontalList(
                playlists: state.playlists.take(_kHomePlaylistsCount).toList(),
                scheme: scheme,
                onPlaylistTap: _showPlaylistSongs),
            const SizedBox(height: _kSpacingXXXXLarge),
          ],
          // 精选专辑（客户端随机抽样，与最近添加去重）
          if (featured.isNotEmpty) ...[
            _buildHomeSectionHeader(
                _kHomeSectionFeaturedAlbums, SynologyMusicTab.albums, scheme),
            const SizedBox(height: _kSpacingXLarge),
            AlbumHorizontalList(
                albums: featured, scheme: scheme, onAlbumTap: _showAlbumSongs),
            const SizedBox(height: _kSpacingXXXXLarge),
          ],
          // 热门艺术家（song_count 倒序）
          if (state.topArtists.isNotEmpty) ...[
            _buildHomeSectionHeader(
                _kHomeSectionTopArtists, SynologyMusicTab.artists, scheme),
            const SizedBox(height: _kSpacingXLarge),
            ArtistHorizontalList(
                artists: state.topArtists,
                scheme: scheme,
                onArtistTap: _showArtistSongs),
            const SizedBox(height: _kSpacingXXXXLarge),
          ],
          // 音乐流派（2列网格色块卡片，PRD 页面最底部模块）
          if (state.genres.isNotEmpty) ...[
            _buildHomeSectionHeader(_kHomeSectionGenres, null, scheme),
            const SizedBox(height: _kSpacingXLarge),
            _buildGenreGrid(state.genres, scheme),
          ],
          // 全空占位（检查所有模块，包括我的锁定）
          if (state.recentAlbums.isEmpty &&
              state.topArtists.isEmpty &&
              state.genres.isEmpty &&
              state.playlists.isEmpty &&
              state.albums.isEmpty &&
              state.songs.isEmpty &&
              state.pins.isEmpty &&
              recentPlaybacks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: _kTopSpacing),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.library_music_outlined,
                        size: _kEmptyIconSize, color: scheme.onSurfaceVariant),
                    const SizedBox(height: _kEmptyIconTextSpacing),
                    Text(_kHomeEmptyText,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: _kSpacingLarge),
                    FilledButton.icon(
                      onPressed: state.isLoading
                          ? null
                          : () => ref
                              .read(synologyMusicProvider.notifier)
                              .loadTab(
                                  SynologyMusicTab.values[_tabController.index],
                                  force: true),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('刷新音乐库'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickEntries(ColorScheme scheme) {
    final entries = [
      QuickEntry(
        icon: Icons.music_note,
        label: '歌曲',
        color: _kQuickEntryColorSongs,
        onTap: () => _switchTab(SynologyMusicTab.songs),
      ),
      QuickEntry(
        icon: Icons.album,
        label: '专辑',
        color: _kQuickEntryColorAlbums,
        onTap: () => _switchTab(SynologyMusicTab.albums),
      ),
      QuickEntry(
        icon: Icons.person,
        label: '歌手',
        color: _kQuickEntryColorArtists,
        onTap: () => _switchTab(SynologyMusicTab.artists),
      ),
      QuickEntry(
        icon: Icons.playlist_play,
        label: '歌单',
        color: _kQuickEntryColorPlaylists,
        onTap: () => _switchTab(SynologyMusicTab.playlists),
      ),
      QuickEntry(
        icon: Icons.category,
        label: '流派',
        color: _kQuickEntryColorGenres,
        onTap: _scrollToGenres,
      ),
      QuickEntry(
        icon: Icons.folder,
        label: '文件夹',
        color: _kQuickEntryColorFolders,
        onTap: () => context.go('/folder'),
      ),
      QuickEntry(
        icon: Icons.shuffle,
        label: 'Random100',
        color: _kQuickEntryColorRandom,
        onTap: _shufflePlay,
      ),
      QuickEntry(
        icon: Icons.settings,
        label: '设置',
        color: _kQuickEntryColorSettings,
        onTap: () => context.go('/settings'),
      ),
    ];
    return SizedBox(
      height: _kQuickEntriesHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: _kListItemHorizontalPadding),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: _kListItemSpacing),
        itemBuilder: (context, index) =>
            QuickEntryButton(entry: entries[index]),
      ),
    );
  }

  void _scrollToGenres() {
    final context = _genreKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        alignment: 0.1, // 滚动到距顶部 10% 的位置
      );
    } else if (_homeScrollController.hasClients) {
      // 兜底：如果 GlobalKey 未就绪，滚动到页面底部
      _homeScrollController.animateTo(
        _homeScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildRecentPlaybacksList(
      List<RecentPlayback> records, ColorScheme scheme) {
    // 动态计算卡片宽度：根据屏幕宽度自适应
    // 小屏手机(<360dp): 100, 中屏(360-414dp): 110, 大屏/平板(>414dp): 120
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth < _kRecentCardSmallThreshold
        ? _kRecentCardWidthSmall
        : screenWidth <= _kRecentCardMediumThreshold
            ? _kRecentCardWidthMedium
            : _kRecentCardWidthLarge;
    // 列表高度 = 封面(正方形) + 间距 + 标题(1行) + 副标题(1行) + 边距
    final listHeight = cardWidth + 6 + 16 + 14 + 8; // 约 cardWidth + 44

    return SizedBox(
      height: listHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: _kListItemHorizontalPadding),
        itemCount: records.length,
        separatorBuilder: (_, __) => const SizedBox(width: _kCardSpacing),
        itemBuilder: (context, index) {
          final record = records[index];
          return Dismissible(
            key: ValueKey('${record.mediaType}_${record.mediaId}'),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(_kCardBorderRadius),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (direction) {
              ref
                  .read(recentPlaybacksProvider.notifier)
                  .remove(record.mediaId, record.mediaType);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已移除「${record.title}」')),
              );
            },
            child: GestureDetector(
              onTap: () => _playRecentPlayback(record),
              onLongPress: () => _showRecentPlaybackMenu(record, scheme),
              child: SizedBox(
                width: cardWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(_kCardBorderRadius),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: record.coverUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: record.coverUrl!,
                                    fit: BoxFit.cover,
                                    cacheManager:
                                        AppImageCacheManager.thumbnail,
                                    errorWidget: (_, __, ___) =>
                                        _albumCoverFallback(scheme),
                                  )
                                : _albumCoverFallback(scheme),
                          ),
                        ),
                        // 右下角悬浮播放按钮
                        Positioned(
                          right: _kPlayButtonMargin,
                          bottom: _kPlayButtonMargin,
                          child: GestureDetector(
                            onTap: () => _playRecentPlayback(record),
                            child: Container(
                              width: _kPlayButtonSize,
                              height: _kPlayButtonSize,
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.play_arrow,
                                  color: Colors.white,
                                  size: _kPlayButtonIconSize),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: _kSpacingMedium),
                    Text(record.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: _kFontSizeBody,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface)),
                    Text(record.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _playRecentPlayback(RecentPlayback record) {
    if (record.mediaType != RecentPlaybackType.song) return;
    // 从当前歌曲列表中找到匹配的歌曲并播放
    final songs = ref.read(synologyMusicProvider).songs;
    final match = songs.where((s) => s.id == record.mediaId).toList();
    if (match.isNotEmpty) {
      ref.read(synologyPlaybackProvider.notifier).playQueue(match, 0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该歌曲已不在当前列表中')),
      );
    }
  }

  Widget _buildPinsList(List<AudioPin> pins, ColorScheme scheme) {
    final gradients = [
      [const Color(0xFFFF6B6B), const Color(0xFFEE5A6F)],
      [const Color(0xFF4ECDC4), const Color(0xFF44A08D)],
      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      [const Color(0xFFF093FB), const Color(0xFFF5576C)],
      [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
      [const Color(0xFFFFA751), const Color(0xFFFF6B6B)],
    ];
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: _kListItemHorizontalPadding),
        itemCount: pins.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final pin = pins[index];
          final gradient = gradients[index % gradients.length];
          return GestureDetector(
            onTap: () => _playPin(pin),
            child: SizedBox(
              width: 110,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: gradient),
                          ),
                          child: const Icon(Icons.favorite,
                              color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                    const SizedBox(height: _kSpacingMedium),
                    Text(pin.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: _kFontSizeBody,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface)),
                    Text(pin.artist ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant)),
                  ]),
            ),
          );
        },
      ),
    );
  }

  void _playPin(AudioPin pin) {
    final songs = ref.read(synologyMusicProvider).songs;
    final match = songs.where((s) => s.id == pin.id).toList();
    if (match.isNotEmpty) {
      ref.read(synologyPlaybackProvider.notifier).playQueue(match, 0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${pin.title}」已不在当前歌曲列表中')),
      );
    }
  }

  void _showRecentPlaybackMenu(RecentPlayback record, ColorScheme scheme) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('播放'),
              onTap: () {
                Navigator.pop(ctx);
                _playRecentPlayback(record);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('移除该记录'),
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(recentPlaybacksProvider.notifier)
                    .remove(record.mediaId, record.mediaType);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSongOptions(
      BuildContext context, ColorScheme scheme, AudioSong song) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 歌曲信息头部
            ListTile(
              leading: SongCover(songId: song.id, size: 48),
              title: Text(song.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                song.artistDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('播放'),
              onTap: () {
                Navigator.pop(ctx);
                final songs = ref.read(synologyMusicProvider).songs;
                final index = songs.indexWhere((s) => s.id == song.id);
                if (index >= 0) {
                  ref
                      .read(synologyPlaybackProvider.notifier)
                      .playQueue(songs, index);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: const Text('下一首播放'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已添加到播放队列下一首')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('添加到歌单'),
              onTap: () {
                Navigator.pop(ctx);
                showAddToPlaylistSheet(context, ref, song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('收藏'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已收藏')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreGrid(List<AudioGenre> genres, ColorScheme scheme) {
    return Padding(
      key: _genreKey,
      padding:
          const EdgeInsets.symmetric(horizontal: _kListItemHorizontalPadding),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
        ),
        itemCount: genres.length,
        itemBuilder: (context, index) {
          final genre = genres[index];
          final gradient = _kGenreGradients[index % _kGenreGradients.length];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _playGenreShuffle(genre),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            genre.name.isEmpty ? '未分类' : genre.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: _kFontSizeMedium,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Icon(Icons.play_circle_outline,
                            color: Colors.white, size: 20),
                      ],
                    ),
                    const SizedBox(height: _kSpacingXSmall),
                    Text(
                      '${genre.songCount} 首',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _playGenreShuffle(AudioGenre genre) async {
    final name = genre.name.isEmpty ? '未分类' : genre.name;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在加载「$name」流派...')),
    );
    try {
      final api = ref.read(synologyAuthProvider.notifier).api;
      final songs = await api.getSongs(genre: genre.name, limit: 500);
      if (songs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('「$name」流派暂无歌曲')),
          );
        }
        return;
      }
      final shuffled = [...songs]..shuffle();
      ref.read(synologyPlaybackProvider.notifier).playQueue(shuffled, 0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载「$name」失败：$e')),
        );
      }
    }
  }

  Widget _albumCoverFallback(ColorScheme scheme) {
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.album, color: scheme.onSurfaceVariant, size: 32),
    );
  }
}
