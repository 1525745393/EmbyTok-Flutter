import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/file_source.dart';
import '../models/local_video_item.dart';

/// WebDAV 扫描服务（P1 第三批）
///
/// 用 PROPFIND 遍历目录，收集视频文件列表。
class WebdavScanner {
  static const _videoExts = {
    '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv',
    '.ts', '.m2ts', '.webm', '.m4v', '.mpg', '.mpeg',
  };

  /// 扫描 WebDAV 源，返回视频项列表
  Future<List<LocalVideoItem>> scan(FileSource source) async {
    final baseUrl = source.config['url'] ?? '';
    final user = source.config['username'] ?? '';
    final pass = source.config['password'] ?? '';
    if (baseUrl.isEmpty) return [];

    final auth = 'Basic ${base64Encode(utf8.encode('$user:$pass'))}';
    final items = <LocalVideoItem>[];

    await _walk(baseUrl, auth, source.id, items, depth: 0);
    return items;
  }

  Future<void> _walk(
    String url,
    String auth,
    String sourceId,
    List<LocalVideoItem> out, {
    int depth = 0,
  }) async {
    if (depth > 5) return; // 防递归过深

    try {
      final client = http.Client();
      try {
        final req = http.Request('PROPFIND', Uri.parse(url));
        req.headers.addAll({
          'Authorization': auth,
          'Depth': '1',
          'Content-Type': 'application/xml; charset=utf-8',
        });
        req.body = '<?xml version="1.0"?>'
            '<d:propfind xmlns:d="DAV:">'
            '<d:prop><d:displayname/><d:resourcetype/>'
            '<d:getcontentlength/><d:getlastmodified/></d:prop>'
            '</d:propfind>';
        final streamed = await client.send(req).timeout(const Duration(seconds: 15));
        final resp = await http.Response.fromStream(streamed);

        if (resp.statusCode != 207) return;

        final xml = resp.body;
        // 简单解析 <response> 块
        final responses = RegExp(r'<response>(.*?)</response>', dotAll: true).allMatches(xml);
        for (final r in responses) {
          final block = r.group(1) ?? '';
          final href = RegExp(r'<href>(.*?)</href>', dotAll: true).firstMatch(block)?.group(1) ?? '';
          final isCollection = block.contains('<collection/>');
          final size = int.tryParse(RegExp(r'<getcontentlength>(.*?)</getcontentlength>').firstMatch(block)?.group(1) ?? '0') ?? 0;

          if (isCollection) {
            // 递归子目录
            final childUrl = _joinUrl(url, href);
            await _walk(childUrl, auth, sourceId, out, depth: depth + 1);
          } else {
            // 从 href 路径取 basename 判断扩展名
            final basename = Uri.decodeComponent(href.split('/').last);
            final lower = basename.toLowerCase();
            if (_videoExts.any(lower.endsWith)) {
              final fileUrl = _joinUrl(url, href);
              out.add(LocalVideoItem(
                id: '$sourceId:$href',
                name: basename.replaceAll(RegExp(r'\.[^.]+$'), ''),
                path: fileUrl,
                sizeBytes: size,
                duration: Duration.zero,
                width: 0,
                height: 0,
                mimeType: 'video/*',
                modifiedAt: DateTime.now(),
                isAppDirFile: false,
                sourceId: sourceId,
                networkUrl: fileUrl,
                // 播放器需要 Basic Auth 头才能访问 WebDAV 文件
                networkHeaders: {
                  'Authorization': auth,
                  'Accept': 'video/*',
                },
              ));
            }
          }
        }
      } finally {
        client.close();
      }
    } catch (_) {
      // 单个目录失败跳过
    }
  }

  String _joinUrl(String base, String href) {
    if (href.startsWith('http')) return href;
    // href 可能是 /dav/video.mp4 相对路径
    final baseUri = Uri.parse(base);
    return baseUri.resolve(href).toString();
  }
}
