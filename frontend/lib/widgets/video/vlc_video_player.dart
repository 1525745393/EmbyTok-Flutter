// VLC 播放器（多播放器 PRD 第四阶段）
//
// 基于 libvlc，网络流兼容性最好。作为 EXO/MPV 之外的兜底引擎，
// 在设置页选择 VLC 后使用。适合播放某些 EXO/MPV 无法硬解的特殊编码流。

import 'package:flutter/material.dart';
import 'package:vlc_player/vlc_player.dart';

import '../../utils/logger.dart';

/// VLC 视频播放器 Widget
///
/// 与 [MpvVideoPlayer] 接口对齐，内部使用 libvlc 渲染。
/// 接收 Emby 播放 URL，自动处理初始化、播放、暂停、seek、销毁。
class VlcVideoPlayer extends StatefulWidget {
  const VlcVideoPlayer({
    super.key,
    required this.url,
    this.httpHeaders,
    this.autoPlay = true,
    this.muted = false,
    this.isCurrentPage = true,
    this.startPosition = Duration.zero,
    this.onPlayerReady,
    this.onPositionChanged,
    this.onPlaybackEnded,
    this.onError,
  });

  final String url;
  final Map<String, String>? httpHeaders;
  final bool autoPlay;
  final bool muted;
  final bool isCurrentPage;
  final Duration startPosition;
  final void Function(VlcPlayerController controller)? onPlayerReady;
  final void Function(Duration position)? onPositionChanged;
  final VoidCallback? onPlaybackEnded;
  final void Function(Object error)? onError;

  @override
  State<VlcVideoPlayer> createState() => _VlcVideoPlayerState();
}

class _VlcVideoPlayerState extends State<VlcVideoPlayer> {
  VlcPlayerController? _controller;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final source = VlcMediaSource(
        uri: Uri.parse(widget.url),
        httpHeaders: widget.httpHeaders ?? const {},
        startPosition: widget.startPosition,
      );

      final controller = VlcPlayerController(
        mediaSource: source,
        autoPlay: widget.autoPlay,
        options: const [
          '--network-caching=1500',
          '--live-caching=3000',
        ],
      );

      _controller = controller;
      widget.onPlayerReady?.call(controller);
      controller.addListener(_onValueChanged);

      if (!widget.isCurrentPage || widget.muted) {
        await controller.pause();
      }
      if (mounted) setState(() {});
    } catch (e, st) {
      AppLogger.severe('VLC 初始化失败', data: {'error': e.toString()});
      widget.onError?.call(e);
    }
  }

  void _onValueChanged() {
    if (_isDisposed || _controller == null) return;
    widget.onPositionChanged?.call(_controller!.value.position);
  }

  @override
  void didUpdateWidget(covariant VlcVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentPage != oldWidget.isCurrentPage) {
      if (widget.isCurrentPage) {
        _controller?.play();
      } else {
        _controller?.pause();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller?.removeListener(_onValueChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return VlcPlayer(
      controller: _controller!,
      backgroundColor: Colors.black,
      fit: VlcVideoFit.contain,
    );
  }
}
