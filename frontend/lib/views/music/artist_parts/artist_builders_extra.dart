// 从 artist_builders.dart 拆分（part 文件，无行为变化）

part of '../artist_detail_page.dart';

// ==================== 歌手详情构建（下半） ====================

extension _ArtistBuilders2 on _ArtistDetailPageState {
  Widget _buildSimilarArtistsSection(
    BuildContext context,
    ColorScheme scheme,
    ArtistMetadata metadata,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '相似歌手',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 横向滚动列表
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: metadata.similarArtists.length,
              itemBuilder: (context, index) {
                final artist = metadata.similarArtists[index];
                return GestureDetector(
                  onTap: () {
                    // 跳转到相似歌手详情页
                    context.push(
                        '/music/artist/${Uri.encodeComponent(artist.name)}');
                  },
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        // 歌手头像（圆形）
                        CircleAvatar(
                          radius: 32,
                          backgroundImage: artist.imageUrl != null
                              ? CachedNetworkImageProvider(artist.imageUrl!)
                              : null,
                          backgroundColor: scheme.surfaceContainerHighest,
                          child: artist.imageUrl != null
                              ? null
                              : Icon(
                                  Icons.person,
                                  size: 32,
                                  color: scheme.onSurfaceVariant,
                                ),
                        ),
                        const SizedBox(height: 8),
                        // 歌手名称
                        Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumsSection(
    BuildContext context,
    ColorScheme scheme,
    AsyncValue<List<AudioAlbum>> albumsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '专辑',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  _showAllAlbumsDialog(context, scheme, albumsAsync);
                },
                child: const Text('更多'),
              ),
            ],
          ),
        ),
        // 专辑横向列表
        SizedBox(
          height: 160,
          child: albumsAsync.when(
            data: (albums) => albums.isEmpty
                ? const Center(child: Text('暂无专辑'))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: albums.length,
                    itemBuilder: (context, index) {
                      final album = albums[index];
                      return _buildAlbumCard(context, scheme, album);
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => const Center(child: Text('加载失败')),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumCard(
    BuildContext context,
    ColorScheme scheme,
    AudioAlbum album,
  ) {
    return GestureDetector(
      onTap: () {
        _showAlbumDetailDialog(context, scheme, album);
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 专辑封面
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: album.coverUrl != null && album.coverUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: album.coverUrl!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _buildAlbumPlaceholder(scheme),
                      errorWidget: (_, __, ___) =>
                          _buildAlbumPlaceholder(scheme),
                    )
                  : _buildAlbumPlaceholder(scheme),
            ),
            const SizedBox(height: 6),
            // 专辑名
            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            // 发行年份
            if (album.year != null)
              Text(
                album.year.toString(),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumPlaceholder(ColorScheme scheme) {
    return Container(
      width: 120,
      height: 120,
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.album,
        size: 40,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildSongsSection(
    BuildContext context,
    ColorScheme scheme,
    AsyncValue<List<AudioSong>> songsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '歌曲',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // 歌曲列表
        songsAsync.when(
          data: (songs) => songs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('暂无歌曲')),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return _buildSongItem(context, scheme, song, index);
                  },
                ),
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, s) => Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text('加载失败: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildSongItem(
    BuildContext context,
    ColorScheme scheme,
    AudioSong song,
    int index,
  ) {
    return ListTile(
      leading: Text(
        '${index + 1}',
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        song.albumDisplay,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      trailing: Text(
        song.durationText,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      onTap: () => _playSong(context, song),
      onLongPress: () => _showSongOptions(context, scheme, song),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    final scheme = Theme.of(context).colorScheme;

    // 根据错误类型显示用户友好的提示
    String errorMessage;
    if (error.toString().contains('SocketException') ||
        error.toString().contains('NetworkException')) {
      errorMessage = '网络连接失败，请检查网络设置';
    } else if (error.toString().contains('TimeoutException')) {
      errorMessage = '请求超时，请稍后重试';
    } else if (error.toString().contains('401') ||
        error.toString().contains('403') ||
        error.toString().contains('Unauthorized')) {
      errorMessage = '登录已过期，请重新登录';
    } else if (error.toString().contains('404')) {
      errorMessage = '未找到相关歌手信息';
    } else {
      errorMessage = '加载失败，请稍后重试';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: scheme.error),
          const SizedBox(height: 16),
          Text(
            errorMessage,
            style: TextStyle(color: scheme.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              ref.invalidate(artistMetadataProvider(_artistName));
              ref.invalidate(artistSongsProvider(_artistName));
              ref.invalidate(artistAlbumsProvider(_artistName));
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumSongsList(
    BuildContext context,
    ColorScheme scheme,
    AudioAlbum album,
    ScrollController scrollController,
  ) {
    final songsAsync = ref.watch(artistSongsProvider(_artistName));

    return songsAsync.when(
      data: (allSongs) {
        // 筛选当前专辑的歌曲（通过 tag.album 字段匹配）
        final albumSongs =
            allSongs.where((song) => song.tag?.album == album.name).toList();

        if (albumSongs.isEmpty) {
          return const Center(child: Text('暂无歌曲'));
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: albumSongs.length,
          itemBuilder: (context, index) {
            final song = albumSongs[index];
            return ListTile(
              leading: Text(
                '${index + 1}',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: song.tag?.album != null ? Text(song.tag!.album!) : null,
              trailing: song.audio?.duration != null
                  ? Text(
                      _formatDuration(song.audio!.duration!),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    )
                  : null,
              onTap: () {
                Navigator.pop(context);
                _playSong(context, song);
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => const Center(child: Text('加载失败')),
    );
  }
}
