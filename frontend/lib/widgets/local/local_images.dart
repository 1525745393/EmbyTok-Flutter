// 本地文件优先海报/背景/演员头像组件
// 本地文件存在 → Image.file；否则 fallback CDN URL
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/local_video_item.dart';
import '../../services/scrape_media_store.dart';
import '../../services/tmdb_service.dart';

/// 本地优先海报
class LocalPosterImage extends StatelessWidget {
  final LocalVideoItem item;
  final String? posterPath;
  final BoxFit fit;
  final Widget placeholder;

  const LocalPosterImage({
    super.key,
    required this.item,
    required this.posterPath,
    this.fit = BoxFit.cover,
    this.placeholder = const ColoredBox(color: const Color(0xFF2A2A2A)),
  });

  @override
  Widget build(BuildContext context) {
    if (posterPath == null || posterPath!.isEmpty) return placeholder;
    return FutureBuilder<File?>(
      future: ScrapeMediaStore.posterFile(item),
      builder: (_, snap) {
        if (snap.hasData && snap.data != null) {
          return Image.file(snap.data!, fit: fit, errorBuilder: (_, __, ___) => _cdn());
        }
        return _cdn();
      },
    );
  }

  Widget _cdn() => CachedNetworkImage(
        imageUrl: TmdbService.posterUrl(posterPath!),
        fit: fit,
        errorWidget: (_, __, ___) => placeholder,
      );
}

/// 本地优先背景
class LocalBackdropImage extends StatelessWidget {
  final LocalVideoItem item;
  final String? backdropPath;
  final BoxFit fit;

  const LocalBackdropImage({
    super.key,
    required this.item,
    required this.backdropPath,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (backdropPath == null || backdropPath!.isEmpty) {
      return const ColoredBox(color: Color(0xFF1A1A1A));
    }
    return FutureBuilder<File?>(
      future: ScrapeMediaStore.backdropFile(item),
      builder: (_, snap) {
        if (snap.hasData && snap.data != null) {
          return Image.file(snap.data!, fit: fit, errorBuilder: (_, __, ___) => _cdn());
        }
        return _cdn();
      },
    );
  }

  Widget _cdn() => CachedNetworkImage(
        imageUrl: TmdbService.backdropUrl(backdropPath!),
        fit: fit,
        errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF1A1A1A)),
      );
}

/// 本地优先演员头像（按 personId）
class LocalCastAvatar extends StatelessWidget {
  final int personId;
  final String? profilePath;
  final double size;

  const LocalCastAvatar({
    super.key,
    required this.personId,
    required this.profilePath,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: FutureBuilder<File?>(
        future: ScrapeMediaStore.castFile(personId),
        builder: (_, snap) {
          if (snap.hasData && snap.data != null) {
            return Image.file(snap.data!,
                width: size, height: size, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _cdn());
          }
          return _cdn();
        },
      ),
    );
  }

  Widget _cdn() {
    if (profilePath == null || profilePath!.isEmpty) {
      return Container(
        width: size, height: size,
        color: Colors.grey[800],
        child: Icon(Icons.person, size: size * 0.5, color: Colors.white30),
      );
    }
    return CachedNetworkImage(
      imageUrl: TmdbService.posterUrl(profilePath!, size: 'w185'),
      width: size, height: size, fit: BoxFit.cover,
      errorWidget: (_, __, ___) => Container(
        width: size, height: size,
        color: Colors.grey[800],
        child: Icon(Icons.person, size: size * 0.5, color: Colors.white30),
      ),
    );
  }
}
