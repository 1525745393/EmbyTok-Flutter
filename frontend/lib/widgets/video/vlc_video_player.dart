// VLC 播放器（多播放器 PRD 第四阶段）
//
// 基于 libvlc，网络流兼容性最好。作为 EXO/MPV 之外的兜底引擎，
// 在设置页选择 VLC 后使用。适合播放某些 EXO/MPV 无法硬解的特殊编码流。

import 'dart:async';

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

  /// Emby 视频流 URL
  final String url;

  /// HTTP 请求头（含 X-Emby-Token）
  final Map<String, String>? httpHeaders;

  /// 自动播放
  final bool autoPlay;

  /// 静音（非当前页时静音）
  final bool muted;

  /// 是否为当前可见页
  final bool isCurrentPage;

  /// 起始位置（续播）
  final Duration startPosition;

  /// 播放器初始化完成回调
  final void Function(VlcPlayerController controller)? onPlayerReady;

  /// 位置变化回调
  final void Function(Duration position)? onPositionChanged;

  /// 播放结束回调
  final VoidCallback? onPlaybackEnded;

  /// 错误回调
  final void Function(Object error)? onError;

  @override
  State<VlcVideoPlayer> createState() => _VlcVideoPlayerState();
}

class _VlcVideoPlayerState extends State<VlcVideoPlayer> {
  VlcPlayerController? _controller;
  StreamSubscription? _positionSub;
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

      // 位置回调
      _positionSub = controller.positionStream.listen((pos) {
        if (!_isDisposed) {
          widget.onPositionChanged?.call(pos);
        }
      });

      if (!widget.isCurrentPage || widget.muted) {
        await controller.pause();
      }

      if (mounted) setState(() {});
    } catch (e, st) {
      logger.severe('VLC 初始化失败', error: e, stackTrace: st);
      widget.onError?.call(e);
    }
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
    _positionSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return VlcPlayer(
      controller: _controller!,
      backgroundColor: Colors.black,
      fit: BoxFit.contain,
    );
  }
}
