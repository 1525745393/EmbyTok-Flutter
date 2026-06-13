// 视频播放器 Widget（增强版）
//
// 相比原始版本，新增能力：
//   1. 自动续播（读取 item.userData.playbackPositionTicks）
//   2. 根据 playback_settings_provider 切换音轨/字幕轨/清晰度
//   3. 外挂字幕下载 + SRT 解析 + 叠加渲染
//   4. 播放进度上报（每 30s 调 EmbytokService.reportPlaybackProgress）
//   5. 停止时 reportPlaybackStopped
//
// 播放策略：
//   - 若 item.mediaSources 非空 + directPlayUrl 可用 -> 使用选中
//     MediaSource.directPlayUrl（追加 AudioStreamIndex / SubtitleStreamIndex）
//   - 否则降级为 item.playbackUrl（保留原始逻辑）
//   - 切换 MediaSource / 音轨 / 字幕轨 会重建 VideoPlayerController

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/playback_settings_provider.dart';
import '../services/services.dart';
import 'subtitle_renderer.dart';

// 外部回调：播放器初始化完成后触发
//   - controller：VideoPlayerController
//   - resumedFrom：若从续播位置启动则为该 Duration；否则为 null
typedef OnControllerReady = void Function(
  VideoPlayerController controller,
  Duration? resumedFrom,
);

class VideoPlayerWidget extends ConsumerStatefulWidget {
  final MediaItem item;
  final OnControllerReady? onControllerReady;
  final bool autoPlay;
  final bool loop;
  final bool autoResume; // 是否自动续播

  const VideoPlayerWidget({
    super.key,
    required this.item,
    this.onControllerReady,
    this.autoPlay = true,
    this.loop = true,
    this.autoResume = true,
  });

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isSeeking = false;

  // 续播位置（若 > Duration.zero 则初始化后 seekTo 到此）
  Duration _resumePosition = Duration.zero;

  // 实际跳转过的位置（用于上报）
  Duration _reportedPosition = Duration.zero;

  // 播放进度计时器
  Timer? _progressTimer;
  DateTime? _lastReportedTime;

  // 当前播放会话 ID
  final String _playSessionId = DateTime.now().millisecondsSinceEpoch.toString();

  // 当前字幕内容
  List<SubtitleCue> _subtitleCues = [];
  bool _subtitlesEnabled = true;

  // 上次的播放设置，用于检测切换
  String? _lastMediaSourceId;
  int _lastAudioIndex = -2;
  int _lastSubtitleIndex = -2;

  // ============================================================
  // 生命周期
  // ============================================================
  @override
  void initState() {
    super.initState();

    // 读取续播位置
    if (widget.autoResume) {
      final ticks = widget.item.userData?.playbackPositionTicks ?? 0.0;
      if (ticks > 0) {
        _resumePosition = Duration(microseconds: (ticks / 10).round());
      }
    }

    // 初始化 playbackSettingsProvider
    Future.microtask(() {
      ref.read(playbackSettingsProvider.notifier).reset(widget.item);
    });

    if (_canPlayVideo) {
      _initVideo();
    }
  }

  @override
  void dispose() {
    _stopProgressReporting();
    _reportStoppedIfNeeded();
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  // ============================================================
  // 判断是否可播放
  // ============================================================
  bool get _canPlayVideo {
    if (kIsWeb) return false;

    // 优先 MediaSource.directPlayUrl；回退到 item.playbackUrl
    final sources = widget.item.mediaSources ?? const [];
    final hasDirectUrl = sources.isNotEmpty &&
        sources.any((s) => (s.directPlayUrl ?? '').isNotEmpty);
    if (hasDirectUrl) return true;
    return widget.item.playbackUrl?.isNotEmpty ?? false;
  }

  // ============================================================
  // 初始化视频控制器
  // ============================================================
  Future<void> _initVideo() async {
    try {
      final settings = ref.read(playbackSettingsProvider);
      final (url, headers) = _buildPlaybackUrl(settings);

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
      );

      _controller!.setLooping(widget.loop);
      await _controller!.initialize();

      // 记录最后一次使用的设置
      _lastMediaSourceId = settings.currentSource?.id;
      _lastAudioIndex = settings.selectedAudioStreamIndex;
      _lastSubtitleIndex = settings.selectedSubtitleStreamIndex;

      // 续播
      if (_resumePosition > Duration.zero) {
        try {
          await _controller!.seekTo(_resumePosition);
        } catch (_) {
          // 某些平台 seek 失败不影响播放
        }
      }

      if (!mounted) return;
      setState(() {
        _initialized = true;
      });

      widget.onControllerReady?.call(_controller!, _resumePosition > Duration.zero ? _resumePosition : null);

      // 加载字幕
      unawaited(_loadSubtitlesIfNeeded(settings));

      if (widget.autoPlay) {
        await _controller!.play();
      }

      _startProgressReporting();
    } catch (e) {
      if (mounted) {
        setState(() {
          _initialized = false;
        });
      }
    }
  }

