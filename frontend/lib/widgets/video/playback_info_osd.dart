// 播放信息 OSD 浮层
//
// 多播放器 PRD 第二轮 P1：实时显示当前引擎、视频编码、分辨率、HDR/杜比格式。
// 通过设置开关控制（默认关闭），在视频流左上角半透明叠加。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/media_item.dart';
import '../../providers/player_engine_provider.dart';

/// 播放信息 OSD 显示开关
///
/// 持久化到 SharedPreferences，用户可在设置中切换。
final playbackInfoOsdProvider = StateProvider<bool>((ref) => false);

/// 播放信息 OSD 浮层
///
/// 半透明黑底白字，叠加在视频左上角，不遮挡主要操作区。
class PlaybackInfoOsd extends ConsumerWidget {
  const PlaybackInfoOsd({
    super.key,
    required this.item,
  });

  /// 当前播放的媒体项
  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(playbackInfoOsdProvider);
    if (!show) return const SizedBox.shrink();

    final engine = ref.watch(
      playerEngineSettingsProvider.select((s) => s.defaultEngine),
    );
    final engineLabel = switch (engine) {
      PlayerEngine.mpv => 'MPV',
      PlayerEngine.exo => 'EXO',
      PlayerEngine.vlc => 'VLC',
      PlayerEngine.external => '外部',
      PlayerEngine.auto => item.isDolbyVision || item.isHdr ? 'MPV(auto)' : 'EXO(auto)',
    };

    final streams = item.primaryMediaSource?.mediaStreams
            .where((s) => s.type == 'Video')
            .toList() ??
        const [];
    final video = streams.isNotEmpty ? streams.first : null;

    final codec = video?.codec?.toUpperCase() ?? '?';
    final width = item.videoWidth ?? 0;
    final height = item.videoHeight ?? 0;
    final res = width > 0 ? '${width}x$height' : '?';
    final hdr = item.isDolbyVision
        ? 'DV'
        : item.isHdr
            ? 'HDR'
            : 'SDR';

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$engineLabel · $codec · $res · $hdr',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
