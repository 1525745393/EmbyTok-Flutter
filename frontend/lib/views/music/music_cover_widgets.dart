// 音乐库通用封面组件
//
// 从 synology_music_view.dart 拆分出来，包含歌曲封面、专辑封面、
// 歌手头像、来源标签、歌手搜索条目等通用组件。
//
// 这些组件在主页面和歌手详情弹层中都被使用，因此提取到共享文件中。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/audio_models.dart';
import '../../providers/providers.dart';
import '../../utils/image_cache_manager.dart';

// ===== 封面组件相关常量 =====

/// 超小字体（时间戳、辅助信息）
const double kCoverFontSizeTiny = 10;

/// 小字体（标签、副标题）
const double kCoverFontSizeSmall = 12;

/// 小间距
const double kCoverSpacingSmall = 4;

/// 中间距
const double kCoverSpacingMedium = 6;

/// 大间距
const double kCoverSpacingLarge = 8;

/// 超大字体（首字母头像）
const double kCoverFontSizeXXLarge = 30;

// ============================
// 歌曲封面组件
// ============================

/// 歌曲封面组件
class SongCover extends ConsumerWidget {

  const SongCover({super.key, required this.songId, required this.size});
  final String songId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final url =
        ref.read(synologyAuthProvider.notifier).api.getSongCoverUrl(songId);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
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

// ============================
// 专辑封面组件
// ============================

/// 专辑封面组件
class AlbumCover extends ConsumerWidget {

  const AlbumCover({super.key, required this.album});
  final AudioAlbum album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final url = ref.read(synologyAuthProvider.notifier).api.getAlbumCoverUrl(
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
              child:
                  Icon(Icons.album, color: scheme.onSurfaceVariant, size: 28),
            ),
          )
        : Container(
            color: scheme.surfaceContainerHighest,
            child: Icon(Icons.album, color: scheme.onSurfaceVariant, size: 28),
          );
  }
}

// ============================
// 歌手头像组件
// ============================

/// 歌手圆形头像组件
///
/// 优先加载 NAS 歌手图（cover.cgi + artist_name）；无图/加载失败时
/// 回退为「渐变背景 + 歌手名首字母」（QQ音乐/酷狗风格）。
class ArtistAvatar extends ConsumerStatefulWidget {

  const ArtistAvatar({super.key, required this.artistName, required this.size});
  final String artistName;
  final double size;

  @override
  ConsumerState<ArtistAvatar> createState() => _ArtistAvatarState();
}

class _ArtistAvatarState extends ConsumerState<ArtistAvatar> {
  /// 聚合信息（Last.fm → 群晖 → 首字母，缓存命中时同步完成）
  Future<ArtistInfoResult>? _infoFuture;

  @override
  void initState() {
    super.initState();
    _infoFuture = ref.read(artistInfoCacheProvider).get(widget.artistName);
  }

  @override
  void didUpdateWidget(covariant ArtistAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistName != widget.artistName) {
      _infoFuture = ref.read(artistInfoCacheProvider).get(widget.artistName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = widget.artistName.trim().isEmpty
        ? '?'
        : widget.artistName.trim().substring(0, 1).toUpperCase();
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.85),
            scheme.primary.withValues(alpha: 0.45),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<ArtistInfoResult>(
        future: _infoFuture,
        builder: (context, snapshot) {
          final url = snapshot.data?.imageUrl;
          if (url == null) return _initialFallback(initial, scheme);
          return CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            cacheManager: AppImageCacheManager.thumbnail,
            errorWidget: (_, __, ___) => _initialFallback(initial, scheme),
          );
        },
      ),
    );
  }

  /// 首字母渐变头像（无图兜底）
  Widget _initialFallback(String initial, ColorScheme scheme) {
    return Container(
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: scheme.onPrimary,
          fontSize: kCoverFontSizeXXLarge,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ============================
// 数据出处标签
// ============================

/// 数据出处小标签
class SourceBadge extends StatelessWidget {

  const SourceBadge({super.key, required this.source, required this.imageSource});
  final ArtistInfoSource source;
  final ArtistInfoSource imageSource;

  @override
  Widget build(BuildContext context) {
    // 取非空的来源优先展示（简介来源 > 头像来源）
    final shown = source != ArtistInfoSource.none
        ? source
        : (imageSource != ArtistInfoSource.none ? imageSource : null);
    if (shown == null) return const SizedBox.shrink();
    final (color, bg) = switch (shown) {
      ArtistInfoSource.lastfm => (
          const Color(0xFFD51007),
          const Color(0xFFD51007).withValues(alpha: 0.12),
        ),
      ArtistInfoSource.synology => (
          const Color(0xFF2C8EF4),
          const Color(0xFF2C8EF4).withValues(alpha: 0.12),
        ),
      ArtistInfoSource.wikipedia => (
          const Color(0xFF616161),
          const Color(0xFF616161).withValues(alpha: 0.12),
        ),
      ArtistInfoSource.none => (null, null),
    };
    if (color == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        shown.label,
        style:
            TextStyle(fontSize: kCoverFontSizeTiny, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ============================
// 歌手搜索结果条目
// ============================

/// 歌手搜索结果条目：头像 + 名字 + 简介 + 出处标签
class ArtistSearchTile extends ConsumerWidget {

  const ArtistSearchTile({
    super.key,
    required this.artist,
    required this.onTap,
    this.hitSource = ArtistInfoSource.none,
  });
  final AudioArtist artist;

  /// 条目来源（在哪搜到的）：群晖 NAS 本地库 / Last.fm 在线搜索。
  /// none 表示不显示条目来源标签（仅内容出处标签）。
  final ArtistInfoSource hitSource;

  /// 点击回调（由页面层提供，复用现有歌手歌曲弹层逻辑）
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final infoFuture = ref.read(artistInfoCacheProvider).get(artist.name);

    return FutureBuilder<ArtistInfoResult>(
      future: infoFuture,
      builder: (context, snapshot) {
        final info = snapshot.data;
        final bio = info?.bio;
        final bioSource = info?.bioSource ?? ArtistInfoSource.none;
        final imageSource = info?.imageSource ?? ArtistInfoSource.none;
        // 内容出处（头像/简介实际来源）；与条目来源相同时不重复显示
        final contentSource =
            bioSource != ArtistInfoSource.none ? bioSource : imageSource;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ArtistAvatar(artistName: artist.name, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              artist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // 条目来源标签（在哪搜到的）：群晖 NAS / Last.fm
                          SourceBadge(
                              source: hitSource,
                              imageSource: ArtistInfoSource.none),
                          // 内容出处标签（头像/简介实际来源）
                          if (contentSource != hitSource)
                            SourceBadge(
                                source: contentSource,
                                imageSource: ArtistInfoSource.none),
                        ],
                      ),
                      if (bio != null && bio.isNotEmpty) ...[
                        const SizedBox(height: kCoverSpacingSmall),
                        Text(
                          bio,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: kCoverFontSizeSmall,
                            height: 1.4,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 20, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        );
      },
    );
  }
}
