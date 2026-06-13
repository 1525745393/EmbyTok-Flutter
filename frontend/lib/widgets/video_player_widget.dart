// 视频播放器 Widget：基于 video_player 插件，支持播放/暂停/跳转/倍速

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';

// 视频播放器：优先播放 item.playbackUrl，如为空则降级为缩略图
// 通过 item.playbackHttpHeaders 传递 Emby 认证头
class VideoPlayerWidget extends StatefulWidget {
  final MediaItem item;
  // 控制回调：暴露给外部调用
  final void Function(VideoPlayerController controller)? onControllerReady;
  final bool autoPlay;
  final bool loop;

  const VideoPlayerWidget({
    super.key,
    required this.item,
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

  // 判断是否可以播放视频
  bool get _canPlayVideo {
    if (widget.item.playbackUrl == null || widget.item.playbackUrl!.isEmpty) {
      return false;
    }
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

  // 初始化 video_player 控制器
  // 关键点：通过 httpHeaders 传递 X-Emby-Token 认证头
  Future<void> _initVideo() async {
    try {
      final url = widget.item.playbackUrl!;
      // 从 MediaItem 中读取 Emby 认证头，或提供默认值
      final headers = widget.item.playbackHttpHeaders ??
          _buildDefaultHeaders();

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
        if (widget.autoPlay) {
          await _controller!.play();
        }
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

  // 默认认证头（兜底：当 MediaItem 没有头时使用）
  Map<String, String> _buildDefaultHeaders() {
    // 注意：这里不能访问 ApiClient 的 token，因为视频播放器是独立的。
    // 实际使用时应由 MediaItem.withEmbyUrls() 提前构造好 header。
    // 这个默认值是作为安全网。
    return <String, String>{
      'X-Emby-Client': 'EmbyTok',
      'X-Emby-Device-Name': 'Mobile',
      'X-Emby-Client-Version': '1.0.0',
      'Accept': '*/*',
    };
  }

  // ——— 外部控制 API ———
  void play() {
    _controller?.play();
  }

  void pause() {
    _controller?.pause();
  }

  Future<void> seekTo(Duration position) async {
    await _controller?.seekTo(position);
  }

  Future<void> setRate(double rate) async {
    await _controller?.setPlaybackSpeed(rate);
  }

  @override
  void dispose() {
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
  // 对 Emby 来说，thumbnailUrl 已包含 api_key，所以 Image.network 可以直接加载
  Widget _buildThumbnailPlaceholder() {
    final url = widget.item.thumbnailUrl;
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
