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
    // 获取认证信息用于构造图片 URL
    final authState = ref.watch(authProvider);
    final embyServerUrl = authState.embyServerUrl;
    final token = authState.token;

    // 获取图片 URL
    final imageUrl = item.thumbnailUrlWithAuth(embyServerUrl, token, maxWidth: 400);

    // 计算播放进度
    final progress = _calculateProgress(item);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColorL2,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 封面图 + 时长标签 + 进度条
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 封面图
                  _buildCoverImage(imageUrl),
                  // 右上角时长标签
                  if (item.durationSeconds != null)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: _buildDurationBadge(item.durationSeconds!),
                    ),
                  // 底部播放进度条
                  if (progress > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 4,
                      child: _buildProgressBar(progress),
                    ),
                ],
              ),
            ),
            // 标题区域
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textPrimary,
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

  // 构建封面图
  Widget _buildCoverImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholder();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildPlaceholder(),
    );
  }

  // 骨架屏占位图（加载中时显示渐变动画）
  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            surfaceColorL3,
            surfaceColorL2,
            surfaceColorL3,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.video_library_outlined,
          color: textQuaternary,
          size: 40,
        ),
      ),
    );
  }

  // 时长标签
  Widget _buildDurationBadge(double seconds) {
    final duration = _formatDuration(seconds);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: durationBadgeBackground,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        duration,
        style: const TextStyle(
          color: textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // 播放进度条
  Widget _buildProgressBar(double progress) {
    return Container(
      height: 3,
      color: progressBackground,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          color: primaryPink,
        ),
      ),
    );
  }

  // 计算播放进度（0.0 ~ 1.0）
  double _calculateProgress(MediaItem item) {
    if (item.userData == null || item.durationSeconds == null) return 0.0;
    if (item.durationSeconds! <= 0) return 0.0;

    final positionSeconds = item.userData!.playbackPositionTicks / 10000000.0;
    return (positionSeconds / item.durationSeconds!).clamp(0.0, 1.0);
  }

  // 格式化时长（秒 -> HH:MM:SS 或 MM:SS）
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
