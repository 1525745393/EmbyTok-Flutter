// 音乐库首页横向列表组件
//
// 从 synology_music_view.dart 拆分出来，提升代码可维护性。
//
// 包含：
// - AlbumHorizontalList：专辑横向列表
// - ArtistHorizontalList：歌手横向列表
// - PlaylistHorizontalList：歌单横向列表
//
// 设计说明：
// - 通过回调函数（onAlbumTap/onArtistTap/onPlaylistTap）解耦对 state 的依赖
// - 封面图使用模型层预计算的 coverUrl（P2-2 优化）
// - 所有样式常量提取为命名常量，避免魔法数字

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/audio_models.dart';
import '../../utils/image_cache_manager.dart';

// ===== 横向列表常量 =====

/// 专辑横向列表高度
const double kAlbumListHeight = 160;

/// 歌手横向列表高度
const double kArtistListHeight = 110;

/// 歌单横向列表高度
const double kPlaylistListHeight = 150;

/// 专辑卡片宽度
const double kAlbumCardWidth = 110;

/// 歌手卡片宽度
const double kArtistCardWidth = 72;

/// 歌单卡片宽度
const double kPlaylistCardWidth = 110;

/// 横向列表水平内边距
const double kHorizontalListPadding = 16;

/// 专辑/歌单卡片间距
const double kAlbumCardSpacing = 12;

/// 歌手卡片间距
const double kArtistCardSpacing = 16;

/// 封面圆角
const double kCoverRadius = 10;

/// 歌手头像半径
const double kArtistAvatarRadius = 32;

/// 歌单渐变背景列表
const List<List<Color>> kPlaylistGradients = [
  [Color(0xFF667EEA), Color(0xFF764BA2)],
  [Color(0xFFF093FB), Color(0xFFF5576C)],
  [Color(0xFF4FACFE), Color(0xFF00F2FE)],
  [Color(0xFF43E97B), Color(0xFF38F9D7)],
  [Color(0xFFFFD26F), Color(0xFFFF9472)],
];

/// 专辑横向列表
class AlbumHorizontalList extends StatelessWidget {

  const AlbumHorizontalList({
    super.key,
    required this.albums,
    required this.scheme,
    required this.onAlbumTap,
  });
  final List<AudioAlbum> albums;
  final ColorScheme scheme;
  final void Function(AudioAlbum album) onAlbumTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kAlbumListHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kHorizontalListPadding),
        itemCount: albums.length,
        separatorBuilder: (_, __) => const SizedBox(width: kAlbumCardSpacing),
        itemBuilder: (context, index) {
          final album = albums[index];
          // P2-2：直接使用模型层预计算的 coverUrl，避免重复计算
          final coverUrl = album.coverUrl;
          return GestureDetector(
            onTap: () => onAlbumTap(album),
            child: SizedBox(
              width: kAlbumCardWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(kCoverRadius),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: coverUrl != null
                          ? CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              cacheManager: AppImageCacheManager.thumbnail,
                              errorWidget: (_, __, ___) =>
                                  Container(color: scheme.surfaceContainerHighest, child: Icon(Icons.album, color: scheme.onSurfaceVariant, size: 32)),
                            )
                          : Container(color: scheme.surfaceContainerHighest, child: Icon(Icons.album, color: scheme.onSurfaceVariant, size: 32)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    album.displayArtist ?? album.albumArtist ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 歌手横向列表
class ArtistHorizontalList extends StatelessWidget {

  const ArtistHorizontalList({
    super.key,
    required this.artists,
    required this.scheme,
    required this.onArtistTap,
  });
  final List<AudioArtist> artists;
  final ColorScheme scheme;
  final void Function(AudioArtist artist) onArtistTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kArtistListHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kHorizontalListPadding),
        itemCount: artists.length,
        separatorBuilder: (_, __) => const SizedBox(width: kArtistCardSpacing),
        itemBuilder: (context, index) {
          final artist = artists[index];
          // P2-2：直接使用模型层预计算的 coverUrl，避免重复计算
          final coverUrl = artist.coverUrl;
          return GestureDetector(
            onTap: () => onArtistTap(artist),
            child: SizedBox(
              width: kArtistCardWidth,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: kArtistAvatarRadius,
                    backgroundColor: scheme.surfaceContainerHighest,
                    backgroundImage: coverUrl != null
                        ? CachedNetworkImageProvider(coverUrl,
                            cacheManager: AppImageCacheManager.thumbnail)
                        : null,
                    child: coverUrl == null
                        ? Text(
                            artist.name.isNotEmpty
                                ? artist.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 歌单横向列表
class PlaylistHorizontalList extends StatelessWidget {

  const PlaylistHorizontalList({
    super.key,
    required this.playlists,
    required this.scheme,
    required this.onPlaylistTap,
  });
  final List<AudioPlaylist> playlists;
  final ColorScheme scheme;
  final void Function(AudioPlaylist playlist) onPlaylistTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kPlaylistListHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kHorizontalListPadding),
        itemCount: playlists.length,
        separatorBuilder: (_, __) => const SizedBox(width: kAlbumCardSpacing),
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          final gradient = kPlaylistGradients[index % kPlaylistGradients.length];
          return GestureDetector(
            onTap: () => onPlaylistTap(playlist),
            child: SizedBox(
              width: kPlaylistCardWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(kCoverRadius),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: gradient,
                          ),
                        ),
                        child: const Icon(
                          Icons.playlist_play,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    playlist.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
