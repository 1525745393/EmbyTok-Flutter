// 视频播放器 Widget：基于 video_player 插件，支持播放/暂停/跳转/倍速
// 自动上报播放进度到 Emby 服务器

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';
import '../utils/logger.dart';

// 视频播放器：优先播放 item.playbackUrl，支持动态构造 Emby URL
class VideoPlayerWidget extends StatefulWidget {
  final MediaItem item;
  // Emby 服务器认证信息（用于动态构造播放 URL 和上报进度）
  final String? embyServerUrl;
  final String? token;
  // 控制回调：暴露给外部调用
  final void Function(VideoPlayerController controller)? onControllerReady;
  final bool autoPlay;
  final bool loop;
  // 降级策略参数
  final String? fallbackUrl;
  final VoidCallback? onFallback;

  const VideoPlayerWidget({
    super.key,
    required this.item,
    this.embyServerUrl,
    this.token,
    this.onControllerReady,
    this.autoPlay = true,
    this.loop = true,
    this.fallbackUrl,
    this.onFallback,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  String? _errorMessage;

  Timer? _progressTimer;
  int _lastReportedSeconds = 0;

  @override
  void initState() {
    super.initState();
    // 监听静音状态变化
    ref.listenManual(isMutedProvider, (previous, next) {
      _controller?.setVolume(next ? 0.0 : 1.0);
    });
  }

  // 获取播放 URL
  String? get _playbackUrl {
    if (widget.item.playbackUrl != null && widget.item.playbackUrl!.isNotEmpty) {
      return widget.item.playbackUrl;
    }
    return widget.item.computePlaybackUrl(widget.embyServerUrl, widget.token);
  }

  // 判断是否可以播放视频
  bool get _canPlayVideo {
    final url = _playbackUrl;
    if (url == null || url.isEmpty) return false;
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

  // 初始化视频控制器 + 从上次位置继续播放
  Future<void> _initVideo() async {
    final url = _playbackUrl;
    if (url == null) {
      AppLogger.error('无法获取播放地址', data: {'itemId': widget.item.id});
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '无法获取播放地址';
        });
      }
      return;
    }

    AppLogger.info('初始化视频播放器', data: {'itemId': widget.item.id, 'url': url});

    try {
      final headers = widget.item.authHeaders(widget.token);

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
      );
      _controller!.setLooping(widget.loop);
      await _controller!.initialize();

      // 根据静音状态设置初始音量
      final isMuted = ref.read(isMutedProvider);
      _controller!.setVolume(isMuted ? 0.0 : 1.0);

      if (mounted) {
        setState(() {
          _initialized = true;
          _hasError = false;
        });

        // 从上次位置继续播放
        final resumeTicks = widget.item.userData?.playbackPositionTicks ?? 0.0;
        if (resumeTicks > 0) {
          final resumeSec = (resumeTicks / 10000000.0).round();
          if (resumeSec > 0 && resumeSec < _controller!.value.duration.inSeconds) {
            AppLogger.info('从上次位置继续播放', data: {
              'itemId': widget.item.id,
              'resumeSeconds': resumeSec,
            });
            await _controller!.seekTo(Duration(seconds: resumeSec));
          }
        }

        AppLogger.info('视频播放器初始化成功', data: {
          'itemId': widget.item.id,
          'duration': _controller!.value.duration.inSeconds,
        });
        widget.onControllerReady?.call(_controller!);
        if (widget.autoPlay) {
          await _controller!.play();
          _startProgressReporting();
        }
      }
    } catch (e) {
      AppLogger.error('视频播放器初始化失败', error: e, data: {'itemId': widget.item.id, 'url': url});

      // 尝试降级策略
      if (widget.fallbackUrl != null && widget.fallbackUrl!.isNotEmpty) {
        AppLogger.warn('主播放 URL 失败，尝试降级', data: {
          'error': e.toString(),
          'fallbackUrl': widget.fallbackUrl,
        });
        widget.onFallback?.call();

        try {
          _controller = VideoPlayerController.networkUrl(Uri.parse(widget.fallbackUrl!));
          _controller!.setLooping(widget.loop);
          await _controller!.initialize();

          if (mounted) {
            setState(() {
              _initialized = true;
              _hasError = false;
            });
            AppLogger.info('降级 URL 初始化成功', data: {
              'itemId': widget.item.id,
              'fallbackUrl': widget.fallbackUrl,
            });
            widget.onControllerReady?.call(_controller!);
            if (widget.autoPlay) {
              await _controller!.play();
              _startProgressReporting();
            }
          }
          return;
        } catch (fallbackError) {
          AppLogger.error('降级 URL 也失败', error: fallbackError, data: {
            'itemId': widget.item.id,
            'fallbackUrl': widget.fallbackUrl,
          });
        }
      }

      if (mounted) {
        setState(() {
          _initialized = false;
          _hasError = true;
          _errorMessage = '视频加载失败';
        });
      }
    }
  }

  // 定时上报播放进度（每 30 秒上报一次）
  void _startProgressReporting() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _reportProgress();
    });
  }

  // 上报当前播放进度到 Emby
  Future<void> _reportProgress() async {
    if (_controller == null || !_initialized) return;
    final position = _controller!.value.position;
    final currentSeconds = position.inSeconds;
    // 避免重复上报相同位置
    if ((currentSeconds - _lastReportedSeconds).abs() < 10) return;
    _lastReportedSeconds = currentSeconds;

    final positionTicks = currentSeconds * 10000000;
    try {
      if (widget.embyServerUrl != null && widget.token != null) {
        await EmbytokService().reportPlaybackPosition(
          itemId: widget.item.id,
          positionTicks: positionTicks,
          serverUrl: widget.embyServerUrl,
          token: widget.token,
        );
      }
    } catch (e) {
      AppLogger.error('上报播放进度失败', error: e, data: {'itemId': widget.item.id});
    }
  }

  // 上报停止位置（离开页面时调用）
  Future<void> _reportStopped() async {
    if (_controller == null || !_initialized) return;
    final position = _controller!.value.position;
    final positionTicks = position.inSeconds * 10000000;

    try {
      if (widget.embyServerUrl != null && widget.token != null) {
        await EmbytokService().reportPlaybackStopped(
          itemId: widget.item.id,
          positionTicks: positionTicks,
          serverUrl: widget.embyServerUrl,
          token: widget.token,
        );
      }
    } catch (e) {
      AppLogger.error('上报播放停止位置失败', error: e, data: {'itemId': widget.item.id});
    }
  }

  // 外部控制 API
  void play() {
    _controller?.play();
    _startProgressReporting();
  }

  void pause() {
    _controller?.pause();
    _reportProgress();
    _progressTimer?.cancel();
  }

  Future<void> seekTo(Duration position) async {
    await _controller?.seekTo(position);
    _reportProgress();
  }

  Future<void> setRate(double rate) async {
    await _controller?.setPlaybackSpeed(rate);
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _reportStopped();
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_canPlayVideo) {
      AppLogger.warn('无法播放视频，显示缩略图占位', data: {
        'itemId': widget.item.id,
        'hasPlaybackUrl': widget.item.playbackUrl != null,
        'isWeb': kIsWeb,
      });
      return _buildThumbnailPlaceholder();
    }

    if (_controller == null || !_initialized) {
      if (_hasError) {
        AppLogger.error('视频播放器处于错误状态', data: {
          'itemId': widget.item.id,
          'errorMessage': _errorMessage,
        });
      }
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE91E63)),
      );
    }

    // 视频方向自适应显示
    return _buildVideoWithAdaptiveFit();
  }

  // 根据视频内容和屏幕方向自适应显示
  Widget _buildVideoWithAdaptiveFit() {
    final videoSize = _controller!.value.size;
    // 计算视频宽高比（>1 表示横屏，<1 表示竖屏）
    final videoAspectRatio = videoSize.width / videoSize.height;
    // 判断视频是否为横屏
    final isLandscapeVideo = videoAspectRatio > 1.0;

    // 获取缩略图 URL 作为模糊背景
    final thumbnailUrl = widget.item.thumbnailUrlWithAuth(
      widget.embyServerUrl,
      widget.token,
      maxWidth: 800,
    );

    if (isLandscapeVideo) {
      // 横屏视频：在竖屏设备上使用 BoxFit.contain + 模糊背景
      return Stack(
        fit: StackFit.expand,
        children: [
          // 模糊背景图
          if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
            Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black),
            )
          else
            Container(color: Colors.black),
          // 视频居中显示（BoxFit.contain）
          Center(
            child: AspectRatio(
              aspectRatio: videoAspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),
        ],
      );
    } else {
      // 竖屏视频：全屏填充（BoxFit.cover）
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: videoSize.width,
            height: videoSize.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    }
  }

  // 缩略图占位
  Widget _buildThumbnailPlaceholder() {
    final url = widget.item.thumbnailUrlWithAuth(widget.embyServerUrl, widget.token);
    final headers = widget.item.authHeaders(widget.token);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null && url.isNotEmpty)
          Image.network(
            url,
            fit: BoxFit.cover,
            headers: headers.isNotEmpty ? headers : null,
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
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.movie_outlined, size: 64, color: Colors.white30),
                  if (_hasError && _errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (kIsWeb || !_canPlayVideo)
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
