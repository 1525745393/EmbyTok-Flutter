// 歌手详情页
//
// 歌手简介功能 V1.0
// 独立的歌手详情页，包含可折叠头部、操作按钮、简介模块、专辑列表、歌曲列表。
//
// 参考 QQ音乐/酷狗音乐的歌手详情页交互：
// - 顶部可折叠头部（SliverAppBar），滚动时头像缩小为导航栏头像
// - 操作按钮行（播放全部、收藏、分享）
// - 简介模块（摘要3行截断，展开全文，来源标注）
// - 专辑列表（横向滚动）
// - 歌曲列表（垂直列表，支持播放）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/artist_metadata.dart';
import '../../models/audio_models.dart';
import '../../providers/artist_metadata_provider.dart';
import '../../utils/html_parser.dart';
import 'mini_player_bar.dart';

/// 歌手详情页
///
/// 通过路由 `/music/artist/:name` 访问，或通过构造函数传入歌手对象。
class ArtistDetailPage extends ConsumerStatefulWidget {
  /// 歌手名称（路由参数）
  final String? artistName;

  /// 歌手对象（直接传入时优先使用）
  final AudioArtist? artist;

  const ArtistDetailPage({
    super.key,
    this.artistName,
    this.artist,
  });

  @override
  ConsumerState<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends ConsumerState<ArtistDetailPage> {
  /// 歌手名称
  late String _artistName;

  /// 简介是否展开
  bool _bioExpanded = false;

  /// 是否已收藏
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _artistName = widget.artist?.name ?? widget.artistName ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // 加载歌手元数据（头像、简介、标签等）
    final metadataAsync = ref.watch(artistMetadataProvider(_artistName));

    // 加载歌手歌曲列表
    final songsAsync = ref.watch(artistSongsProvider(_artistName));

    // 加载歌手专辑列表
    final albumsAsync = ref.watch(artistAlbumsProvider(_artistName));

    return Scaffold(
      body: metadataAsync.when(
        data: (metadata) => _buildContent(
          context,
          scheme,
          metadata,
          songsAsync,
          albumsAsync,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => _buildError(context, e),
      ),
      bottomNavigationBar: const MiniPlayerBar(),
    );
  }

  /// 构建页面主体内容
  Widget _buildContent(
    BuildContext context,
    ColorScheme scheme,
    ArtistMetadata metadata,
    AsyncValue<List<AudioSong>> songsAsync,
    AsyncValue<List<AudioAlbum>> albumsAsync,
  ) {
    return CustomScrollView(
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
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  /// 构建可折叠头部（SliverAppBar）
  Widget _buildSliverAppBar(
    BuildContext context,
    ColorScheme scheme,
    ArtistMetadata metadata,
  ) {
    return SliverAppBar(
      expandedHeight: 280,
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // 歌手头像（圆形）
                CircleAvatar(
                  radius: 60,
                  backgroundImage: metadata.hasImage
                      ? NetworkImage(metadata.imageUrl!)
                      : null,
                  backgroundColor: scheme.surfaceVariant,
                  child: metadata.hasImage
                      ? null
                      : Icon(
                          Icons.person,
                          size: 60,
                          color: scheme.onSurfaceVariant,
                        ),
                ),
                const SizedBox(height: 16),
                // 歌手名称
                Text(
                  _artistName,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // 风格标签 + 听众数
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (metadata.hasTags) ...[
                      ...metadata.tags.take(3).map(
                            (tag) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
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
                ),
              ],
            ),
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
            final showAvatar = top < kToolbarHeight + 40;
            if (!showAvatar) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 16,
                backgroundImage:
                    metadata.hasImage ? NetworkImage(metadata.imageUrl!) : null,
                backgroundColor: scheme.surfaceVariant,
                child: metadata.hasImage
                    ? null
                    : Icon(Icons.person, size: 16, color: scheme.onSurfaceVariant),
              ),
            );
          },
        ),
      ],
    );
  }

  /// 构建操作按钮行
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
              setState(() => _isFavorite = !_isFavorite);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isFavorite ? '已收藏歌手' : '已取消收藏'),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('分享功能开发中'),
                  duration: Duration(seconds: 1),
                ),
              );
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

  /// 构建歌手简介模块
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
              overflow: _bioExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
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
              overflow: _bioExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
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
              // 数据来源标注
              Text(
                '数据来源：${metadata.sourceDisplayName}'
                '${metadata.bioLang == 'en' ? ' · 英文' : ''}',
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建相似歌手部分（V1.1）
  ///
  /// 横向滚动列表，显示相似歌手头像和名称，点击跳转到对应歌手详情页。
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
                    context.push('/music/artist/${Uri.encodeComponent(artist.name)}');
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
                              ? NetworkImage(artist.imageUrl!)
                              : null,
                          backgroundColor: scheme.surfaceVariant,
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

  /// 构建专辑列表部分
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
                  // TODO: 跳转到专辑列表页
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

  /// 构建专辑卡片
  Widget _buildAlbumCard(
    BuildContext context,
    ColorScheme scheme,
    AudioAlbum album,
  ) {
    return GestureDetector(
      onTap: () {
        // TODO: 跳转到专辑详情页
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
                  ? Image.network(
                      album.coverUrl!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildAlbumPlaceholder(scheme),
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

  /// 构建专辑占位图
  Widget _buildAlbumPlaceholder(ColorScheme scheme) {
    return Container(
      width: 120,
      height: 120,
      color: scheme.surfaceVariant,
      child: Icon(
        Icons.album,
        size: 40,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  /// 构建歌曲列表部分
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

  /// 构建歌曲列表项
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
    );
  }

  /// 构建错误状态
  Widget _buildError(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('加载失败: $error'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => setState(() {}),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 播放全部歌曲
  void _playAll(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('播放全部功能开发中'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// 播放单首歌曲
  void _playSong(BuildContext context, AudioSong song) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('播放: ${song.title}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

}
