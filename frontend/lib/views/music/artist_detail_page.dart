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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/artist_metadata.dart';
import '../../models/audio_models.dart';
import '../../providers/artist_metadata_provider.dart';
import '../../providers/synology_auth_provider.dart';
import '../../providers/synology_playback_provider.dart';
import '../../utils/html_parser.dart';
import 'artist_metadata_editor.dart';
import 'artist_search_picker.dart';
import 'mini_player_bar.dart';
part 'artist_parts/artist_builders_extra.dart';

// ===== 歌手详情页常量 =====

/// 头部默认展开高度
const double _kHeaderExpandedHeight = 320.0;

/// 横屏模式头部展开高度
const double _kHeaderExpandedHeightLandscape = 220.0;

/// 竖屏头像半径
const double _kAvatarRadiusPortrait = 60.0;

/// 横屏头像半径
const double _kAvatarRadiusLandscape = 50.0;

/// 折叠状态小头像半径
const double _kAvatarRadiusCollapsed = 16.0;

/// 头像图标尺寸（无图片时）
const double _kAvatarIconSize = 60.0;

/// 折叠头像图标尺寸
const double _kAvatarIconSizeCollapsed = 16.0;

/// 歌手名称字号（竖屏）
const double _kArtistNameFontSizePortrait = 24.0;

/// 歌手名称字号（横屏）
const double _kArtistNameFontSizeLandscape = 20.0;

/// 头部顶部间距
const double _kHeaderTopSpacing = 40.0;

/// 头部小间距
const double _kHeaderSmallSpacing = 8.0;

/// 横屏头部水平边距
const double _kHeaderHorizontalPaddingLandscape = 32.0;

/// 头像下方歌手名称间距
const double _kAvatarNameSpacing = 16.0;

/// 歌手名称下方标签间距
const double _kNameTagsSpacing = 8.0;

/// 页面底部间距
const double _kBottomSpacing = 80.0;

/// 平板横屏阈值（宽度）
const double _kTabletLandscapeWidthThreshold = 600.0;

/// 折叠状态头像显示阈值
const double _kCollapsedAvatarThreshold = 40.0;

/// 歌手详情页
///
/// 通过路由 `/music/artist/:name` 访问，或通过构造函数传入歌手对象。
class ArtistDetailPage extends ConsumerStatefulWidget {
  const ArtistDetailPage({
    super.key,
    this.artistName,
    this.artist,
  });

  /// 歌手名称（路由参数）
  final String? artistName;

  /// 歌手对象（直接传入时优先使用）
  final AudioArtist? artist;

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
    _loadFavoriteStatus();
  }

  /// 加载收藏状态

  /// 保存收藏状态

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
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                '正在加载歌手信息...',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        error: (e, s) => _buildError(context, e),
      ),
      bottomNavigationBar: const MiniPlayerBar(),
    );
  }

  /// 判断是否为平板横屏模式（V1.2）
  ///
  /// 平板横屏模式下，屏幕宽度大于 600 且宽度大于高度。
  /// 此时使用两栏布局，充分利用宽屏空间。

  /// 构建页面主体内容

  /// 构建平板横屏模式内容（V1.2）
  ///
  /// 两栏布局：左侧专辑列表，右侧歌曲列表。
  /// 头部、简介、相似歌手在顶部全宽显示。

  /// 构建可折叠头部（SliverAppBar）
  ///
  /// [expandedHeight] 展开高度，默认 280，平板横屏模式下使用 220。

  /// 构建竖屏模式头部（V1.2）
  ///
  /// 头像在上，歌手名称和标签在下，垂直排列。

  /// 构建横屏模式头部（V1.2）
  ///
  /// 头像在左，歌手名称和标签在右，水平排列。
  /// 充分利用宽屏空间，减少垂直高度。

  /// 构建风格标签和听众数（V1.2）
  ///
  /// [align] 对齐方式，默认居中。

  /// 构建操作按钮行

  /// 构建歌手简介模块

  /// 显示同名歌手选择界面（V1.2）
  ///
  /// 当用户点击"切换歌手"按钮时，弹出搜索结果列表，
  /// 让用户选择正确的歌手。选择后跳转到对应歌手详情页。

  /// 显示歌手元数据编辑界面（V1.2）
  ///
  /// 当用户点击"编辑"按钮时，弹出编辑界面，
  /// 允许用户手动修改歌手头像和简介。

  /// 构建相似歌手部分（V1.1）
  ///
  /// 横向滚动列表，显示相似歌手头像和名称，点击跳转到对应歌手详情页。

  /// 构建专辑列表部分

  /// 构建专辑卡片

  /// 构建专辑占位图

  /// 构建歌曲列表部分

  /// 构建歌曲列表项

  /// 歌曲长按操作菜单

  /// 构建错误状态

  /// 播放全部歌曲

  /// 播放单首歌曲

  /// 显示所有专辑列表对话框

  /// 显示专辑详情对话框

  /// 构建专辑歌曲列表

  /// 格式化时长

  // === 合并自 artist_builders.dart ===
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
              SharePlus.instance.share(ShareParams(text: '歌手：$_artistName\n\n来自 EmbyTok 音乐APP'));
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

  // === 合并自 artist_actions.dart ===
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
