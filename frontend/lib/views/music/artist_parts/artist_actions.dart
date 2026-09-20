// 从 artist_detail_page.dart 拆分（part 文件，无行为变化）

part of '../artist_detail_page.dart';

// ==================== _ArtistActions ====================

extension _ArtistActions on _ArtistDetailPageState {
  Future<void> _loadFavoriteStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('favorite_artists') ?? [];
    if (mounted) {
      setState(() {
        _isFavorite = favorites.contains(_artistName);
      });
    }
  }

  Future<void> _saveFavoriteStatus(bool isFavorite) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('favorite_artists') ?? [];
    if (isFavorite) {
      if (!favorites.contains(_artistName)) {
        favorites.add(_artistName);
      }
    } else {
      favorites.remove(_artistName);
    }
    await prefs.setStringList('favorite_artists', favorites);

    // 异步同步到 NAS（不阻塞 UI）
    try {
      final api = ref.read(synologyAudioApiProvider);
      if (api.isLoggedIn) {
        // 直接调用 NAS 同步服务上传收藏列表
        // 这里简化处理，直接上传完整列表
      }
    } catch (e) {
      // 忽略同步错误，本地保存已成功
    }
  }

  bool _isTabletLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > _kTabletLandscapeWidthThreshold &&
        size.width > size.height;
  }

  Future<void> _showArtistPicker(BuildContext context) async {
    final service = ref.read(artistMetadataServiceProvider);
    final lastFmService = service.lastFmService;
    final deezerService = service.deezerService;

    final selected = await showModalBottomSheet<ArtistSearchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ArtistSearchPicker(
        searchQuery: _artistName,
        lastFmService: lastFmService,
        deezerService: deezerService,
      ),
    );

    if (selected != null && context.mounted) {
      // 跳转到选中的歌手详情页
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ArtistDetailPage(artistName: selected.name),
        ),
      );
    }
  }

  Future<void> _showMetadataEditor(
    BuildContext context,
    ArtistMetadata currentMetadata,
  ) async {
    final updated = await showModalBottomSheet<ArtistMetadata>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ArtistMetadataEditor(
        artistName: _artistName,
        currentMetadata: currentMetadata,
      ),
    );

    if (updated != null && context.mounted) {
      // 刷新页面，显示更新后的元数据
      setState(() {
        // 触发 provider 重新加载
        ref.invalidate(artistMetadataProvider(_artistName));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('歌手信息已更新'),
          duration: Duration(seconds: 2),
        ),
      );
    }
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
              leading: const Icon(Icons.music_note, size: 40),
              title: Text(song.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [
                  if (song.artistDisplay.isNotEmpty) song.artistDisplay,
                  if (song.albumDisplay.isNotEmpty) song.albumDisplay,
                ].join(' · '),
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
                _playSong(context, song);
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

  void _playAll(BuildContext context) {
    final songsAsync = ref.read(artistSongsProvider(_artistName));
    final songs = songsAsync.value ?? [];
    if (songs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无歌曲可播放')),
      );
      return;
    }
    ref.read(synologyPlaybackProvider.notifier).playQueue(songs, 0);
  }

  void _playSong(BuildContext context, AudioSong song) {
    final songsAsync = ref.read(artistSongsProvider(_artistName));
    final songs = songsAsync.value ?? [];
    final index = songs.indexWhere((s) => s.id == song.id);
    if (index >= 0) {
      ref.read(synologyPlaybackProvider.notifier).playQueue(songs, index);
    } else {
      // 如果找不到索引，直接播放该歌曲
      ref.read(synologyPlaybackProvider.notifier).playQueue([song], 0);
    }
  }

  void _showAllAlbumsDialog(
    BuildContext context,
    ColorScheme scheme,
    AsyncValue<List<AudioAlbum>> albumsAsync,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_artistName}的专辑',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 专辑列表
            Expanded(
              child: albumsAsync.when(
                data: (albums) => albums.isEmpty
                    ? const Center(child: Text('暂无专辑'))
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: albums.length,
                        itemBuilder: (context, index) {
                          final album = albums[index];
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: album.coverUrl != null &&
                                      album.coverUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: album.coverUrl!,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      color: scheme.surfaceContainerHighest,
                                      child: const Icon(Icons.album, size: 24),
                                    ),
                            ),
                            title: Text(
                              album.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: album.year != null
                                ? Text('${album.year}')
                                : null,
                            onTap: () {
                              Navigator.pop(context);
                              _showAlbumDetailDialog(context, scheme, album);
                            },
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => const Center(child: Text('加载失败')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlbumDetailDialog(
    BuildContext context,
    ColorScheme scheme,
    AudioAlbum album,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // 专辑头部信息
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 专辑封面
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: album.coverUrl != null && album.coverUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: album.coverUrl!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 80,
                            height: 80,
                            color: scheme.surfaceContainerHighest,
                            child: const Icon(Icons.album, size: 32),
                          ),
                  ),
                  const SizedBox(width: 16),
                  // 专辑信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          album.year != null ? '${album.year}' : '未知年份',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 关闭按钮
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 专辑歌曲列表
            Expanded(
              child: _buildAlbumSongsList(
                  context, scheme, album, scrollController),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
