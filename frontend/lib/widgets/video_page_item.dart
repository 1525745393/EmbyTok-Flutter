// 视频流单页：全屏视频 + 右侧操作按钮 + 左下角标题信息
// 采用 GestureOverlay 处理手势交互（单击/双击/长按/水平拖动）
// 新增：视频切换渐入动画（200ms fade-in）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import 'gesture_overlay.dart';
import 'video_player_widget.dart';

/// 单个视频页：TikTok 卡片样式
class VideoPageItem extends ConsumerStatefulWidget {
  final MediaItem item;
  final VideoPlayerController? preloadedController;

  const VideoPageItem({
    super.key,
    required this.item,
    this.preloadedController,
  });

  @override
  ConsumerState<VideoPageItem> createState() => _VideoPageItemState();
}

class _VideoPageItemState extends ConsumerState<VideoPageItem>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _videoController;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    // 清理当前 item 的 ready 标记（用于下次再滑回来重新淡入）
    ref.read(videoReadyProvider.notifier).clear(widget.item.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final authState = ref.watch(authProvider);
    final embyServerUrl = authState.embyServerUrl;
    final token = authState.token;

    // 响应式读取收藏状态：任何来源的切换都会立即反映到 UI
    final favorited =
        ref.watch(favoritesProvider).favoriteIds.contains(widget.item.id);

    // 读取 ready 状态：当 item.id 在 videoReadyProvider 中，视为 ready
    final isReady = ref.watch(videoReadyProvider).contains(widget.item.id);

    return Semantics(
      label: '视频播放区域，双击点赞此视频',
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 骨架占位：视频未 ready 时显示渐变色块
          AnimatedContainer(
            duration: const Duration(milliseconds: kVideoFadeInMs),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isReady
                    ? [Colors.transparent, Colors.transparent]  // 透明是 Flutter 自带常量
                    : [surfaceColorL2, surfaceColorL3],
              ),
            ),
          ),

          // 视频播放区（Gestures + VideoPlayer）：未 ready 时透明，ready 后 200ms 渐显
          AnimatedOpacity(
            opacity: isReady ? 1.0 : 0.0,
            duration: const Duration(milliseconds: kVideoFadeInMs),
            curve: Curves.easeOut,
            child: GestureOverlay(
              controller: _videoController,
              item: widget.item,
              child: VideoPlayerWidget(
                item: widget.item,
                embyServerUrl: embyServerUrl,
                token: token,
                preloadedController: widget.preloadedController,
                onControllerReady: (c) {
                  setState(() {
                    _videoController = c;
                  });
                  ref.read(isPlayingProvider.notifier).state = true;
                  ref.read(currentPlayingItemProvider.notifier).state =
                      widget.item;
                  // 标记为 ready：触发 AnimatedOpacity 渐显
                  ref.read(videoReadyProvider.notifier).markReady(widget.item.id);
                },
              ),
            ),
          ),

          // 底部渐变 + 标题/简介/类型标签
          _buildBottomGradient(),

          // 右侧渐变 + 操作按钮
          _buildRightActions(favorited),
        ],
      ),
    );
  }

  // 底部半透明黑色渐变 + 标题/简介/类型标签
  // 动态 padding：适配 notch / 动态岛 / 底部手势条；工具栏隐藏时释放顶部空间
  Widget _buildBottomGradient() {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final toolbarVisible = ref.watch(toolbarVisibilityProvider);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          toolbarVisible ? topPadding + 80 : topPadding + 24, // 工具栏隐藏时释放 56px
          96,
          24 + bottomPadding,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                backgroundColor,
                backgroundColor,
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
                color: primaryPink,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.item.type,
                style: const TextStyle(
                  color: textPrimary,
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
                color: textPrimary,
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
                  color: textSecondary,
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 右侧操作按钮列：静音 / 点赞 / 收藏 / 评论 / 分享
  // 动态 padding：适配顶部 notch / 动态岛与底部手势条
  Widget _buildRightActions(bool favorited) {
    final isMuted = ref.watch(isMutedProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 96,
      child: Container(
        padding: EdgeInsets.fromLTRB(0, topPadding + 40, 8, 24 + bottomPadding),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              black54,
              Colors.transparent,  // 透明是 Flutter 自带常量
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildActionButton(
              isMuted ? Icons.volume_off : Icons.volume_up,
              isMuted ? '静音' : '音量',
              color: isMuted ? errorColor : textPrimary,
              onTap: () {
                ref.read(isMutedProvider.notifier).toggle();
                _videoController?.setVolume(isMuted ? 1.0 : 0.0);
              },
            ),
            const SizedBox(height: 20),
            _buildActionButton(
              favorited ? Icons.favorite : Icons.favorite_border,
              '点赞',
              color: favorited ? primaryPink : textPrimary,
              onTap: () =>
                  ref.read(favoritesProvider.notifier).toggleFavorite(widget.item),
            ),
            const SizedBox(height: 20),
            _buildActionButton(
              favorited ? Icons.star : Icons.star_border,
              '收藏',
              color: favorited ? amberColor : textPrimary,
              onTap: () =>
                  ref.read(favoritesProvider.notifier).toggleFavorite(widget.item),
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

  /// 通用操作按钮：图标 + 标签，带按下缩放动画
  Widget _buildActionButton(
    IconData icon,
    String label, {
    Color? color,
    VoidCallback? onTap,
  }) {
    return _PressableActionButton(
      icon: icon,
      label: label,
      color: color ?? textPrimary,
      onTap: onTap,
    );
  }

  String _titleText() {
    if (widget.item.year != null) {
      return '${widget.item.title} (${widget.item.year})';
    }
    return widget.item.title;
  }
}

/// 带按下缩放动画的按钮（内部 Stateful 管理自己的按下状态）
class _PressableActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _PressableActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  State<_PressableActionButton> createState() => _PressableActionButtonState();
}

class _PressableActionButtonState extends State<_PressableActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 120);
    return GestureDetector(
      onTapDown: (_) {
        if (mounted) setState(() => _pressed = true);
      },
      onTapUp: (_) {
        if (mounted) setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () {
        if (mounted) setState(() => _pressed = false);
      },
      child: AnimatedScale(
        scale: _pressed ? 0.8 : 1.0,
        duration: duration,
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.icon,
              color: widget.color,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
