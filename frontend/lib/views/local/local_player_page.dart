// 本地视频全屏播放页：复用 VideoPlayerWidget（三引擎），isLocal=true
// 对应 PRD《本地模式》§4.4
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/local_video_item.dart';
import '../../models/media_item.dart';
import '../../widgets/video/video_player_widget.dart';

class LocalPlayerPage extends ConsumerWidget {
  final LocalVideoItem item;
  const LocalPlayerPage({super.key, required this.item});

  /// 分享本地视频文件（P1）
  Future<void> _share(BuildContext context) async {
    try {
      final path = item.isAppDirFile ? item.path : null;
      if (path == null || path.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('系统媒体库文件暂不支持分享')),
          );
        }
        return;
      }
      await Share.shareXFiles(
        [XFile(path)],
        subject: item.name,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败：$e')),
        );
      }
    }
  }

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
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            tooltip: '分享',
            onPressed: () => _share(context),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: '详情',
            onPressed: () => _showInfo(context),
          ),
        ],
      ),
      body: Center(
        child: VideoPlayerWidget(
          item: mediaItem,
          isLocal: true,
          autoPlay: true,
          loop: false,
          isCurrentPage: true,
          externalSubtitlePaths: item.subtitlePaths,
        ),
      ),
    );
  }

  /// 详情弹窗（P1：文件名/大小/分辨率/时长/路径）
  void _showInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              _infoRow('分辨率', item.resolutionLabel),
              _infoRow('时长', item.durationLabel),
              _infoRow('大小', item.sizeLabel),
              _infoRow('修改时间',
                  '${item.modifiedAt.year}-${item.modifiedAt.month.toString().padLeft(2, '0')}-${item.modifiedAt.day.toString().padLeft(2, '0')}'),
              if (item.isAppDirFile) _infoRow('路径', item.relativePath ?? item.path),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
