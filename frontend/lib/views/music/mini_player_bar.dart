// 底部迷你播放栏组件
//
// 从 synology_music_view.dart 拆分出来，提升代码可维护性。
//
// 功能：
// - 显示当前播放歌曲的封面、标题、歌手
// - 播放控制：上一首/播放/暂停/下一首
// - 播放模式切换：列表循环/单曲循环/随机播放
// - 进度条显示
// - 超窄屏适配（<360px 隐藏播放模式和停止按钮）
// - 点击展开全屏播放器

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../synology_full_player.dart';
import 'music_cover_widgets.dart';

// ===== 迷你播放栏常量 =====

/// 小间距
const double kMiniPlayerSpacingSmall = 4;

/// 中等间距
const double kMiniPlayerSpacingMedium = 10;

/// 中等字体（列表项正文）
const double kMiniPlayerFontSizeBody = 13;

/// 小字体（歌手名）
const double kMiniPlayerFontSizeSmall = 11;

/// 封面尺寸
const double kMiniPlayerCoverSize = 44;

/// 进度条高度
const double kMiniPlayerProgressHeight = 2;

/// 超窄屏宽度阈值
const double kMiniPlayerNarrowWidthThreshold = 360;

/// 播放模式按钮图标尺寸
const double kMiniPlayerModeIconSize = 17;

/// 上一首/下一首按钮图标尺寸
const double kMiniPlayerSkipIconSize = 22;

/// 播放/暂停按钮图标尺寸
const double kMiniPlayerPlayIconSize = 34;

/// 停止按钮图标尺寸
const double kMiniPlayerStopIconSize = 17;

/// 按钮最小宽度
const double kMiniPlayerButtonMinWidth = 34;

/// 按钮最小高度
const double kMiniPlayerButtonMinHeight = 40;

/// 左侧水平边距
const double kMiniPlayerPaddingLeft = 12;

/// 右侧水平边距
const double kMiniPlayerPaddingRight = 4;

/// 底部垂直边距
const double kMiniPlayerPaddingBottom = 4;

/// 进度条与内容间距
const double kMiniPlayerProgressContentSpacing = 4;

/// 封面与文字间距
const double kMiniPlayerCoverTextSpacing = 10;

/// 底部迷你播放栏
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(synologyPlaybackProvider);
    final song = state.currentSong;
    if (song == null) return const SizedBox.shrink();

    final notifier = ref.read(synologyPlaybackProvider.notifier);
    // 超窄屏（<360px）隐藏播放模式和停止按钮，保留核心上一首/播放/下一首
    final isNarrow = MediaQuery.sizeOf(context).width < kMiniPlayerNarrowWidthThreshold;

    return Material(
      color: scheme.surfaceContainerHighest,
      elevation: 10,
      child: InkWell(
        onTap: () => showFullPlayerSheet(context),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              kMiniPlayerPaddingLeft,
              0,
              kMiniPlayerPaddingRight,
              kMiniPlayerPaddingBottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 进度条
                LinearProgressIndicator(
                  value: state.duration.inMilliseconds > 0
                      ? (state.position.inMilliseconds /
                              state.duration.inMilliseconds)
                          .clamp(0.0, 1.0)
                      : 0,
                  minHeight: kMiniPlayerProgressHeight,
                  backgroundColor: scheme.outlineVariant.withValues(alpha: 0.4),
                  color: scheme.primary,
                ),
                const SizedBox(height: kMiniPlayerProgressContentSpacing),
                Row(
                  children: [
                    SongCover(songId: song.id, size: kMiniPlayerCoverSize),
                    const SizedBox(width: kMiniPlayerCoverTextSpacing),
                    // 标题 + 歌手
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: kMiniPlayerFontSizeBody,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          if (song.artistDisplay.isNotEmpty)
                            Text(
                              song.artistDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: kMiniPlayerFontSizeSmall, color: scheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                    // 播放控制（紧凑布局，防窄屏溢出；超窄屏隐藏播放模式和停止按钮）
                    if (!isNarrow)
                      _compactButton(
                        scheme: scheme,
                        icon: Icon(
                          switch (state.mode) {
                            SynologyPlaybackMode.listLoop => Icons.repeat,
                            SynologyPlaybackMode.singleLoop => Icons.repeat_one,
                            SynologyPlaybackMode.shuffle => Icons.shuffle,
                          },
                          size: kMiniPlayerModeIconSize,
                        ),
                        color: state.mode == SynologyPlaybackMode.listLoop
                            ? scheme.onSurfaceVariant
                            : scheme.primary,
                        tooltip: '播放模式：${state.mode.label}',
                        onPressed: notifier.cycleMode,
                      ),
                    _compactButton(
                      scheme: scheme,
                      icon: const Icon(Icons.skip_previous, size: kMiniPlayerSkipIconSize),
                      color: scheme.onSurface,
                      tooltip: '上一首',
                      onPressed:
                          state.currentIndex > 0 ? notifier.previous : null,
                    ),
                    _compactButton(
                      scheme: scheme,
                      icon: Icon(
                        state.isLoading
                            ? Icons.hourglass_top
                            : state.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                        size: kMiniPlayerPlayIconSize,
                      ),
                      color: scheme.primary,
                      tooltip: state.isPlaying ? '暂停' : '播放',
                      onPressed: state.isLoading ? null : notifier.togglePlay,
                    ),
                    _compactButton(
                      scheme: scheme,
                      icon: const Icon(Icons.skip_next, size: kMiniPlayerSkipIconSize),
                      color: scheme.onSurface,
                      tooltip: '下一首',
                      onPressed: state.currentIndex < state.queue.length - 1
                          ? notifier.next
                          : null,
                    ),
                    if (!isNarrow)
                      _compactButton(
                        scheme: scheme,
                        icon: const Icon(Icons.close, size: kMiniPlayerStopIconSize),
                        color: scheme.onSurfaceVariant,
                        tooltip: '停止',
                        onPressed: notifier.stop,
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

  /// 紧凑播放控制按钮（压缩点击热区，避免窄屏溢出）
  Widget _compactButton({
    required ColorScheme scheme,
    required Widget icon,
    required Color color,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: icon,
      color: color,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(
        minWidth: kMiniPlayerButtonMinWidth,
        minHeight: kMiniPlayerButtonMinHeight,
      ),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }
}
