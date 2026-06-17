// 视频播放器 Widget：基于 video_player 插件，支持播放/暂停/跳转/倍速

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';

// 视频播放器：优先使用 preloadedController（已预加载），否则动态构造
// 设计：preloadedController 用于快速切换场景，避免每次重新初始化
class VideoPlayerWidget extends StatefulWidget {
  final MediaItem item;
  // Emby 服务器认证信息（用于动态构造播放 URL）
  final String? embyServerUrl;
  final String? token;
  // 预加载控制器（如果为 null，则动态创建）
  final VideoPlayerController? preloadedController;
  // 控制回调：暴露给外部调用
  final void Function(VideoPlayerController controller)? onControllerReady;
  final bool autoPlay;
  final bool loop;

  const VideoPlayerWidget({
    super.key,
    required this.item,
    this.embyServerUrl,
    this.token,
    this.preloadedController,
    this.onControllerReady,
    this.autoPlay = true,
    this.loop = true,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  String? _errorMessage;
  // 降级链等级：0=Direct Play, 1=Direct Stream, 2=HLS
  // 仅在动态创建路径（路径2）使用降级，预加载路径不降级
  int _fallbackLevel = 0;

  // 获取播放 URL：优先使用 item.playbackUrl，否则尝试动态构造
  String? get _playbackUrl {
    // 优先使用预置的 playbackUrl
    if (widget.item.playbackUrl != null && widget.item.playbackUrl!.isNotEmpty) {
      return widget.item.playbackUrl;
    }
    // 尝试动态构造 Emby 视频流 URL
    return widget.item.computePlaybackUrl(widget.embyServerUrl, widget.token);
  }

  // 根据降级等级获取对应的播放 URL
  // level 0: Direct Play（computePlaybackUrl）
  // level 1: Direct Stream（computeDirectStreamUrl，Remux 不重编码）
  // level 2: HLS 转码（computeHlsUrl）
  String? _getUrlForFallbackLevel(int level) {
    switch (level) {
      case 1:
        return widget.item.computeDirectStreamUrl(widget.embyServerUrl, widget.token);
      case 2:
        return widget.item.computeHlsUrl(widget.embyServerUrl, widget.token);
      case 0:
      default:
        return widget.item.computePlaybackUrl(widget.embyServerUrl, widget.token);
    }
  }

  // 判断是否可以播放视频（需要 playbackUrl 且非 web 环境）
  bool get _canPlayVideo {
    final url = _playbackUrl;
    if (url == null || url.isEmpty) return false;
    // web 环境下 video_player 需要额外配置，降级为缩略图展示
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

  // 初始化视频控制器
  // 优先级：优先使用 widget.preloadedController（已预加载的），否则动态构造
  // 错误处理策略：
  //   1. 任何异常都降级到缩略图展示（不崩溃）
  //   2. 检查 mounted 避免在已释放的 widget 上 setState
  //   3. 控制器引用仅在本类内部使用，外部通过 onControllerReady 获取
  Future<void> _initVideo() async {
    // ---- 路径 1：有预加载控制器 ----
    if (widget.preloadedController != null) {
      try {
        _controller = widget.preloadedController;
        // addListener 监听错误
        _controller!.addListener(() {
          if (!mounted) return;
          if (_controller!.value.hasError && !_hasError) {
            setState(() {
              _hasError = true;
              _errorMessage = '播放出错';
            });
          }
        });
        // 预加载控制器可能还未初始化（如果预加载还没完成），等待初始化
        if (!_controller!.value.isInitialized) {
          await _controller!.initialize().timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('视频初始化超时');
            },
          );
        }
        _controller!.setLooping(widget.loop);
        if (mounted) {
          setState(() {
            _initialized = true;
            _hasError = false;
          });
          widget.onControllerReady?.call(_controller!);
          if (widget.autoPlay) {
            try {
              await _controller!.play();
            } catch (e) {
              debugPrint('autoPlay error: $e');
            }
          }
        }
        return;
      } catch (e) {
        debugPrint('VideoPlayer preloaded init error: $e，回退到动态创建');
        // 预加载失败，回退到动态创建
      }
    }

    // ---- 路径 2：动态创建控制器 ----
    final url = _getUrlForFallbackLevel(_fallbackLevel);
    if (url == null) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '无法获取播放地址';
        });
      }
      return;
    }

    try {
      final headers = widget.item.authHeaders(widget.token);

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
      );

      // 监听播放器错误事件（例如网络中断、解码失败等）
      _controller!.addListener(() {
        if (!mounted) return;
        if (_controller!.value.hasError && !_hasError) {
          setState(() {
            _hasError = true;
            _errorMessage = '播放出错';
          });
        }
      });

      _controller!.setLooping(widget.loop);
      await _controller!.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('视频初始化超时');
        },
      );
      if (mounted) {
        setState(() {
          _initialized = true;
          _hasError = false;
        });
        widget.onControllerReady?.call(_controller!);
        if (widget.autoPlay) {
          try {
            await _controller!.play();
          } catch (e) {
            debugPrint('autoPlay error: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('VideoPlayer initialization error: $e');
      // 降级链：Direct Play(0) → Direct Stream(1) → HLS(2)
      // 仅在未达到最高降级等级时重试
      if (_fallbackLevel < 2) {
        _fallbackLevel++;
        debugPrint('降级到 level $_fallbackLevel 重试播放');
        // 释放当前失败的控制器，避免资源泄漏
        try {
          await _controller?.dispose();
        } catch (_) {}
        _controller = null;
        // 递归调用自身以使用新的降级等级
        if (mounted) {
          await _initVideo();
        }
        return;
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

  // 外部控制 API：播放
  void play() {
    try {
      _controller?.play();
    } catch (e) {
      debugPrint('play error: $e');
    }
  }

  // 外部控制 API：暂停
  void pause() {
    try {
      _controller?.pause();
    } catch (e) {
      debugPrint('pause error: $e');
    }
  }

  // 外部控制 API：跳转（内部由手势层调用）
  Future<void> seekTo(Duration position) async {
    try {
      await _controller?.seekTo(position);
    } catch (e) {
      debugPrint('seekTo error: $e');
    }
  }

  // 外部控制 API：设置倍速
  Future<void> setRate(double rate) async {
    try {
      await _controller?.setPlaybackSpeed(rate);
    } catch (e) {
      debugPrint('setRate error: $e');
    }
  }

  @override
  void dispose() {
    // 先停后释放，给底层 MediaCodec 留出缓冲时间
    try {
      _controller?.pause();
    } catch (_) {}
    try {
      _controller?.dispose();
    } catch (_) {}
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
    // 优先使用带认证信息的缩略图 URL
    final url = widget.item.thumbnailUrlWithAuth(widget.embyServerUrl, widget.token);
    // 获取认证头用于图片请求
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
        // web 环境或无法播放时的播放图标占位
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
