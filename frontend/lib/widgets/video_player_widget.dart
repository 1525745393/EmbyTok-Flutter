// 视频播放器 Widget：仅使用 Direct Play 模式

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/image_cache_manager.dart';
import '../utils/logger.dart';
import 'subtitle_renderer.dart';

// 视频播放器：优先使用 preloadedController（已预加载），否则动态构造
// 设计：preloadedController 用于快速切换场景，避免每次重新初始化
// 仅使用 Direct Play 模式
class VideoPlayerWidget extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<VideoPlayerWidget> createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  // 错误信息统一使用 AppError，便于按类型展示和区分重试按钮
  AppError? _errorMessage;
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
  // 内存压力释放：收到系统内存警告时立即释放非当前页 controller
  static const Duration _backgroundReleaseDelay = Duration(seconds: 2);
  // 字幕选择变化监听订阅（在 initState 中注册，dispose 时关闭）
  ProviderSubscription<String?>? _subtitleSubscription;

  // 获取播放 URL：优先使用 item.playbackUrl，否则尝试动态构造
  String? get _playbackUrl {
    // 优先使用预置的 playbackUrl
    final url = widget.item.playbackUrl;
    if (url != null && url.isNotEmpty) {
      return url;
    }
    // 尝试动态构造 Emby 视频流 URL
    return widget.item.computePlaybackUrl(widget.embyServerUrl, widget.token);
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
    // 监听字幕选择变化：用户选择新字幕轨道时异步加载
    // 必须在 initState 中通过 listenManual 注册，不能在 build 中，
    // 否则会因 build 时序问题导致选择事件被遗漏
    _subtitleSubscription = ref.listenManual<String?>(selectedSubtitleProvider, (previous, next) {
      if (next != previous) {
        _loadSubtitle(next);
      }
    });
    if (_canPlayVideo) {
      _initVideo();
    }
  }

  // 跟踪当前 widget.item.id，用于检测 item 切换
  String? _currentItemId;

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
        // 非当前页：启动延迟释放计时器。
        // 关键修复：不再以 c.value.isInitialized 为前提条件——
        // 若此时 controller 仍在初始化中（c==null 或未 initialized），
        // 旧逻辑会跳过计时器，导致 init 完成后 controller 永久驻留不释放（OOM 根因）。
        _backgroundReleaseTimer?.cancel();
        _backgroundReleaseTimer = Timer(_backgroundReleaseDelay, () {
          if (_isDisposed || !mounted) return;
          if (!widget.isCurrentPage && _controller != null) {
            AppLogger.debug('非当前页超时，释放 controller 资源', data: {'itemId': widget.item.id});
            _releaseCurrentController();
            if (mounted) {
              setState(() {
                _initialized = false;
              });
            }
          }
        });
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
  void _scheduleBackgroundReleaseIfNeeded() {
    if (widget.isCurrentPage || _isDisposed) return;
    _backgroundReleaseTimer?.cancel();
    _backgroundReleaseTimer = Timer(_backgroundReleaseDelay, () {
      if (_isDisposed || !mounted) return;
      if (!widget.isCurrentPage && _controller != null) {
        AppLogger.debug('非当前页初始化完成后超时，释放 controller 资源',
            data: {'itemId': widget.item.id});
        _releaseCurrentController();
        if (mounted) setState(() { _initialized = false; });
      }
    });
  }

  // 释放当前 controller 的资源
  // 始终 dispose 而非归还池，避免外部 listener（VideoPageItem 的 _onVideoChanged）
  // 残留在归还池的 controller 上，复用时触发陈旧 listener 导致状态错乱
  void _releaseCurrentController() {
    final c = _controller;
    if (c != null) {
      try { c.removeListener(_onControllerChanged); } catch (_) {}
      try { c.pause(); } catch (_) {}
      try { c.dispose(); } catch (_) {}
    }
    _controller = null;
    _sizeWasEmpty = false;
    widget.onControllerReleased?.call();
  }

  // 释放旧 controller 并用新 widget.item 重新初始化
  Future<void> _reinitForNewItem() async {
    if (_isDisposed) return;
    // 取消所有待执行的计时器
    _backgroundReleaseTimer?.cancel();
    // 释放旧 controller
    _releaseCurrentController();
    // 重置状态
    if (!mounted || _isDisposed) return;
    // item 切换时重置预加载标记，允许使用新 item 的预加载 controller
    _preloadedControllerUsed = false;
    setState(() {
      _initialized = false;
      _hasError = false;
      _errorMessage = null;
      _subtitleCues = const <SubtitleCue>[]; // 清空旧字幕，避免新视频初始时显示旧字幕
    });
    // 重新初始化
    if (_canPlayVideo) {
      await _initVideo();
    } else if (mounted && !_isDisposed) {
      setState(() {
        _hasError = true;
        _errorMessage = AppError.notFound(message: '无法获取播放地址');
      });
    }
  }

  // 统一的控制器变化监听器（命名方法，便于 dispose 显式移除）
  // 处理：错误状态标记、位置变化（跨秒更新字幕）
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

  // 初始化视频控制器
  // 优先级：优先使用 widget.preloadedController（已预加载的），否则动态构造
  // 错误处理策略：
  //   1. 任何异常都降级到缩略图展示（不崩溃）
  //   2. 检查 mounted 避免在已释放的 widget 上 setState
  //   3. 控制器引用仅在本类内部使用，外部通过 onControllerReady 获取
  Future<void> _initVideo() async {
    if (_isDisposed) return;
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
        if (_isDisposed) {
          try { c.dispose(); } catch (_) {}
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
        if (!_isDisposed) {
          preloadedInitSucceeded = true;
        }
      } catch (e) {
        AppLogger.debug('VideoPlayer preloaded init error，回退到动态创建', data: {'error': e.toString()});
        // 预加载失败：清理可能已被赋值的 _controller 后回退到动态创建
        _releaseCurrentController();
      }
    }
    if (preloadedInitSucceeded) return;
    if (_isDisposed) return;

    // ---- 路径 2：动态创建控制器（仅使用 Direct Play） ----
    final url = _playbackUrl;
    if (url == null) {
      if (mounted && !_isDisposed) {
        setState(() {
          _hasError = true;
          _errorMessage = AppError.notFound(message: '无法获取播放地址');
        });
      }
      return;
    }

    try {
      final headers = widget.item.authHeaders(widget.token);

      final c = VideoPlayerController.networkUrl(
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
      if (_isDisposed) {
        try { c.dispose(); } catch (_) {}
        return;
      }
      if (mounted && !_isDisposed) {
        // 修复：先 play 再 setState，确保 VideoPlayer 构建时 controller 已在播放
        _applyInitialVolume(c);
        _autoLoadDefaultSubtitle();
        // 续播位置 seek：在 play 之前执行，避免与 autoPlay 产生竞态条件
        await _seekToResumePosition();
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
    } catch (e) {
      AppLogger.debug('VideoPlayer initialization error', data: {'error': e.toString()});
      if (_isDisposed) return;
      if (mounted && !_isDisposed) {
        setState(() {
          _initialized = false;
          _hasError = true;
          _errorMessage = AppError.playback(message: '视频加载失败');
        });
      }
    }
  }

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

  // 从 Emby 服务器同步的续播位置 seek 到对应进度
  // 在 _initVideo() 中 play 之前调用，避免竞态条件
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
    // 先停后释放，给底层 MediaCodec 留出缓冲时间
    _releaseCurrentController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vc = _controller;

    // 场景 1：无法播放视频，显示缩略图占位
    if (!_canPlayVideo) {
      return _buildThumbnailPlaceholder(context);
    }

    // 场景 2：视频正在初始化，显示加载指示器
    if (vc == null || !_initialized) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
      );
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
    final isFullscreen = ref.watch(isFullscreenProvider);
    // 当前实际显示的字幕（优先用异步加载的 _subtitleCues，否则用 item 自带的）
    final displayCues = _subtitleCues.isNotEmpty
        ? _subtitleCues
        : (widget.item.subtitleCues ?? const <SubtitleCue>[]);
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: FittedBox(
              fit: isLandscape ? BoxFit.contain : BoxFit.cover,
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
              child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
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
    );
  }

  // 根据 selectedSubtitleProvider 的最新值异步加载字幕
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
    final sources = widget.item.mediaSources;
    final mediaSourceId =
        (sources != null && sources.isNotEmpty)
            ? sources.first.id
            : null;
    if (mediaSourceId == null || mediaSourceId.isEmpty) {
      AppLogger.warn('字幕加载失败：无有效 mediaSourceId', data: {
        'itemId': widget.item.id,
        'sourcesCount': sources?.length ?? 0,
      });
      return;
    }
    // 从 item 的 subtitleTracks 中找到对应 track
    final tracks = widget.item.subtitleTracks;
    AppLogger.debug('字幕轨道列表', data: {
      'tracksCount': tracks.length,
      'tracks': tracks.map((t) => '${t.id}:${t.language}:${t.displayName}').toList(),
    });
    SubtitleTrack? selectedTrack;
    int? trackIndex;
    for (int i = 0; i < tracks.length; i++) {
      if (tracks[i].id == selectedTrackId) {
        selectedTrack = tracks[i];
        // track.id 本身就是 stream.index 的字符串形式，直接解析
        trackIndex = int.tryParse(tracks[i].id);
        break;
      }
    }
    // 如果没找到匹配的 track，尝试直接解析 selectedTrackId 作为索引
    trackIndex ??= int.tryParse(selectedTrackId);
    if (trackIndex == null || selectedTrack == null) {
      AppLogger.warn('字幕加载失败：找不到匹配的字幕轨道', data: {
        'itemId': widget.item.id,
        'selectedTrackId': selectedTrackId,
        'availableTrackIds': tracks.map((t) => t.id).toList(),
      });
      return;
    }

    AppLogger.debug('开始加载字幕', data: {
      'itemId': widget.item.id,
      'mediaSourceId': mediaSourceId,
      'trackIndex': trackIndex,
      'format': selectedTrack.format,
      'language': selectedTrack.language,
    });

    final embService = ref.read(embbytokServiceProvider);
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
      // Emby 字幕 API 支持通过 format 参数请求输出格式，统一请求 srt
      final cues = await embService.getSubtitleCues(
        itemId: widget.item.id,
        mediaSourceId: mediaSourceId,
        index: trackIndex,
      );
      AppLogger.debug('字幕加载完成', data: {
        'itemId': widget.item.id,
        'trackIndex': trackIndex,
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

  // 自动加载默认字幕轨道（controller 就绪后调用）
  // 策略：优先匹配用户偏好语言，匹配失败选 isDefault 或第一个
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
      // 精确匹配语言代码
      matchedTrack = tracks.firstWhere(
        (t) => t.language.toLowerCase() == settings.language.toLowerCase(),
        orElse: () => tracks.first,
      );
      // firstWhere 的 orElse 会返回 first，但需要验证是否真的匹配到了
      if (matchedTrack.language.toLowerCase() != settings.language.toLowerCase()) {
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

  // 应用初始音量：根据 isMutedProvider、autoPlay 和 isCurrentPage 决定音量
  // 预加载池中的 controller 默认 volume=0，取出播放时需要恢复
  // 非当前页始终静音，避免并发播放时双音
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

  // 根据 isCurrentPage 状态同步播放/暂停和音量
  void _syncPlaybackState(VideoPlayerController c) {
    if (!c.value.isInitialized) return;
    if (widget.isCurrentPage) {
      _applyInitialVolume(c);
      if (widget.autoPlay) {
        try { c.play(); } catch (_) {}
      }
    } else {
      try { c.pause(); } catch (_) {}
      try { c.setVolume(0.0); } catch (_) {}
    }
  }

  // 缩略图占位：web 环境或无播放地址时使用
  Widget _buildThumbnailPlaceholder(BuildContext context) {
    // 根据屏幕像素密度动态计算缓存宽度，避免解码过大图片浪费内存
    final mq = MediaQuery.of(context);
    final cacheWidth =
        (mq.size.width * mq.devicePixelRatio).round().clamp(400, 1080);

    // 优先使用带认证信息的缩略图 URL，maxWidth 与 memCacheWidth 对齐，
    // 让服务端也缩放到对应尺寸，减少网络传输量
    final url = widget.item.thumbnailUrlWithAuth(
      widget.embyServerUrl, widget.token,
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
              color: scheme.surface.withOpacity(0.3),
              child: Center(
                child: CircularProgressIndicator(color: scheme.primary, strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: scheme.surface.withOpacity(0.3),
              child: Center(
                child: Icon(Icons.broken_image, size: 64, color: scheme.onSurface.withOpacity(0.4)),
              ),
            ),
          )
        else
          Container(
            color: scheme.surface.withOpacity(0.3),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    errorIcon,
                    size: 64,
                    color: _hasError
                        ? scheme.error.withOpacity(0.7)
                        : scheme.onSurface.withOpacity(0.4),
                  ),
                  if (_hasError && errMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errMsg.message,
                      style: TextStyle(color: scheme.onSurface.withOpacity(0.5), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    // 可重试错误显示重试按钮
                    if (errMsg.isRetryable) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: retryInitialization,
                        icon: Icon(Icons.refresh, size: 16),
                        label: const Text('重试', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
              color: scheme.onSurface.withOpacity(0.7),
              shadows: [
                Shadow(
                  color: scheme.surface.withOpacity(0.54),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
