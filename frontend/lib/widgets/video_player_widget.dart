// 视频播放器 Widget：基于 video_player 插件，支持播放/暂停/跳转/倍速

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';

// 视频播放器：优先播放 item.playbackUrl，如为空则降级为缩略图
class VideoPlayerWidget extends StatefulWidget {
  final MediaItem item;
  // 控制回调：暴露给外部调用
  final void Function(VideoPlayerController controller)? onControllerReady;
  final bool autoPlay;
  final bool loop;
  final String? embyServerUrl;
  final String? token;

  /// 进度更新回调：每 10 秒触发一次，返回当前位置和总时长（秒）
  final void Function(int positionSeconds, int durationSeconds)?
      onProgressUpdate;

  /// 初始播放位置（秒）：用于从上次位置继续播放
  final int? initialPosition;

  /// 视频播放完毕回调
  final VoidCallback? onVideoEnded;

  const VideoPlayerWidget({
    super.key,
    required this.item,
    this.onControllerReady,
    this.autoPlay = true,
    this.loop = true,
    this.embyServerUrl,
    this.token,
    this.onProgressUpdate,
    this.initialPosition,
    this.onVideoEnded,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  Timer? _progressTimer;
  int _lastReportedPosition = 0; // 上次报告的进度位置

  /// 解析出有效的播放 URL（优先 playbackUrl，否则动态构造 Emby 流 URL）
  String? _resolvePlaybackUrl() {
    if (widget.item.playbackUrl != null && widget.item.playbackUrl!.isNotEmpty) {
      return widget.item.playbackUrl;
    }
    return widget.item.computePlaybackUrl(widget.embyServerUrl, widget.token);
  }

  /// 是否可以播放视频：有有效的 URL 且非 web 环境
  bool get _canPlayVideo {
    if (_resolvePlaybackUrl() == null) return false;
    if (kIsWeb) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    if (_canPlayVideo) {
      _initVideo();
    }
  }

  // 初始化 video_player 控制器
  Future<void> _initVideo() async {
    final url = _resolvePlaybackUrl();
    if (url == null) return;
    try {
      final headers = widget.item.authHeaders(widget.token);
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
      );
      _controller!.setLooping(widget.loop);
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _initialized = true;
        });
        widget.onControllerReady?.call(_controller!);

        // 如果有初始位置，跳转到该位置
        if (widget.initialPosition != null && widget.initialPosition! > 0) {
          await _controller!.seekTo(Duration(seconds: widget.initialPosition!));
          _lastReportedPosition = widget.initialPosition!;
        }

        if (widget.autoPlay) {
          await _controller!.play();
        }

        // 启动进度更新定时器
        _startProgressTimer();

        // 监听视频播放状态，检测播放完毕
        _controller!.addListener(_videoListener);
      }
    } catch (e) {
      // 初始化失败：降级为缩略图展示
      if (mounted) {
        setState(() {
          _initialized = false;
        });
      }
    }
  }

  /// 视频播放状态监听器：检测视频是否播放完毕
  void _videoListener() {
    if (_controller == null || !_initialized) return;

    // 检测视频是否播放完毕
    final position = _controller!.value.position;
    final duration = _controller!.value.duration;

    // 当播放位置接近结尾（剩余小于 500ms）且未设置循环时，触发回调
    if (!widget.loop &&
        duration.inMilliseconds > 0 &&
        position.inMilliseconds >= duration.inMilliseconds - 500) {
      widget.onVideoEnded?.call();
    }
  }

  /// 启动进度更新定时器：每 10 秒触发一次回调
  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _reportProgress();
    });
  }

  /// 报告当前播放进度
  void _reportProgress() {
    if (_controller == null || !_initialized) return;
    if (widget.onProgressUpdate == null) return;

    final position = _controller!.value.position.inSeconds;
    final duration = _controller!.value.duration.inSeconds;

    // 只有位置变化超过 5 秒才报告，避免重复
    if ((position - _lastReportedPosition).abs() >= 5) {
      widget.onProgressUpdate!(position, duration);
      _lastReportedPosition = position;
    }
  }

  /// 停止进度更新定时器
  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  // 外部控制 API：播放
  void play() {
    _controller?.play();
  }

  // 外部控制 API：暂停
  void pause() {
    _controller?.pause();
  }

  // 外部控制 API：跳转
  Future<void> seekTo(Duration position) async {
    await _controller?.seekTo(position);
  }

  // 外部控制 API：设置倍速
  Future<void> setRate(double rate) async {
    await _controller?.setPlaybackSpeed(rate);
  }

  @override
  void dispose() {
    // 退出时报告最终进度
    _reportProgress();
    _stopProgressTimer();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 场景 1：无法播放视频，显示缩略图占位
    if (!_canPlayVideo) {
      return _buildThumbnailPlaceholder();
    }

    // 场景 2：视频正在初始化，显示加载指示器
    if (_controller == null || !_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE91E63)),
      );
    }

    // 场景 3：正常播放视频，用 FittedBox 填满容器
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }

  // 缩略图占位：web 环境或无播放地址时使用
  Widget _buildThumbnailPlaceholder() {
    // 优先使用 thumbnailUrl（简化字段），否则用 Emby imageUrl 构造
    final url = widget.item.thumbnailUrl ??
        widget.item.primaryUrl(
          embyServerUrl: widget.embyServerUrl,
          apiKey: widget.token,
          maxWidth: 800,
        );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null && url.isNotEmpty)
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey[900],
              child: const Center(
                child: Icon(Icons.broken_image, size: 64, color: Colors.white30),
              ),
            ),
            loadingBuilder: (_, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFE91E63)),
              );
            },
          )
        else
          Container(
            color: Colors.grey[900],
            child: const Center(
              child: Icon(Icons.movie_outlined, size: 64, color: Colors.white30),
            ),
          ),
        // web 环境下的播放图标占位
        if (kIsWeb)
          const Center(
            child: Icon(
              Icons.play_circle_fill,
              size: 96,
              color: Colors.white70,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 12,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
