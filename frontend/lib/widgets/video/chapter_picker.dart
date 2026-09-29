// 章节导航 Bottom Sheet
//
// 多播放器 PRD 第二轮 P1：显示 Emby 章节列表，点击跳转。

import 'package:flutter/material.dart';

import '../models/media_item.dart';

/// 显示章节导航 bottom sheet
///
/// [chapters] 章节列表
/// [onSeek] 点击章节时跳转回调（参数为目标位置秒）
void showChapterPicker({
  required BuildContext context,
  required List<VideoChapter> chapters,
  required void Function(double seconds) onSeek,
}) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '章节导航',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: chapters.length,
              itemBuilder: (_, i) {
                final ch = chapters[i];
                final mmss = _formatTimestamp(ch.startPositionSeconds);
                return ListTile(
                  leading: Text(
                    mmss,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  title: Text(
                    ch.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onSeek(ch.startPositionSeconds);
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

String _formatTimestamp(double seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds.toInt() % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
