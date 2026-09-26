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
part 'video_page_item_parts/video_page_item_actions.dart';
part 'video_page_item_parts/video_page_item_build.dart';

part 'video_page_item_widgets.dart';
part 'video_page_item_shell.dart';
part 'video_page_item_reporting.dart';

/// 单个视频页：TikTok 卡片样式
// ===== UI 布局常量（避免魔法数字，提升可维护性）=====

/// 底部信息栏渐变遮罩高度
const double _kBottomInfoGradientHeight = 120;

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

  /// 播放开始时同步 MediaSession 媒体项与播放状态
  ///
  /// 字段映射说明（基于 MediaItem 实际模型，与任务描述的伪代码有差异）：
  /// - title：MediaItem.title（必填，无 name 字段）
  /// - artist：MediaItem.seriesName（无 album/artist 字段，剧集名副标题即可）
  /// - artUri：通过 primaryUrl() 构造完整 URL（含 api_key），无 primaryImageThumbUrl 字段
  /// - duration：MediaItem.runtimeTicks（小写 r），1 tick = 100ns = 0.1μs

  /// 记录观看统计（完播率）

  // ===== 视频状态变化监听 =====
  // 功耗优化：合并 _onVideoChangedForReport 逻辑，减少 controller listener 数量。
  // 位置写入 Provider 仅在跨秒时触发，避免每帧无效 Notifier 通知。

  // ===== 播放上报链方法 =====

  // ===== 认证辅助 =====
  // 缓存 auth 值，避免 dispose() 后 ref.read 抛 "Cannot use ref after disposed"
  String? _cachedServerUrl;
  String? _cachedToken;

  // 使用 ref.read 而非 ref.watch，因为这些方法在非 build 上下文中调用
  // （如 _reportPlaybackStart、_reportPlaybackProgress 等回调）
  // 只需读取当前值，不需要订阅变化触发重建
  // dispose 时返回缓存值，防止 ref after disposed 异常
  String? _authServerUrl() => _cachedServerUrl ?? ref.read(authProvider).embyServerUrl;
  String? _authToken() => _cachedToken ?? ref.read(authProvider).token;

  /// 安全执行上报类异步操作：捕获异常并记录日志，避免未捕获的 Future 错误
  /// 用于 markAsPlayed、report* 等不阻塞主流程的后台请求
  ///
  /// 简化说明：错误处理统一交给 [safeUnawaited] 内层的 catchError 完成，
  /// 不再额外包一层 catchError，避免冗余。operation 作为 context 传入便于日志排查。

  // ===== 全屏切换 =====
  // 方案 A：进入全屏页（FullscreenVideoPage）
  // - 全屏页不创建新 controller，复用 currentVideoControllerProvider
  // - 进度 100% 不丢，零额外内存
  // - 退出全屏用系统返回键，PopScope 自动处理

  // ===== 控制层显示/隐藏 =====

  // ===== 播放/暂停切换 =====
  // 统一 try/catch：controller 可能已被 VideoPlayerWidget 释放（非当前页
  // 背景延迟释放后用户立即点击），对已 dispose 的 controller 调用
  // play/pause 会走平台通道抛 PlatformException，未捕获将导致闪退。

  // ===== 分享 =====

  // ===== 删除确认 =====

  // ===== Duration 格式化 =====

  @override
  @override
  @override
  Widget build(BuildContext context) {
    // 缓存 auth 值，dispose 后上报使用缓存值避免 ref after disposed
    final auth = ref.read(authProvider);
    _cachedServerUrl = auth.embyServerUrl;
    _cachedToken = auth.token;
    return _buildPage(context);
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
