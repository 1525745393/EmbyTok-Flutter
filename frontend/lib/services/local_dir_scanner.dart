import 'dart:io';
import '../../models/local_video_item.dart';

/// 本地文件夹扫描器（P0：用户指定目录）
///
/// 从用户在文件浏览器里选的文件夹递归列出视频文件，生成 LocalVideoItem。
/// 用于"手机文件夹"文件源类型。
class LocalDirScanner {
  static const _videoExts = {
    '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.ts', '.m2ts',
    '.webm', '.m4v', '.mpg', '.mpeg', '.3gp', '.rmvb', '.rm', '.asf',
  };

  /// 递归扫描 [rootPath] 下所有视频文件
  Future<List<LocalVideoItem>> scan(String rootPath) async {
    final result = <LocalVideoItem>[];
    final root = Directory(rootPath);
    if (!await root.exists()) return result;

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.path.split('/').last;
      if (name.startsWith('.')) continue;
      final dot = name.lastIndexOf('.');
      if (dot < 0) continue;
      final ext = name.substring(dot).toLowerCase();
      if (!_videoExts.contains(ext)) continue;
      try {
        final stat = await entity.stat();
        result.add(LocalVideoItem(
          id: 'localdir:${entity.path}',
          name: name.substring(0, dot),
          path: entity.path,
          sizeBytes: stat.size,
          duration: Duration.zero,
          width: 0,
          height: 0,
          mimeType: 'video/*',
          modifiedAt: stat.modified,
          isAppDirFile: true,
          relativePath: rootPath,
        ));
      } catch (_) {}
    }
    // 按修改时间倒序
    result.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return result;
  }
}
