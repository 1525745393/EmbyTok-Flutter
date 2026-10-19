// 本地文件优先海报/背景/演员头像组件
// 本地文件存在 → Image.file；否则 fallback CDN URL
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/local_video_item.dart';
import '../../services/scrape_media_store.dart';
import '../../services/tmdb_service.dart';

/// 本地优先海报
///
/// 用 StatefulWidget 缓存 FutureBuilder 的 future，避免列表滚动重建时
/// 每次 build 都重新发起 posterFile() 查询导致图片闪烁/抖动。
class LocalPosterImage extends StatefulWidget {

  const LocalPosterImage({
    super.key,
    required this.item,
    required this.posterPath,
    this.fit = BoxFit.cover,
    this.placeholder = const ColoredBox(color: Color(0xFF2A2A2A)),
  });
  final LocalVideoItem item;
  final String? posterPath;
  final BoxFit fit;
  final Widget placeholder;

  @override
  State<LocalPosterImage> createState() => _LocalPosterImageState();
}

class _LocalPosterImageState extends State<LocalPosterImage> {
  Future<File?>? _future;

  @override
  void initState() {
    super.initState();
    _future = ScrapeMediaStore.posterFile(widget.item);
  }

  @override
  void didUpdateWidget(LocalPosterImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 列表项复用 State 时（ListView.builder），item 变化才重建 future
    if (oldWidget.item.pathHash != widget.item.pathHash) {
      _future = ScrapeMediaStore.posterFile(widget.item);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 即使 posterPath 为 null（从 .nfo 恢复的元数据），也先查本地海报文件
    return FutureBuilder<File?>(
      future: _future,
      builder: (_, snap) {
        if (snap.hasData && snap.data != null) {
          return Image.file(snap.data!, fit: widget.fit, errorBuilder: (_, __, ___) => _placeholderOrCdn());
        }
        return _placeholderOrCdn();
      },
    );
  }

  Widget _placeholderOrCdn() {
    if (widget.posterPath == null || widget.posterPath!.isEmpty) return widget.placeholder;
    return _cdn();
  }

  Widget _cdn() => CachedNetworkImage(
        imageUrl: TmdbService.posterUrl(widget.posterPath!),
        fit: widget.fit,
        errorWidget: (_, __, ___) => widget.placeholder,
      );
}

/// 本地优先背景
class LocalBackdropImage extends StatefulWidget {

  const LocalBackdropImage({
    super.key,
    required this.item,
    required this.backdropPath,
    this.fit = BoxFit.cover,
  });
  final LocalVideoItem item;
  final String? backdropPath;
  final BoxFit fit;

  @override
  State<LocalBackdropImage> createState() => _LocalBackdropImageState();
}

class _LocalBackdropImageState extends State<LocalBackdropImage> {
  Future<File?>? _future;

  @override
  void initState() {
    super.initState();
    _future = ScrapeMediaStore.backdropFile(widget.item);
  }

  @override
  void didUpdateWidget(LocalBackdropImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.pathHash != widget.item.pathHash) {
      _future = ScrapeMediaStore.backdropFile(widget.item);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 即使 backdropPath 为 null（从 .nfo 恢复），也先查本地背景图文件
    return FutureBuilder<File?>(
      future: _future,
      builder: (_, snap) {
        if (snap.hasData && snap.data != null) {
          return Image.file(snap.data!, fit: widget.fit, errorBuilder: (_, __, ___) => _placeholderOrCdn());
        }
        return _placeholderOrCdn();
      },
    );
  }

  Widget _placeholderOrCdn() {
    if (widget.backdropPath == null || widget.backdropPath!.isEmpty) {
      return const ColoredBox(color: Color(0xFF1A1A1A));
    }
    return _cdn();
  }

  Widget _cdn() => CachedNetworkImage(
        imageUrl: TmdbService.backdropUrl(widget.backdropPath!),
        fit: widget.fit,
        errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF1A1A1A)),
      );
}

/// 本地优先单集剧照
class LocalStillImage extends StatefulWidget {
  const LocalStillImage({
    super.key,
    required this.item,
    required this.stillPath,
    this.fit = BoxFit.cover,
  });
  final LocalVideoItem item;
  final String? stillPath;
  final BoxFit fit;

  @override
  State<LocalStillImage> createState() => _LocalStillImageState();
}

class _LocalStillImageState extends State<LocalStillImage> {
  Future<File?>? _future;

  @override
  void initState() {
    super.initState();
    _future = ScrapeMediaStore.stillFile(widget.item);
  }

  @override
  void didUpdateWidget(LocalStillImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.pathHash != widget.item.pathHash) {
      _future = ScrapeMediaStore.stillFile(widget.item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _future,
      builder: (_, snap) {
        if (snap.hasData && snap.data != null) {
          return Image.file(snap.data!, fit: widget.fit, errorBuilder: (_, __, ___) => _cdn());
        }
        return _cdn();
      },
    );
  }

  Widget _cdn() {
    if (widget.stillPath == null || widget.stillPath!.isEmpty) {
      return const ColoredBox(color: Color(0xFF1A1A1A));
    }
    return CachedNetworkImage(
      imageUrl: TmdbService.posterUrl(widget.stillPath!, size: 'w300'),
      fit: widget.fit,
      errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF1A1A1A)),
    );
  }
}

/// 本地优先演员头像（按 personId）
class LocalCastAvatar extends StatefulWidget {

  const LocalCastAvatar({
    super.key,
    required this.personId,
    required this.profilePath,
    this.size = 48,
  });
  final int personId;
  final String? profilePath;
  final double size;

  @override
  State<LocalCastAvatar> createState() => _LocalCastAvatarState();
}

class _LocalCastAvatarState extends State<LocalCastAvatar> {
  Future<File?>? _future;

  @override
  void initState() {
    super.initState();
    _future = ScrapeMediaStore.castFile(widget.personId);
  }

  @override
  void didUpdateWidget(LocalCastAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.personId != widget.personId) {
      _future = ScrapeMediaStore.castFile(widget.personId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: FutureBuilder<File?>(
        future: _future,
        builder: (_, snap) {
          if (snap.hasData && snap.data != null) {
            return Image.file(snap.data!,
                width: widget.size, height: widget.size, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _cdn());
          }
          return _cdn();
        },
      ),
    );
  }

  Widget _cdn() {
    if (widget.profilePath == null || widget.profilePath!.isEmpty) {
      return Container(
        width: widget.size, height: widget.size,
        color: Colors.grey[800],
        child: Icon(Icons.person, size: widget.size * 0.5, color: Colors.white30),
      );
    }
    return CachedNetworkImage(
      imageUrl: TmdbService.posterUrl(widget.profilePath!, size: 'w185'),
      width: widget.size, height: widget.size, fit: BoxFit.cover,
      errorWidget: (_, __, ___) => Container(
        width: widget.size, height: widget.size,
        color: Colors.grey[800],
        child: Icon(Icons.person, size: widget.size * 0.5, color: Colors.white30),
      ),
    );
  }
}
