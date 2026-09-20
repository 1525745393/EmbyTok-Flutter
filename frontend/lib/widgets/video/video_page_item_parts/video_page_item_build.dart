// 从 video_page_item.dart 拆分（part 文件，无行为变化）

part of '../video_page_item.dart';

// ==================== build 实现 ====================

extension _VideoPageItemBuild on _VideoPageItemState {
  Widget _buildPage(BuildContext context) {
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
                        const Duration(
                            seconds:
                                _VideoPageItemState._controlsAutoHideSeconds),
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
