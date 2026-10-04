// 本地视频章节提取：用 media_kit (libmpv) 读取文件内嵌章节
// 不播放视频，仅打开文件读 chapter 列表后立即释放

import 'dart:async';
import 'package:media_kit/media_kit.dart';
import '../models/media_item.dart';

class LocalChapterService {
  static final Map<String, List<VideoChapter>> _cache = {};

  /// 读取本地文件章节（路径或 networkUrl）
  static Future<List<VideoChapter>> getChapters(String path) async {
    if (_cache.containsKey(path)) return _cache[path]!;

    final result = <VideoChapter>[];
    Player? player;
    try {
      player = Player(
        configuration: const PlayerConfiguration(
          bufferSize: 0,
          title: 'chapter_probe',
        ),
      );
      await player.open(Media(path), play: false);
      // 等待元数据加载
      await Future.delayed(const Duration(milliseconds: 500));

      final chapters = player.state.chapters;
      for (final c in chapters) {
        result.add(VideoChapter(
          startPositionTicks: (c.time * 10000000).toInt(),
          name: c.title.isEmpty ? '章节 ${chapters.indexOf(c) + 1}' : c.title,
        ));
      }
    } catch (_) {
      // 读取失败返回空
    } finally {
      try {
        await player?.dispose();
      } catch (_) {}
    }

    _cache[path] = result;
    return result;
  }
}
