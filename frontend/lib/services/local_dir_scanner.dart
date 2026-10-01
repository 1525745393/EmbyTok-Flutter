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

  /// 递归扫描 [rootPaths] 下所有视频文件（支持多文件夹挂载）
  ///
  /// 最多收集 5000 个视频，避免用户误选根目录时扫描过久。
  Future<List<LocalVideoItem>> scan(List<String> rootPaths) async {
    final result = <LocalVideoItem>[];
    const maxFiles = 5000;
    for (final rootPath in rootPaths) {
      final root = Directory(rootPath);
      if (!await root.exists()) continue;
      await for (final entity in root.list(recursive: true, followLinks: false)) {
        if (result.length >= maxFiles) break;
        if (entity is! File) continue;
        final name = entity.path.split('/').last;
        if (name.startsWith('.')) continue;
        final dot = name.lastIndexOf('.');
        if (dot < 0) continue;
        final ext = name.substring(dot).toLowerCase();
        if (!_videoExts.contains(ext)) continue;
        try {
          final stat = await entity.stat();
          final parent = entity.path.substring(0, entity.path.lastIndexOf('/'));
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
            relativePath: parent,
          ));
        } catch (_) {}
      }
      if (result.length >= maxFiles) break;
    }
    result.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return result;
  }
}