  // 重建控制器（切换源/音轨/字幕轨时调用）
  Future<void> _rebuildController({bool keepPosition = true}) async {
    final settings = ref.read(playbackSettingsProvider);
    final (url, headers) = _buildPlaybackUrl(settings);

    // 保存当前位置
    final currentPos = _controller?.value.position ?? Duration.zero;
    final wasPlaying = _controller?.value.isPlaying ?? false;

    // 停掉旧控制器
    _stopProgressReporting();
    await _controller?.dispose();
    _controller = null;

    if (!mounted) return;
    setState(() {
      _initialized = false;
    });

    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
      );
      await _controller!.initialize();

      _lastMediaSourceId = settings.currentSource?.id;
      _lastAudioIndex = settings.selectedAudioStreamIndex;
      _lastSubtitleIndex = settings.selectedSubtitleStreamIndex;

      // 恢复位置
      final resumePos = keepPosition && currentPos > Duration.zero
          ? currentPos
          : _resumePosition;
      if (resumePos > Duration.zero) {
        try {
          await _controller!.seekTo(resumePos);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _initialized = true;
      });

      widget.onControllerReady?.call(_controller!, null);

      // 重新加载字幕
      unawaited(_loadSubtitlesIfNeeded(settings));

      if (wasPlaying || widget.autoPlay) {
        await _controller!.play();
      }

