// 视频播放器 Widget：仅使用 Direct Play 模式

import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:vlc_player/vlc_player.dart' show VlcVideoFit;

import '../../models/models.dart';
import '../../providers/player_engine_provider.dart';
import '../../providers/providers.dart';
import '../../services/external_player_service.dart';
import '../../utils/image_cache_manager.dart';
import '../../utils/logger.dart';
import 'mpv_video_player.dart';
import 'vlc_video_player.dart';
import 'subtitle_renderer.dart';
// 视频播放器：优先使用 preloadedController（已预加载），否则动态构造
// 设计：preloadedController 用于快速切换场景，避免每次重新初始化
// 仅使用 Direct Play 模式
class VideoPlayerWidget extends ConsumerStatefulWidget {
  const VideoPlayerWidget({
    super.key,
    required this.item,
    this.embyServerUrl,
    this.token,
    this.preloadedController,
    this.onControllerReady,
    this.onControllerReleased,
    this.autoPlay = true,
    this.loop = true,
    this.startFromResumePosition = false,
    this.isCurrentPage = true,
    this.isLocal = false,
    this.externalSubtitlePaths = const [],
    this.extraHttpHeaders = const {},
    this.onPlaybackEnded,
  });
  final MediaItem item;
  // 本地模式标记：true=播放手机本地文件（file:///），跳过 Emby 认证头与 AudioStreamIndex 追加
  final bool isLocal;
  // 本地模式：外挂字幕文件绝对路径列表（P3）
  final List<String> externalSubtitlePaths;
  // 额外 HTTP 请求头（P2：WebDAV Basic Auth 等），合并到播放器请求中
  final Map<String, String> extraHttpHeaders;
  // 播放结束回调（本地连播 P3）
  final VoidCallback? onPlaybackEnded;
  // Emby 服务器认证信息（用于动态构造播放 URL）
  final String? embyServerUrl;
  final String? token;
  // 预加载控制器（如果为 null，则动态创建）
  final VideoPlayerController? preloadedController;
  // 控制回调：暴露给外部调用
  final void Function(VideoPlayerController controller)? onControllerReady;
  // 控制器被释放（dispose）时回调，通知外部清理就绪状态
  final VoidCallback? onControllerReleased;
  final bool autoPlay;
  final bool loop;
  // 是否从续播位置开始播放（Emby 服务器同步的播放进度）
  final bool startFromResumePosition;
  // 是否为当前可见页面（非当前页初始化后暂停+静音，避免并发播放/解码）
  final bool isCurrentPage;

