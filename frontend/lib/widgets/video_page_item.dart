// 视频流单页：全屏视频 + 右侧操作按钮 + 左下角标题信息
// 采用 GestureOverlay 处理手势交互（单击/双击/长按/水平拖动）
//
// 相比原始版本新增：
//   - 右上角齿轮按钮 → 打开 PlaybackSettingsSheet（音轨/字幕/清晰度）
//   - 续播提示：播放器从 userData 位置继续播放时，顶部闪现 "已从 XX:XX 继续"

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import 'gesture_overlay.dart';
import 'playback_settings_sheet.dart';
import 'video_player_widget.dart';

// 单个视频页：TikTok 卡片样式
class VideoPageItem extends ConsumerStatefulWidget {
  final MediaItem item;

  const VideoPageItem({super.key, required this.item});

  @override
  ConsumerState<VideoPageItem> createState() => _VideoPageItemState();
}

class _VideoPageItemState extends ConsumerState<VideoPageItem> {
  VideoPlayerController? _videoController;

  // 续播提示
  Duration? _resumedFrom;
  bool _showResumeHint = false;

  @override
  Widget build(BuildContext context) {
    final favorited =
        ref.watch(favoritesProvider).favoriteIds.contains(widget.item.id);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 底层：视频播放器 + 手势覆盖层
        GestureOverlay(
          controller: _videoController,
          item: widget.item,
          child: VideoPlayerWidget(
            item: widget.item,
            onControllerReady: (c, resumedFrom) {
              setState(() {
                _videoController = c;
                _resumedFrom = resumedFrom;
                if (resumedFrom != null) {
                  _showResumeHint = true;
                  // 3 秒后自动隐藏
                  Future<void>.delayed(const Duration(seconds: 3), () {
                    if (mounted) {
                      setState(() {
                        _showResumeHint = false;
                      });
                    }
                  });
                }
              });
              ref.read(isPlayingProvider.notifier).state = true;
              ref.read(currentPlayingItemProvider.notifier).state =
                  widget.item;
            },
          ),
        ),

        // 顶部：齿轮按钮（右上角）+ 续播提示
        _buildTopBar(),

        // 底部渐变 + 标题/简介/类型标签
        _buildBottomGradient(),

        // 右侧渐变 + 操作按钮
        _buildRightActions(favorited),
      ],
    );
  }

  // 顶部栏：右上角齿轮 + 左上角续播提示
  Widget _buildTopBar() {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 续播提示（动画：淡入淡出 + 下滑）
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _showResumeHint && _resumedFrom != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.history,
                                color: Colors.white70, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '已从 ${_formatDuration(_resumedFrom!)} 继续',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              // 齿轮按钮（打开播放设置）
              IconButton(
                icon: const Icon(
                  Icons.settings,
                  color: Colors.white70,
                  size: 26,
                ),
                onPressed: () {
                  _openPlaybackSettings();
                },
                tooltip: '播放设置',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 打开播放设置底部面板
  void _openPlaybackSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const PlaybackSettingsSheet(),
    );
  }

  // 底部半透明黑色渐变 + 标题/简介/类型标签
  Widget _buildBottomGradient() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 80, 96, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black87,
              Colors.black54,
              Colors.transparent,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE91E63),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.item.type,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _titleText(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (widget.item.overview != null && widget.item.overview!.isNotEmpty)
              Text(
                widget.item.overview!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 右侧操作按钮列：关注 / 点赞 / 收藏 / 评论 / 分享
  Widget _buildRightActions(bool favorited) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 96,
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 40, 8, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              Colors.black54,
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildActionButton(Icons.person_add, '关注', onTap: () {}),
            const SizedBox(height: 20),
            _buildActionButton(
              favorited ? Icons.favorite : Icons.favorite_border,
              '点赞',
              color: favorited ? const Color(0xFFE91E63) : Colors.white,
              onTap: () {
                ref.read(favoritesProvider.notifier).toggleFavorite(widget.item);
              },
            ),
            const SizedBox(height: 20),
            _buildActionButton(
              favorited ? Icons.star : Icons.star_border,
              '收藏',
              color: favorited ? Colors.amber : Colors.white,
              onTap: () {
                ref.read(favoritesProvider.notifier).toggleFavorite(widget.item);
              },
            ),
            const SizedBox(height: 20),
            _buildActionButton(Icons.mode_comment_outlined, '评论', onTap: () {}),
            const SizedBox(height: 20),
            _buildActionButton(Icons.share, '分享', onTap: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label, {
    Color? color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color ?? Colors.white,
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Duration → mm:ss
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final hours = d.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String _titleText() {
    if (widget.item.year != null) {
      return '${widget.item.title} (${widget.item.year})';
    }
    return widget.item.title;
  }
}
