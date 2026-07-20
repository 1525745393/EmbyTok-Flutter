// 视频播放器 Widget：支持三级播放降级链 + 运行时 error 自动降级

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
// 三级播放降级链：Direct Play(0) → Direct Stream(1) → HLS(2)
// - 初始化失败时自动尝试下一级
// - 运行时发生 error（如解码失败/网络中断）时也尝试降级
class VideoPlayerWidget extends ConsumerStatefulWidget {
  final MediaItem item;
  // Emby 服务器认证信息（用于动态构造播放 URL）
  final String? embyServerUrl;
  final String? token;
  // 预加载控制器（如果为 null，则动态创建）
  final VideoPlayerController? preloadedController;
  // 预加载控制器的播放等级（0=DirectPlay, 1=DirectStream, 2=HLS）
  // 如非空，将同步到 playbackLevelProvider，保证 Emby 上报一致
  final int? preloadedPlaybackLevel;
  // 控制回调：暴露给外部调用
  final void Function(VideoPlayerController controller)? onControllerReady;
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
    this.preloadedPlaybackLevel,
    this.onControllerReady,
    this.autoPlay = true,
    this.loop = true,
    this.startFromResumePosition = false,
    this.isCurrentPage = true,
  });

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  // 错误信息统一使用 AppError，便于按类型展示和区分重试按钮
  AppError? _errorMessage;
  // 使用 ValueNotifier 减少字幕重绘频率（只在跨秒时更新）
  final ValueNotifier<int> _positionSeconds = ValueNotifier<int>(0);
  // 异步加载的字幕 Cues（从 Emby 服务器获取）
  List<SubtitleCue> _subtitleCues = const <SubtitleCue>[];
  // 降级链等级：0=Direct Play, 1=Direct Stream, 2=HLS
  // 仅在动态创建路径（路径2）使用降级，预加载路径不降级
  int _fallbackLevel = 0;
  // 标记当前正在执行降级（避免 listener 与 initVideo 递归调用导致的重复降级）
  bool _isFallbackInProgress = false;
  // 标记是否正在执行用户发起的播放模式切换（区别于自动降级）
  bool _isUserSwitchInProgress = false;
  // 标记 widget 是否已 dispose，防止异步操作在 dispose 后继续执行
  bool _isDisposed = false;
  // 标记视频尺寸是否为空（初始化后 size 仍为 0 的边缘情况）
  bool _wasSizeEmpty = false;
  // 降级延迟计时器（网络错误时延迟重试，避免资源风暴）
  Timer? _fallbackTimer;
  // 非当前页延迟释放计时器（2秒后释放 controller 节省解码资源）
  // 缩短自 5 秒：平衡快速来回滑动的体验与内存占用
  Timer? _backgroundReleaseTimer;
  // 内存压力释放：收到系统内存警告时立即释放非当前页 controller
  static const Duration _backgroundReleaseDelay = Duration(seconds: 2);

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
          if (!widget.isCurrentPage && _controller != null && !_isFallbackInProgress && !_isUserSwitchInProgress) {
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
          _fallbackLevel = _initialFallbackLevel;
          _initVideo();
        }
      }
    }
  }

  /// 重试初始化：用户点击"重试"按钮时调用
  ///
  /// 清除错误状态并重新触发初始化流程
  void _retryInitialization() {
    if (_isDisposed || !mounted) return;
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _initialized = false;
      _fallbackLevel = _initialFallbackLevel;
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
      if (!widget.isCurrentPage && _controller != null && !_isFallbackInProgress && !_isUserSwitchInProgress) {
        AppLogger.debug('非当前页初始化完成后超时，释放 controller 资源',
            data: {'itemId': widget.item.id});
        _releaseCurrentController();
        if (mounted) setState(() { _initialized = false; });
      }
    });
  }

  // 释放当前 controller 的资源（统一方法，避免重复代码）
  void _releaseCurrentController() {
    final c = _controller;
    if (c != null) {
      try { c.removeListener(_onControllerChanged); } catch (_) {}
      try { c.pause(); } catch (_) {}
      // 智能释放：优先将会话归还到预加载池，供下次来回滑动复用
      // 条件：controller 已初始化且非错误状态（_hasError=false）
      // 若池拒绝接收（池满或已有同 item 会话），则直接 dispose
      // playSessionId 传空字符串：Emby 上报在 VideoPageItem 层维护独立
      // _playSessionId，归还池的会话仅用于复用 controller，不参与上报
      if (c.value.isInitialized && !_hasError) {
        final pool = ref.read(videoPoolProvider);
        // 仅当池中尚无该 item 的会话时才归还，避免覆盖预加载的会话
        if (!pool.hasSession(widget.item.id)) {
          try {
            pool.returnSession(PlaybackSession(
              itemId: widget.item.id,
              controller: c,
              playSessionId: '',
              playbackLevel: _fallbackLevel,
            ));
            _controller = null;
            return;
          } catch (_) {
            // 归还失败，回退到直接 dispose
          }
        }
      }
      try { c.dispose(); } catch (_) {}
    }
    _controller = null;
    _wasSizeEmpty = false;
  }

  // 释放旧 controller 并用新 widget.item 重新初始化
  Future<void> _reinitForNewItem() async {
    if (_isDisposed) return;
    // 取消所有待执行的计时器
    _fallbackTimer?.cancel();
    _backgroundReleaseTimer?.cancel();
    // 释放旧 controller
    _releaseCurrentController();
    // 重置状态
    if (!mounted || _isDisposed) return;
    setState(() {
      _initialized = false;
      _hasError = false;
      _errorMessage = null;
      _fallbackLevel = _initialFallbackLevel; // 从用户设置的默认画质开始
      _isFallbackInProgress = false;
      _isUserSwitchInProgress = false;
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
  // 处理：错误降级链触发、错误状态标记、位置变化（跨秒更新字幕）
  void _onControllerChanged() {
    if (!mounted) return;
    final controller = _controller;
    if (controller == null) return;
    // 错误处理：触发降级链或标记错误状态
    // 检查 _isUserSwitchInProgress：避免用户主动切换时旧 controller 错误事件触发自动降级
    if (controller.value.hasError &&
        !_hasError &&
        !_isFallbackInProgress &&
        !_isUserSwitchInProgress &&
        _fallbackLevel < 2 &&
        _autoFallbackEnabled) {
      _triggerRuntimeFallback();
      return;
    }
    // 降级进行中或用户切换中时，不标记错误状态，避免中间状态导致 UI 闪烁
    if (controller.value.hasError &&
        !_hasError &&
        !_isFallbackInProgress &&
        !_isUserSwitchInProgress) {
      setState(() {
        _hasError = true;
        _errorMessage = AppError.playback(message: '播放出错');
        _isFallbackInProgress = false;
      });
    }
    // 位置变化：更新字幕
    final sec = controller.value.position.inSeconds;
    if (sec != _positionSeconds.value) {
      _positionSeconds.value = sec;
    }
    // 视频尺寸从 Size.zero 变为有效尺寸时，需重建以从加载指示器切换到播放 UI
    if (controller.value.isInitialized &&
        !controller.value.size.isEmpty &&
        _wasSizeEmpty) {
      _wasSizeEmpty = false;
      setState(() {});
    }
  }

  // 根据画质字符串获取对应的降级等级
  int _qualityToLevel(String quality) {
    switch (quality) {
      case 'directStream':
        return 1;
      case 'hls':
        return 2;
      case 'original':
      default:
        return 0;
    }
  }

  // 获取当前默认画质对应的初始降级等级
  int get _initialFallbackLevel {
    final quality = ref.read(videoQualityProvider);
    return _qualityToLevel(quality);
  }

  // 判断是否启用自动降级
  bool get _autoFallbackEnabled {
    return ref.read(autoFallbackEnabledProvider);
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
    if (preloaded != null) {
      // IIFE：把非空参数传入，函数体内 Dart 会把形参 c 视为非空
      Future<void> usePreloaded(VideoPlayerController c) async {
        _controller = c;
        // 同步预加载时的播放等级，供播放上报 PlayMethod 一致
        final preloadLevel = widget.preloadedPlaybackLevel;
        if (preloadLevel != null) {
          _fallbackLevel = preloadLevel;
          ref.read(playbackLevelProvider.notifier).setLevel(_fallbackLevel);
        }
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
            setState(() {
              _initialized = true;
              _hasError = false;
            });
            _applyInitialVolume(c);
            widget.onControllerReady?.call(c);
            _autoLoadDefaultSubtitle();
            // 续播位置 seek：在 play 之前执行，避免与 autoPlay 产生竞态条件
            await _seekToResumePosition();
            // 根据是否当前页决定播放/暂停（非当前页静音暂停，避免并发播放）
            _syncPlaybackState(c);
            // 修复：init 完成时若已是非当前页（init 期间页面切走的竞态），
            // 立即调度释放计时器，防止 controller 永久驻留
            _scheduleBackgroundReleaseIfNeeded();
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
        // 重置降级级别，动态创建从用户设置的默认画质开始
        _fallbackLevel = _initialFallbackLevel;
      }
    }
    if (preloadedInitSucceeded) return;
    if (_isDisposed) return;

    // ---- 路径 2：动态创建控制器 ----
    final url = _getUrlForFallbackLevel(_fallbackLevel);
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

      // 监听器：运行时 error 触发降级链，否则仅标记错误状态
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
      // 初始化成功：同步降级等级到 provider（供播放上报判断 PlayMethod）
      ref.read(playbackLevelProvider.notifier).setLevel(_fallbackLevel);
      if (mounted && !_isDisposed) {
        setState(() {
          _initialized = true;
          _hasError = false;
        });
        _applyInitialVolume(c);
        widget.onControllerReady?.call(c);
        _autoLoadDefaultSubtitle();
        // 续播位置 seek：在 play 之前执行，避免与 autoPlay 产生竞态条件
        await _seekToResumePosition();
        // 根据是否当前页决定播放/暂停（非当前页静音暂停，避免并发播放）
        _syncPlaybackState(c);
        // 修复：init 完成时若已是非当前页（init 期间页面切走的竞态），
        // 立即调度释放计时器，防止 controller 永久驻留
        _scheduleBackgroundReleaseIfNeeded();
      }
    } catch (e) {
      AppLogger.debug('VideoPlayer initialization error', data: {'error': e.toString()});
      if (_isDisposed) return;
      // 防止与 listener 触发的降级竞态：listener 可能已开始降级流程
      if (_isFallbackInProgress) return;
      // 非当前页不做降级重试，直接显示错误占位（避免浪费带宽和解码资源）
      if (!widget.isCurrentPage) {
        if (mounted && !_isDisposed) {
          setState(() {
            _initialized = false;
            _hasError = true;
            _errorMessage = AppError.playback(message: '视频加载失败');
          });
        }
        return;
      }
      if (_fallbackLevel < 2 && _autoFallbackEnabled) {
        _isFallbackInProgress = true;
        _fallbackLevel++;
        AppLogger.debug('降级重试播放', data: {'level': _fallbackLevel});
        _releaseCurrentController();
        if (mounted && !_isDisposed) {
          // 添加短暂延迟避免快速递归造成资源风暴
          await Future<void>.delayed(const Duration(milliseconds: 50));
          _isFallbackInProgress = false;
          if (!_isDisposed && mounted) {
            await _initVideo();
          }
        }
        return;
      }
      // 三级降级都失败：标记最终错误状态
      ref.read(playbackLevelProvider.notifier).setLevel(2);
      if (mounted && !_isDisposed) {
        setState(() {
          _initialized = false;
          _hasError = true;
          _errorMessage = AppError.playback(message: '视频加载失败');
        });
      }
    }
  }

  // 运行时降级：初始化成功但播放过程中发生 error（解码失败、网络抖动等）
  Future<void> _triggerRuntimeFallback() async {
    if (_isDisposed) return;
    if (_isFallbackInProgress) return;
    if (_fallbackLevel >= 2) return;
    _isFallbackInProgress = true;

    // 记录当前播放进度，降级成功后 seek 回相同位置
    int positionSeconds = 0;
    try {
      final c = _controller;
      if (c != null && c.value.isInitialized) {
        positionSeconds = c.value.position.inSeconds;
      }
    } catch (_) {}

    final nextLevel = _fallbackLevel + 1;
    AppLogger.debug('运行时降级', data: {'from': _fallbackLevel, 'to': nextLevel, 'itemId': widget.item.id});

    // 释放当前失败的 controller
    _releaseCurrentController();
    _fallbackLevel = nextLevel;
    if (_isDisposed) return;

    final newUrl = _getUrlForFallbackLevel(_fallbackLevel);
    if (newUrl == null || newUrl.isEmpty) {
      if (mounted && !_isDisposed) {
        setState(() {
          _hasError = true;
          _errorMessage = AppError.notFound(message: '无法获取播放地址');
          _isFallbackInProgress = false;
        });
      }
      return;
    }

    try {
      final headers = widget.item.authHeaders(widget.token);
      final c = VideoPlayerController.networkUrl(
        Uri.parse(newUrl),
        httpHeaders: headers,
      );
      _controller = c;
      // 新 controller 也注册降级监听器（再失败则继续降级）
      c.addListener(_onControllerChanged);

      c.setLooping(widget.loop);
      await c.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('视频降级初始化超时'),
      );
      if (_isDisposed) {
        try { c.dispose(); } catch (_) {}
        return;
      }
      // 降级成功：同步新的降级等级
      ref.read(playbackLevelProvider.notifier).setLevel(_fallbackLevel);
      // seek 回到失败前的播放位置，减少用户感知
      if (positionSeconds > 0) {
        try {
          await c.seekTo(Duration(seconds: positionSeconds));
        } catch (_) {}
      }
      if (mounted && !_isDisposed) {
        setState(() {
          _initialized = true;
          _hasError = false;
          _isFallbackInProgress = false;
        });
        _applyInitialVolume(c);
        widget.onControllerReady?.call(c);
        _autoLoadDefaultSubtitle();
        _syncPlaybackState(c);
        // 修复：降级成功后若已非当前页，同样需要调度释放计时器
        _scheduleBackgroundReleaseIfNeeded();
      }
    } catch (e) {
      AppLogger.warn('运行时降级失败', data: {'error': e.toString()});
      if (_isDisposed) return;
      if (_fallbackLevel < 2 && _autoFallbackEnabled) {
        _isFallbackInProgress = false;
        // 添加延迟避免快速递归造成资源风暴，让出主线程
        _fallbackTimer?.cancel();
        _fallbackTimer = Timer(const Duration(milliseconds: 100), () {
          if (!_isDisposed && mounted && !_isFallbackInProgress) {
            _triggerRuntimeFallback();
          }
        });
      } else {
        ref.read(playbackLevelProvider.notifier).setLevel(2);
        if (mounted && !_isDisposed) {
          setState(() {
            _initialized = false;
            _hasError = true;
            _errorMessage = AppError.playback(message: '视频播放失败');
            _isFallbackInProgress = false;
          });
        }
      }
    }
  }

  // 用户手动切换播放模式（Direct/Transcode/Fbk）：用新的播放 URL 重新初始化播放器
  Future<void> _userInitiatedReinit(int newLevel) async {
    if (_isDisposed) return;
    if (_isUserSwitchInProgress) return;
    _isUserSwitchInProgress = true;
    // 取消待执行的计时器
    _fallbackTimer?.cancel();
    _backgroundReleaseTimer?.cancel();
    // 记录当前播放进度，切换成功后 seek 回相同位置
    int positionSeconds = 0;
    try {
      final c = _controller;
      if (c != null && c.value.isInitialized) {
        positionSeconds = c.value.position.inSeconds;
      }
    } catch (_) {}

    // 释放当前 controller
    _releaseCurrentController();
    _fallbackLevel = newLevel;
    if (_isDisposed) return;

    final newUrl = _getUrlForFallbackLevel(_fallbackLevel);
    if (newUrl == null || newUrl.isEmpty) {
      if (mounted && !_isDisposed) {
        setState(() {
          _hasError = true;
          _errorMessage = AppError.notFound(message: '无法获取播放地址');
          _isUserSwitchInProgress = false;
        });
      }
      return;
    }

    try {
      final headers = widget.item.authHeaders(widget.token);

      final c = VideoPlayerController.networkUrl(
        Uri.parse(newUrl),
        httpHeaders: headers,
      );
      _controller = c;
      c.addListener(_onControllerChanged);

      c.setLooping(widget.loop);
      await c.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('播放模式切换初始化超时');
        },
      );
      if (_isDisposed) {
        try { c.dispose(); } catch (_) {}
        return;
      }
      // 切换成功：同步新的降级等级
      ref.read(playbackLevelProvider.notifier).setLevel(_fallbackLevel);
      // seek 回到切换前的播放位置，减少用户感知
      if (positionSeconds > 0) {
        try {
          await c.seekTo(Duration(seconds: positionSeconds));
        } catch (_) {}
      }
      if (mounted && !_isDisposed) {
        setState(() {
          _initialized = true;
          _hasError = false;
          _isUserSwitchInProgress = false;
        });
        _applyInitialVolume(c);
        widget.onControllerReady?.call(c);
        _autoLoadDefaultSubtitle();
        _syncPlaybackState(c);
      }
    } catch (e) {
      AppLogger.warn('播放模式切换失败', data: {'error': e.toString()});
      if (mounted && !_isDisposed) {
        setState(() {
          _hasError = true;
          _errorMessage = AppError.playback(message: '切换失败');
          _isUserSwitchInProgress = false;
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
    _fallbackTimer?.cancel();
    _backgroundReleaseTimer?.cancel();
    _positionSeconds.dispose();
    // 先停后释放，给底层 MediaCodec 留出缓冲时间
    _releaseCurrentController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vc = _controller;
    // 监听播放模式切换（用户手动点击按钮触发）
    ref.listen<int>(playbackLevelProvider, (previous, next) {
      // 只有当外部设置等级变化后才响应；且非自己内部 setLevel 设置的不响应
      // 内部会在初始化/降级成功后调用 setLevel，那时 _fallbackLevel == next，所以相等，不触发
      // 用户点击按钮时，_fallbackLevel != next，触发重新初始化
      if (next != _fallbackLevel && _initialized && !_isFallbackInProgress) {
        _userInitiatedReinit(next);
      }
    });

    // 监听字幕选择：用户选择新字幕轨道时异步加载
    ref.listen<String?>(selectedSubtitleProvider, (previous, next) {
      if (next != previous) {
        _loadSubtitle(next);
      }
    });

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
    // 视频尺寸为 0 时（HLS 流初始化后偶现），渲染 SizedBox(0,0) 会导致黑屏
    // 此时显示加载指示器，等待 size 更新后再渲染
    final videoSize = vc.value.size;
    if (videoSize.isEmpty) {
      _wasSizeEmpty = true;
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
      );
    }
    // 监听选中的字幕轨道 ID，变化时异步加载
    final selectedSubId = ref.watch(selectedSubtitleProvider);
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
                width: videoSize.width,
                height: videoSize.height,
                child: VideoPlayer(vc),
              ),
            ),
          ),
          if (displayCues.isNotEmpty && selectedSubId != null)
            RepaintBoundary(
              child: ValueListenableBuilder<int>(
                valueListenable: _positionSeconds,
                builder: (_, seconds, __) {
                  return SubtitleRenderer(
                    position: Duration(seconds: seconds),
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
    if (!mounted) return;
    if (selectedTrackId == null) {
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
      return;
    }
    // 从 item 的 subtitleTracks 中找到对应 track 的 index
    final tracks = widget.item.subtitleTracks;
    int? trackIndex;
    for (int i = 0; i < tracks.length; i++) {
      if (tracks[i].id == selectedTrackId) {
        // track.id 本身就是 "N" 形式（例如 "0"/"1"），直接解析
        final maybeIndex = int.tryParse(tracks[i].id);
        if (maybeIndex != null) {
          trackIndex = maybeIndex;
          break;
        }
        // 否则退而求其次：用 i 作为轨道索引
        trackIndex = i;
        break;
      }
    }
    trackIndex ??= int.tryParse(selectedTrackId);
    if (trackIndex == null) return;

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
      final cues = await embService.getSubtitleCues(
        itemId: widget.item.id,
        mediaSourceId: mediaSourceId,
        index: trackIndex,
      );
      // 双重检查：避免 dispose 后 setState
      if (mounted && !_isDisposed) {
        setState(() {
          _subtitleCues = cues;
        });
      }
    } catch (e) {
      // 字幕加载失败不影响播放，仅记录日志
      AppLogger.warn('字幕加载失败', data: {
        'itemId': widget.item.id,
        'trackIndex': trackIndex,
        'error': e.toString(),
      });
    }
  }

  // 自动加载默认字幕轨道（controller 就绪后调用）
  // 策略：用户未手动选择时，自动选中 isDefault 或第一个字幕轨道
  void _autoLoadDefaultSubtitle() {
    final currentSelected = ref.read(selectedSubtitleProvider);
    // 用户已手动选择过，不自动覆盖
    if (currentSelected != null) return;
    final tracks = widget.item.subtitleTracks;
    if (tracks.isEmpty) return;
    // 优先选择 isDefault 的轨道，否则选第一个
    final defaultTrack = tracks.firstWhere(
      (t) => t.isDefault,
      orElse: () => tracks.first,
    );
    ref.read(selectedSubtitleProvider.notifier).state = defaultTrack.id;
    // _loadSubtitle 会通过 ref.listen 自动触发
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
                        onPressed: _retryInitialization,
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
