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
    this.fit = VlcVideoFit.contain,
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

  /// 画面缩放模式
  final VlcVideoFit fit;

  @override
  State<VlcVideoPlayer> createState() => VlcVideoPlayerState();
}

/// VLC 播放器公开 State，供 VideoPlayerWidget 通过 GlobalKey 统一控制
class VlcVideoPlayerState extends State<VlcVideoPlayer> {
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
      AppLogger.error('VLC 初始化失败', data: {'error': e.toString()});
      widget.onError?.call(e);
    }
  }

  void _onValueChanged() {
    if (_isDisposed || _controller == null) return;
    widget.onPositionChanged?.call(_controller!.value.position);
  }

  /// 播放速度控制（与 EXO/MPV 对齐）
  void setSpeed(double speed) {
    try {
      // vlc_player 2.x 使用 setPlaybackSpeed，而非 setRate
      _controller?.setPlaybackSpeed(speed);
    } catch (e) {
      AppLogger.debug('VLC setSpeed 失败', data: {'error': e.toString()});
    }
  }

  /// 跳转
  void seekTo(Duration position) {
    try {
      _controller?.seekTo(position);
    } catch (e) {
      AppLogger.debug('VLC seekTo 失败', data: {'error': e.toString()});
    }
  }

  /// 设置音量（0.0 ~ 1.0，VLC 原生音量范围 0 ~ 100）
  void setVolume(double value) {
    try {
      final v = (value.clamp(0.0, 1.0) * 100).round();
      _controller?.setVolume(v);
    } catch (e) {
      AppLogger.debug('VLC setVolume 失败', data: {'error': e.toString()});
    }
  }

  /// 播放
  void play() => _controller?.play();

  /// 暂停
  void pause() => _controller?.pause();

  /// 外部调用：获取当前播放位置
  Duration get position => _controller?.value.position ?? Duration.zero;

  /// 外部调用：获取视频总时长
  Duration get duration => _controller?.value.duration ?? Duration.zero;

  /// 外部调用：是否正在播放
  bool get isPlaying => _controller?.value.isPlaying ?? false;

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
    // 静音状态变化（与 MPV 对齐）
    if (widget.muted != oldWidget.muted) {
      _controller?.setVolume(widget.muted ? 0 : 100);
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
      fit: widget.fit,
    );
  }
}
