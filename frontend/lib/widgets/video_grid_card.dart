// 视频网格卡片组件：显示封面图、标题、时长和播放进度

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/models.dart';
import '../providers/providers.dart';

// 网格卡片组件
class VideoGridCard extends ConsumerWidget {
  final MediaItem item;
  final VoidCallback? onTap;

  const VideoGridCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final embyServerUrl = authState.embyServerUrl;
    final token = authState.token;

    final imageUrl = item.thumbnailUrlWithAuth(embyServerUrl, token, maxWidth: 400);
    final progress = _calculateProgress(item);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCoverImage(imageUrl, scheme),
                  if (item.durationSeconds != null)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: _buildDurationBadge(item.durationSeconds!, scheme),
                    ),
                  if (progress > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 4,
                      child: _buildProgressBar(progress, scheme),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(String? imageUrl, ColorScheme scheme) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholder(scheme);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => _buildPlaceholder(scheme),
      errorWidget: (context, url, error) => _buildPlaceholder(scheme),
    );
  }

  Widget _buildPlaceholder(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surface.withOpacity(0.4),
            scheme.surface.withOpacity(0.25),
            scheme.surface.withOpacity(0.4),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.video_library_outlined,
          color: scheme.onSurfaceVariant.withOpacity(0.5),
          size: 40,
        ),
      ),
    );
  }

  Widget _buildDurationBadge(double seconds, ColorScheme scheme) {
    final duration = _formatDuration(seconds);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.87),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        duration,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progress, ColorScheme scheme) {
    return Container(
      height: 3,
      color: scheme.onSurface.withOpacity(0.2),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          color: scheme.primary,
        ),
      ),
    );
  }

  double _calculateProgress(MediaItem item) {
    if (item.userData == null || item.durationSeconds == null) return 0.0;
    if (item.durationSeconds! <= 0) return 0.0;

    final positionSeconds = item.userData!.playbackPositionTicks / 10000000.0;
    return (positionSeconds / item.durationSeconds!).clamp(0.0, 1.0);
  }

  String _formatDuration(double seconds) {
    final totalSeconds = seconds.round();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
