// 从 synology_music_view.dart 拆分（part 文件，无行为变化）

part of '../synology_music_view.dart';

// ==================== _MusicSheetsMixin ====================

extension _MusicSheetsMixin on _SynologyMusicViewState {
  Future<void> _showAlbumSongs(AudioAlbum album) async {
    try {
      final songs =
          await ref.read(synologyMusicProvider.notifier).loadAlbumSongs(album);
      if (!mounted) return;
      await _showSongsSheet(
        title: album.name,
        subtitle: album.artistDisplay,
        songs: songs,
        emptyText: '专辑内暂无歌曲',
        cover: _albumCoverUrl(album),
      );
    } catch (e) {
      if (!mounted) return;
      AppLogger.warn('加载专辑歌曲失败',
          data: {'album': album.name, 'error': e.toString()});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '加载专辑歌曲失败：${e.toString().length > 50 ? '${e.toString().substring(0, 50)}...' : e.toString()}')),
      );
    }
  }

  Future<void> _showArtistSongs(AudioArtist artist) async {
    // 跳转到独立的歌手详情页（V1.0 歌手简介功能）
    // 歌手详情页包含：可折叠头部、操作按钮、简介模块、专辑列表、歌曲列表
    context.push('/music/artist/${Uri.encodeComponent(artist.name)}');
  }

  Future<void> _showPlaylistSongs(AudioPlaylist playlist) async {
    try {
      final songs = await ref
          .read(synologyMusicProvider.notifier)
          .loadPlaylistSongs(playlist.id);
      if (!mounted) return;
      await _showSongsSheet(
        title: playlist.name,
        songs: songs,
        emptyText: '歌单内暂无歌曲',
      );
    } catch (e) {
      if (!mounted) return;
      AppLogger.warn('加载歌单歌曲失败',
          data: {'playlist': playlist.name, 'error': e.toString()});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '加载歌单歌曲失败：${e.toString().length > 50 ? '${e.toString().substring(0, 50)}...' : e.toString()}')),
      );
    }
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
                            fontSize: _kFontSizeLarge,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            // 歌手简介允许多行展示（最多 3 行）
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: _kFontSizeSmall,
                                height: 1.4,
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
                            color: scheme.onSurfaceVariant,
                            fontSize: _kFontSizeBody),
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
                          leading: SongCover(songId: song.id, size: 40),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: _kFontSizeMedium,
                              fontWeight:
                                  isCurrent ? FontWeight.w700 : FontWeight.w500,
                              color:
                                  isCurrent ? scheme.primary : scheme.onSurface,
                            ),
                          ),
                          subtitle: song.artistDisplay.isNotEmpty
                              ? Text(
                                  song.artistDisplay,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: _kFontSizeSmall,
                                      color: scheme.onSurfaceVariant),
                                )
                              : null,
                          trailing: Text(
                            song.durationText,
                            style: TextStyle(
                                fontSize: _kFontSizeSmall,
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
