// 视频流单页：全屏视频 + 右侧操作按钮 + 左下角标题信息
// 采用 GestureOverlay 处理手势交互（单击/双击/长按/水平拖动）
// 新增：视频切换渐入动画（200ms fade-in）
// 新增：TikTok 风格播放体验（横屏全屏、控制层、细线进度条、中央播放按钮）

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import 'gesture_overlay.dart';
import 'video_controls.dart';
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

class _VideoPageItemState extends ConsumerState<VideoPageItem> {
  VideoPlayerController? _videoController;

  // 横屏全屏沉浸模式状态
  bool _isFullscreen = false;

  // 控制层（VideoControls）显示状态
  bool _controlsVisible = false;
  Timer? _controlsHideTimer;

  // 控制层自动隐藏时长
  static const int _controlsAutoHideSeconds = 3;

  @override
  void dispose() {
    // 清理计时器
    _controlsHideTimer?.cancel();
    // 退出时恢复竖屏方向（避免横屏状态残留）
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    // 清理当前 item 的 ready 标记（用于下次再滑回来重新淡入）
    ref.read(videoReadyProvider.notifier).clear(widget.item.id);
    // 显式释放视频控制器，避免 MediaCodec 泄漏导致 OOM
    _videoController?.dispose();
    _videoController = null;
    super.dispose();
  }

  // 切换横屏全屏沉浸模式
  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      // 进入横屏沉浸：强制横屏 + 隐藏工具栏
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      ref.read(toolbarVisibilityProvider.notifier).hide();
    } else {
      // 退出横屏沉浸：恢复竖屏
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      ref.read(toolbarVisibilityProvider.notifier).show();
    }
  }

  // 切换控制层显示/隐藏（由 GestureOverlay 单击触发）
  void _toggleControls() {
    if (_controlsVisible) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  // 显示控制层并启动自动隐藏计时器
  void _showControls() {
    _controlsHideTimer?.cancel();
    setState(() {
      _controlsVisible = true;
    });
    _controlsHideTimer = Timer(
      const Duration(seconds: _controlsAutoHideSeconds),
      _hideControls,
    );
  }

  // 隐藏控制层
  void _hideControls() {
    _controlsHideTimer?.cancel();
    if (mounted) {
      setState(() {
        _controlsVisible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final embyServerUrl = authState.embyServerUrl;
    final token = authState.token;

    // 响应式读取收藏状态：任何来源的切换都会立即反映到 UI
    final favorited =
        ref.watch(favoritesProvider).favoriteIds.contains(widget.item.id);

    // 读取 ready 状态：当 item.id 在 videoReadyProvider 中，视为 ready
    final isReady = ref.watch(videoReadyProvider).contains(widget.item.id);

    // 读取播放状态（用于中央播放按钮显示）
    final isPlaying = ref.watch(isPlayingProvider);

    // 横屏全屏模式下使用黑色背景 + 居中布局
    final content = Stack(
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
                  ? [Colors.transparent, Colors.transparent]
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
            onSingleTap: _toggleControls,
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

        // TikTok 风格底部细线进度条（始终可见）
        if (_videoController != null && _videoController!.value.isInitialized)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ThinProgressBar(controller: _videoController!),
          ),

        // 中央播放/暂停按钮（暂停时显示）
        if (_videoController != null && _videoController!.value.isInitialized && !isPlaying)
          _buildCenterPlayButton(),

        // 控制层（VideoControls）：可隐藏，3 秒无操作自动淡出
        if (_videoController != null && _videoController!.value.isInitialized)
          Positioned(
            left: 0,
            right: 0,
            bottom: _isFullscreen ? 0 : kBottomNavHeight,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: Duration(milliseconds: _controlsVisible ? 200 : 300),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: VideoControls(controller: _videoController!),
              ),
            ),
          ),

        // 底部渐变 + 标题/简介/类型标签（横屏全屏模式下隐藏）
        if (!_isFullscreen) _buildBottomGradient(),

        // 右侧渐变 + 操作按钮（横屏全屏模式下隐藏）
        if (!_isFullscreen) _buildRightActions(favorited),

        // 横屏全屏模式下显示退出按钮（右上角）
        if (_isFullscreen) _buildExitFullscreenButton(),
      ],
    );

    // 横屏全屏模式：黑色背景 + 居中
    if (_isFullscreen) {
      return Semantics(
        label: '横屏全屏视频播放',
        child: Container(
          color: backgroundColor,
          child: content,
        ),
      );
    }

    return Semantics(
      label: '视频播放区域，双击点赞此视频',
      child: content,
    );
  }

  // 中央播放按钮：暂停时显示半透明播放图标
  Widget _buildCenterPlayButton() {
    return Positioned.fill(
      child: Center(
        child: GestureDetector(
          onTap: () {
            try {
              _videoController?.play();
              ref.read(isPlayingProvider.notifier).state = true;
              // 显示控制层并重置计时器
              _showControls();
            } catch (e) {
              debugPrint('center play button error: $e');
            }
          },
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0x99000000), // 60% 不透明黑色
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow,
              color: textPrimary,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }

  // 横屏全屏模式下的退出按钮（右上角）
  Widget _buildExitFullscreenButton() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + 8,
      right: 16,
      child: IconButton(
        icon: const Icon(Icons.fullscreen_exit, color: textPrimary, size: 28),
        onPressed: _toggleFullscreen,
      ),
    );
  }

  // 底部半透明黑色渐变 + 标题/简介/类型标签
  // 动态 padding：适配底部导航栏高度 + 底部手势条
  // 底部导航栏显示时向上偏移 kBottomNavHeight，隐藏时仅保留安全 padding
  Widget _buildBottomGradient() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final toolbarVisible = ref.watch(toolbarVisibilityProvider);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          80, // 顶部距离：从视频画面上方开始计算（避开右侧操作按钮的垂直范围
          96,
          // 底部距离：导航栏可见时 = kBottomNavHeight + 手势条 + 24px；隐藏时 = 手势条 + 24px
          toolbarVisible
              ? kBottomNavHeight + bottomPadding + 24
              : bottomPadding + 24,
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
  // 动态 padding：顶部工具栏可见时向下偏移 kAppToolbarHeight，避开半透明工具栏
  Widget _buildRightActions(bool favorited) {
    final isMuted = ref.watch(isMutedProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final toolbarVisible = ref.watch(toolbarVisibilityProvider);

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 96,
      child: Container(
        // 顶部距离：工具栏可见时 = 顶部安全区 + 工具栏高度 + 40px；隐藏时 = 安全区 + 40px
        padding: EdgeInsets.fromLTRB(
          0,
          toolbarVisible
              ? topPadding + kAppToolbarHeight + 40
              : topPadding + 40,
          8,
          24 + bottomPadding,
        ),
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
              _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
              _isFullscreen ? '退出' : '全屏',
              color: textPrimary,
              onTap: _toggleFullscreen,
            ),
            const SizedBox(height: 20),
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

/// TikTok 风格底部细线进度条
/// 高度 2px，始终可见，颜色为品牌粉色，背景半透明黑色
class _ThinProgressBar extends StatefulWidget {
  final VideoPlayerController controller;

  const _ThinProgressBar({required this.controller});

  @override
  State<_ThinProgressBar> createState() => _ThinProgressBarState();
}

class _ThinProgressBarState extends State<_ThinProgressBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.controller.value.duration;
    final position = widget.controller.value.position;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      height: 2,
      width: double.infinity,
      color: const Color(0x4D000000), // 30% 不透明黑色背景
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(color: primaryPink),
      ),
    );
  }
}
