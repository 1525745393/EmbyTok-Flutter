// 视频流单页：全屏视频 + 右侧操作按钮 + 左下角标题信息
// 完整 Emby 播放上报链（reportCapabilities / reportPlaybackStart /
//       reportPlaybackPosition / reportPlaybackStopped）

import 'dart:async';

import 'dart:convert';

import '../../utils/safe_insets.dart';
import '../../utils/safe_unawaited.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../providers/video_comments_provider.dart';
import '../../services/embytok_service.dart';
import '../../utils/logger.dart';
import '../../utils/fullscreen_navigator.dart';
import '../../utils/constants.dart';
import 'gesture_overlay.dart';
import 'video_controls.dart';
import 'video_player_widget.dart';

// 拆分出的子组件
import 'video_action_button.dart';
import 'video_comments_sheet.dart';
import 'video_control_buttons.dart';
import 'video_progress_bars.dart';
import 'video_sheet_utils.dart' as sheet_utils;
import 'video_draggable_clean_actions.dart';
part 'video_page_item_widgets.dart';
part 'video_page_item_shell.dart';
part 'video_page_item_reporting.dart';

/// 单个视频页：TikTok 卡片样式
// ===== UI 布局常量（避免魔法数字，提升可维护性）=====

/// 底部信息栏渐变遮罩高度
const double _kBottomInfoGradientHeight = 80;

/// 底部控制栏高度（VideoControls compact 模式）
const double _kBottomControlBarHeight = 24;

/// 右侧操作栏宽度
const double _kRightActionWidth = 72;

/// 右侧操作栏顶部偏移（有 toolbar 时避开刘海 + 额外间距）
const double _kRightActionTopWithToolbar = 48;

/// 右侧操作栏顶部偏移（无 toolbar 时）
const double _kRightActionTopNoToolbar = 32;

/// 右侧操作栏右侧内边距
const double _kRightActionRightPadding = 6;

/// 水平方向通用内边距
const double _kHorizontalPadding = 16;

// ===== 动画与时长常量 =====

/// 快速动画时长（淡入淡出、过渡等）
const Duration _kAnimationFast = Duration(milliseconds: 300);

/// 正常动画时长
const Duration _kAnimationNormal = Duration(seconds: 2);

/// SnackBar 显示时长
const Duration _kSnackBarDuration = Duration(seconds: 2);

/// 播放进度上报间隔
const Duration _kProgressReportInterval = Duration(seconds: 5);

/// 自动隐藏控制栏延迟
const Duration _kControlsAutoHideDelay = Duration(seconds: 4);

// ===== 字体大小常量 =====

/// 小字体（标签、辅助信息）
const double _kFontSizeSmall = 12;

/// 中字体（正文、副标题）
const double _kFontSizeMedium = 14;

/// 中等字体（按钮、列表项）
const double _kFontSizeBody = 13;

/// 大字体（标题）
const double _kFontSizeLarge = 18;

// ===== 间距与内边距常量 =====

/// 小间距
const double _kSpacingSmall = 6;

/// 中间距
const double _kSpacingMedium = 8;

/// 大间距
const double _kSpacingLarge = 12;

/// 标签内边距（水平/垂直）
const double _kTagPaddingHorizontal = 10;
const double _kTagPaddingVertical = 4;

class VideoPageItem extends ConsumerStatefulWidget {
  const VideoPageItem({
    super.key,
    required this.item,
    this.preloadedSession,
    this.onVideoEnded,
    this.startFromResumePosition = false,
    this.onPrevEpisode,
    this.source = 'feed',
    this.isCurrentPage = true,
  });
  final MediaItem item;
  final PlaybackSession? preloadedSession;
  final VoidCallback? onVideoEnded;
  final bool startFromResumePosition;
  final VoidCallback? onPrevEpisode;

  /// 数据源标识（用于观看统计）：nextUp/resume/suggestions/similar/feed
  final String source;

  /// 是否为当前可见页：非当前页初始化后静音暂停，避免相邻预加载页并发有声播放
  final bool isCurrentPage;

  @override
  ConsumerState<VideoPageItem> createState() => _VideoPageItemState();
}

