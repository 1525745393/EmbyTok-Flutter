// 视频播放器 Widget：仅使用 Direct Play 模式

import 'dart:async';

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
part 'video_player_parts/video_player_controls.dart';

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
  });
  final MediaItem item;
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

class VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  // 错误信息统一使用 AppError，便于按类型展示和区分重试按钮
  AppError? _errorMessage;
  // 自动降级：记录当前是否已降级到备用引擎
  // MPV 失败 → 自动切 EXO；EXO 失败 → 自动切 VLC；VLC 失败 → 报错
  PlayerEngine? _fallbackEngine;
  // MPV 模式下的播放器 state 引用（统一位置/时长/播放状态接口）
  dynamic _mpvState;
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
    // 优先使用预置的 playbackUrl
    var url = widget.item.playbackUrl;
    if (url == null || url.isEmpty) {
      // 尝试动态构造 Emby 视频流 URL
      url = widget.item.computePlaybackUrl(widget.embyServerUrl, widget.token);
    }
    if (url == null || url.isEmpty) return null;
    // 追加音轨参数（用户选择非默认音轨时）
    final audioIndex = ref.read(selectedAudioStreamIndexProvider);
    if (audioIndex != null) {
      final sep = url.contains('?') ? '&' : '?';
      url = '$url${sep}AudioStreamIndex=$audioIndex';
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
    if (!mounted) return;
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

  // 外部控制 API：播放
  void play() {
    try {
      _controller?.play();
    } catch (e) {
      AppLogger.debug('play error', data: {'error': e.toString()});
    }
  }

  // 外部控制 API：暂停
  void pause() {
    try {
      _controller?.pause();
    } catch (e) {
      AppLogger.debug('pause error', data: {'error': e.toString()});
    }
  }

  // 外部控制 API：跳转（内部由手势层调用）
  Future<void> seekTo(Duration position) async {
    try {
      await _controller?.seekTo(position);
    } catch (e) {
      AppLogger.debug('seekTo error', data: {'error': e.toString()});
    }
  }

  /// 统一获取当前播放位置（ExoPlayer 或 MPV 均支持）
  Duration get currentPosition {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      return c.value.position;
    }
    return _mpvState?.position ?? Duration.zero;
  }

  /// 统一获取视频总时长
  Duration get totalDuration {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      return c.value.duration;
    }
    return _mpvState?.duration ?? Duration.zero;
  }

  /// 统一获取是否正在播放
  bool get isPlaying {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      return c.value.isPlaying;
    }
    return _mpvState?.isPlaying ?? false;
  }

  // 从 Emby 服务器同步的续播位置 seek 到对应进度
  // 在 _initVideo() 中 play 之前调用，避免竞态条件

  // 外部控制 API：设置倍速
  Future<void> setRate(double rate) async {
    try {
      await _controller?.setPlaybackSpeed(rate);
    } catch (e) {
      AppLogger.debug('setRate error', data: {'error': e.toString()});
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
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
        key: ValueKey('mpv_${widget.item.id}'),
        url: mpvUrl,
        httpHeaders: widget.token != null
            ? {
                'X-Emby-Token': widget.token!,
                'Accept': 'video/*',
              }
            : const {'Accept': 'video/*'},
        autoPlay: widget.autoPlay,
        muted: !widget.isCurrentPage,
        isCurrentPage: widget.isCurrentPage,
        hwDec: engineSettings.mpvHwDec,
        cacheSizeMb: engineSettings.mpvCacheSizeMb,
        forceAssStyle: engineSettings.mpvForceAssStyle,
        fit: boxFit,
        onPositionChanged: (pos) {
          // 同步 MPV 播放位置到外层进度条
          _positionMs.value = pos.inMilliseconds;
        },
        onError: (msg) => retryInitialization(),
      ));
    }

    // VLC 引擎分支：libvlc，网络流兼容性兜底
    if (effectiveEngine == PlayerEngine.vlc) {
      final vlcUrl = _playbackUrl;
      if (vlcUrl == null || vlcUrl.isEmpty) {
        return _buildThumbnailPlaceholder(context);
      }
      return wrapFixedRatio(VlcVideoPlayer(
        key: ValueKey('vlc_${widget.item.id}'),
        url: vlcUrl,
        httpHeaders: widget.token != null
            ? {
                'X-Emby-Token': widget.token!,
                'Accept': 'video/*',
              }
            : const {'Accept': 'video/*'},
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
}
