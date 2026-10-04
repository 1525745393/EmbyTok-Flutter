// 本地视频章节提取：用 ffprobe 读取文件内嵌章节
// 桌面端直接调 ffprobe；Android 无 ffprobe 二进制，返回空

import 'dart:convert';
import 'dart:io';
import '../models/media_item.dart';

class LocalChapterService {
  static final Map<String, List<VideoChapter>> _cache = {};

  static Future<List<VideoChapter>> getChapters(String path) async {
    if (_cache.containsKey(path)) return _cache[path]!;

    final result = <VideoChapter>[];
    try {
      // 仅本地文件路径，networkUrl 跳过
      if (path.startsWith('http')) {
        _cache[path] = result;
        return result;
      }
      final proc = await Process.run('ffprobe', [
        '-v', 'quiet',
        '-print_format', 'json',
        '-show_chapters',
        path,
      ]);
      if (proc.exitCode == 0) {
        final data = jsonDecode(proc.stdout as String);
        final chapters = data['chapters'] as List? ?? [];
        for (final c in chapters) {
          final start = double.tryParse(c['start']?.toString() ?? '') ?? 0;
          final tags = c['tags'] as Map?;
          final title = tags?['title']?.toString() ??
              tags?['title_eng']?.toString() ??
              '章节 ${chapters.indexOf(c) + 1}';
          result.add(VideoChapter(
            startPositionTicks: (start * 10000000).toInt(),
            name: title,
          ));
        }
      }
    } catch (_) {
      // ffprobe 不可用（如 Android），返回空
    }
    _cache[path] = result;
    return result;
  }
}