class _VideoPageItemState extends ConsumerState<VideoPageItem>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  final GlobalKey<VideoPlayerWidgetState> _videoPlayerKey =
      GlobalKey<VideoPlayerWidgetState>();
  bool _hasNotifiedEnded = false;
  bool _hasStoppedReported = false;
  bool _providerCleaned = false;
  bool _statsRecorded = false;

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
  late final EmbytokService _service;
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

  // 中央播放/暂停按钮显示状态（仅非纯净模式，2秒后自动隐藏）
  bool _centerButtonVisible = false;
  Timer? _centerButtonHideTimer;

  // 纯净模式下可拖动按钮组的引用，用于单击屏幕时显示按钮以便退出纯净模式
  final GlobalKey<DraggableCleanActionsState> _cleanActionsKey =
      GlobalKey<DraggableCleanActionsState>();

  // 功耗优化：上一次报告的播放位置秒数，用于跨秒节流 Provider 写入
  int _lastPositionSecond = -1;

  // 保存 listenManual 订阅引用，dispose 时显式 close 避免内存泄漏
  ProviderSubscription<bool>? _isPlayingSubscription;
  ProviderSubscription<bool>? _isAutoPlaySubscription;

  @override
  void initState() {
    super.initState();
    _service = ref.read(embytokServiceProvider);
    WidgetsBinding.instance.addObserver(this);
    _lastLifecycleState = WidgetsBinding.instance.lifecycleState;
    _discRotationCtrl = AnimationController(
      vsync: this,
      duration: _kControlsAutoHideDelay,
    );
    _discRotation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _discRotationCtrl, curve: Curves.linear));

    // 监听播放状态变化（播放时旋转唱片，暂停时停止）
    // 放在 initState 中通过 listenManual 注册，避免每次 build 重复注册
    // 修复：原先 initState 中无条件 ..repeat() 会让唱片在未播放时也持续旋转，
    // 既浪费电量又使集成测试 pumpAndSettle 永不收敛（无限帧调度）。
    // 改为 fireImmediately，依据当前 isPlayingProvider（初始 false）决定是否旋转。
    _isPlayingSubscription =
        ref.listenManual<bool>(isPlayingProvider, (previous, next) {
      if (next) {
        if (!_discRotationCtrl.isAnimating) _discRotationCtrl.repeat();
      } else {
        if (_discRotationCtrl.isAnimating) _discRotationCtrl.stop();
      }
    }, fireImmediately: true);

    // PR #72：监听纯净模式（isAutoPlay）变化，同步到工具栏可见性
    // - isAutoPlay=true → setAutoPlayActive(true)，顶部工具栏 + 底部导航栏持续隐藏
    // - isAutoPlay=false → setAutoPlayActive(false)，工具栏恢复显示（除非全屏引用计数>0）
    // fireImmediately: true 确保初始值同步（避免页面切换后纯净模式状态丢失）
    _isAutoPlaySubscription =
        ref.listenManual<bool>(isAutoPlayProvider, (prev, next) {
      ref.read(toolbarVisibilityProvider.notifier).setAutoPlayActive(next);
    }, fireImmediately: true);
  }

  // App 进入后台时仅停止唱片动画，音频由 AudioHandler 接管继续播放；回到前台时恢复画面渲染
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final prev = _lastLifecycleState;
    _lastLifecycleState = state;
    if (prev == null) return;

    final wasForeground = prev == AppLifecycleState.resumed;
    final isForeground = state == AppLifecycleState.resumed;

    if (wasForeground && !isForeground) {
      // 进入后台：不主动暂停，由 AudioHandler 接管音频播放
      _wasPlayingBeforeBackground = _videoController?.value.isPlaying ?? false;
      // 仅停止唱片旋转动画（UI 相关）
      _discRotationCtrl.stop();
      // 注意：不暂停 _videoController，音频继续播放（后台听剧场景）
    } else if (!wasForeground && isForeground) {
      if (_wasPlayingBeforeBackground) {
        try {
          if (_videoController != null &&
              _videoController!.value.isInitialized &&
              !_videoController!.value.isPlaying) {
            _videoController!.play();
          }
        } catch (e) {
          // controller 可能已被后台释放（非当前页），忽略并记录
          AppLogger.warn('前台恢复播放失败，controller 可能已释放',
              data: {'itemId': widget.item.id, 'error': e.toString()});
        }
        if (!_discRotationCtrl.isAnimating) {
          _discRotationCtrl.repeat();
        }
      }
    }
  }

  // ===== 底部信息条：始终可见 =====
  // 原设计为播放3秒后自动隐藏，但用户反馈需要始终可见以便随时查看标题、进度等
  void _resetInfoHideTimer() {
    _infoHideTimer?.cancel();
    if (!mounted) return;
    setState(() => _isInfoVisible = true);
  }

  @override
  void didUpdateWidget(covariant VideoPageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentPage &&
        !oldWidget.isCurrentPage &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
      ref.read(currentVideoControllerProvider.notifier).state =
          _videoController;
      // _startPlaybackIfCurrent 现为 async（需等待服务端进度拉取与 seek），
      // 此处为事件回调上下文，使用 safeUnawaited fire-and-forget
      safeUnawaited(
        _startPlaybackIfCurrent(),
        context:
            'didUpdateWidget._startPlaybackIfCurrent(itemId:${widget.item.id})',
      );
    } else if (!widget.isCurrentPage && oldWidget.isCurrentPage) {
      _progressTimer?.cancel();
      _progressTimer = null;
      if (_hasStartedReported && !_hasStoppedReported) {
        _reportPlaybackProgress(isPauseEvent: true);
      }
      _infoHideTimer?.cancel();
      _controlsHideTimer?.cancel();
      _centerButtonHideTimer?.cancel();
    }
  }

  @override
  void deactivate() {
    // 在 deactivate 中清理 Provider 状态（而非 dispose），
    // 因为 riverpod 禁止在 dispose() 中使用 ref.read()。
    // deactivate 可能被多次调用（widget 从 tree 移除又重新插入），用 _providerCleaned 做幂等。
    if (!_providerCleaned) {
      _providerCleaned = true;
      // 修复：ProviderContainer 可能已 dispose（如测试环境 addTearDown 后），
      // 或 widget 已 deactivate 导致 ancestor lookup 失败。
      // 此时 provider 状态会随 container 一起清理，无需手动清除。
      try {
        ref.read(videoReadyProvider.notifier).clear(widget.item.id);
        final ctrl = ref.read(currentVideoControllerProvider);
        if (ctrl != null && identical(ctrl, _videoController)) {
          ref.read(currentVideoControllerProvider.notifier).state = null;
        }
      } catch (_) {
        // ProviderContainer 已 dispose，provider 状态随 container 一起清理
      }
    }
    // 观看统计：在 deactivate 中记录（避免 dispose 中调用 ref.read 违反 Riverpod 规范）
    if (!_statsRecorded) {
      _statsRecorded = true;
      _recordWatchStats();
    }
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    // widget 重新插入树中时重置标记，确保后续 deactivate 能再次清理
    _providerCleaned = false;
    _statsRecorded = false;
    // 如果有 controller 且已初始化，重新标记 ready（避免 deactivate 清理后视频画面不显示）
    if (_videoController != null && _videoController!.value.isInitialized) {
      ref.read(videoReadyProvider.notifier).markReady(widget.item.id);
    }
    // 如果有 controller 且是当前页，重新写入 Provider（避免 deactivate 清理后状态丢失）
    if (_videoController != null && widget.isCurrentPage) {
      ref.read(currentVideoControllerProvider.notifier).state =
          _videoController;
      ref.read(isPlayingProvider.notifier).state =
          _videoController!.value.isPlaying;
    }
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
    _centerButtonHideTimer?.cancel();
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
  //
  // 进度双向同步：在播放启动流程中先从服务端拉取最新播放进度，
  // 与本地进度取较新者后执行 seek，确保多端观看进度互通。
  // 拉取失败时降级到本地进度，不影响播放。
  Future<void> _startPlaybackIfCurrent() async {
    if (!widget.isCurrentPage) return;
    final controller = _videoController;
    if (controller != null && controller.value.isInitialized) {
      final isMuted = ref.read(isMutedProvider);
      controller.setVolume(isMuted ? 0.0 : 1.0);
      try {
        controller.play();
      } catch (e) {
        AppLogger.warn('播放视频失败', data: {'error': e.toString()});
      }
      ref.read(isPlayingProvider.notifier).state = true;
    }
    ref.read(playbackStateProvider.notifier).setItem(widget.item);
    ref.read(currentVideoControllerProvider.notifier).state = _videoController;
    _resetInfoHideTimer();

    // === 进度双向同步：从服务端拉取最新进度 ===
    int resumePositionTicks = 0;
    try {
      final auth = ref.read(authProvider);
      final serverPosition = await _service.getPlaybackPosition(
        widget.item.id,
        userId: auth.user?.id,
        serverUrl: auth.embyServerUrl,
        token: auth.token,
      );
      final localPosition =
          widget.item.userData?.playbackPositionTicks.toInt() ?? 0;
      // 取较新者：服务端进度更大说明其他设备看了更多
      resumePositionTicks =
          serverPosition > localPosition ? serverPosition : localPosition;
    } catch (_) {
      // 拉取失败，使用本地进度降级
      resumePositionTicks =
          widget.item.userData?.playbackPositionTicks.toInt() ?? 0;
    }

    // 使用合并后的进度执行 seek，覆盖 VideoPlayerWidget 中基于本地 userData 的初次 seek
    // 确保播放器定位到最新进度（其他设备的观看位置）
    if (resumePositionTicks > 0 &&
        controller != null &&
        controller.value.isInitialized) {
      final posMs = (resumePositionTicks / 10000.0).round();
      if (posMs > 0) {
        try {
          await controller.seekTo(Duration(milliseconds: posMs));
        } catch (e) {
          AppLogger.warn('跳转播放位置失败',
              data: {'error': e.toString(), 'position': posMs});
        }
      }
    }

    // 异步等待后 widget 可能已被 dispose，避免在 dispose 后访问 ref
    if (!mounted) return;

    _ensureCapabilitiesReported();
    _reportPlaybackStart();
    _startProgressTimer();

    // 同步 MediaSession：播放开始时设置媒体项并更新播放状态，
    // 使锁屏/通知栏显示标题、封面与播放控件
    _syncMediaSessionOnStart();
  }

  /// 播放开始时同步 MediaSession 媒体项与播放状态
  ///
  /// 字段映射说明（基于 MediaItem 实际模型，与任务描述的伪代码有差异）：
  /// - title：MediaItem.title（必填，无 name 字段）
  /// - artist：MediaItem.seriesName（无 album/artist 字段，剧集名副标题即可）
  /// - artUri：通过 primaryUrl() 构造完整 URL（含 api_key），无 primaryImageThumbUrl 字段
  /// - duration：MediaItem.runtimeTicks（小写 r），1 tick = 100ns = 0.1μs
  void _syncMediaSessionOnStart() {
    final audioHandler = ref.read(audioHandlerProvider);
    // 封面图 URL：需带 serverUrl 与 token 才能被系统 MediaSession 访问
    final serverUrl = _authServerUrl();
    final token = _authToken();
    final artUri = widget.item.primaryUrl(
      embyServerUrl: serverUrl,
      apiKey: token,
    );
    // ticks → Duration：1 tick = 100ns = 0.1μs，故 microseconds = ticks / 10
    final ticks = widget.item.runtimeTicks;
    final duration =
        ticks != null ? Duration(microseconds: (ticks / 10).round()) : null;
    audioHandler.setMediaItem(
      title: widget.item.title,
      artist: widget.item.seriesName,
      artUri: artUri,
      duration: duration,
    );
    audioHandler.updatePlaybackState(
      isPlaying: true,
      position: Duration.zero,
    );
  }

  /// 记录观看统计（完播率）
  void _recordWatchStats() {
    // 只有当前页才记录，避免预加载页误记录拉低完播率
    if (!widget.isCurrentPage) return;
    final controller = _videoController;
    if (controller == null) return;
    try {
      if (!controller.value.isInitialized) return;
      final position = controller.value.position;
      final duration = controller.value.duration;
      if (duration.inMilliseconds <= 0) return;
      // 使用微秒计算避免毫秒整数除法的精度损失
      final completionRate = position.inMicroseconds / duration.inMicroseconds;
      ref.read(watchStatsProvider.notifier).recordWatch(
            itemId: widget.item.id,
            itemType: widget.item.type,
            itemTitle: widget.item.title,
            completionRate: completionRate,
            source: widget.source,
          );
    } catch (e) {
      // controller 可能已被子 widget VideoPlayerWidget dispose，
      // 此时跳过统计记录，避免 dispose 链中断
      AppLogger.debug('recordWatchStats 跳过：controller 不可访问',
          data: {'itemId': widget.item.id, 'error': e.toString()});
    }
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
            ref
                .read(cacheControllerProvider)
                .invalidateResume(serverUrl, token);
            ref
                .read(cacheControllerProvider)
                .invalidateItemDetail(widget.item.id, serverUrl);
            ref.read(cacheControllerProvider).invalidateNextUp(serverUrl);
            ref.read(cacheControllerProvider).invalidateWatchHistory(serverUrl);
          } catch (e) {
            AppLogger.warn('视频播放结束后更新缓存失败', data: {'error': e.toString()});
          }
        }
        ref.read(videoListProvider.notifier).removePlayedItem(widget.item.id);
        // 视频播放结束：已移除自动播放和下一集功能
        // 用户需要手动滑动切换到下一个视频
      }
    }
  }

  // ===== 播放上报链方法 =====
  String _newPlaySessionId() =>
      'emb-flutter-${DateTime.now().microsecondsSinceEpoch}';

  void _reportPlaybackStart() {
    if (_hasStartedReported) return;
    _hasStartedReported = true;
    // 如果来自预加载会话，则复用其 playSessionId，保证预加载和播放使用同一个会话
    // 空字符串视为无效，生成新的会话 ID
    final preloadedId = widget.preloadedSession?.playSessionId;
    _playSessionId = (preloadedId != null && preloadedId.isNotEmpty)
        ? preloadedId
        : _newPlaySessionId();
    _safeReport(
      () => _service.reportPlaybackStart(
        itemId: widget.item.id,
        mediaSourceId: widget.item.id,
        playSessionId: _playSessionId!,
        playMethod: 'DirectPlay',
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
    final positionTicks = (position?.inMilliseconds ?? 0) * 10000;
    final isPaused = controller != null && !controller.value.isPlaying;
    final volume = controller?.value.volume;
    final volumeLevel = volume != null ? (volume * 100).round() : null;
    _safeReport(
      () => _service.reportPlaybackPosition(
        itemId: widget.item.id,
        positionTicks: positionTicks,
        mediaSourceId: widget.item.id,
        playSessionId: _playSessionId,
        isPaused: isPaused,
        volumeLevel: volumeLevel,
        playMethod: 'DirectPlay',
        eventName: isPauseEvent ? 'Pause' : 'TimeUpdate',
        serverUrl: _authServerUrl(),
        token: _authToken(),
      ),
      'reportPlaybackPosition',
    );

    // 同步 MediaSession 位置：与 Emby 上报同频（每 5 秒或暂停时），
    // 使锁屏进度条与实际播放位置保持一致
    // 注意：节流 return 时不会执行到此，避免无谓的 MediaSession 写入
    final audioHandler = ref.read(audioHandlerProvider);
    audioHandler.updatePlaybackState(
      isPlaying: !isPaused,
      position: position ?? Duration.zero,
    );
  }

  void _reportPlaybackStopped() {
    if (_hasStoppedReported) return;
    _hasStoppedReported = true;
    final controller = _videoController;
    final position = controller?.value.position;
    final positionTicks =
        position != null ? position.inMilliseconds * 10000 : 0;
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

    // 清除 MediaSession：播放停止后通知栏移除播放控件，
    // 避免锁屏仍显示已结束媒体的播放按钮
    final audioHandler = ref.read(audioHandlerProvider);
    audioHandler.updatePlaybackState(
      isPlaying: false,
      position: Duration.zero,
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
      } catch (e) {
        AppLogger.warn('更新观看历史缓存失败', data: {'error': e.toString()});
      }
    }
    _hasStartedReported = false;
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(_kProgressReportInterval, (_) {
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
  ///
  /// 简化说明：错误处理统一交给 [safeUnawaited] 内层的 catchError 完成，
  /// 不再额外包一层 catchError，避免冗余。operation 作为 context 传入便于日志排查。
  void _safeReport(Future<void> Function() action, String operation) {
    safeUnawaited(
      action(),
      context: 'report:$operation(itemId:${widget.item.id})',
    );
  }

  // ===== 全屏切换 =====
  // 方案 A：进入全屏页（FullscreenVideoPage）
  // - 全屏页不创建新 controller，复用 currentVideoControllerProvider
  // - 进度 100% 不丢，零额外内存
  // - 退出全屏用系统返回键，PopScope 自动处理
  Future<void> _openFullscreenPage() async {
    final success = await FullscreenNavigator.open(
      ref: ref,
      context: context,
      onExit: () {
        if (mounted) {
          ref.read(toolbarVisibilityProvider.notifier).show();
          ref.read(isFullscreenProvider.notifier).state = false;
          // 退出全屏后重新隐藏系统栏（全屏页 dispose 时会恢复 edgeToEdge）
          // feed 模式需要保持沉浸式
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        }
      },
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('视频正在准备中，请稍后'),
          behavior: SnackBarBehavior.floating,
          duration: _kSnackBarDuration,
        ),
      );
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
    _controlsHideTimer =
        Timer(const Duration(seconds: _controlsAutoHideSeconds), _hideControls);
  }

  void _hideControls() {
    _controlsHideTimer?.cancel();
    if (mounted) setState(() => _controlsVisible = false);
  }

  // ===== 播放/暂停切换 =====
  // 统一 try/catch：controller 可能已被 VideoPlayerWidget 释放（非当前页
  // 背景延迟释放后用户立即点击），对已 dispose 的 controller 调用
  // play/pause 会走平台通道抛 PlatformException，未捕获将导致闪退。
  void _togglePlay() {
    final controller = _videoController;
    if (controller == null) return;
    try {
      if (controller.value.isPlaying) {
        controller.pause();
        ref.read(isPlayingProvider.notifier).state = false;
        // 暂停时显示▶播放图标，不自动隐藏（用户需要点击恢复播放）
        if (!ref.read(isAutoPlayProvider)) {
          _centerButtonHideTimer?.cancel();
          if (mounted) setState(() => _centerButtonVisible = true);
        }
      } else {
        controller.play();
        ref.read(isPlayingProvider.notifier).state = true;
        // 播放时立即隐藏中央按钮（不显示⏸）
        if (!ref.read(isAutoPlayProvider)) {
          _centerButtonHideTimer?.cancel();
          if (mounted) setState(() => _centerButtonVisible = false);
        }
      }
    } catch (e) {
      AppLogger.warn('播放/暂停操作失败，controller 可能已释放',
          data: {'itemId': widget.item.id, 'error': e.toString()});
    }
  }

  // ===== 分享 =====
  Future<void> _shareItem() async {
    final item = widget.item;
    final url = item.playbackUrl;
    final String text;
    if (url != null && url.isNotEmpty) {
      text = '${item.title}\n$url\n（来自 EmbyTok）';
    } else {
      text = '${item.title}\n（来自 EmbyTok）';
    }
    try {
      await Share.share(text, subject: item.title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e'), duration: _kSnackBarDuration),
        );
      }
    }
  }

  // ===== 删除确认 =====
  Future<void> _showDeleteConfirmDialog() async {
    final confirmed =
        await sheet_utils.showDeleteConfirmDialog(context, widget.item.title);
    if (confirmed) {
      // 提前获取认证信息并判空，避免 token 过期/丢失时强制断言崩溃
      final serverUrl = _authServerUrl();
      final token = _authToken();
      if (serverUrl == null || token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('认证信息缺失，请重新登录后再试'),
              duration: _kSnackBarDuration,
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('已删除'), duration: _kSnackBarDuration));
          // 从视频列表中移除当前 item，避免用户反向滑回已删除的视频
          ref.read(videoListProvider.notifier).removeItem(widget.item.id);
          widget.onVideoEnded?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e'), duration: _kAnimationNormal),
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final embyServerUrl = authState.embyServerUrl;
    final token = authState.token;
    // 使用 select 仅监听当前 item 的就绪状态，避免其他 item 就绪状态变化时触发重建
    final isReady =
        ref.watch(videoReadyProvider.select((s) => s.contains(widget.item.id)));
    final isAutoPlay = ref.watch(isAutoPlayProvider);
    final toolbarVisible = ref.watch(toolbarVisibilityProvider);
    // 监听全屏状态：进入全屏时隐藏本页 UI 控件，但 VideoPlayer 保持渲染
    // 画面通过透明 FullscreenVideoPage 覆盖层显示，避免纹理释放/重新注册导致黑屏
    final isInFullscreen = ref.watch(isFullscreenProvider);
    // 监听全屏页的重试请求：ref.listen 必须在 build 中调用，
    // Riverpod 会自动管理订阅生命周期（initState 中调用会触发 debugDoingBuild 断言）
    ref.listen<String?>(videoRetryRequestProvider, (prev, next) {
      if (next != null && next == widget.item.id) {
        _videoPlayerKey.currentState?.retryInitialization();
        // 清除请求，避免重复触发
        ref.read(videoRetryRequestProvider.notifier).state = null;
      }
    });
    final scheme = Theme.of(context).colorScheme;
    // 沉浸式（immersiveSticky）下 MediaQuery.padding 会被系统置 0，
    // 但物理刘海 / 手势条仍存在，故用 SafeInsets 取物理避让值。
    final bottomPadding = SafeInsets.bottomOf(context);

    double rs(double base, [double maxScale = 1.7]) =>
        responsiveSize(context, base, maxScale);

    // 封面图 URL（用于唱片按钮）
    final posterUrl =
        widget.item.primaryUrl(embyServerUrl: embyServerUrl, apiKey: token) ??
            '';
    final posterHeaders = widget.item.authHeaders(token);

    // ============ 主 Stack ============
    final content = Stack(
      fit: StackFit.expand,
      children: [
        // 骨架占位：视频未 ready 时显示渐变色块
        AnimatedContainer(
          duration: _kAnimationFast,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isReady
                  ? [Colors.transparent, Colors.transparent]
                  : [scheme.surface.withValues(alpha: 0.7), scheme.surface],
            ),
          ),
        ),

        // 视频播放区（Gestures + VideoPlayer）
        // 全屏时 VideoPlayer 保持渲染，画面通过透明 FullscreenVideoPage 覆盖层显示，
        // 避免移除 VideoPlayer 后 Texture 无法重新注册导致黑屏
        // RepaintBoundary：视频渲染是独立图层，与控制层隔离，避免控制层状态变化触发视频重绘
        RepaintBoundary(
          child: AnimatedOpacity(
            opacity: isReady ? 1.0 : 0.0,
            duration: _kAnimationFast,
            curve: Curves.easeOut,
            child: GestureOverlay(
              controller: _videoController,
              item: widget.item,
              enableGestures: !_controlsVisible,
              onSingleTap: () {
                if (isAutoPlay) {
                  // 纯净模式：单击屏幕切换控制条显示/隐藏，与全屏页行为一致
                  // 用户可通过控制条暂停/播放、拖动进度、调节倍速、切换字幕等
                  _toggleControls();
                  _cleanActionsKey.currentState?.show();
                } else {
                  // 非纯净模式：单击切换播放/暂停
                  // 信息条始终可见，无需单击控制显隐
                  _togglePlay();
                }
              },
              child: VideoPlayerWidget(
                key: _videoPlayerKey,
                item: widget.item,
                isCurrentPage: widget.isCurrentPage,
                embyServerUrl: embyServerUrl,
                token: token,
                preloadedController: widget.preloadedSession?.controller,
                startFromResumePosition: widget.startFromResumePosition,
                onControllerReleased: () {
                  // 修复：deactivate() 中已清理 Provider 状态，dispose 阶段不再重复清理。
                  // 避免 VideoPlayerWidget.dispose → _releaseCurrentController → 此回调
                  // 时 ref.read 访问已 deactivate 的 widget ancestor 导致断言失败。
                  if (_providerCleaned) return;
                  ref.read(videoReadyProvider.notifier).clear(widget.item.id);
                  // 关键修复：controller 被 VideoPlayerWidget 释放时，必须清除本组件的引用，
                  // 否则 _videoController 会指向已 dispose 的 controller，
                  // 导致 didUpdateWidget 中 _startPlaybackIfCurrent() 对已 dispose 的 controller
                  // 调用 play() 无效，视频无法播放。
                  // 同时移除 listener 避免对已 dispose 的 controller 持有 listener 造成泄漏。
                  if (!mounted) return;
                  final old = _videoController;
                  if (old != null) {
                    try {
                      old.removeListener(_onVideoChanged);
                    } catch (e) {
                      AppLogger.warn('移除视频控制器监听器失败',
                          data: {'error': e.toString()});
                    }
                    // 同步清除 currentVideoControllerProvider（如果持有相同引用）
                    // 否则 FullscreenNavigator.open 会拿到已 dispose 的 controller，
                    // 进入全屏页后 isControllerReady=false，导致黑屏
                    final current = ref.read(currentVideoControllerProvider);
                    if (current != null && identical(current, old)) {
                      ref.read(currentVideoControllerProvider.notifier).state =
                          null;
                    }
                  }
                  setState(() => _videoController = null);
                },
                onControllerReady: (c) {
                  // 异步回调中 setState 前必须检查 mounted，避免 widget 已销毁时抛异常
                  if (!mounted) return;
                  // 判断是否为新的 controller 实例（非当前持有的）
                  // 场景：首次初始化（_videoController==null）、controller 被释放后重新初始化、
                  // 用户切换画质后 _userInitiatedReinit 创建新 controller
                  final isNewController = !identical(_videoController, c);
                  // 切换 controller 前先移除旧 controller 上的 listener，
                  // 避免内存泄漏和旧 controller 状态变化时误触发 _onVideoChanged
                  if (isNewController && _videoController != null) {
                    _videoController!.removeListener(_onVideoChanged);
                  }
                  setState(() => _videoController = c);
                  ref
                      .read(videoReadyProvider.notifier)
                      .markReady(widget.item.id);
                  c.addListener(_onVideoChanged);
                  // 仅当前页启动播放上报/进度上报，避免相邻预加载页并发有声播放与重复上报
                  if (widget.isCurrentPage) {
                    // 如果是新 controller 实例，重置上报状态并重新上报
                    if (isNewController) {
                      // 先上报旧会话结束（如果之前有开始上报过）
                      if (_hasStartedReported && !_hasStoppedReported) {
                        _reportPlaybackStopped();
                      }
                      _hasStartedReported = false;
                      _hasStoppedReported = false;
                      _playSessionId = null;
                      _lastProgressReport =
                          DateTime.fromMicrosecondsSinceEpoch(0);
                    }
                    // _startPlaybackIfCurrent 现为 async（需等待服务端进度拉取与 seek），
                    // 此处为 controller 就绪回调上下文，使用 safeUnawaited fire-and-forget
                    safeUnawaited(
                      _startPlaybackIfCurrent(),
                      context:
                          'onControllerReady._startPlaybackIfCurrent(itemId:${widget.item.id})',
                    );
                  }
                },
              ),
            ),
          ),
        ),

        // 全屏时隐藏所有 UI 控件，VideoPlayer 保持渲染
        // 画面通过透明 FullscreenVideoPage 覆盖层显示
        if (!isInFullscreen) ...[
          // 中央播放/暂停按钮 —— 独立子组件，仅监听 isPlayingProvider 避免父组件过度重建
          // 非纯净模式：单击切换播放/暂停后显示，2秒后自动隐藏
          // 纯净模式：不显示（由 VideoControls 控制条操作）
          _CenterPlayButtonWrapper(
            controller: _videoController,
            onPlay: _togglePlay,
            visible: _centerButtonVisible,
            isAutoPlay: isAutoPlay,
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
          if (_videoController != null &&
              _videoController!.value.isInitialized &&
              (isAutoPlay))
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
                    onToggleFullscreen: _openFullscreenPage,
                    isInFullscreen: false,
                    compact: true,
                    onSeekStart: () {
                      _controlsHideTimer?.cancel();
                    },
                    onSeekEnd: () {
                      _controlsHideTimer?.cancel();
                      _controlsHideTimer = Timer(
                        const Duration(seconds: _controlsAutoHideSeconds),
                        _hideControls,
                      );
                    },
                  ),
                ),
              ),
            ),
        ],

        // 底部渐变 + 标题/简介/类型标签（非纯净模式）
        if ((_isInfoExpanded || !isAutoPlay) && !isInFullscreen)
          _BottomInfoBar(
            item: widget.item,
            controller: _videoController,
            isVisible: _isInfoVisible,
            toolbarVisible: toolbarVisible,
            bottomPadding: bottomPadding,
            onToggleFullscreen: _openFullscreenPage,
            formatDuration: _formatDuration,
          ),

        // 右侧操作按钮（非纯净模式）
        if (!isAutoPlay && !isInFullscreen)
          _RightActionButtons(
            item: widget.item,
            controller: _videoController,
            discRotation: _discRotation,
            posterUrl: posterUrl,
            posterHeaders: posterHeaders,
            toolbarVisible: toolbarVisible,
            bottomPadding: bottomPadding,
            onToggleFullscreen: _openFullscreenPage,
            onInfoTap: () {
              setState(() => _isInfoExpanded = !_isInfoExpanded);
              sheet_utils.showVideoInfoSheet(context, widget.item);
            },
            onDeleteTap: _showDeleteConfirmDialog,
            onShareTap: _shareItem,
            onCommentTap: () => showVideoCommentsSheet(context, widget.item.id),
            onSpeedTap: () =>
                sheet_utils.showSpeedControlPanel(context, _videoController),
            onSubtitleTap: () => sheet_utils.showSubtitleSelector(
                context, widget.item.subtitleTracks),
          ),

        // 纯净模式：可拖动按钮组
        if (isAutoPlay && !isInFullscreen)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return DraggableCleanActions(
                  key: _cleanActionsKey,
                  containerSize:
                      Size(constraints.maxWidth, constraints.maxHeight),
                  buttonWidth: rs(80, 2.0),
                  bottomSafeArea: bottomPadding + 80 + 16,
                  rightSafeArea: 16,
                  buttons: Container(
                    padding: const EdgeInsets.all(_kSpacingLarge),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 只保留纯净模式开关，移除倍速按钮等其他功能
                        AutoPlayButton(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // 顶部操作区：全屏模式下控制条已有退出按钮，无需额外入口

        // NextUp 自动播放提示条和下一集按钮已移除
        // 用户需要手动滑动切换到下一个视频
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
class PlaybackShell extends ConsumerStatefulWidget {
  // 数据源标识，用于观看统计，默认 'feed'

  const PlaybackShell({
    super.key,
    required this.item,
    this.items = const [],
    required this.onBack,
    this.source = 'feed',
  });
  final MediaItem item; // 当前播放的视频
  final List<MediaItem> items; // 视频列表（可选）
  final VoidCallback onBack; // 返回回调
  final String source;

  @override
  ConsumerState<PlaybackShell> createState() => _PlaybackShellState();
}
