// 从 artist_detail_page.dart 拆分（part 文件，无行为变化）

part of '../artist_detail_page.dart';

// ==================== _ArtistBuilders ====================

extension _ArtistBuilders on _ArtistDetailPageState {
  Widget _buildContent(
    BuildContext context,
    ColorScheme scheme,
    ArtistMetadata metadata,
    AsyncValue<List<AudioSong>> songsAsync,
    AsyncValue<List<AudioAlbum>> albumsAsync,
  ) {
    // 平板横屏模式：使用两栏布局
    if (_isTabletLandscape(context)) {
      return _buildTabletLandscapeContent(
        context,
        scheme,
        metadata,
        songsAsync,
        albumsAsync,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(artistMetadataProvider(_artistName));
        ref.invalidate(artistSongsProvider(_artistName));
        ref.invalidate(artistAlbumsProvider(_artistName));
      },
      child: CustomScrollView(
        slivers: [
          // 可折叠头部区域
          _buildSliverAppBar(context, scheme, metadata),

          // 操作按钮行
          SliverToBoxAdapter(
            child: _buildActionButtons(context, scheme, metadata),
          ),

          // 歌手简介模块
          if (metadata.hasBio)
            SliverToBoxAdapter(
              child: _buildBioSection(context, scheme, metadata),
            ),

          // 相似歌手（V1.1）
          if (metadata.hasSimilarArtists)
            SliverToBoxAdapter(
              child: _buildSimilarArtistsSection(context, scheme, metadata),
            ),

          // 歌手专辑列表
          SliverToBoxAdapter(
            child: _buildAlbumsSection(context, scheme, albumsAsync),
          ),

          // 歌手歌曲列表
          SliverToBoxAdapter(
            child: _buildSongsSection(context, scheme, songsAsync),
          ),

          // 底部间距
          const SliverToBoxAdapter(
              child: const SizedBox(height: _kBottomSpacing)),
        ],
      ),
    );
  }