      _startProgressReporting();
    } catch (e) {
      if (mounted) {
        setState(() {
          _initialized = false;
        });
      }
    }
  }

  // 根据 playbackSettings 构造播放 URL 与 headers
  (String url, Map<String, String> headers) _buildPlaybackUrl(
    PlaybackSettings settings,
  ) {
    final src = settings.currentSource;
    final baseUrl = src?.directPlayUrl ?? widget.item.playbackUrl ?? '';
    final headers = src?.httpHeaders ??
        widget.item.playbackHttpHeaders ??
        _buildDefaultHeaders();

    // 追加 AudioStreamIndex / SubtitleStreamIndex（仅在使用 mediaSource 时）
    if (src != null && (src.directPlayUrl ?? '').isNotEmpty) {
      final queryParts = <String>[];
      final audioStream = settings.currentAudioStream;
      if (audioStream != null) {
        queryParts.add('AudioStreamIndex=${audioStream.index}');
      }
      // 内嵌字幕（非外挂）：告诉 Emby 服务器把字幕烧进视频流
      final subStream = settings.currentSubtitleStream;
      if (subStream != null && !subStream.isExternal) {
        queryParts.add('SubtitleStreamIndex=${subStream.index}');
      }
      if (queryParts.isNotEmpty) {
        final sep = baseUrl.contains('?') ? '&' : '?';
        return (baseUrl + sep + queryParts.join('&'), headers);
      }
    }
    return (baseUrl, headers);
  }

  // 默认认证头（兜底）
  Map<String, String> _buildDefaultHeaders() {
    return <String, String>{
      'X-Emby-Client': 'EmbyTok',
      'X-Emby-Device-Name': 'Mobile',
      'X-Emby-Client-Version': '1.0.0',
      'Accept': '*/*',
    };
  }

  // ============================================================
  // 字幕加载（外挂 SRT / VTT）
  // ============================================================
  Future<void> _loadSubtitlesIfNeeded(PlaybackSettings settings) async {
    _subtitleCues = [];
    final subStream = settings.currentSubtitleStream;
    if (subStream == null) {
      if (mounted) setState(() {});
      return;
    }
    // 内嵌字幕（isExternal=false）由服务器烧进流里，无需本地处理
    if (!subStream.isExternal) {
      if (mounted) setState(() {});
      return;
    }
    final url = subStream.deliveryUrl;
    if (url == null || url.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    try {
      // 从当前源继承 X-Emby-Token 等认证头
      final curSrc = settings.currentSource;
      final headers = <String, String>{'Accept': '*/*'};
      if (curSrc?.httpHeaders != null) {
        headers.addAll(curSrc!.httpHeaders!);
      }
      final content = await _httpGetText(url, headers);
      if (content != null && content.isNotEmpty) {
        _subtitleCues = parseSrt(content);
      }
    } catch (_) {
      // 字幕加载失败不影响视频播放
    }
    if (mounted) setState(() {});
  }

  // 基于 dart:io 的简化 HTTP GET，返回文本内容
  Future<String?> _httpGetText(String url, Map<String, String> headers) async {
    HttpClient? client;
    try {
      client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      headers.forEach((name, value) {
        request.headers.set(name, value);
      });
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final bytes = await consolidateHttpClientResponseBytes(response);
      // 优先 UTF-8，对于简单字幕足够
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    } finally {
      client?.close();
    }
  }

  // ============================================================
  // 进度上报
  // ============================================================
  void _startProgressReporting() {
    _stopProgressReporting();
    _lastReportedTime = DateTime.now();
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _reportProgress();
    });
  }

  void _stopProgressReporting() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  Future<void> _reportProgress() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    if (!ctrl.value.isInitialized) return;

    final pos = ctrl.value.position;
    if (pos == _reportedPosition) return; // 无变化跳过
    _reportedPosition = pos;

    // 转为 Emby tick（1 tick = 100ns）
    final ticks = (pos.inMicroseconds * 10).toInt();

    try {
      final service = EmbytokService();
      final src = ref.read(playbackSettingsProvider).currentSource;
      await service.reportPlaybackProgress(
        itemId: widget.item.id,
        positionTicks: ticks,
        isPaused: !ctrl.value.isPlaying,
        mediaSourceId: src?.id,
        playSessionId: _playSessionId,
      );
    } catch (_) {
      // 上报失败静默处理
    }
  }

  void _reportStoppedIfNeeded() {
    final ctrl = _controller;
    if (ctrl == null) return;
    if (!ctrl.value.isInitialized) return;
    final pos = ctrl.value.position;
    final ticks = (pos.inMicroseconds * 10).toInt();
    try {
      final service = EmbytokService();
      final src = ref.read(playbackSettingsProvider).currentSource;
      // ignore: discarded_futures
      service.reportPlaybackStopped(
        itemId: widget.item.id,
        positionTicks: ticks,
        mediaSourceId: src?.id,
        playSessionId: _playSessionId,
      );
    } catch (_) {}
  }

  // ============================================================
  // 外部控制 API
  // ============================================================
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

  // ============================================================
  // 构建
  // ============================================================
  @override
  Widget build(BuildContext context) {
    // 监听播放设置变化
    ref.listen<PlaybackSettings>(playbackSettingsProvider, (prev, next) {
      final sourceChanged =
          (prev?.selectedMediaSourceId) != next.selectedMediaSourceId;
      final audioChanged =
          (prev?.selectedAudioStreamIndex) != next.selectedAudioStreamIndex;
      final subIdxChanged =
          (prev?.selectedSubtitleStreamIndex) != next.selectedSubtitleStreamIndex;

      // 源切换 / 音轨切换 -> 需要重建控制器（video_player 不支持热切换）
      if (sourceChanged || audioChanged) {
        unawaited(_rebuildController(keepPosition: true));
        return;
      }
      // 字幕轨切换：如果是内嵌字幕，则需要重建控制器让服务器重新编码；
      // 若是外挂字幕，只需重新下载即可
      if (subIdxChanged) {
        final subStream = next.currentSubtitleStream;
        if (subStream != null && !subStream.isExternal) {
          unawaited(_rebuildController(keepPosition: true));
        } else {
          unawaited(_loadSubtitlesIfNeeded(next));
        }
      }
    });

    // 监听播放位置（用于字幕渲染刷新）
    if (!_canPlayVideo) return _buildThumbnailPlaceholder();
    if (_controller == null || !_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE91E63)),
      );
    }

    return _VideoPlayerWithSubtitles(
      controller: _controller!,
      cues: _subtitleCues,
      subtitlesEnabled: _subtitlesEnabled,
    );
  }

  // 缩略图占位：web 环境或无播放地址时使用
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
        if (kIsWeb)
          const Center(
            child: Icon(
              Icons.play_circle_fill,
              size: 96,
              color: Colors.white70,
              shadows: [
                Shadow(color: Colors.black54, blurRadius: 12),
              ],
            ),
          ),
      ],
    );
  }
}

// 视频播放器 + 字幕叠加渲染（独立 Widget 以获得独立刷新）
class _VideoPlayerWithSubtitles extends StatefulWidget {
  final VideoPlayerController controller;
  final List<SubtitleCue> cues;
  final bool subtitlesEnabled;

  const _VideoPlayerWithSubtitles({
    required this.controller,
    required this.cues,
    required this.subtitlesEnabled,
  });

  @override
  State<_VideoPlayerWithSubtitles> createState() => _VideoPlayerWithSubtitlesState();
}

class _VideoPlayerWithSubtitlesState extends State<_VideoPlayerWithSubtitles> {
  late final VoidCallback _listener;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _listener = () {
      if (!mounted) return;
      final pos = widget.controller.value.position;
      if (pos != _position) {
        setState(() {
          _position = pos;
        });
      }
    };
    widget.controller.addListener(_listener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: widget.controller.value.size.width,
              height: widget.controller.value.size.height,
              child: VideoPlayer(widget.controller),
            ),
          ),
        ),
        // 字幕叠加
        SubtitleRenderer(
          position: _position,
          cues: widget.cues,
          enabled: widget.subtitlesEnabled,
        ),
      ],
    );
  }
}
