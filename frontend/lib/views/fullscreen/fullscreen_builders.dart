// 从 fullscreen_video_page.dart 拆分（part 文件，无行为变化）

part of '../fullscreen_video_page.dart';

// ==================== _FullscreenBuilders ====================

extension _FullscreenBuilders on _FullscreenVideoPageState {
  Widget _buildErrorState(VideoPlayerController? controller) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 56),
          const SizedBox(height: _kSpacingLarge),
          const Text(
            '视频加载失败',
            style: TextStyle(color: Colors.white70, fontSize: _kFontSizeLarge),
          ),
          const SizedBox(height: _kSpacingMedium),
          Text(
            controller?.value.errorDescription ?? '网络错误或资源不可用',
            style: const TextStyle(
                color: Colors.white54, fontSize: _kFontSizeBody),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _kSpacingXLarge),
          TextButton.icon(
            onPressed: _retryVideo,
            icon: const Icon(Icons.refresh, size: 20),
            label:
                const Text('重试', style: TextStyle(fontSize: _kFontSizeLarge)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white24,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(MediaItem? playingItem, bool isActuallyLandscape) {
    final IconData orientIcon;
    final String orientTooltip;
    switch (_orientationPref) {
      case _OrientationPref.landscape:
        orientIcon = Icons.screen_lock_portrait;
        orientTooltip = '切换竖屏';
        break;
      case _OrientationPref.portrait:
        orientIcon = Icons.screen_rotation;
        orientTooltip = '跟随系统';
        break;
      case _OrientationPref.sensor:
        orientIcon = Icons.screen_lock_landscape;
        orientTooltip = '锁定横屏';
        break;
    }

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      // 沉浸式（immersiveSticky）下 MediaQuery.padding 被系统置 0，SafeArea 失效；
      // 改用 SafeInsets 取物理刘海/挖孔避让值，确保横屏左右刘海与顶部刘海均被避开
      child: Padding(
        padding: EdgeInsets.only(
          left: SafeInsets.leftOf(context),
          top: SafeInsets.topOf(context),
          right: SafeInsets.rightOf(context),
        ),
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: kToolbarAnimMs),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.fullscreen_exit,
                      color: Colors.white, size: 28),
                  onPressed: () {
                    widget.onExit?.call();
                    Navigator.of(context).pop();
                  },
                  tooltip: '退出全屏',
                ),
                if (playingItem != null)
                  Expanded(
                    child: Text(
                      playingItem.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: _kFontSizeLarge,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                IconButton(
                  icon: Icon(orientIcon, color: Colors.white, size: 24),
                  onPressed: _toggleOrientation,
                  tooltip: orientTooltip,
                ),
                IconButton(
                  icon:
                      const Icon(Icons.settings, color: Colors.white, size: 24),
                  onPressed: () => _toggleSettingsPanel(_SettingsTab.speed),
                  tooltip: '设置',
                ),
                IconButton(
                  icon: const Icon(Icons.lock_open,
                      color: Colors.white, size: 24),
                  onPressed: _lockScreen,
                  tooltip: '锁屏',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    VideoPlayerController controller,
    MediaItem? playingItem,
    List<MediaItem> items,
  ) {
    // 绑定最新 controller 的 seekTo，确保拖动结束时 seek 到当前 controller
    _sliderSeekHandler.seekTo = controller.seekTo;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      // 沉浸式（immersiveSticky）下 MediaQuery.padding 被系统置 0，SafeArea 失效；
      // 改用 SafeInsets 取物理避让值，确保底部进度条不被手势条遮挡、横屏左右不被侧边刘海遮挡
      child: Padding(
        padding: EdgeInsets.only(
          left: SafeInsets.leftOf(context),
          right: SafeInsets.rightOf(context),
          bottom: SafeInsets.bottomOf(context),
        ),
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: kToolbarAnimMs),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    final position = value.position;
                    final duration = value.duration;
                    final progress = duration.inMilliseconds > 0
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 0.0;
                    // 拖动期间显示预览时间，否则显示真实播放位置
                    final previewMs = _sliderSeekHandler.seekPreviewMs;
                    final displayPosition = previewMs != null
                        ? Duration(milliseconds: previewMs.round())
                        : position;
                    return Row(
                      children: [
                        Text(
                          _formatDuration(displayPosition),
                          style: const TextStyle(
                              color: Colors.white, fontSize: _kFontSizeSmall),
                        ),
                        const SizedBox(width: _kSpacingMedium),
                        Expanded(
                          child: Slider(
                            value: progress.clamp(0.0, 1.0),
                            // 拖动开始：标记进入拖动状态，初始化预览
                            onChangeStart: (_) {
                              _sliderSeekHandler.startDrag();
                              setState(() {});
                            },
                            // 拖动中：仅更新预览时间，不发起 seek（防抖核心）
                            onChanged: (v) {
                              setState(() {
                                _sliderSeekHandler.updateDrag(v, duration);
                              });
                            },
                            // 拖动结束：触发一次 seekTo 并清除预览
                            onChangeEnd: (v) {
                              _sliderSeekHandler.endDrag(v, duration);
                              setState(() {});
                            },
                            activeColor: Theme.of(context).colorScheme.primary,
                            inactiveColor: Colors.white24,
                          ),
                        ),
                        const SizedBox(width: _kSpacingMedium),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: _kFontSizeSmall),
                        ),
                      ],
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.skip_previous, color: Colors.white),
                      onPressed: _hasPrevious() ? _jumpToPrevious : null,
                    ),
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: controller,
                      builder: (context, value, child) {
                        return IconButton(
                          icon: Icon(
                            value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: Colors.white,
                            size: 44,
                          ),
                          onPressed: () {
                            if (value.isPlaying) {
                              controller.pause();
                            } else {
                              controller.play();
                            }
                          },
                        );
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.subtitles,
                          color: Colors.white, size: 22),
                      onPressed: playingItem != null
                          ? () => _showSubtitleMenu(playingItem)
                          : null,
                      tooltip: '字幕',
                    ),
                    IconButton(
                      icon: ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: controller,
                        builder: (context, value, child) {
                          return Text(
                            '${value.playbackSpeed.toStringAsFixed(1)}x',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: _kFontSizeBody,
                                fontWeight: FontWeight.w600),
                          );
                        },
                      ),
                      onPressed: () => _toggleSettingsPanel(_SettingsTab.speed),
                      tooltip: '倍速',
                    ),
                    IconButton(
                      icon: const Icon(Icons.aspect_ratio,
                          color: Colors.white, size: 22),
                      onPressed: () => _toggleSettingsPanel(_SettingsTab.ratio),
                      tooltip: '画面比例',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsPanel(VideoPlayerController controller) {
    // 沉浸式下 SafeArea 失效（padding 被置 0），改用 SafeInsets 避让物理刘海
    final safeInsets = SafeInsets.of(context);
    return Positioned(
      right: kSpacingLg + safeInsets.right,
      bottom: kFullscreenSettingsPanelBottom + safeInsets.bottom,
      child: AnimatedOpacity(
        opacity: _showSettingsPanel ? 1.0 : 0.0,
        duration: const Duration(milliseconds: kToolbarAnimMs),
        child: Container(
          width: kFullscreenSettingsPanelWidth,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSettingsTabBar(),
              const Divider(color: Colors.white24, height: 1),
              _buildSettingsContent(controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTabBar() {
    return Row(
      children: _SettingsTab.values.map((tab) {
        final selected = _settingsTab == tab;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _settingsTab = tab),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Icon(
                _tabIcon(tab),
                color: selected ? Colors.white : Colors.white54,
                size: 20,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSettingsContent(VideoPlayerController controller) {
    switch (_settingsTab) {
      case _SettingsTab.speed:
        return _buildSpeedList(controller);
      case _SettingsTab.ratio:
        return _buildRatioList();
    }
  }

  Widget _buildSpeedList(VideoPlayerController controller) {
    const rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final currentRate = ref.watch(playbackRateProvider);
    return Column(
      children: rates.map((rate) {
        final selected = (rate - currentRate).abs() < kPlaybackRateTolerance;
        return _SettingsListItem(
          label:
              '${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 2)}x',
          selected: selected,
          onTap: () {
            controller.setPlaybackSpeed(rate);
            ref.read(playbackRateProvider.notifier).state = rate;
            _startHideTimer();
          },
        );
      }).toList(),
    );
  }

  Widget _buildRatioList() {
    const modes = [
      (_AspectRatioMode.auto, '自适应'),
      (_AspectRatioMode.contain, '完整显示'),
      (_AspectRatioMode.cover, '填满裁剪'),
      (_AspectRatioMode.fill, '拉伸填充'),
      (_AspectRatioMode.sixteenNine, '16:9'),
      (_AspectRatioMode.fourThree, '4:3'),
    ];
    return Column(
      children: modes.map((m) {
        final selected = m.$1 == _aspectMode;
        return _SettingsListItem(
          label: m.$2,
          selected: selected,
          onTap: () {
            setState(() => _aspectMode = m.$1);
            _startHideTimer();
          },
        );
      }).toList(),
    );
  }

  Widget _buildLockUI() {
    // 沉浸式下 SafeArea 失效（padding 被置 0），改用 SafeInsets 避让物理刘海
    final safeInsets = SafeInsets.of(context);
    return Positioned(
      left: 12 + safeInsets.left,
      top: safeInsets.top,
      bottom: safeInsets.bottom,
      child: Center(
        child: GestureDetector(
          onTap: _unlockScreen,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, color: Colors.white, size: 28),
                SizedBox(height: _kSpacingSmall),
                Text(
                  '点击\n解锁',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: _kFontSizeTiny,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkToast() {
    return Positioned(
      // 沉浸式下 MediaQuery.padding.top 归零，改用 SafeInsets.topOf 取物理刘海高度，
      // 保证 Toast 在刘海下方 60px 处显示，不被遮挡
      top: SafeInsets.topOf(context) + 60,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 18),
              const SizedBox(width: _kSpacingMedium),
              Text(
                _networkToastMessage ?? '',
                style: const TextStyle(
                    color: Colors.white, fontSize: _kFontSizeBody),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalIndicator({
    required IconData icon,
    required double value,
    required String label,
  }) {
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 36),
              const SizedBox(height: _kSpacingMedium),
              SizedBox(
                width: kFullscreenVolumeBarWidth,
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: _kSpacingXSmall),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSubtitleMenu(MediaItem item) async {
    final selectedSubId = ref.read(selectedSubtitleProvider);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SubtitleSelector(
        tracks: item.subtitleTracks,
        selectedTrackId: selectedSubId,
        onSelected: (track) {
          if (track == null) {
            ref.read(subtitleSettingsProvider.notifier).setLanguage('');
            ref.read(selectedSubtitleProvider.notifier).state = null;
          } else {
            // 本地字幕不保存语言偏好（语言代码为 'local'）
            if (track.language != 'local') {
              ref
                  .read(subtitleSettingsProvider.notifier)
                  .setLanguage(track.language);
            }
            ref.read(selectedSubtitleProvider.notifier).state = track.id;
          }
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
