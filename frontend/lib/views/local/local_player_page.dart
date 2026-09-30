// 本地视频全屏播放页：复用 VideoPlayerWidget（三引擎），isLocal=true
// 对应 PRD《本地模式》§4.4
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/local_video_item.dart';
import '../../models/media_item.dart';
import '../../widgets/video/video_player_widget.dart';

class LocalPlayerPage extends ConsumerWidget {
  final LocalVideoItem item;
  const LocalPlayerPage({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 把 LocalVideoItem 转成 MediaItem：playbackUrl 用 file:/// 绝对路径
    // photo_manager 系统媒体库资产 path 为空，需要在播放时取 file.path
    final playbackUrl = item.isAppDirFile
        ? 'file://${item.path}'
        : 'content://media/external/video/media/${item.id}';

    final mediaItem = MediaItem(
      id: item.id,
      title: item.name,
      type: 'Movie',
      playbackUrl: playbackUrl,
      durationSeconds: item.duration.inSeconds.toDouble(),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          item.name,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: VideoPlayerWidget(
          item: mediaItem,
          isLocal: true,
          autoPlay: true,
          loop: false,
          isCurrentPage: true,
        ),
      ),
    );
  }
}
