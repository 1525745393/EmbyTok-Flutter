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
  });

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  String? _errorMessage;
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
    if (newItemId == _currentItemId) return; // 同一个视频，不重置
    AppLogger.debug('VideoPlayerWidget item 切换，重建 controller', data: {
      'oldItemId': _currentItemId,
      'newItemId': newItemId,
    });
    _currentItemId = newItemId;
    // 异步释放 + 重新初始化（fire-and-forget）
    _reinitForNewItem();
  }

  // 释放旧 controller 并用新 widget.item 重新初始化
  Future<void> _reinitForNewItem() async {
    // 释放旧 controller
    final c = _controller;
    if (c != null) {
      try {
        c.removeListener(_onControllerChanged);
        await c.dispose();
      } catch (e) {
        // warn 没有 error 命名参数；改用 error 传递异常对象
        AppLogger.error('释放旧 controller 失败', error: e);
      }
      _controller = null;
    }
    // 重置状态
    if (!mounted) return;
    setState(() {
      _initialized = false;
      _hasError = false;
      _errorMessage = null;
      _fallbackLevel = 0; // 重新从最高级（DirectPlay）开始尝试
      _isFallbackInProgress = false;
      _isUserSwitchInProgress = false;
    });
    // 重新初始化
    if (_canPlayVideo) {
      await _initVideo();
    } else if (mounted) {
      setState(() {
        _hasError = true;
        _errorMessage = '无法获取播放地址';
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
    if (controller.value.hasError &&
        !_hasError &&
        !_isFallbackInProgress &&
        _fallbackLevel < 2) {
      _triggerRuntimeFallback();
      return;
    }
    if (controller.value.hasError && !_hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = '播放出错';
        _isFallbackInProgress = false;
      });
    }
    // 位置变化：更新字幕
    final sec = controller.value.position.inSeconds;
    if (sec != _positionSeconds.value) {
      _positionSeconds.value = sec;
    }
  }

  // 初始化视频控制器
  // 优先级：优先使用 widget.preloadedController（已预加载的），否则动态构造
  // 错误处理策略：
  //   1. 任何异常都降级到缩略图展示（不崩溃）
  //   2. 检查 mounted 避免在已释放的 widget 上 setState
  //   3. 控制器引用仅在本类内部使用，外部通过 onControllerReady 获取
  Future<void> _initVideo() async {
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
        c.setLooping(widget.loop);
        if (mounted) {
          setState(() {
            _initialized = true;
            _hasError = false;
          });
          widget.onControllerReady?.call(c);
          _autoLoadDefaultSubtitle();
          // 续播位置 seek：在 play 之前执行，避免与 autoPlay 产生竞态条件
          await _seekToResumePosition();
          if (widget.autoPlay) {
            try {
              await c.play();
            } catch (e) {
              debugPrint('autoPlay error: $e');
            }
          }
        }
      }

      try {
        await usePreloaded(preloaded);
        preloadedInitSucceeded = true;
      } catch (e) {
        debugPrint('VideoPlayer preloaded init error: $e，回退到动态创建');
        // 预加载失败：清理可能已被赋值的 _controller 后回退到动态创建
        try {
          await _controller?.dispose();
        } catch (_) {}
        _controller = null;
      }
    }
    if (preloadedInitSucceeded) return;

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
      // 初始化成功：同步降级等级到 provider（供播放上报判断 PlayMethod）
      ref.read(playbackLevelProvider.notifier).setLevel(_fallbackLevel);
      if (mounted) {
        setState(() {
          _initialized = true;
          _hasError = false;
        });
        widget.onControllerReady?.call(c);
        _autoLoadDefaultSubtitle();
        // 续播位置 seek：在 play 之前执行，避免与 autoPlay 产生竞态条件
        await _seekToResumePosition();
        if (widget.autoPlay) {
          try {
            await c.play();
          } catch (e) {
            debugPrint('autoPlay error: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('VideoPlayer initialization error: $e');
      if (_fallbackLevel < 2) {
        _fallbackLevel++;
        debugPrint('降级到 level $_fallbackLevel 重试播放');
        try {
          await _controller?.dispose();
        } catch (_) {}
        _controller = null;
        if (mounted) {
          await _initVideo();
        }
        return;
      }
      // 三级降级都失败：标记最终错误状态
      ref.read(playbackLevelProvider.notifier).setLevel(2);
      if (mounted) {
        setState(() {
          _initialized = false;
          _hasError = true;
          _errorMessage = '视频加载失败';
        });
      }
    }
  }

  // 运行时降级：初始化成功但播放过程中发生 error（解码失败、网络抖动等）
  Future<void> _triggerRuntimeFallback() async {
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
    debugPrint('运行时降级 $_fallbackLevel → $nextLevel (item=${widget.item.id})');

    // 释放当前失败的 controller
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _fallbackLevel = nextLevel;

    final newUrl = _getUrlForFallbackLevel(_fallbackLevel);
    if (newUrl == null || newUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '无法获取播放地址';
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
      // 降级成功：同步新的降级等级
      ref.read(playbackLevelProvider.notifier).setLevel(_fallbackLevel);
      // seek 回到失败前的播放位置，减少用户感知
      if (positionSeconds > 0) {
        try {
          await c.seekTo(Duration(seconds: positionSeconds));
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _initialized = true;
          _hasError = false;
          _isFallbackInProgress = false;
        });
        widget.onControllerReady?.call(c);
        _autoLoadDefaultSubtitle();
        if (widget.autoPlay) {
          try {
            await c.play();
          } catch (e) {
            debugPrint('fallback autoPlay error: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('运行时降级失败: $e');
      if (_fallbackLevel < 2) {
        _isFallbackInProgress = false;
        _triggerRuntimeFallback();
      } else {
        ref.read(playbackLevelProvider.notifier).setLevel(2);
        if (mounted) {
          setState(() {
            _initialized = false;
            _hasError = true;
            _errorMessage = '视频播放失败';
            _isFallbackInProgress = false;
          });
        }
      }
    }
  }

  // 用户手动切换播放模式（Direct/Transcode/Fbk）：用新的播放 URL 重新初始化播放器
  Future<void> _userInitiatedReinit(int newLevel) async {
    if (_isUserSwitchInProgress) return;
    _isUserSwitchInProgress = true;
    // 记录当前播放进度，切换成功后 seek 回相同位置
    int positionSeconds = 0;
    try {
      final c = _controller;
      if (c != null && c.value.isInitialized) {
        positionSeconds = c.value.position.inSeconds;
      }
    } catch (_) {}

    // 释放当前失败的 controller
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _fallbackLevel = newLevel;

    final newUrl = _getUrlForFallbackLevel(_fallbackLevel);
    if (newUrl == null || newUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '无法获取播放地址';
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
      // 切换成功：同步新的降级等级
      ref.read(playbackLevelProvider.notifier).setLevel(_fallbackLevel);
      // seek 回到切换前的播放位置，减少用户感知
      if (positionSeconds > 0) {
        try {
          await c.seekTo(Duration(seconds: positionSeconds));
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _initialized = true;
          _hasError = false;
          _isUserSwitchInProgress = false;
        });
        widget.onControllerReady?.call(c);
        _autoLoadDefaultSubtitle();
        if (widget.autoPlay) {
          try {
            await c.play();
          } catch (e) {
            debugPrint('playMode switch play error: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('播放模式切换失败: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '切换失败';
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
      debugPrint('续播 seek 到 ${posMs}ms');
    } catch (e) {
      debugPrint('续播 seek 失败: $e');
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
    _positionSeconds.dispose();
    // 显式移除命名 listener，保证监听器与控制器生命周期解耦
    _controller?.removeListener(_onControllerChanged);
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
          FittedBox(
            fit: isLandscape ? BoxFit.contain : BoxFit.cover,
            child: SizedBox(
              width: vc.value.size.width,
              height: vc.value.size.height,
              child: VideoPlayer(vc),
            ),
          ),
          if (displayCues.isNotEmpty && selectedSubId != null)
            ValueListenableBuilder<int>(
              valueListenable: _positionSeconds,
              builder: (_, seconds, __) {
                return SubtitleRenderer(
                  position: Duration(seconds: seconds),
                  cues: displayCues,
                  enabled: true,
                );
              },
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
    final cues = await embService.getSubtitleCues(
      itemId: widget.item.id,
      mediaSourceId: mediaSourceId,
      index: trackIndex,
    );
    if (mounted) {
      setState(() {
        _subtitleCues = cues;
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

  // 缩略图占位：web 环境或无播放地址时使用
  Widget _buildThumbnailPlaceholder(BuildContext context) {
    // 优先使用带认证信息的缩略图 URL
    final url = widget.item.thumbnailUrlWithAuth(widget.embyServerUrl, widget.token);
    // 获取认证头用于图片请求
    final headers = widget.item.authHeaders(widget.token);
    final scheme = Theme.of(context).colorScheme;
    final errMsg = _errorMessage;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null && url.isNotEmpty)
          CachedNetworkImage(
            imageUrl: url,
            cacheManager: AppImageCacheManager.thumbnail,
            fit: BoxFit.cover,
            httpHeaders: headers.isNotEmpty ? headers : null,
            memCacheWidth: 800,
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
                  Icon(Icons.movie_outlined, size: 64, color: scheme.onSurface.withOpacity(0.4)),
                  if (_hasError && errMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errMsg,
                      style: TextStyle(color: scheme.onSurface.withOpacity(0.5), fontSize: 12),
                    ),
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
