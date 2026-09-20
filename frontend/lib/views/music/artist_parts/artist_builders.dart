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
}
