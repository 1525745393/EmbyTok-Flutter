// 视频流单页：全屏视频 + 右侧操作按钮 + 左下角标题信息
// 完整 Emby 播放上报链（reportCapabilities / reportPlaybackStart /
//       reportPlaybackPosition / reportPlaybackStopped）

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';
import '../services/video_pool_service.dart';
import '../utils/logger.dart';
import '../views/fullscreen_video_page.dart';
import 'gesture_overlay.dart';
import 'video_controls.dart';
import 'video_player_widget.dart';

// 拆分出的子组件
import 'video/video_action_button.dart';
import 'video/video_control_buttons.dart';
import 'video/video_progress_bars.dart';
import 'video/video_sheet_utils.dart' as sheet_utils;
import 'video/video_draggable_clean_actions.dart';

/// 单个视频页：TikTok 卡片样式
class VideoPageItem extends ConsumerStatefulWidget {
  final MediaItem item;
  final PlaybackSession? preloadedSession;
  final VoidCallback? onVideoEnded;
  final bool startFromResumePosition;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPrevEpisode;
  /// 数据源标识（用于观看统计）：nextUp/resume/suggestions/similar/feed
  final String source;
  /// 是否为当前可见页：非当前页初始化后静音暂停，避免相邻预加载页并发有声播放
  final bool isCurrentPage;

  const VideoPageItem({
    super.key,
    required this.item,
    this.preloadedSession,
    this.onVideoEnded,
    this.startFromResumePosition = false,
    this.onNextEpisode,
    this.onPrevEpisode,
    this.source = 'feed',
    this.isCurrentPage = true,
  });

  @override
  ConsumerState<VideoPageItem> createState() => _VideoPageItemState();
}