  @override
  ConsumerState<VideoPlayerWidget> createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget>
    implements PlayerControlHandle {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  // 错误信息统一使用 AppError，便于按类型展示和区分重试按钮
  AppError? _errorMessage;
  // 自动降级：记录当前是否已降级到备用引擎
  // MPV 失败 → 自动切 EXO；EXO 失败 → 自动切 VLC；VLC 失败 → 报错
  PlayerEngine? _fallbackEngine;
  // MPV 公开 State 的 GlobalKey（统一控制通道：seek/setRate/setVolume）
  final GlobalKey<MpvVideoPlayerState> _mpvKey =
      GlobalKey<MpvVideoPlayerState>();
  // VLC 公开 State 的 GlobalKey（统一控制通道）
  final GlobalKey<VlcVideoPlayerState> _vlcKey =
      GlobalKey<VlcVideoPlayerState>();
  // 使用 ValueNotifier 减少字幕重绘频率（只在跨秒时更新）
  final ValueNotifier<int> _positionMs = ValueNotifier<int>(0);
  // 异步加载的字幕 Cues（从 Emby 服务器获取）
  List<SubtitleCue> _subtitleCues = const <SubtitleCue>[];
  // 标记 widget 是否已 dispose，防止异步操作在 dispose 后继续执行
  bool _isDisposed = false;
  // 标记视频尺寸是否曾为空（用于尺寸更新时触发重建以隐藏加载指示器）
  bool _sizeWasEmpty = false;
  // 标记预加载 controller 是否已被使用过（可能已被 dispose）
  // 避免 _initVideo() 被重新调用时重复使用已 dispose 的预加载 controller
  bool _preloadedControllerUsed = false;
  // 非当前页延迟释放计时器（2秒后释放 controller 节省解码资源）
  // 缩短自 5 秒：平衡快速来回滑动的体验与内存占用
  Timer? _backgroundReleaseTimer;
  /// 断网自动重试计数（播放出错后自动重试，最多 2 次）
  int _autoRetryCount = 0;
  // 非当前页 controller 释放延迟（800ms，快速滑动时由 isPageScrollingProvider 触发即时释放）
  static const Duration _backgroundReleaseDelay = Duration(milliseconds: 800);
  // 字幕选择变化监听订阅（在 initState 中注册，dispose 时关闭）
  ProviderSubscription<String?>? _subtitleSubscription;
  // 音轨选择变化监听订阅
  ProviderSubscription<int?>? _audioTrackSubscription;

  // 获取播放 URL：优先使用 item.playbackUrl，否则尝试动态构造
  // 追加 AudioStreamIndex 参数支持多音轨切换
  String? get _playbackUrl {
    // 本地文件源：优先用 localNetworkUrl / localPath，不走 Emby
    if (widget.item.isLocalFile) {
      if (widget.item.localNetworkUrl != null &&
          widget.item.localNetworkUrl!.isNotEmpty) {
        return widget.item.localNetworkUrl;
      }
      if (widget.item.localPath != null && widget.item.localPath!.isNotEmpty) {
        return 'file://${widget.item.localPath}';
      }
      return null;
    }
    // 优先使用预置的 playbackUrl
    var url = widget.item.playbackUrl;
    if (url == null || url.isEmpty) {
      // 尝试动态构造 Emby 视频流 URL
      url = widget.item.computePlaybackUrl(widget.embyServerUrl, widget.token);
    }
    if (url == null || url.isEmpty) return null;
    // 追加音轨参数（用户选择非默认音轨时）
    // 本地文件跳过：AudioStreamIndex 是 Emby 服务端参数，会破坏本地 file:// URL
    if (!widget.isLocal) {
      final audioIndex = ref.read(selectedAudioStreamIndexProvider);
      if (audioIndex != null) {
        final sep = url.contains('?') ? '&' : '?';
        url = '$url${sep}AudioStreamIndex=$audioIndex';
      }
    }
    return url;
  }

  // 判断是否可以播放视频（需要 playbackUrl 且非 web 环境）
  bool get _canPlayVideo {
    final url = _playbackUrl;
    if (url == null || url.isEmpty) return false;
    // web 环境下 video_player 需要额外配置，降级为缩略图展示
    if (kIsWeb) return false;
    return true;
  }

  /// 播放失败时用第三方外部播放器兜底
  ///
  /// 内置播放器无法解码某些编码（如 Dolby Vision P7、HEVC 10bit 等）时，
  /// 自动唤起 VLC / MX Player 等外部播放器播放视频流。
  Future<void> _playWithExternalPlayerFromError(BuildContext context) async {
    final url = _playbackUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法获取播放地址')),
      );
      return;
    }
    final success = await ExternalPlayerService.play(
      videoUrl: url,
      title: widget.item.title,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? '已唤起外部播放器'
            : '未找到可用的外部播放器，请安装 VLC 或 MX Player'),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // 监听字幕选择变化：用户选择新字幕轨道时异步加载
    // 必须在 initState 中通过 listenManual 注册，不能在 build 中，
    // 否则会因 build 时序问题导致选择事件被遗漏
    _subtitleSubscription =
        ref.listenManual<String?>(selectedSubtitleProvider, (previous, next) {
      if (next != previous) {
        _loadSubtitle(next);
      }
    });
    // 音轨切换：重建 controller 并 seek 回原位置
    _audioTrackSubscription =
        ref.listenManual<int?>(selectedAudioStreamIndexProvider, (prev, next) {
      if (prev != next && mounted && _canPlayVideo) {
        _reinitForAudioTrackSwitch();
      }
    });
    if (_canPlayVideo) {
      _initVideo();
    }
    // 注册统一控制句柄：横屏覆盖层通过 currentPlayerControlProvider
    // 调用 seekTo/setRate/setVolume，三引擎同步生效
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        ref.read(currentPlayerControlProvider.notifier).state = this;
      }
    });
  }

  // 跟踪当前 widget.item.id，用于检测 item 切换
  String? _currentItemId;

  // 重初始化令牌：防止 _reinitForNewItem 异步竞态导致并发初始化
  // 每次调用 _reinitForNewItem 时递增，_initVideo 中每次 await 后检查令牌是否过期
  int _reinitToken = 0;

  // didUpdateWidget：跟踪 widget.item.id 变化
  // 场景：用户看 video-X 播到 30s → 切到"推荐"模式 → items 列表被替换
  //   → video-X 被我们保留到 loadedItems[0]（见 video_list_provider._ensurePlayingItemFirst）
  //   → PageView 重新 build 时可能给本 widget 传一个不同的 item（item.id != _currentItemId）
  // 此时必须释放旧 controller，用新 item 重新初始化。
  // 不然会出现"画面还在播旧视频，但元信息/封面是另一部"的鬼影 bug。
  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newItemId = widget.item.id;
    if (_currentItemId == null) {
      _currentItemId = newItemId;
      return;
    }
    // 优先处理 item 切换：避免先用旧 controller 同步状态再立即重建
    if (newItemId != _currentItemId) {
      AppLogger.debug('VideoPlayerWidget item 切换，重建 controller', data: {
        'oldItemId': _currentItemId,
        'newItemId': newItemId,
      });
      _currentItemId = newItemId;
      // 异步释放 + 重新初始化（fire-and-forget）
      _reinitForNewItem();
      return;
    }
    // 同一个视频，处理 isCurrentPage 变化：同步播放/暂停状态和音量
    // 场景：PageView 滑动后，旧页变为非当前页（需暂停），新页变为当前页（需恢复播放）
    if (oldWidget.isCurrentPage != widget.isCurrentPage) {
      final c = _controller;
      // 仅在 controller 已初始化时同步播放/暂停；未初始化时仍需处理计时器
      if (c != null && c.value.isInitialized) {
        _syncPlaybackState(c);
      }
      if (!widget.isCurrentPage) {
        // 非当前页：滚动中立即释放，否则启动延迟释放计时器
        // 滚动中释放防止快速滑动时累积 6-8 个已初始化的 controller（每个 20-50MB）
        if (ref.read(isPageScrollingProvider)) {
          _releaseCurrentController();
        } else {
          _backgroundReleaseTimer?.cancel();
          _backgroundReleaseTimer = Timer(_backgroundReleaseDelay, () {
            if (_isDisposed || !mounted) return;
            if (!widget.isCurrentPage && _controller != null) {
              AppLogger.debug('非当前页超时，释放 controller 资源',
                  data: {'itemId': widget.item.id});
              _releaseCurrentController();
              if (mounted) {
                setState(() {
                  _initialized = false;
                });
              }
            }
          });
        }
      } else {
        // 回到当前页：取消释放计时器，如 controller 已被释放则重新初始化
        _backgroundReleaseTimer?.cancel();
        if (_controller == null || !_controller!.value.isInitialized) {
          _initialized = false;
          _hasError = false;
          _initVideo();
        }
      }
    }
  }

  /// 重试初始化：用户点击"重试"按钮时调用
  ///
  /// 公开方法：清除错误状态并重新触发初始化流程，供外部通过 GlobalKey 调用
  void retryInitialization() {
    if (_isDisposed || !mounted) return;

    // 自动降级：根据当前引擎自动切换到下一个备用引擎
    final engineSettings = ref.read(playerEngineSettingsProvider);
    final current = _fallbackEngine ?? engineSettings.defaultEngine;
    PlayerEngine? next;
    if (current == PlayerEngine.mpv) {
      next = PlayerEngine.exo;
    } else if (current == PlayerEngine.exo) {
      next = PlayerEngine.vlc;
    }
    // VLC 已是最后兜底，不再降级
    if (next != null) {
      _fallbackEngine = next;
      // 记录降级日志
      AppLogger.warn('自动降级：$current → $next', tag: 'EngineFallback');
    }

    setState(() {
      _hasError = false;
      _errorMessage = null;
      _initialized = false;
    });
    // 重新触发初始化（依赖 didUpdateWidget 中的初始化逻辑）
    _reinitForNewItem();
  }

  /// 若当前为非播放页，启动后台延迟释放计时器
  ///
  /// 在每个控制器初始化成功出口处统一调用，确保无论 controller 在什么时机
  /// 完成初始化（含 isCurrentPage 已变 false 的异步竞态情况），都能及时释放。
  /// 已有计时器时先取消，保证幂等。

  // 释放当前 controller 的资源
  // 始终 dispose 而非归还池，避免外部 listener（VideoPageItem 的 _onVideoChanged）
  // 残留在归还池的 controller 上，复用时触发陈旧 listener 导致状态错乱

  // 释放旧 controller 并用新 widget.item 重新初始化

  // 统一的控制器变化监听器（命名方法，便于 dispose 显式移除）
  // 处理：错误状态标记、位置变化（跨秒更新字幕）

  // 初始化视频控制器
  // 优先级：优先使用 widget.preloadedController（已预加载的），否则动态构造
  // 错误处理策略：
  //   1. 任何异常都降级到缩略图展示（不崩溃）
  //   2. 检查 mounted 避免在已释放的 widget 上 setState
  //   3. 控制器引用仅在本类内部使用，外部通过 onControllerReady 获取

  // 外部控制 API：播放（三引擎同步）
  @override
  void play() {
    try {
      _controller?.play();
      _mpvKey.currentState?.play();
      _vlcKey.currentState?.play();
    } catch (e) {
      AppLogger.debug('play error', data: {'error': e.toString()});
    }
  }

  // 外部控制 API：暂停（三引擎同步）
  @override
  void pause() {
    try {
      _controller?.pause();
      _mpvKey.currentState?.pause();
      _vlcKey.currentState?.pause();
    } catch (e) {
      AppLogger.debug('pause error', data: {'error': e.toString()});
    }
  }

  // 外部控制 API：跳转（三引擎同步）
  @override
  Future<void> seekTo(Duration position) async {
    try {
      await _controller?.seekTo(position);
      _mpvKey.currentState?.seekTo(position);
      _vlcKey.currentState?.seekTo(position);
    } catch (e) {
      AppLogger.debug('seekTo error', data: {'error': e.toString()});
    }
  }

  /// 统一获取当前播放位置（ExoPlayer 或 MPV/VLC 均支持）
  Duration get currentPosition {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      return c.value.position;
    }
    // MPV/VLC 分支：onPositionChanged 回调写入 _positionMs
    return Duration(milliseconds: _positionMs.value);
  }

  /// 统一获取视频总时长
  Duration get totalDuration {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      return c.value.duration;
    }
    // MPV 分支：从 GlobalKey 读取
    final mpvDur = _mpvKey.currentState?.duration;
    if (mpvDur != null && mpvDur > Duration.zero) return mpvDur;
    // VLC 分支：从 GlobalKey 读取
    final vlcDur = _vlcKey.currentState?.duration;
    if (vlcDur != null && vlcDur > Duration.zero) return vlcDur;
    return Duration.zero;
  }

  /// 统一获取是否正在播放
  bool get isPlaying {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      return c.value.isPlaying;
    }
    return _mpvKey.currentState?.isPlaying ??
        _vlcKey.currentState?.isPlaying ??
        false;
  }

  // 从 Emby 服务器同步的续播位置 seek 到对应进度
  // 在 _initVideo() 中 play 之前调用，避免竞态条件

  // 外部控制 API：设置倍速（三引擎同步）
  @override
  Future<void> setRate(double rate) async {
    try {
      await _controller?.setPlaybackSpeed(rate);
      _mpvKey.currentState?.setRate(rate);
      _vlcKey.currentState?.setSpeed(rate);
    } catch (e) {
      AppLogger.debug('setRate error', data: {'error': e.toString()});
    }
  }

  // 外部控制 API：设置音量 0.0 ~ 1.0（三引擎同步）
  @override
  void setVolume(double value) {
    try {
      _controller?.setVolume(value);
      _mpvKey.currentState?.setVolume(value);
      _vlcKey.currentState?.setVolume(value);
    } catch (e) {
      AppLogger.debug('setVolume error', data: {'error': e.toString()});
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    // 注销统一控制句柄（避免横屏持有已 dispose 的 State）
    try {
      ref.read(currentPlayerControlProvider.notifier).state = null;
    } catch (_) {}
    _backgroundReleaseTimer?.cancel();
    _positionMs.dispose();
    _subtitleSubscription?.close();
    _audioTrackSubscription?.close();
    // 先停后释放，给底层 MediaCodec 留出缓冲时间
    _releaseCurrentController();
    super.dispose();
  }

  // 音轨切换：记录当前播放位置，释放旧 controller，用新 URL 重建后 seek 回原位置
  Future<void> _reinitForAudioTrackSwitch() async {
    if (_isDisposed) return;
    // 递增令牌：快速连续切换音轨时取消上一次未完成的初始化
    final token = ++_reinitToken;
    // 记录当前位置
    final currentPos = _controller?.value.position ?? Duration.zero;
    AppLogger.debug('音轨切换，重建播放器', data: {
      'itemId': widget.item.id,
      'positionMs': currentPos.inMilliseconds,
      'audioIndex': ref.read(selectedAudioStreamIndexProvider),
    });
    // 释放旧 controller
    _releaseCurrentController();
    if (!mounted || _isDisposed || _reinitToken != token) return;
    // 标记预加载 controller 已使用（不使用预加载，因为它带的是原始 URL）
    _preloadedControllerUsed = true;
    setState(() {
      _initialized = false;
      _hasError = false;
    });
    // 用新 URL 初始化（传入 token 实现竞态保护）
    await _initVideo(token: token);
    // seek 回原位置（仅当令牌仍有效时）
    if (_reinitToken != token || _isDisposed) return;
    if (_controller != null && mounted) {
      try {
        await _controller!.seekTo(currentPos);
        if (widget.isCurrentPage) await _controller!.play();
      } catch (e) {
        AppLogger.debug('音轨切换后 seek 失败', data: {'error': e.toString()});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 多播放器 PRD：根据用户设置和视频元数据选择渲染引擎
    // - mpv：强制使用 libmpv
    // - vlc：强制使用 libvlc（网络流兼容性兜底）
    // - auto：杜比 Vision/HDR10 内容自动用 MPV，其余用 ExoPlayer
    // - exo：强制 ExoPlayer
    // 多引擎自动降级策略：
    // - 用户选择 MPV 或 auto 触发 MPV 时，MPV 报错自动降级到 EXO
    // - EXO 报错自动降级到 VLC
    // - VLC 仍失败则显示错误提示
    final engineSettings = ref.watch(playerEngineSettingsProvider);
    final fitMode = ref.watch(videoFitModeProvider);
    final isFullscreen = ref.watch(isFullscreenProvider);
    // 根据用户设置的缩放模式映射到 BoxFit
    // 自适应（fit）模式：智能根据屏幕方向 + 视频方向选择最佳显示
    //   - 横屏全屏：contain（电影完整显示，不裁剪）
    //   - 竖屏 feed：竖屏视频 cover（TikTok 风格铺满），横屏视频 contain（黑边）
    // 固定比例（16:9 / 4:3）模式下，内部视频强制 contain，外层用 AspectRatio 限制显示区域
    final isLandscapeVideo = widget.item.isLandscape;
    final boxFit = switch (fitMode) {
      VideoFitMode.fit => isFullscreen
          ? BoxFit.contain
          : (isLandscapeVideo ? BoxFit.contain : BoxFit.cover),
      VideoFitMode.fill => BoxFit.cover,
      VideoFitMode.stretch => BoxFit.fill,
      VideoFitMode.sixteenNine => BoxFit.contain,
      VideoFitMode.fourThree => BoxFit.contain,
    };
    // 固定比例辅助：非空时用 Center + AspectRatio 包裹播放器
    double? fixedAspectRatio = switch (fitMode) {
      VideoFitMode.sixteenNine => 16 / 9,
      VideoFitMode.fourThree => 4 / 3,
      _ => null,
    };
    Widget wrapFixedRatio(Widget child) {
      if (fixedAspectRatio == null) return child;
      return Center(
        child: AspectRatio(aspectRatio: fixedAspectRatio!, child: child),
      );
    }
    // 有效引擎：优先使用降级后的引擎，否则用用户设置
    final effectiveEngine = _fallbackEngine ?? engineSettings.defaultEngine;
    final useMpv = effectiveEngine == PlayerEngine.mpv ||
        (effectiveEngine == PlayerEngine.auto &&
            (widget.item.isDolbyVision || widget.item.isHdr));
    if (useMpv) {
      final mpvUrl = _playbackUrl;
      if (mpvUrl == null || mpvUrl.isEmpty) {
        return _buildThumbnailPlaceholder(context);
      }
      return wrapFixedRatio(MpvVideoPlayer(
        key: _mpvKey,
        url: mpvUrl,
        // 本地文件不传 Emby 认证头；WebDAV 等网络源合并 extraHttpHeaders
        httpHeaders: widget.isLocal
            ? {...widget.extraHttpHeaders}
            : (widget.token != null
                ? {
                    'X-Emby-Token': widget.token!,
                    'Accept': 'video/*',
                    ...widget.extraHttpHeaders,
                  }
                : {'Accept': 'video/*', ...widget.extraHttpHeaders}),
        autoPlay: widget.autoPlay,
        muted: !widget.isCurrentPage,
        isCurrentPage: widget.isCurrentPage,
        hwDec: engineSettings.mpvHwDec,
        cacheSizeMb: engineSettings.mpvCacheSizeMb,
        forceAssStyle: engineSettings.mpvForceAssStyle,
        fit: boxFit,
        externalSubtitlePaths: widget.externalSubtitlePaths,
        onPositionChanged: (pos) {
          // 同步 MPV 播放位置到外层进度条
          _positionMs.value = pos.inMilliseconds;
        },
        onError: (msg) => retryInitialization(),
        onPlaybackEnded: () {
          widget.onPlaybackEnded?.call();
        },
      ));
    }

    // VLC 引擎分支：libvlc，网络流兼容性兜底
    if (effectiveEngine == PlayerEngine.vlc) {
      final vlcUrl = _playbackUrl;
      if (vlcUrl == null || vlcUrl.isEmpty) {
        return _buildThumbnailPlaceholder(context);
      }
      return wrapFixedRatio(VlcVideoPlayer(
        key: _vlcKey,
        url: vlcUrl,
        // 本地文件不传 Emby 认证头；WebDAV 等网络源合并 extraHttpHeaders
        httpHeaders: widget.isLocal
            ? {...widget.extraHttpHeaders}
            : (widget.token != null
                ? {
                    'X-Emby-Token': widget.token!,
                    'Accept': 'video/*',
                    ...widget.extraHttpHeaders,
                  }
                : {'Accept': 'video/*', ...widget.extraHttpHeaders}),
        autoPlay: widget.autoPlay,
        muted: !widget.isCurrentPage,
        isCurrentPage: widget.isCurrentPage,
        fit: switch (fitMode) {
          VideoFitMode.fit => isFullscreen
              ? VlcVideoFit.contain
              : (isLandscapeVideo ? VlcVideoFit.contain : VlcVideoFit.cover),
          VideoFitMode.fill => VlcVideoFit.cover,
          VideoFitMode.stretch => VlcVideoFit.fill,
          VideoFitMode.sixteenNine => VlcVideoFit.contain,
          VideoFitMode.fourThree => VlcVideoFit.contain,
        },
        onPositionChanged: (pos) {
          // 同步 VLC 播放位置到外层进度条
          _positionMs.value = pos.inMilliseconds;
        },
        onError: (e) => retryInitialization(),
        externalSubtitlePaths: widget.externalSubtitlePaths,
      ));
    }

    final vc = _controller;

    // 场景 1：无法播放视频，显示缩略图占位
    if (!_canPlayVideo) {
      return wrapFixedRatio(_buildThumbnailPlaceholder(context));
    }

    // 场景 2：视频正在初始化，显示加载指示器
    if (vc == null || !_initialized) {
      return wrapFixedRatio(Center(
        child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary),
      ));
    }

    // 场景 3：正常播放视频（带字幕叠加）
    // BoxFit 策略：
    //   - 竖屏视频：cover（填满容器，TikTok 风格）
    //   - 横屏视频：contain（完整显示，上下黑边，避免裁剪）
    final isLandscape = widget.item.isLandscape;
    // 视频尺寸：使用 controller.value.size，若为空则使用 1x1 占位（避免 VideoPlayer 首次构建时尺寸为0导致渲染异常）
    final videoSize = vc.value.size;
    final hasValidSize = !videoSize.isEmpty;
    // 记录尺寸是否曾为空，用于尺寸更新时触发重建以隐藏加载指示器
    if (!hasValidSize) {
      _sizeWasEmpty = true;
    }
    // 监听选中的字幕轨道 ID，变化时异步加载
    final selectedSubId = ref.watch(selectedSubtitleProvider);
    // isFullscreen 已在上方 boxFit 计算处 watch，此处复用，避免重复 watch
    // 当前实际显示的字幕（优先用异步加载的 _subtitleCues，否则用 item 自带的）
    final displayCues = _subtitleCues.isNotEmpty
        ? _subtitleCues
        : (widget.item.subtitleCues ?? const <SubtitleCue>[]);
    return wrapFixedRatio(SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: FittedBox(
              fit: boxFit,
              child: SizedBox(
                width: hasValidSize ? videoSize.width : 1,
                height: hasValidSize ? videoSize.height : 1,
                child: VideoPlayer(vc),
              ),
            ),
          ),
          // 视频尺寸为空时显示加载指示器（视频仍在后台初始化）
          if (!hasValidSize)
            Center(
              child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary),
            ),
          if (displayCues.isNotEmpty && selectedSubId != null && !isFullscreen)
            RepaintBoundary(
              child: ValueListenableBuilder<int>(
                valueListenable: _positionMs,
                builder: (_, ms, __) {
                  return SubtitleRenderer(
                    position: Duration(milliseconds: ms),
                    cues: displayCues,
                    enabled: true,
                  );
                },
              ),
            ),
        ],
      ),
    ));
  }

  // 根据 selectedSubtitleProvider 的最新值异步加载字幕

  // 自动加载默认字幕轨道（controller 就绪后调用）
  // 策略：优先匹配用户偏好语言，匹配失败选 isDefault 或第一个

  // 应用初始音量：根据 isMutedProvider、autoPlay 和 isCurrentPage 决定音量
  // 预加载池中的 controller 默认 volume=0，取出播放时需要恢复
  // 非当前页始终静音，避免并发播放时双音

  // 根据 isCurrentPage 状态同步播放/暂停和音量

  // 缩略图占位：web 环境或无播放地址时使用

  // === 播放控制与初始化（原 video_player_controls.dart）===
  void _scheduleBackgroundReleaseIfNeeded() {
    if (widget.isCurrentPage || _isDisposed) return;
    _backgroundReleaseTimer?.cancel();
    // 快速滑动中：立即释放，防止累积多个 controller 导致 OOM
    if (ref.read(isPageScrollingProvider)) {
      _releaseCurrentController();
      return;
    }
    _backgroundReleaseTimer =
        Timer(VideoPlayerWidgetState._backgroundReleaseDelay, () {
      if (_isDisposed || !mounted) return;
      if (!widget.isCurrentPage && _controller != null) {
        AppLogger.debug('非当前页初始化完成后超时，释放 controller 资源',
            data: {'itemId': widget.item.id});
        _releaseCurrentController();
        if (mounted) {
          setState(() {
            _initialized = false;
          });
        }
      }
    });
  }

  void _releaseCurrentController() {
    final c = _controller;
    if (c != null) {
      try {
        c.removeListener(_onControllerChanged);
      } catch (_) {
        // 资源释放失败不影响主流程，静默处理
      }
      try {
        c.pause();
      } catch (_) {
        // 资源释放失败不影响主流程，静默处理
      }
      try {
        c.dispose();
      } catch (_) {
        // 资源释放失败不影响主流程，静默处理
      }
    }
    _controller = null;
    _sizeWasEmpty = false;
    widget.onControllerReleased?.call();
  }

  Future<void> _reinitForNewItem() async {
    if (_isDisposed) return;
    final token = ++_reinitToken;
    // 取消所有待执行的计时器
    _backgroundReleaseTimer?.cancel();
    // 释放旧 controller
    _releaseCurrentController();
    // 重置状态
    if (!mounted || _isDisposed) return;
    if (_reinitToken != token) return;
    // item 切换时重置预加载标记，允许使用新 item 的预加载 controller
    _preloadedControllerUsed = false;
    // 视频切换时清空本地字幕轨道（本地字幕是针对特定视频的）
    ref.read(localSubtitleTracksProvider.notifier).clear();
    setState(() {
      _initialized = false;
      _hasError = false;
      _errorMessage = null;
      _autoRetryCount = 0; // 重试成功后重置计数
      _subtitleCues = const <SubtitleCue>[]; // 清空旧字幕，避免新视频初始时显示旧字幕
    });
    // 重新初始化
    if (_canPlayVideo) {
      await _initVideo(token: token);
    } else if (mounted && !_isDisposed) {
      setState(() {
        _hasError = true;
        _errorMessage = AppError.notFound(message: '无法获取播放地址');
      });
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final controller = _controller;
    if (controller == null) return;
    // 错误处理：标记错误状态
    if (controller.value.hasError && !_hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = AppError.playback(message: '播放出错');
      });
      // 断网自动恢复：5 秒后自动重试一次，最多重试 2 次
      _autoRetryCount++;
      if (_autoRetryCount <= 2) {
        AppLogger.info('播放出错，5 秒后自动重试', data: {'retry': _autoRetryCount});
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && !_isDisposed && _hasError) {
            retryInitialization();
          }
        });
      }
    }
    // 位置变化：更新字幕
    final ms = controller.value.position.inMilliseconds;
    if ((ms - _positionMs.value).abs() >= 50) {
      _positionMs.value = ms;
    }
    // 视频尺寸从 Size.zero 变为有效尺寸时，触发重建以隐藏加载指示器
    if (controller.value.isInitialized &&
        !controller.value.size.isEmpty &&
        _sizeWasEmpty) {
      _sizeWasEmpty = false;
      setState(() {});
    }
  }

  Future<void> _initVideo({int token = 0}) async {
    if (_isDisposed) return;

    bool isCancelled() => _reinitToken != token || _isDisposed;
    // 播放前预检：检测网络连接状态
    try {
      final result = await Connectivity().checkConnectivity();
      if (result == ConnectivityResult.none) {
        if (isCancelled()) return;
        setState(() {
          _hasError = true;
          _errorMessage = AppError.network(message: '无网络连接，请检查网络设置');
        });
        return;
      }
    } catch (_) {
      // 网络检测失败不阻断播放，继续尝试
    }
    // 同步当前 item.id，供 didUpdateWidget 后续对比
    _currentItemId = widget.item.id;

    // ---- 路径 1：有预加载控制器 ----
    // 由于 widget.preloadedController 是字段，Dart 流分析不会对其判空后续访问做类型提升。
    // 解决方式：在 if 块内用本地 lambda 包装，让 preloaded 作为非空参数传入，
    // lambda 内部对 c 即为非空 VideoPlayerController，可正常调用方法。
    final preloaded = widget.preloadedController;
    bool preloadedInitSucceeded = false;
    // 关键修复：如果预加载 controller 已被使用过（可能已被 dispose），
    // 不再重复使用，直接走动态创建路径。
    // 场景：非当前页 controller 被 _backgroundReleaseTimer 释放后，
    // 用户滑回该页面，didUpdateWidget 重新调用 _initVideo()，
    // 此时 widget.preloadedController 指向的 controller 已被 dispose，
    // 重复使用会导致 play/seek 等操作静默失败，视频无法播放。
    if (preloaded != null && !_preloadedControllerUsed) {
      _preloadedControllerUsed = true;
      // IIFE：把非空参数传入，函数体内 Dart 会把形参 c 视为非空
      Future<void> usePreloaded(VideoPlayerController c) async {
        _controller = c;
        c.addListener(_onControllerChanged);
        if (!c.value.isInitialized) {
          await c.initialize().timeout(
                const Duration(seconds: 15),
                onTimeout: () => throw TimeoutException('视频初始化超时'),
              );
        }
        if (isCancelled()) {
          try {
            c.dispose();
          } catch (_) {
            // 资源释放失败不影响主流程，静默处理
          }
          return;
        }
        if (_isDisposed) {
          try {
            c.dispose();
          } catch (_) {
            // 资源释放失败不影响主流程，静默处理
          }
          return;
        }
        c.setLooping(widget.loop);
        if (mounted && !_isDisposed) {
          // 修复：先 play 再 setState，确保 VideoPlayer 构建时 controller 已在播放
          // 原顺序：setState → onControllerReady → seek → play
          //   导致 VideoPlayer 首次构建时 controller 未播放，纹理不初始化，画面黑屏
          _applyInitialVolume(c);
          _autoLoadDefaultSubtitle();
          // 续播位置 seek：在 play 之前执行，避免与 autoPlay 产生竞态条件
          await _seekToResumePosition();
          if (isCancelled()) {
            try {
              c.dispose();
            } catch (_) {
              // 资源释放失败不影响主流程，静默处理
            }
            return;
          }
          // 根据是否当前页决定播放/暂停（非当前页静音暂停，避免并发播放）
          _syncPlaybackState(c);
          if (mounted && !_isDisposed) {
            setState(() {
              _initialized = true;
              _hasError = false;
            });
            widget.onControllerReady?.call(c);
            // 修复：init 完成时若已是非当前页（init 期间页面切走的竞态），
            // 立即调度释放计时器，防止 controller 永久驻留
            _scheduleBackgroundReleaseIfNeeded();
          }
        }
      }

      try {
        await usePreloaded(preloaded);
        if (isCancelled()) return;
        if (!_isDisposed) {
          preloadedInitSucceeded = true;
        }
      } catch (e) {
        AppLogger.debug('VideoPlayer preloaded init error，回退到动态创建',
            data: {'error': e.toString()});
        // 预加载失败：清理可能已被赋值的 _controller 后回退到动态创建
        _releaseCurrentController();
      }
    }
    if (preloadedInitSucceeded) return;
    if (_isDisposed) return;

    // ---- 路径 0：本地文件（isLocal）直接用 VideoPlayerController.file ----
    // 本地模式不走 Emby URL 降级链；playbackUrl 形如 file:///storage/.../xxx.mp4
    if (widget.isLocal) {
      final url = _playbackUrl;
      if (url == null || url.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage = AppError.playback(message: '无法获取本地文件路径');
        });
        return;
      }
      try {
        final uri = Uri.parse(url);
        // file:// URI 转 File；同时兼容直接传绝对路径
        final file = uri.scheme == 'file'
            ? File(uri.toFilePath())
            : File(url);
        final c = VideoPlayerController.file(file);
        _controller = c;
        c.addListener(_onControllerChanged);
        await c.initialize().timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException('本地视频初始化超时'),
        );
        if (isCancelled() || _isDisposed) {
          try { c.dispose(); } catch (_) {}
          return;
        }
        c.setLooping(widget.loop);
        _applyInitialVolume(c);
        if (mounted && !_isDisposed) {
          setState(() {
            _initialized = true;
            _hasError = false;
          });
          if (widget.autoPlay) await c.play();
          widget.onControllerReady?.call(c);
        }
        return;
      } catch (e) {
        AppLogger.warn('本地视频 EXO 初始化失败', data: {'error': '$e'});
        // 本地文件 EXO 失败不降级到网络 URL；让上层引擎选择（MPV/VLC 兜底）
        if (mounted && !_isDisposed) {
          setState(() {
            _hasError = true;
            _errorMessage = AppError.playback(message: '本地视频播放失败：$e');
          });
        }
        return;
      }
    }

    // ---- 路径 2：动态创建控制器（含 DirectPlay → DirectStream → HLS 降级链）----
    // OOM 防护：PageView 缓存的相邻页面若也创建控制器，每个 1080p 控制器
    // 解码缓冲区约 30-50MB，快速滑动时 3-5 个控制器同时存在可导致 OOM。
    // 非当前页跳过动态创建，仅在 isCurrentPage 变为 true 时由 didUpdateWidget 触发创建。
    if (!widget.isCurrentPage) {
      AppLogger.debug('非当前页跳过动态创建控制器，仅显示缩略图', data: {'itemId': widget.item.id});
      return;
    }

    // 降级链：DirectPlay → DirectStream → HLS（与 VideoPoolService.preload 一致）。
    // 部分视频 DirectPlay 编码/封装 ExoPlayer 不兼容（HEVC 10bit、特殊音轨等），
    // 直接失败会导致"播放异常"，降级到转码流可显著提升播放成功率。
    //
    // 杜比视界内容：EXO 不支持 DV Profile 7 解码，直接从 HLS 转码开始，
    // 避免先黑屏再降级的用户体验问题。
    final playSessionId = 'emb-dyn-${DateTime.now().microsecondsSinceEpoch}';
    final isDv = widget.item.isDolbyVision;
    final urls = <int, String?>{
      0: isDv
          ? null
          : _playbackUrl,
      1: isDv
          ? null
          : widget.item.computeDirectStreamUrl(widget.embyServerUrl, widget.token),
      2: widget.item.computeHlsUrl(widget.embyServerUrl, widget.token,
          playSessionId: playSessionId),
    };
    if (isDv) {
      AppLogger.info('杜比视界内容，直接使用HLS转码播放',
          data: {'itemId': widget.item.id});
    }

    for (int level = 0; level < 3; level++) {
      final url = urls[level];
      if (url == null || url.isEmpty) continue;
      final headers = {
        ...widget.item.authHeaders(widget.token),
        ...widget.extraHttpHeaders,
      };

      VideoPlayerController? c;
      try {
        c = VideoPlayerController.networkUrl(
          Uri.parse(url),
          httpHeaders: headers,
        );
        _controller = c;

        c.addListener(_onControllerChanged);

        c.setLooping(widget.loop);
        await c.initialize().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException('视频初始化超时');
          },
        );
        if (isCancelled()) {
          try {
            c.dispose();
          } catch (_) {
            // 资源释放失败不影响主流程，静默处理
          }
          return;
        }
        if (_isDisposed) {
          try {
            c.dispose();
          } catch (_) {
            // 资源释放失败不影响主流程，静默处理
          }
          return;
        }
        if (mounted && !_isDisposed) {
          // 修复：先 play 再 setState，确保 VideoPlayer 构建时 controller 已在播放
          _applyInitialVolume(c);
          // 应用用户上次保存的播放速度
          final savedSpeed = ref.read(defaultPlaybackRateProvider);
          if (savedSpeed != 1.0) {
            c.setPlaybackSpeed(savedSpeed);
          }
          _autoLoadDefaultSubtitle();
          // 续播位置 seek：在 play 之前执行，避免与 autoPlay 产生竞态条件
          await _seekToResumePosition();
          if (isCancelled()) {
            try {
              c.dispose();
            } catch (_) {
              // 资源释放失败不影响主流程，静默处理
            }
            return;
          }
          // 根据是否当前页决定播放/暂停（非当前页静音暂停，避免并发播放）
          _syncPlaybackState(c);
          if (mounted && !_isDisposed) {
            setState(() {
              _initialized = true;
              _hasError = false;
            });
            widget.onControllerReady?.call(c);
            // 修复：init 完成时若已是非当前页（init 期间页面切走的竞态），
            // 立即调度释放计时器，防止 controller 永久驻留
            _scheduleBackgroundReleaseIfNeeded();
          }
        }
        return; // 当前级别成功，降级链结束
      } catch (e) {
        AppLogger.debug('VideoPlayer dynamic init failed, 尝试降级',
            data: {'level': level, 'error': e.toString()});
        // 清理当前失败的 controller，继续下一级降级
        if (c != null) {
          try {
            c.removeListener(_onControllerChanged);
          } catch (_) {
            // 资源释放失败不影响主流程，静默处理
          }
          try {
            c.dispose();
          } catch (_) {
            // 资源释放失败不影响主流程，静默处理
          }
        }
        _controller = null;
      }
    }

    // 三级全部失败：显示错误状态（不崩溃）
    if (_isDisposed) return;
    if (mounted && !_isDisposed) {
      setState(() {
        _initialized = false;
        _hasError = true;
        _errorMessage = AppError.playback(message: '视频加载失败');
      });
    }
  }

  Future<void> _seekToResumePosition() async {
    if (!widget.startFromResumePosition) return;
    final c = _controller;
    if (c == null) return;
    final posTicks = widget.item.userData?.playbackPositionTicks ?? 0.0;
    if (posTicks <= 0.0) return;
    final posMs = (posTicks / 10000.0).round();
    if (posMs <= 0) return;
    try {
      await c.seekTo(Duration(milliseconds: posMs));
      AppLogger.debug('续播 seek', data: {'positionMs': posMs});
    } catch (e) {
      AppLogger.debug('续播 seek 失败', data: {'error': e.toString()});
    }
  }

  Future<void> _loadSubtitle(String? selectedTrackId) async {
    AppLogger.debug('字幕加载请求', data: {
      'itemId': widget.item.id,
      'selectedTrackId': selectedTrackId,
    });
    if (!mounted) return;
    if (selectedTrackId == null) {
      AppLogger.debug('字幕：关闭字幕');
      setState(() {
        _subtitleCues = const <SubtitleCue>[];
      });
      return;
    }

    // 先从本地字幕轨道中查找
    final localTracks = ref.read(localSubtitleTracksProvider);
    SubtitleTrack? selectedTrack;
    int? trackIndex;
    bool isLocal = false;

    for (final track in localTracks) {
      if (track.id == selectedTrackId) {
        selectedTrack = track;
        isLocal = true;
        break;
      }
    }

    // 本地没找到，再从服务器字幕轨道中查找
    if (selectedTrack == null) {
      final tracks = widget.item.subtitleTracks;
      AppLogger.debug('字幕轨道列表（服务器）', data: {
        'tracksCount': tracks.length,
        'tracks': tracks
            .map((t) => '${t.id}:${t.language}:${t.displayName}')
            .toList(),
      });
      for (int i = 0; i < tracks.length; i++) {
        if (tracks[i].id == selectedTrackId) {
          selectedTrack = tracks[i];
          // 轨道 ID 格式为 "sourceId:index"，解析出 index
          final parts = tracks[i].id.split(':');
          if (parts.length == 2) {
            trackIndex = int.tryParse(parts[1]);
          } else {
            trackIndex = int.tryParse(tracks[i].id);
          }
          break;
        }
      }
    }

    if (selectedTrack == null) {
      AppLogger.warn('字幕加载失败：找不到匹配的字幕轨道', data: {
        'itemId': widget.item.id,
        'selectedTrackId': selectedTrackId,
      });
      // 清空旧字幕，避免显示上一个视频的残留字幕
      if (mounted && !_isDisposed) {
        setState(() {
          _subtitleCues = const <SubtitleCue>[];
        });
      }
      return;
    }

    // 服务器字幕需要 mediaSourceId
    String? mediaSourceId;
    if (!isLocal) {
      // 从轨道 ID "sourceId:index" 中解析出 mediaSourceId
      final idParts = selectedTrack.id.split(':');
      if (idParts.length == 2) {
        mediaSourceId = idParts[0];
      } else {
        final sources = widget.item.mediaSources;
        mediaSourceId =
            (sources != null && sources.isNotEmpty) ? sources.first.id : null;
      }
      if (mediaSourceId == null || mediaSourceId.isEmpty) {
        AppLogger.warn('字幕加载失败：无有效 mediaSourceId', data: {
          'itemId': widget.item.id,
          'selectedTrackId': selectedTrack.id,
        });
        if (mounted && !_isDisposed) {
          setState(() {
            _subtitleCues = const <SubtitleCue>[];
          });
        }
        return;
      }
      if (trackIndex == null) {
        AppLogger.warn('字幕加载失败：无效的轨道索引', data: {
          'itemId': widget.item.id,
          'selectedTrackId': selectedTrackId,
        });
        if (mounted && !_isDisposed) {
          setState(() {
            _subtitleCues = const <SubtitleCue>[];
          });
        }
        return;
      }
    }

    AppLogger.debug('开始加载字幕', data: {
      'itemId': widget.item.id,
      'mediaSourceId': mediaSourceId,
      'trackIndex': trackIndex,
      'format': selectedTrack.format,
      'language': selectedTrack.language,
      'isLocal': isLocal,
    });

    final embService = ref.read(embytokServiceProvider);
    // 注入当前认证信息（确保字幕请求头包含 Token）
    final authState = ref.read(authProvider);
    final serverUrl = authState.embyServerUrl;
    final token = authState.token;
    if (serverUrl != null && token != null) {
      embService.setupAuth(
        embyServerUrl: serverUrl,
        apiKey: token,
        userId: authState.user?.id,
      );
    }
    try {
      List<SubtitleCue> cues;
      // 本地外挂字幕：从文件读取
      if (isLocal &&
          selectedTrack.localFilePath != null &&
          selectedTrack.localFilePath!.isNotEmpty) {
        cues = await embService.getSubtitleCuesFromFile(
          filePath: selectedTrack.localFilePath!,
          format: selectedTrack.format,
        );
      } else {
        // 服务器字幕：按轨道的原始格式请求，保留原生样式（ASS/VTT 等）
        // 外挂字幕直接用 DeliveryUrl，内嵌字幕走标准流端点
        cues = await embService.getSubtitleCues(
          itemId: widget.item.id,
          mediaSourceId: mediaSourceId!,
          index: trackIndex!,
          format: selectedTrack.format,
          directUrl: selectedTrack.url,
        );
      }
      AppLogger.debug('字幕加载完成', data: {
        'itemId': widget.item.id,
        'trackIndex': trackIndex,
        'format': selectedTrack.format,
        'isLocal': selectedTrack.localFilePath != null,
        'cuesCount': cues.length,
      });
      // 双重检查：避免 dispose 后 setState
      if (mounted && !_isDisposed) {
        setState(() {
          _subtitleCues = cues;
        });
      }
    } catch (e) {
      // 字幕加载失败不影响播放，记录详细日志
      AppLogger.warn('字幕加载异常', data: {
        'itemId': widget.item.id,
        'mediaSourceId': mediaSourceId,
        'trackIndex': trackIndex,
        'error': e.toString(),
      });
      if (mounted && !_isDisposed) {
        setState(() {
          _subtitleCues = const <SubtitleCue>[];
        });
      }
    }
  }

  void _autoLoadDefaultSubtitle() {
    final tracks = widget.item.subtitleTracks;
    if (tracks.isEmpty) {
      ref.read(selectedSubtitleProvider.notifier).state = null;
      return;
    }
    final settings = ref.read(subtitleSettingsProvider);
    SubtitleTrack? matchedTrack;

    // 用户有偏好语言时，优先匹配
    if (settings.language.isNotEmpty) {
      final preferred = _normalizeLang(settings.language);
      // 精确匹配 + 规范化匹配（chi/zho/zh 视为中文）
      matchedTrack = tracks.firstWhere(
        (t) =>
            t.language.toLowerCase() == settings.language.toLowerCase() ||
            _normalizeLang(t.language) == preferred,
        orElse: () => tracks.first,
      );
      // firstWhere 的 orElse 会返回 first，但需要验证是否真的匹配到了
      if (_normalizeLang(matchedTrack.language) != preferred) {
        matchedTrack = null;
      }
    }

    // 未匹配到偏好语言，选默认或第一个
    matchedTrack ??= tracks.firstWhere(
      (t) => t.isDefault,
      orElse: () => tracks.first,
    );

    ref.read(selectedSubtitleProvider.notifier).state = matchedTrack.id;
    // 直接加载字幕，不依赖 ref.listen（避免时序竞态）
    _loadSubtitle(matchedTrack.id);
  }

  /// 规范化语言代码，使不同写法能匹配到同一语言
  /// 例如 chi/zho/zh → zh, eng/english → en
  static String _normalizeLang(String code) {
    final c = code.toLowerCase().trim();
    const aliases = {
      'chi': 'zh',
      'zho': 'zh',
      'cn': 'zh',
      'chs': 'zh',
      'cht': 'zh',
      'eng': 'en',
      'english': 'en',
      'jpn': 'ja',
      'jp': 'ja',
      'kor': 'ko',
      'kr': 'ko',
      'fre': 'fr',
      'fra': 'fr',
      'french': 'fr',
      'ger': 'de',
      'deu': 'de',
      'german': 'de',
      'spa': 'es',
      'esp': 'es',
      'por': 'pt',
      'rus': 'ru',
    };
    return aliases[c] ?? c;
  }

  void _applyInitialVolume(VideoPlayerController c) {
    final isMuted = ref.read(isMutedProvider);
    try {
      if (!widget.isCurrentPage) {
        c.setVolume(0.0);
        return;
      }
      // 非自动播放场景默认有声；自动播放场景根据静音开关决定
      final shouldMute = widget.autoPlay && isMuted;
      c.setVolume(shouldMute ? 0.0 : 1.0);
    } catch (e) {
      // controller 可能已释放或异常，静默处理避免中断初始化流程
      AppLogger.warn('设置初始音量失败', data: {'error': e.toString()});
    }
  }

  void _syncPlaybackState(VideoPlayerController c) {
    if (!c.value.isInitialized) return;
    if (widget.isCurrentPage) {
      _applyInitialVolume(c);
      if (widget.autoPlay) {
        try {
          c.play();
        } catch (_) {
          // 资源释放失败不影响主流程，静默处理
        }
      }
    } else {
      try {
        c.pause();
      } catch (_) {
        // 资源释放失败不影响主流程，静默处理
      }
      try {
        c.setVolume(0.0);
      } catch (_) {
        // 资源释放失败不影响主流程，静默处理
      }
    }
  }

  Widget _buildThumbnailPlaceholder(BuildContext context) {
    // 根据屏幕像素密度动态计算缓存宽度，避免解码过大图片浪费内存
    final mq = MediaQuery.of(context);
    final cacheWidth =
        (mq.size.width * mq.devicePixelRatio).round().clamp(400, 1080);

    // 优先使用带认证信息的缩略图 URL，maxWidth 与 memCacheWidth 对齐，
    // 让服务端也缩放到对应尺寸，减少网络传输量
    final url = widget.item.thumbnailUrlWithAuth(
      widget.embyServerUrl,
      widget.token,
      maxWidth: cacheWidth,
    );
    // 获取认证头用于图片请求
    final headers = widget.item.authHeaders(widget.token);
    final scheme = Theme.of(context).colorScheme;
    final errMsg = _errorMessage;
    // 根据错误类型选择图标：网络类用 wifi_off，播放类用 error_outline
    final errorIcon = switch (errMsg?.type) {
      ErrorType.network || ErrorType.timeout => Icons.wifi_off_outlined,
      ErrorType.notFound => Icons.movie_filter_outlined,
      ErrorType.playback => Icons.error_outline,
      _ => Icons.movie_outlined,
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null && url.isNotEmpty)
          CachedNetworkImage(
            imageUrl: url,
            cacheManager: AppImageCacheManager.thumbnail,
            fit: BoxFit.cover,
            httpHeaders: headers.isNotEmpty ? headers : null,
            memCacheWidth: cacheWidth,
            placeholder: (_, __) => Container(
              color: scheme.surface.withValues(alpha: 0.3),
              child: Center(
                child: CircularProgressIndicator(
                    color: scheme.primary, strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: scheme.surface.withValues(alpha: 0.3),
              child: Center(
                child: Icon(Icons.broken_image,
                    size: 64, color: scheme.onSurface.withValues(alpha: 0.4)),
              ),
            ),
          )
        else
          Container(
            color: scheme.surface.withValues(alpha: 0.3),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    errorIcon,
                    size: 64,
                    color: _hasError
                        ? scheme.error.withValues(alpha: 0.7)
                        : scheme.onSurface.withValues(alpha: 0.4),
                  ),
                  if (_hasError && errMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errMsg.message,
                      style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    // 可重试错误显示重试按钮
                    if (errMsg.isRetryable) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: retryInitialization,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('重试', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 播放失败时建议用外部播放器（VLC/MX Player）兜底
                      TextButton.icon(
                        onPressed: () =>
                            _playWithExternalPlayerFromError(context),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('用外部播放器打开',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        // web 环境或无法播放时的播放图标占位
        if (kIsWeb || !_canPlayVideo)
          Center(
            child: Icon(
              Icons.play_circle_fill,
              size: 96,
              color: scheme.onSurface.withValues(alpha: 0.7),
              shadows: [
                Shadow(
                  color: scheme.surface.withValues(alpha: 0.54),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
      ],
    );
  }

}
