// 全屏播放页（点击 mini player 展开，参考 QQ音乐/酷狗音乐交互）
//
// 功能：
// - 大封面旋转动画（播放时旋转，暂停静止）
// - 点击封面 ↔ 歌词 切换视图（LRC 滚动高亮当前行）
// - 底部进度条可拖动 + 时间显示
// - 播放控制：模式 / 上一首 / 播放暂停 / 下一首 / 停止

import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audio_models.dart';
import '../providers/download_provider.dart';
import '../providers/providers.dart';
import '../utils/image_cache_manager.dart';
import '../utils/lrc_parser.dart';

/// 打开全屏播放页
Future<void> showFullPlayerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _FullPlayerSheet(),
  );
}

class _FullPlayerSheet extends ConsumerStatefulWidget {
  const _FullPlayerSheet();

  @override
  ConsumerState<_FullPlayerSheet> createState() => _FullPlayerSheetState();
}

class _FullPlayerSheetState extends ConsumerState<_FullPlayerSheet> {
  /// 当前显示封面还是歌词
  bool _showLyrics = false;

  /// 拖动进度中暂存的本地值（null=未拖动）
  double? _dragValue;

  final _lyricsController = ScrollController();

  @override
  void dispose() {
    _lyricsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(synologyPlaybackProvider);
    final song = state.currentSong;
    if (song == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final notifier = ref.read(synologyPlaybackProvider.notifier);
    final lyricsLines =
        state.lyrics == null ? const <LrcLine>[] : parseLrc(state.lyrics!);

    // 深色渐变背景（全屏播放页氛围）
    final background = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF101B2E),
            Color(0xFF1A2E4A),
            Color(0xFF10203A),
          ],
        ),
      ),
    );

    return SizedBox(
      height: MediaQuery.sizeOf(context).height,
      child: Stack(
        children: [
          background,
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(song, scheme),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showLyrics = !_showLyrics),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _showLyrics
                          ? _buildLyricsView(
                              lyricsLines, state.position, scheme)
                          : _buildCoverView(song, state, scheme),
                    ),
                  ),
                ),
                _buildProgressArea(state, notifier, scheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================
  // 顶部
  // ============================

  Widget _buildTopBar(AudioSong song, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            tooltip: '收起',
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  song.artistDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // 睡眠定时器入口
          Consumer(
            builder: (context, ref, _) {
              final st = ref.watch(synologyPlaybackProvider);
              final active = st.sleepTimerActive;
              final mins = st.sleepTimerRemainingSeconds ~/ 60;
              return IconButton(
                icon: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      active ? Icons.bedtime : Icons.bedtime_outlined,
                      color: active ? Colors.amberAccent : Colors.white,
                    ),
                    if (active)
                      Positioned(
                        bottom: 0,
                        child: Text(
                          '${mins}m',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                tooltip: active ? '睡眠定时器（剩余 $mins 分钟）' : '睡眠定时器',
                onPressed: () => _showSleepTimerSheet(context),
              );
            },
          ),
          // 下载当前歌曲到本地（离线播放）
          IconButton(
            icon: const Icon(Icons.download_for_offline_outlined,
                color: Colors.white),
            tooltip: '下载到本地',
            onPressed: () {
              final s = ref.read(synologyPlaybackProvider).currentSong;
              if (s == null) return;
              ref.read(downloadProvider.notifier).enqueue(s);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已加入下载队列，可在"我的-下载管理"查看'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: '停止播放',
            onPressed: () {
              ref.read(synologyPlaybackProvider.notifier).stop();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // ============================
  // 睡眠定时器设置
  // ============================

  Future<void> _showSleepTimerSheet(BuildContext context) async {
    final notifier = ref.read(synologyPlaybackProvider.notifier);
    final current = ref.read(synologyPlaybackProvider);

    int? selectedMinutes; // null = 关闭
    var behavior = current.sleepTimerBehavior;
    var fadeOut = current.sleepTimerFadeOut;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (_, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text('睡眠定时器',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  if (current.sleepTimerActive)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '当前剩余：${current.sleepTimerRemainingSeconds ~/ 60} 分钟 '
                        '${current.sleepTimerRemainingSeconds % 60} 秒',
                        style: const TextStyle(color: Colors.amber, fontSize: 13),
                      ),
                    ),
                  // 快捷时长
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final m in const [0, 15, 30, 45, 60])
                        ChoiceChip(
                          label: Text(m == 0 ? '关闭' : '$m 分钟'),
                          selected: selectedMinutes == m,
                          onSelected: (_) => setLocal(() => selectedMinutes = m),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('到点行为',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  RadioListTile<SleepTimerBehavior>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('立即停止播放'),
                    value: SleepTimerBehavior.immediateStop,
                    groupValue: behavior,
                    onChanged: (v) =>
                        setLocal(() => behavior = v ?? SleepTimerBehavior.immediateStop),
                  ),
                  RadioListTile<SleepTimerBehavior>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('当前歌曲结束后停止'),
                    value: SleepTimerBehavior.currentSongEnd,
                    groupValue: behavior,
                    onChanged: (v) =>
                        setLocal(() => behavior = v ?? SleepTimerBehavior.currentSongEnd),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('停止前 30 秒渐进淡出'),
                    value: fadeOut,
                    onChanged: (v) => setLocal(() => fadeOut = v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (selectedMinutes == null) {
                          // 未选：若当前有定时则取消
                          await notifier.cancelSleepTimer();
                        } else if (selectedMinutes == 0) {
                          await notifier.cancelSleepTimer();
                        } else {
                          await notifier.startSleepTimer(
                            duration: Duration(minutes: selectedMinutes!),
                            behavior: behavior,
                            fadeOut: fadeOut,
                          );
                        }
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                      child: Text(selectedMinutes == null || selectedMinutes == 0
                          ? '取消定时器'
                          : '开始定时'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================
  // 封面视图（旋转动画）
  // ============================

  Widget _buildCoverView(
      AudioSong song, SynologyPlaybackState state, ColorScheme scheme) {
    final coverUrl = state.coverUrl;
    return Center(
      child: _RotatingCover(
        playing: state.isPlaying && !state.isLoading,
        coverUrl: coverUrl,
        fallbackIcon: Icons.music_note,
      ),
    );
  }

  // ============================
  // 歌词视图（LRC 滚动高亮）
  // ============================

  Widget _buildLyricsView(
      List<LrcLine> lines, Duration position, ColorScheme scheme) {
    final active = activeLrcIndex(lines, position);
    if (lines.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: 48,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              '暂无歌词',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // 高亮行滚动到视口中部
    final target = active < 0 ? 0 : active;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_lyricsController.hasClients) return;
      const itemExtent = 44.0;
      final offset = target * itemExtent -
          (MediaQuery.sizeOf(context).height * 0.32 - itemExtent / 2);
      if ((_lyricsController.offset - offset).abs() > 4) {
        _lyricsController.animateTo(
          offset.clamp(0.0, _lyricsController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: _lyricsController,
      padding: EdgeInsets.symmetric(
        vertical: MediaQuery.sizeOf(context).height * 0.30,
      ),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final isActive = index == active;
        final line = lines[index];
        return Container(
          height: 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            line.text.isEmpty ? '♪' : line.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isActive ? 17 : 14,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.45),
              height: 1.3,
            ),
          ),
        );
      },
    );
  }

  // ============================
  // 底部进度 + 控制
  // ============================

  Widget _buildProgressArea(SynologyPlaybackState state,
      SynologyPlaybackNotifier notifier, ColorScheme scheme) {
    final durationMs = state.duration.inMilliseconds;
    final currentMs = _dragValue != null
        ? _dragValue! * durationMs
        : state.position.inMilliseconds.toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF2C8EF4),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF2C8EF4).withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value:
                  durationMs > 0 ? (currentMs / durationMs).clamp(0.0, 1.0) : 0,
              onChangeStart: (_) => setState(
                  () => _dragValue = currentMs / math.max(durationMs, 1)),
              onChanged: (v) => setState(() => _dragValue = v),
              onChangeEnd: (v) {
                ref
                    .read(synologyPlaybackProvider.notifier)
                    .seekTo(Duration(milliseconds: (v * durationMs).round()));
                setState(() => _dragValue = null);
              },
            ),
          ),
          // 时间
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatDuration(Duration(milliseconds: currentMs.round())),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  formatDuration(state.duration),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 控制按钮（FittedBox 缩放：极端窄屏 <360dp 时整体等比缩小，不溢出）
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    switch (state.mode) {
                      SynologyPlaybackMode.listLoop => Icons.repeat,
                      SynologyPlaybackMode.singleLoop => Icons.repeat_one,
                      SynologyPlaybackMode.shuffle => Icons.shuffle,
                    },
                    size: 22,
                  ),
                  color: state.mode == SynologyPlaybackMode.listLoop
                      ? Colors.white.withValues(alpha: 0.5)
                      : const Color(0xFF2C8EF4),
                  tooltip: '播放模式：${state.mode.label}',
                  onPressed: notifier.cycleMode,
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 34),
                  color: Colors.white,
                  tooltip: '上一首',
                  onPressed: state.currentIndex > 0 ? notifier.previous : null,
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(
                    state.isLoading
                        ? Icons.hourglass_top
                        : state.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                    size: 62,
                  ),
                  color: const Color(0xFF2C8EF4),
                  tooltip: state.isPlaying ? '暂停' : '播放',
                  onPressed: state.isLoading ? null : notifier.togglePlay,
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 34),
                  color: Colors.white,
                  tooltip: '下一首',
                  onPressed: state.currentIndex < state.queue.length - 1
                      ? notifier.next
                      : null,
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined, size: 24),
                  color: Colors.white.withValues(alpha: 0.6),
                  tooltip: '停止',
                  onPressed: notifier.stop,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================
