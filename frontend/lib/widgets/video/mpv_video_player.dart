// MPV 播放器（多播放器 PRD 第三阶段）
//
// 基于 media_kit (libmpv)，支持 HDR/杜比 Vision、ASS 字幕、全格式硬解/软解。
// 作为 EXO (video_player) 之外的备选引擎，在设置页选择 MPV 后使用。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../providers/player_engine_provider.dart';
import '../../utils/logger.dart';

/// MPV 视频播放器 Widget
///
/// 与 [VideoPlayerWidget] 接口对齐，内部使用 libmpv 渲染。
/// 接收 Emby 播放 URL，自动处理初始化、播放、暂停、seek、销毁。
class MpvVideoPlayer extends StatefulWidget {
  const MpvVideoPlayer({
    super.key,
    required this.url,
    this.httpHeaders,
    this.autoPlay = true,
    this.muted = false,
    this.isCurrentPage = true,
    this.startPosition = Duration.zero,
    this.hwDec = MpvHwDec.auto,
    this.cacheSizeMb = 16,
    this.forceAssStyle = false,
    this.fit = BoxFit.contain,
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

  /// 是否为当前可见页（PageView 滑动时自动暂停/恢复）
  final bool isCurrentPage;

  /// 起始位置（续播）
  final Duration startPosition;

  /// MPV 解码方式（自动/硬解/软解）
  final MpvHwDec hwDec;

  /// 网络缓存大小（MB）
  final int cacheSizeMb;

  /// 强制覆盖 ASS 字幕字体样式
  final bool forceAssStyle;

  /// 画面缩放模式
  final BoxFit fit;

  /// 播放器初始化完成回调
  final void Function(Player player)? onPlayerReady;

  /// 播放位置变化回调（每秒）
  final void Function(Duration position)? onPositionChanged;

  /// 播放结束回调
  final VoidCallback? onPlaybackEnded;

  /// 错误回调
  final void Function(String message)? onError;

  @override
  State<MpvVideoPlayer> createState() => MpvVideoPlayerState();
}

/// MPV 播放器公开 State，供 VideoPlayerWidget 通过 GlobalKey 统一控制
class MpvVideoPlayerState extends State<MpvVideoPlayer> {
  Player? _player;
  VideoController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _completeSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// 外部调用：暂停播放
  void pause() => _player?.pause();

  /// 外部调用：恢复播放
  void play() => _player?.play();

  /// 外部调用：设置静音
  void setMuted(bool muted) =>
      _player?.setVolume(muted ? 0 : 100);

  /// 外部调用：设置音量（0.0 ~ 1.0，映射到 0 ~ 100）
  void setVolume(double value) {
    try {
      final v = (value.clamp(0.0, 1.0) * 100).round();
      _player?.setVolume(v);
    } catch (e) {
      AppLogger.debug('MPV setVolume 失败', data: {'error': e.toString()});
    }
  }

  /// 外部调用：获取当前播放位置
  Duration get position => _player?.state.position ?? Duration.zero;

  /// 外部调用：获取视频总时长
  Duration get duration => _player?.state.duration ?? Duration.zero;

  /// 外部调用：是否正在播放
  bool get isPlaying => _player?.state.playing ?? false;

  /// 外部调用：设置播放速度
  void setRate(double rate) {
    try {
      _player?.setRate(rate);
    } catch (e) {
      AppLogger.debug('MPV setRate 失败', data: {'error': e.toString()});
    }
  }

  /// 外部调用：跳转
  void seekTo(Duration position) {
    try {
      _player?.seek(position);
    } catch (e) {
      AppLogger.debug('MPV seek 失败', data: {'error': e.toString()});
    }
  }

  Future<void> _init() async {
    try {
      // 创建 MPV 播放器，应用用户配置的缓冲大小
      // 字幕使用 media_kit 默认的 Flutter Widget 渲染；
      // 若启用 libass=true，Android 必须额外配置 libassAndroidFont 字体文件，否则字幕崩溃
      _player = Player(
        configuration: PlayerConfiguration(
          bufferSize: widget.cacheSizeMb * 1024 * 1024,
          logLevel: MPVLogLevel.warn,
          title: 'EmbyTok',
        ),
      );
      _controller = VideoController(_player!);

      // 打开视频流
      await _player!.open(
        Media(
          widget.url,
          httpHeaders: widget.httpHeaders,
        ),
        play: widget.autoPlay,
      );

      // 设置起始位置
      if (widget.startPosition > Duration.zero) {
        await _player!.seek(widget.startPosition);
      }

      // 静音
      await _player!.setVolume(widget.muted ? 0 : 100);

      // 监听播放结束
      _completeSub = _player!.stream.completed.listen((completed) {
        if (completed && mounted) {
          widget.onPlaybackEnded?.call();
        }
      });

      // 监听位置变化（每 5 秒回调一次，减少 UI 重建）
      Duration lastCallback = Duration.zero;
      _positionSub = _player!.stream.position.listen((pos) {
        if (pos - lastCallback > const Duration(seconds: 5)) {
          lastCallback = pos;
          widget.onPositionChanged?.call(pos);
        }
      });

      if (mounted) {
        setState(() => _initialized = true);
        widget.onPlayerReady?.call(_player!);
      }
      AppLogger.info('MPV 播放器初始化成功', data: {'url': widget.url});
    } catch (e) {
      AppLogger.error('MPV 播放器初始化失败', error: e);
      if (mounted) {
        setState(() => _hasError = true);
        widget.onError?.call(e.toString());
      }
    }
  }

  @override
  void didUpdateWidget(MpvVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_player == null) return;
    // PageView 滑动：非当前页暂停+静音，当前页恢复
    if (oldWidget.isCurrentPage != widget.isCurrentPage) {
      if (widget.isCurrentPage) {
        _player!.play();
        _player!.setVolume(widget.muted ? 0 : 100);
      } else {
        _player!.pause();
        _player!.setVolume(0);
      }
    } else if (oldWidget.muted != widget.muted) {
      _player!.setVolume(widget.muted ? 0 : 100);
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _completeSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.white54, size: 48),
              SizedBox(height: 8),
              Text(
                'MPV 播放器加载失败',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    if (!_initialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return Video(
      controller: _controller!,
      fit: widget.fit,
      alignment: Alignment.center,
    );
  }
}