  Widget _buildTabletLandscapeContent(
    BuildContext context,
    ColorScheme scheme,
    ArtistMetadata metadata,
    AsyncValue<List<AudioSong>> songsAsync,
    AsyncValue<List<AudioAlbum>> albumsAsync,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(artistMetadataProvider(_artistName));
        ref.invalidate(artistSongsProvider(_artistName));
        ref.invalidate(artistAlbumsProvider(_artistName));
      },
      child: CustomScrollView(
        slivers: [
          // 可折叠头部区域（横屏模式下高度更小）
          _buildSliverAppBar(context, scheme, metadata,
              expandedHeight: _kHeaderExpandedHeightLandscape),

          // 操作按钮行
          SliverToBoxAdapter(
            child: _buildActionButtons(context, scheme, metadata),
          ),

          // 歌手简介模块
          if (metadata.hasBio)
            SliverToBoxAdapter(
              child: _buildBioSection(context, scheme, metadata),
            ),

          // 相似歌手（V1.1）
          if (metadata.hasSimilarArtists)
            SliverToBoxAdapter(
              child: _buildSimilarArtistsSection(context, scheme, metadata),
            ),

          // 两栏布局：左侧专辑，右侧歌曲
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧：专辑列表
                  Expanded(
                    child: _buildAlbumsSection(context, scheme, albumsAsync),
                  ),
                  const SizedBox(width: 24),
                  // 右侧：歌曲列表
                  Expanded(
                    child: _buildSongsSection(context, scheme, songsAsync),
                  ),
                ],
              ),
            ),
          ),

          // 底部间距
          const SliverToBoxAdapter(
              child: const SizedBox(height: _kBottomSpacing)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    ColorScheme scheme,
    ArtistMetadata metadata, {
    double? expandedHeight,
  }) {
    final isLandscape = _isTabletLandscape(context);
    final height = expandedHeight ??
        (isLandscape
            ? _kHeaderExpandedHeightLandscape
            : _kHeaderExpandedHeight);
    return SliverAppBar(
      expandedHeight: height,
      pinned: true,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      flexibleSpace: FlexibleSpaceBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            // 滚动时标题渐显
            final top = constraints.biggest.height;
            final opacity = (1 - (top - kToolbarHeight) / 120).clamp(0.0, 1.0);
            return Opacity(
              opacity: opacity,
              child: Text(
                _artistName,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.primary.withValues(alpha: 0.15),
                scheme.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: isLandscape
                ? _buildLandscapeHeader(scheme, metadata)
                : _buildPortraitHeader(scheme, metadata),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      actions: [
        // 折叠状态下显示小头像
        LayoutBuilder(
          builder: (context, constraints) {
            final top = constraints.biggest.height;
            final showAvatar =
                top < kToolbarHeight + _kCollapsedAvatarThreshold;
            if (!showAvatar) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: _kAvatarRadiusCollapsed,
                backgroundImage: metadata.hasImage
                    ? CachedNetworkImageProvider(metadata.imageUrl!)
                    : null,
                backgroundColor: scheme.surfaceContainerHighest,
                child: metadata.hasImage
                    ? null
                    : Icon(Icons.person,
                        size: _kAvatarIconSizeCollapsed,
                        color: scheme.onSurfaceVariant),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPortraitHeader(ColorScheme scheme, ArtistMetadata metadata) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: _kHeaderTopSpacing),
        // 歌手头像（圆形）
        CircleAvatar(
          radius: _kAvatarRadiusPortrait,
          backgroundImage: metadata.hasImage
              ? CachedNetworkImageProvider(metadata.imageUrl!)
              : null,
          backgroundColor: scheme.surfaceContainerHighest,
          child: metadata.hasImage
              ? null
              : Icon(
                  Icons.person,
                  size: _kAvatarIconSize,
                  color: scheme.onSurfaceVariant,
                ),
        ),
        const SizedBox(height: _kAvatarNameSpacing),
        // 歌手名称
        Text(
          _artistName,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: _kArtistNameFontSizePortrait,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: _kNameTagsSpacing),
        // 风格标签 + 听众数
        _buildTagsAndListeners(scheme, metadata),
      ],
    );
  }

  Widget _buildLandscapeHeader(ColorScheme scheme, ArtistMetadata metadata) {
    return Padding(
      padding: const EdgeInsets.only(
        top: _kHeaderTopSpacing,
        left: _kHeaderHorizontalPaddingLandscape,
        right: _kHeaderHorizontalPaddingLandscape,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 歌手头像（圆形）
          CircleAvatar(
            radius: _kAvatarRadiusLandscape,
            backgroundImage: metadata.hasImage
                ? CachedNetworkImageProvider(metadata.imageUrl!)
                : null,
            backgroundColor: scheme.surfaceContainerHighest,
            child: metadata.hasImage
                ? null
                : Icon(
                    Icons.person,
                    size: _kAvatarRadiusLandscape,
                    color: scheme.onSurfaceVariant,
                  ),
          ),
          const SizedBox(width: 24),
          // 歌手信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 歌手名称
                Text(
                  _artistName,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: _kArtistNameFontSizeLandscape + 8,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: _kHeaderSmallSpacing),
                // 风格标签 + 听众数
                _buildTagsAndListeners(scheme, metadata,
                    align: CrossAxisAlignment.start),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsAndListeners(
    ColorScheme scheme,
    ArtistMetadata metadata, {
    CrossAxisAlignment align = CrossAxisAlignment.center,
  }) {
    return Row(
      mainAxisAlignment: align == CrossAxisAlignment.start
          ? MainAxisAlignment.start
          : MainAxisAlignment.center,
      children: [
        if (metadata.hasTags) ...[
          ...metadata.tags.take(3).map(
                (tag) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
        ],
        if (metadata.listeners != null) ...[
          const SizedBox(width: 8),
          Text(
            '${metadata.formattedListeners} 听众',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    ColorScheme scheme,
    ArtistMetadata metadata,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 播放全部（主按钮）
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _playAll(context),
              icon: const Icon(Icons.play_arrow),
              label: const Text('播放全部'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 收藏（次要按钮）
          OutlinedButton.icon(
            onPressed: () {
              final newState = !_isFavorite;
              setState(() => _isFavorite = newState);
              _saveFavoriteStatus(newState);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(newState ? '已收藏歌手' : '已取消收藏'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : null,
            ),
            label: const Text('收藏'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          // 分享（次要按钮）
          OutlinedButton.icon(
            onPressed: () {
              Share.share('歌手：$_artistName\n\n来自 EmbyTok 音乐APP');
            },
            icon: const Icon(Icons.share),
            label: const Text('分享'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection(
    BuildContext context,
    ColorScheme scheme,
    ArtistMetadata metadata,
  ) {
    final bioContent = metadata.bioContent ?? metadata.bioSummary ?? '';
    final hasHtml = bioContent.contains('<') && bioContent.contains('>');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          const Text(
            '简介',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // 简介内容（支持 HTML 富文本渲染）
          if (hasHtml)
            HtmlText(
              bioContent,
              maxLines: _bioExpanded ? null : 3,
              overflow:
                  _bioExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            )
          else
            Text(
              metadata.bioSummary ?? '',
              maxLines: _bioExpanded ? null : 3,
              overflow:
                  _bioExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          const SizedBox(height: 4),
          // 展开/收起按钮 + 来源标注
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() => _bioExpanded = !_bioExpanded),
                child: Text(_bioExpanded ? '收起 ▲' : '展开全文 ▼'),
              ),
              // 数据来源标注 + 切换歌手 + 编辑按钮
              Row(
                children: [
                  Text(
                    '数据来源：${metadata.sourceDisplayName}'
                    '${metadata.bioLang == 'en' ? ' · 英文' : ''}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _showArtistPicker(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '切换歌手',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => _showMetadataEditor(context, metadata),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, size: 12, color: scheme.primary),
                        const SizedBox(width: 2),
                        Text(
                          '编辑',
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

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