// 旋转封面
// ============================

class _RotatingCover extends StatefulWidget {

  const _RotatingCover({
    required this.playing,
    required this.coverUrl,
    required this.fallbackIcon,
  });
  final bool playing;
  final String? coverUrl;
  final IconData fallbackIcon;

  @override
  State<_RotatingCover> createState() => _RotatingCoverState();
}

class _RotatingCoverState extends State<_RotatingCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _RotatingCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.playing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 封面尺寸 = 宽 68% 与可用高度的较小值：
    // - 常规竖屏：68% 宽度（视觉为主）
    // - 矮屏/横屏/小屏：受高度约束，避免超出 Expanded 区域溢出
    final mq = MediaQuery.sizeOf(context);
    final size = math.min(mq.width * 0.68, mq.height * 0.42);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.rotate(
        angle: _controller.value * 2 * math.pi,
        child: child,
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipOval(
          child: widget.coverUrl != null
              ? CachedNetworkImage(
                  imageUrl: widget.coverUrl!,
                  fit: BoxFit.cover,
                  cacheManager: AppImageCacheManager.thumbnail,
                  errorWidget: (_, __, ___) => _fallback(),
                )
              : _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFF2A3D5C),
      child: Icon(
        widget.fallbackIcon,
        color: Colors.white.withValues(alpha: 0.7),
        size: 72,
      ),
    );
  }
}