class _VideoPageItemState extends ConsumerState<VideoPageItem>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  bool _hasNotifiedEnded = false;
  // 播放停止上报是否已发送，防止 dispose 与结束回调重复上报导致重复会话
  bool _hasStoppedReported = false;
  // Provider 状态是否已清理（deactivate 幂等保护，避免多次调用重复清理）
  bool _providerCleaned = false;

  // 唱片式静音按钮动画控制器
  late final AnimationController _discRotationCtrl;
  late final Animation<double> _discRotation;

  // App 生命周期状态跟踪
  AppLifecycleState? _lastLifecycleState;
  // 记录进入后台前是否在播放，用于回到前台时恢复
  bool _wasPlayingBeforeBackground = false;

  // 底部信息条 3 秒自动隐藏
  Timer? _infoHideTimer;
  bool _isInfoVisible = true;

  // 播放上报相关
  final EmbytokService _service = EmbytokService();
  Timer? _progressTimer;
  String? _playSessionId;
  bool _hasStartedReported = false;
  bool _capabilitiesReported = false;
  DateTime _lastProgressReport = DateTime.fromMicrosecondsSinceEpoch(0);
  static const _progressReportMinSeconds = 4;

  // 底部信息面板展开/收起
  bool _isInfoExpanded = false;

  // 控制层（VideoControls）显示状态
  bool _controlsVisible = false;
  Timer? _controlsHideTimer;
  static const int _controlsAutoHideSeconds = 3;

  // NextUp（下一集提示）状态
  MediaItem? _nextUpItem;
  bool _showNextUpBanner = false;
  int _nextUpCountdown = 5;
  Timer? _nextUpTimer;
  static const int _nextUpCountdownSeconds = 5;

  // 功耗优化：上一次报告的播放位置秒数，用于跨秒节流 Provider 写入
  int _lastPositionSecond = -1;

  // 保存 listenManual 订阅引用，dispose 时显式 close 避免内存泄漏
  ProviderSubscription<bool>? _isPlayingSubscription;
  ProviderSubscription<bool>? _isAutoPlaySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastLifecycleState = WidgetsBinding.instance.lifecycleState;
    _discRotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _discRotation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _discRotationCtrl, curve: Curves.linear));

    // 监听播放状态变化（播放时旋转唱片，暂停时停止）
    // 放在 initState 中通过 listenManual 注册，避免每次 build 重复注册
    _isPlayingSubscription = ref.listenManual<bool>(isPlayingProvider, (previous, next) {
      if (next) {
        if (!_discRotationCtrl.isAnimating) _discRotationCtrl.repeat();
      } else {
        if (_discRotationCtrl.isAnimating) _discRotationCtrl.stop();
      }
    });

    // PR #72：监听纯净模式（isAutoPlay）变化，同步到工具栏可见性
    // - isAutoPlay=true → setAutoPlayActive(true)，顶部工具栏 + 底部导航栏持续隐藏
    // - isAutoPlay=false → setAutoPlayActive(false)，工具栏恢复显示（除非全屏引用计数>0）
    // fireImmediately: true 确保初始值同步（避免页面切换后纯净模式状态丢失）
    _isAutoPlaySubscription = ref.listenManual<bool>(isAutoPlayProvider, (prev, next) {
      ref.read(toolbarVisibilityProvider.notifier).setAutoPlayActive(next);
    }, fireImmediately: true);
  }

  // App 进入后台时暂停视频和唱片动画，回到前台时恢复
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final prev = _lastLifecycleState;
    _lastLifecycleState = state;
    if (prev == null) return;

    final wasForeground = prev == AppLifecycleState.resumed;
    final isForeground = state == AppLifecycleState.resumed;

    if (wasForeground && !isForeground) {
      _wasPlayingBeforeBackground = _videoController?.value.isPlaying ?? false;
      if (_videoController != null &&
          _videoController!.value.isInitialized &&
          _videoController!.value.isPlaying) {
        _videoController!.pause();
      }
      _discRotationCtrl.stop();
    } else if (!wasForeground && isForeground) {
      if (_wasPlayingBeforeBackground) {
        if (_videoController != null &&
            _videoController!.value.isInitialized &&
            !_videoController!.value.isPlaying) {
          _videoController!.play();
        }
        if (!_discRotationCtrl.isAnimating) {
          _discRotationCtrl.repeat();
        }
      }
    }
  }

  // ===== 底部信息条 3 秒自动隐藏 =====
  void _resetInfoHideTimer() {
    _infoHideTimer?.cancel();
    if (!mounted) return;
    setState(() => _isInfoVisible = true);
    final c = _videoController;
    final isPlaying = c != null && c.value.isInitialized && c.value.isPlaying;
    if (isPlaying) {
      _infoHideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isInfoVisible = false);
      });
    }
  }

  // 切换信息条显示（用于点击画面手动触发）
  void _toggleInfoBar() {
    _infoHideTimer?.cancel();
    if (!mounted) return;
    setState(() => _isInfoVisible = !_isInfoVisible);
    if (_isInfoVisible) {
      final c = _videoController;
      final isPlaying = c != null && c.value.isInitialized && c.value.isPlaying;
      if (isPlaying) {
        _infoHideTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isInfoVisible = false);
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant VideoPageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentPage && !oldWidget.isCurrentPage && _videoController != null) {
      // 由相邻预加载页变为当前页：补齐播放/进度上报（此前因非当前页被静音暂停）
      ref.read(currentVideoControllerProvider.notifier).state = _videoController;
      _startPlaybackIfCurrent();
    }
  }

  @override
  void deactivate() {
    // 在 deactivate 中清理 Provider 状态（而非 dispose），
    // 因为 riverpod 禁止在 dispose() 中使用 ref.read()。
    // deactivate 可能被多次调用（widget 从 tree 移除又重新插入），用 _providerCleaned 做幂等。
    if (!_providerCleaned) {
      _providerCleaned = true;
      ref.read(videoReadyProvider.notifier).clear(widget.item.id);
      final ctrl = ref.read(currentVideoControllerProvider);
      if (ctrl != null && identical(ctrl, _videoController)) {
        ref.read(currentVideoControllerProvider.notifier).state = null;
      }
    }
    super.deactivate();
  }

  @override
  void dispose() {
    // 显式取消 listenManual 订阅，避免内存泄漏
    _isPlayingSubscription?.close();
    _isAutoPlaySubscription?.close();
    WidgetsBinding.instance.removeObserver(this);
    _infoHideTimer?.cancel();
    _discRotationCtrl.dispose();
    _videoController?.removeListener(_onVideoChanged);
    _progressTimer?.cancel();
    _progressTimer = null;
    if (_hasStartedReported) _reportPlaybackStopped();
    _controlsHideTimer?.cancel();
    _nextUpTimer?.cancel();
    _nextUpTimer = null;
    // Provider 状态清理已移到 deactivate()，避免 riverpod 违规
    // 观看统计：记录本次观看的完播率
    _recordWatchStats();
    // ⚠️ _videoController 由内部 VideoPlayerWidget 负责 dispose，这里只清空引用
    _videoController = null;
    _capabilitiesReported = false;
    _hasStartedReported = false;
    _playSessionId = null;
    _hasNotifiedEnded = false;
    _hasStoppedReported = false;
    super.dispose();
  }

  // 仅当本页为当前可见页时启动播放上报与进度上报，
  // 避免相邻预加载页并发以有声方式播放并重复向 Emby 上报播放
  void _startPlaybackIfCurrent() {
    if (!widget.isCurrentPage) return;
    ref.read(isPlayingProvider.notifier).state = true;
    ref.read(currentPlayingItemProvider.notifier).state = widget.item;
    ref.read(currentVideoControllerProvider.notifier).state = _videoController;
    _resetInfoHideTimer();
    _ensureCapabilitiesReported();
    _reportPlaybackStart();
    _startProgressTimer();
  }

  /// 记录观看统计（完播率）
  void _recordWatchStats() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final position = controller.value.position;
    final duration = controller.value.duration;
    if (duration.inMilliseconds <= 0) return;
    final completionRate = position.inMilliseconds / duration.inMilliseconds;
    ref.read(watchStatsProvider.notifier).recordWatch(
          itemId: widget.item.id,
          itemType: widget.item.type,
          itemTitle: widget.item.title,
          completionRate: completionRate,
          source: widget.source,
        );
  }

  // ===== 视频状态变化监听 =====
  // 功耗优化：合并 _onVideoChangedForReport 逻辑，减少 controller listener 数量。
  // 位置写入 Provider 仅在跨秒时触发，避免每帧无效 Notifier 通知。
  void _onVideoChanged() {
    if (!mounted) return;
    final controller = _videoController;
    if (controller == null) return;
    // 播放状态：仅在变化时同步 Provider（避免每帧 setState 等效操作）
    final isPlaying = controller.value.isPlaying;
    if (ref.read(isPlayingProvider) != isPlaying) {
      ref.read(isPlayingProvider.notifier).state = isPlaying;
      // 播放状态变化时触发暂停上报（原 _onVideoChangedForReport 逻辑）
      if (!isPlaying) _reportPlaybackProgress(isPauseEvent: true);
    }
    // 位置：仅在跨秒时写入 Provider，减少级联重建
    final posSec = controller.value.position.inSeconds;
    if (posSec != _lastPositionSecond) {
      _lastPositionSecond = posSec;
      ref.read(currentPositionProvider.notifier).state =
          controller.value.position;
    }
    // 注意：不再在每帧里重置信息条隐藏计时器（原逻辑会导致隐藏 1 帧后又被重新显示，
    // 使“3 秒自动隐藏”永远不生效）。信息条的显隐由 _resetInfoHideTimer 在合适时机触发。
    if (!_hasNotifiedEnded) {
      final pos = controller.value.position;
      final dur = controller.value.duration;
      if (dur.inMilliseconds > 0 && (dur - pos).inMilliseconds < 1000) {
        _hasNotifiedEnded = true;
        _reportPlaybackStopped();
        _safeReport(
          () => _service.markAsPlayed(
            widget.item.id,
            serverUrl: _authServerUrl(),
            token: _authToken(),
          ),
          'markAsPlayed',
        );
        // 视频播完标记已看后，失效续播、详情、NextUp 和观看历史缓存
        // NextUp 列表在看完一集后会变化，必须失效避免下次看到旧数据
        // watchHistory 中已播放条目会更新，需失效以反映最新观看进度
        final serverUrl = _authServerUrl();
        final token = _authToken();
        if (serverUrl != null && token != null) {
          try {
            ref.read(cacheControllerProvider).invalidateResume(serverUrl, token);
            ref
                .read(cacheControllerProvider)
                .invalidateItemDetail(widget.item.id, serverUrl);
            ref.read(cacheControllerProvider).invalidateNextUp(serverUrl);
            ref.read(cacheControllerProvider).invalidateWatchHistory(serverUrl);
          } catch (_) {}
        }
        ref.read(videoListProvider.notifier).removePlayedItem(widget.item.id);
        _queryNextUp();
      }
    }
  }

  // ===== NextUp 下一集查询与倒计时 =====
  Future<void> _queryNextUp() async {
    final seriesId = widget.item.seriesId;
    final isEpisode = widget.item.type == 'Episode' ||
        (widget.item.seriesName != null && widget.item.seriesName!.isNotEmpty);
    if (!isEpisode) {
      _fallbackAutoPlay();
      return;
    }
    try {
      final resp = await _service.getNextUp(
        seriesId: seriesId,
        limit: 1,
        serverUrl: _authServerUrl(),
        token: _authToken(),
      );
      final candidates = resp.items.where((it) => it.id != widget.item.id).toList();
      if (mounted && candidates.isNotEmpty) {
        setState(() {
          _nextUpItem = candidates.first;
          _showNextUpBanner = true;
          _nextUpCountdown = _nextUpCountdownSeconds;
        });
        _startNextUpCountdown();
      } else if (mounted) {
        _fallbackAutoPlay();
      }
    } catch (_) {
      if (mounted) _fallbackAutoPlay();
    }
  }

  void _startNextUpCountdown() {
    _nextUpTimer?.cancel();
    _nextUpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _nextUpCountdown--);
      if (_nextUpCountdown <= 0) {
        timer.cancel();
        _playNextUp();
      }
    });
  }

  void _playNextUp() {
    _nextUpTimer?.cancel();
    if (!mounted) return;
    if (widget.onNextEpisode != null) {
      setState(() => _showNextUpBanner = false);
      widget.onNextEpisode!.call();
    } else {
      _fallbackAutoPlay();
    }
  }

  void _cancelNextUp() {
    _nextUpTimer?.cancel();
    if (!mounted) return;
    setState(() => _showNextUpBanner = false);
  }

  void _fallbackAutoPlay() {
    final autoPlay = ref.read(isAutoPlayProvider);
    if (autoPlay) widget.onVideoEnded?.call();
  }

  // ===== 播放上报链方法 =====
  String _newPlaySessionId() => 'emb-flutter-${DateTime.now().microsecondsSinceEpoch}';

  String _playMethodFromLevel(int level) => level >= 2 ? 'Transcode' : 'DirectPlay';

  void _ensureCapabilitiesReported() {
    if (_capabilitiesReported) return;
    _capabilitiesReported = true;
    _safeReport(
      () => _service.reportCapabilities(
        serverUrl: _authServerUrl(),
        token: _authToken(),
      ),
      'reportCapabilities',
    );
  }

  void _reportPlaybackStart() {
    if (_hasStartedReported) return;
    _hasStartedReported = true;
    // 如果来自预加载会话，则复用其 playSessionId，保证预加载和播放使用同一个会话
    _playSessionId = widget.preloadedSession?.playSessionId ?? _newPlaySessionId();
    // 如果来自预加载会话，同步播放等级到 provider（保证 reportPlaybackProgress 正确）
    if (widget.preloadedSession != null) {
      ref.read(playbackLevelProvider.notifier).setLevel(widget.preloadedSession!.playbackLevel);
    }
    final level = ref.read(playbackLevelProvider);
    final method = _playMethodFromLevel(level);
    _safeReport(
      () => _service.reportPlaybackStart(
        itemId: widget.item.id,
        mediaSourceId: widget.item.id,
        playSessionId: _playSessionId!,
        playMethod: method,
        serverUrl: _authServerUrl(),
        token: _authToken(),
      ),
      'reportPlaybackStart',
    );
  }

  void _reportPlaybackProgress({bool isPauseEvent = false}) {
    final now = DateTime.now();
    if (!isPauseEvent) {
      final delta = now.difference(_lastProgressReport);
      if (delta.inSeconds < _progressReportMinSeconds) return;
    }
    _lastProgressReport = now;
    final controller = _videoController;
    final position = controller?.value.position;
    final positionTicks = (position?.inSeconds ?? 0) * 10000000;
    final isPaused = controller != null && !controller.value.isPlaying;
    final volume = controller?.value.volume;
    final volumeLevel = volume != null ? (volume * 100).round() : null;
    final level = ref.read(playbackLevelProvider);
    final method = _playMethodFromLevel(level);
    _safeReport(
      () => _service.reportPlaybackPosition(
        itemId: widget.item.id,
        positionTicks: positionTicks,
        mediaSourceId: widget.item.id,
        playSessionId: _playSessionId,
        isPaused: isPaused,
        volumeLevel: volumeLevel,
        playMethod: method,
        eventName: isPauseEvent ? 'Pause' : 'TimeUpdate',
        serverUrl: _authServerUrl(),
        token: _authToken(),
      ),
      'reportPlaybackPosition',
    );
  }

  void _reportPlaybackStopped() {
    if (_hasStoppedReported) return;
    _hasStoppedReported = true;
    final controller = _videoController;
    final position = controller?.value.position;
    final positionTicks = position != null ? position.inSeconds * 10000000 : 0;
    _safeReport(
      () => _service.reportPlaybackStopped(
        itemId: widget.item.id,
        positionTicks: positionTicks,
        mediaSourceId: widget.item.id,
        playSessionId: _playSessionId,
        serverUrl: _authServerUrl(),
        token: _authToken(),
      ),
      'reportPlaybackStopped',
    );
    // 播放停止后续播进度已变，失效续播、详情和观看历史缓存确保下次获取最新数据
    // watchHistory 列表（含 Resume）依赖播放进度，必须失效
    final serverUrl = _authServerUrl();
    final token = _authToken();
    if (serverUrl != null && token != null) {
      try {
        ref.read(cacheControllerProvider).invalidateResume(serverUrl, token);
        ref
            .read(cacheControllerProvider)
            .invalidateItemDetail(widget.item.id, serverUrl);
        ref.read(cacheControllerProvider).invalidateWatchHistory(serverUrl);
      } catch (_) {}
    }
    _hasStartedReported = false;
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _reportPlaybackProgress();
    });
  }

  // ===== 认证辅助 =====
  // 使用 ref.read 而非 ref.watch，因为这些方法在非 build 上下文中调用
  // （如 _reportPlaybackStart、_reportPlaybackProgress 等回调）
  // 只需读取当前值，不需要订阅变化触发重建
  String? _authServerUrl() => ref.read(authProvider).embyServerUrl;
  String? _authToken() => ref.read(authProvider).token;

  /// 安全执行上报类异步操作：捕获异常并记录日志，避免未捕获的 Future 错误
  /// 用于 markAsPlayed、report* 等不阻塞主流程的后台请求
  void _safeReport(Future<void> Function() action, String operation) {
    unawaited(
      action().catchError((Object e, StackTrace st) {
        AppLogger.warn('上报操作失败', data: {
          'operation': operation,
          'itemId': widget.item.id,
          'error': e.toString(),
        });
      }),
    );
  }

  // ===== 全屏切换 =====
  // 方案 A：进入全屏页（FullscreenVideoPage）
  // - 全屏页不创建新 controller，复用 currentVideoControllerProvider
  // - 进度 100% 不丢，零额外内存
  // - 退出全屏用系统返回键，PopScope 自动处理
  Future<void> _openFullscreenPage() async {
    // 进入前隐藏工具栏（沉浸感）
    ref.read(toolbarVisibilityProvider.notifier).hide();
    // push 全屏页
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FullscreenVideoPage(),
        fullscreenDialog: true,
      ),
    );
    // 退出全屏后恢复工具栏
    if (mounted) {
      ref.read(toolbarVisibilityProvider.notifier).show();
      // 退出全屏后重新隐藏系统栏（全屏页 dispose 时会恢复 edgeToEdge）
      // feed 模式需要保持沉浸式
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  // ===== 控制层显示/隐藏 =====
  void _toggleControls() {
    if (_controlsVisible) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  void _showControls() {
    _controlsHideTimer?.cancel();
    if (!mounted) return;
    setState(() => _controlsVisible = true);
    _controlsHideTimer = Timer(const Duration(seconds: _controlsAutoHideSeconds), _hideControls);
  }

  void _hideControls() {
    _controlsHideTimer?.cancel();
    if (mounted) setState(() => _controlsVisible = false);
  }

  // ===== 播放/暂停切换 =====
  void _togglePlay() {
    if (_videoController == null) return;
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
      ref.read(isPlayingProvider.notifier).state = false;
    } else {
      _videoController!.play();
      ref.read(isPlayingProvider.notifier).state = true;
    }
  }

  // ===== 删除确认 =====
  Future<void> _showDeleteConfirmDialog() async {
    final confirmed = await sheet_utils.showDeleteConfirmDialog(context, widget.item.title);
    if (confirmed) {
      // 提前获取认证信息并判空，避免 token 过期/丢失时强制断言崩溃
      final serverUrl = _authServerUrl();
      final token = _authToken();
      if (serverUrl == null || token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('认证信息缺失，请重新登录后再试'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      try {
        await _service.deleteItem(
          itemId: widget.item.id,
          serverUrl: serverUrl,
          token: token,
        );
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('已删除'), duration: Duration(seconds: 2)));
          // 从视频列表中移除当前 item，避免用户反向滑回已删除的视频
          ref.read(videoListProvider.notifier).removeItem(widget.item.id);
          widget.onVideoEnded?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e'), duration: const Duration(seconds: 2)),
          );
        }
      }
    }
  }

  // ===== Duration 格式化 =====
  String _formatDuration(Duration duration) {
    if (duration.inSeconds <= 0) return '0:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours >= 1) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _titleText() {
    if (widget.item.year != null) return '${widget.item.title} (${widget.item.year})';
    return widget.item.title;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final embyServerUrl = authState.embyServerUrl;
    final token = authState.token;
    // 使用 select 仅监听当前 item 的收藏状态，避免 favoritesProvider 任意变化时触发重建
    final favorited = ref.watch(
        favoritesProvider.select((s) => s.favoriteIds.contains(widget.item.id)));
    // 使用 select 仅监听当前 item 的就绪状态，避免其他 item 就绪状态变化时触发重建
    final isReady = ref.watch(
        videoReadyProvider.select((s) => s.contains(widget.item.id)));
    final isAutoPlay = ref.watch(isAutoPlayProvider);
    final toolbarVisible = ref.watch(toolbarVisibilityProvider);
    final scheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final rs = (double base, [double maxScale = 1.7]) => responsiveSize(context, base, maxScale);

    // 封面图 URL（用于唱片按钮）
    final posterUrl =
        widget.item.primaryUrl(embyServerUrl: embyServerUrl, apiKey: token) ?? '';
    final posterHeaders = widget.item.authHeaders(token);

    // ============ 主 Stack ============
    final content = Stack(
      fit: StackFit.expand,
      children: [
        // 骨架占位：视频未 ready 时显示渐变色块
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isReady
                  ? [Colors.transparent, Colors.transparent]
                  : [scheme.surface.withOpacity(0.7), scheme.surface],
            ),
          ),
        ),

        // 视频播放区（Gestures + VideoPlayer）
        AnimatedOpacity(
          opacity: isReady ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: GestureOverlay(
            controller: _videoController,
            item: widget.item,
            enableGestures: !_controlsVisible,
            onSingleTap: () {
              if (isAutoPlay) {
                _toggleControls();
              } else {
                _togglePlay();
              }
            },
            child: VideoPlayerWidget(
              item: widget.item,
              isCurrentPage: widget.isCurrentPage,
              embyServerUrl: embyServerUrl,
              token: token,
              preloadedController: widget.preloadedSession?.controller,
              preloadedPlaybackLevel: widget.preloadedSession?.playbackLevel,
              startFromResumePosition: widget.startFromResumePosition,
              onControllerReady: (c) {
                // 异步回调中 setState 前必须检查 mounted，避免 widget 已销毁时抛异常
                if (!mounted) return;
                setState(() => _videoController = c);
                ref.read(videoReadyProvider.notifier).markReady(widget.item.id);
                c.addListener(_onVideoChanged);
                // 仅当前页启动播放上报/进度上报，避免相邻预加载页并发有声播放与重复上报
                if (widget.isCurrentPage) {
                  _startPlaybackIfCurrent();
                }
              },
            ),
          ),
        ),

        // 中央播放/暂停按钮（暂停时显示）—— 独立子组件，仅监听 isPlayingProvider 避免父组件过度重建
        _CenterPlayButtonWrapper(
          controller: _videoController,
          onPlay: _togglePlay,
        ),

        // 倍速状态徽章
        if (_videoController != null &&
            _videoController!.value.isInitialized &&
            _videoController!.value.playbackSpeed > 1.0)
          SpeedBadge(speed: _videoController!.value.playbackSpeed),

        // 底部细线进度条：仅在全屏 / 纯净模式且控制条隐藏时显示（VideoControls 显示时有自己的进度条）
        if (_videoController != null &&
            _videoController!.value.isInitialized &&
            (isAutoPlay) &&
            !_controlsVisible)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ThinProgressBar(controller: _videoController!),
          ),

        // 控制层（VideoControls）：仅在无信息栏时显示（全屏 / 纯净模式），非全屏非纯净模式下信息栏已有进度条替代
        if (_videoController != null && _videoController!.value.isInitialized && (isAutoPlay))
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: Duration(milliseconds: _controlsVisible ? 200 : 300),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: VideoControls(
                  controller: _videoController!,
                  subtitleTracks: widget.item.subtitleTracks,
                  onPrevEpisode: widget.onPrevEpisode,
                  onNextEpisode: widget.onNextEpisode,
                  onToggleFullscreen: _openFullscreenPage,
                  isInFullscreen: false,
                ),
              ),
            ),
          ),

        // 底部渐变 + 标题/简介/类型标签（非纯净模式）
        if ((_isInfoExpanded || !isAutoPlay))
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedOpacity(
              opacity: _isInfoVisible ? 1.0 : 0.0,
              duration: Duration(milliseconds: _isInfoVisible ? 300 : 500),
              curve: Curves.easeOut,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  80,
                  rs(80, 2.0) + 16,
                  toolbarVisible ? bottomPadding + 24 + 80 : bottomPadding + 24,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      scheme.surface.withOpacity(0.8),
                      scheme.surface.withOpacity(0.5),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 横屏视频：居中显示「全屏观看」按钮
                    if (_videoController != null &&
                        _videoController!.value.isInitialized &&
                        _videoController!.value.size.width > _videoController!.value.size.height)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: _openFullscreenPage,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: scheme.surface.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fullscreen, color: scheme.onSurface, size: 16),
                                  const SizedBox(width: 6),
                                  Text('全屏观看', style: TextStyle(color: scheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(widget.item.type,
                          style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(_titleText(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        if (widget.item.displayRating != null && widget.item.displayRating! > 0)
                          Text('★ ${widget.item.displayRating!.toStringAsFixed(1)}',
                              style: TextStyle(
                                  color: scheme.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (widget.item.overview != null && widget.item.overview!.isNotEmpty)
                      Text(widget.item.overview!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
                    if (_videoController != null && _videoController!.value.isInitialized)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SeekableProgressBar(
                          controller: _videoController!,
                          formatDuration: _formatDuration,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

        // 右侧操作按钮（非纯净模式）
        if (!isAutoPlay)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: rs(80, 2.0),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                0,
                toolbarVisible ? MediaQuery.of(context).padding.top + rs(48) : rs(32),
                rs(6),
                toolbarVisible ? bottomPadding + 24 + 80 : bottomPadding + 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [scheme.surface.withOpacity(0.54), Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 顶部全屏按钮（仅竖屏视频时显示，横屏视频下方已有居中"全屏观看"按钮）
                  if (_videoController == null ||
                      !_videoController!.value.isInitialized ||
                      _videoController!.value.size.width <= _videoController!.value.size.height)
                    PressableActionButton(
                      icon: Icons.fullscreen,
                      label: '全屏',
                      color: scheme.onSurface,
                      onTap: _openFullscreenPage,
                    ),
                  SizedBox(height: rs(16, 1.5)),
                  const AutoPlayButton(),
                  SizedBox(height: rs(16, 1.5)),
                  PosterAvatar(item: widget.item),
                  SizedBox(height: rs(16, 1.5)),
                  PressableActionButton(
                    icon: favorited ? Icons.favorite : Icons.favorite_border,
                    label: '点赞',
                    color: favorited ? scheme.primary : scheme.onSurface,
                    onTap: () => ref.read(favoritesProvider.notifier).toggleFavorite(widget.item),
                  ),
                  SizedBox(height: rs(16, 1.5)),
                  PressableActionButton(
                    icon: Icons.info_outline,
                    label: '信息',
                    color: scheme.onSurface,
                    onTap: () {
                      setState(() => _isInfoExpanded = !_isInfoExpanded);
                      sheet_utils.showVideoInfoSheet(context, widget.item);
                    },
                  ),
                  SizedBox(height: rs(16, 1.5)),
                  PressableActionButton(
                    icon: Icons.delete_outline,
                    label: '删除',
                    color: scheme.error,
                    onTap: _showDeleteConfirmDialog,
                  ),
                  SizedBox(height: rs(16, 1.5)),
                  SpeedControlButton(
                    controller: _videoController,
                    onTap: () => sheet_utils.showSpeedControlPanel(context, _videoController),
                  ),
                  SizedBox(height: rs(16, 1.5)),
                  const PlayModeButton(),
                  SizedBox(height: rs(16, 1.5)),
                  SubtitleButton(
                    hasSubtitles: widget.item.subtitleTracks.isNotEmpty,
                    onTap: () => sheet_utils.showSubtitleSelector(context, widget.item.subtitleTracks),
                  ),
                  SizedBox(height: rs(16, 1.5)),
                  DiscMuteButton(
                    discRotation: _discRotation,
                    controller: _videoController,
                    posterUrl: posterUrl,
                    httpHeaders: posterHeaders,
                  ),
                  if (widget.onNextEpisode != null) ...[
                    SizedBox(height: rs(16, 1.5)),
                    PressableActionButton(
                      icon: Icons.chevron_right,
                      label: '下一集',
                      color: scheme.onSurface,
                      onTap: widget.onNextEpisode,
                    ),
                  ],
                ],
              ),
            ),
          ),

        // 纯净模式：可拖动按钮组
        if (isAutoPlay)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return DraggableCleanActions(
                  containerSize: Size(constraints.maxWidth, constraints.maxHeight),
                  buttonWidth: rs(80, 2.0),
                  bottomSafeArea: bottomPadding + 80 + 16,
                  rightSafeArea: 16,
                  buttons: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surface.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AutoPlayButton(),
                        SizedBox(height: rs(16, 1.5)),
                        SpeedControlButton(
                          controller: _videoController,
                          onTap: () => sheet_utils.showSpeedControlPanel(context, _videoController),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // 顶部操作区：全屏模式下控制条已有退出按钮，无需额外入口

        // NextUp 下一集提示条
        if (_showNextUpBanner && _nextUpItem != null)
          NextUpBanner(
            nextItem: _nextUpItem!,
            countdown: _nextUpCountdown,
            onPlay: _playNextUp,
            onCancel: _cancelNextUp,
          ),
      ],
    );

    // 使用 PopScope：保持 Widget 树结构稳定，仅属性变化
    // 全屏现在由 FullscreenVideoPage 独立承载，本页 _isFullscreen 永远 false
    return PopScope(
      canPop: true,
      child: Semantics(
        label: '视频播放区域，双击点赞此视频',
        child: Container(
          color: null,
          child: content,
        ),
      ),
    );
  }
}

/// 中央播放按钮包装器：仅监听 isPlayingProvider，避免父组件因播放状态变化而整体重建
///
/// 将 [CenterPlayButton] 的显示逻辑拆分到独立 [ConsumerWidget]，
/// 这样 isPlayingProvider 状态变化时只重建本组件，不会触发 [VideoPageItem] 重建。
class _CenterPlayButtonWrapper extends ConsumerWidget {
  final VideoPlayerController? controller;
  final VoidCallback onPlay;

  const _CenterPlayButtonWrapper({
    required this.controller,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(isPlayingProvider);
    // 仅在控制器已初始化且非播放状态时显示中央播放按钮
    if (controller != null && controller!.value.isInitialized && !isPlaying) {
      return CenterPlayButton(onPlay: onPlay);
    }
    return const SizedBox.shrink();
  }
}

/// 播放页面外壳：支持滑动切换视频列表
///
/// 使用 PageView 展示视频列表，支持上下滑动切换视频
class PlaybackShell extends ConsumerStatefulWidget {
  final MediaItem item; // 当前播放的视频
  final List<MediaItem> items; // 视频列表（可选）
  final VoidCallback onBack; // 返回回调

  const PlaybackShell({
    super.key,
    required this.item,
    this.items = const [],
    required this.onBack,
  });

  @override
  ConsumerState<PlaybackShell> createState() => _PlaybackShellState();
}

class _PlaybackShellState extends ConsumerState<PlaybackShell> {
  late PageController _pageController;
  int _currentIndex = 0;
  late List<MediaItem> _items;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0, viewportFraction: 1.0);
    _initItems();
    _preloadAround(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _initItems() {
    // 优先使用传入的列表，否则从 playbackListProvider 获取
    if (widget.items.isNotEmpty) {
      _items = widget.items;
      final initialIndex = _items.indexWhere((i) => i.id == widget.item.id);
      _currentIndex = initialIndex >= 0 ? initialIndex : 0;
      _isLoading = false;
      // 如果初始索引不是 0，滚动到对应位置
      if (initialIndex > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(initialIndex);
          }
        });
      }
    } else {
      // 从 playbackListProvider 获取播放列表
      final playbackState = ref.read(playbackListProvider);
      if (playbackState.items.isNotEmpty) {
        _items = playbackState.items;
        final initialIndex = _items.indexWhere((i) => i.id == widget.item.id);
        _currentIndex = initialIndex >= 0 ? initialIndex : 0;
        _isLoading = false;
        if (initialIndex > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pageController.hasClients) {
              _pageController.jumpToPage(initialIndex);
            }
          });
        }
      } else {
        // 如果列表为空，只播放当前视频
        _items = [widget.item];
        _currentIndex = 0;
        _isLoading = false;
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _preloadAround(index);
  }

  // 接入全局预加载池：预加载相邻视频并清理较远的会话，
  // 避免独立播放页长列表滑动时控制器数量无限增长（与 feed 行为一致）
  void _preloadAround(int index) {
    final auth = ref.read(authProvider);
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    if (serverUrl == null || token == null) return;
    final pool = ref.read(videoPoolProvider);
    Future<void> maybePreload(int i) async {
      if (i < 0 || i >= _items.length) return;
      final it = _items[i];
      if (!pool.hasSession(it.id)) {
        await pool.preload(item: it, serverUrl: serverUrl, token: token);
      }
    }

    unawaited(maybePreload(index - 1));
    unawaited(maybePreload(index + 1));
    final keep = <String>[];
    if (index - 1 >= 0) keep.add(_items[index - 1].id);
    if (index + 1 < _items.length) keep.add(_items[index + 1].id);
    pool.evictExcept(keep);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: scheme.surface,
        body: Center(
          child: CircularProgressIndicator(color: scheme.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          // PageView 支持滑动切换视频
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _items.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final item = _items[index];
              // 复用全局预加载池中的会话（如存在且仍有效），否则回退动态创建
              final rawSession = ref.read(videoPoolProvider).take(item.id);
              final preloadedSession =
                  (rawSession != null && rawSession.isInitialized) ? rawSession : null;
              return VideoPageItem(
                key: ValueKey(item.id),
                item: item,
                isCurrentPage: index == _currentIndex,
                preloadedSession: preloadedSession,
                onVideoEnded: index < _items.length - 1
                    ? () {
                        // 自动播放下一个
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    : null,
                startFromResumePosition: item.hasProgress,
              );
            },
          ),
          // 返回按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: scheme.onSurface),
              onPressed: widget.onBack,
            ),
          ),
          // 当前位置指示器
          if (_items.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surface.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentIndex + 1}/${_items.length}',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
