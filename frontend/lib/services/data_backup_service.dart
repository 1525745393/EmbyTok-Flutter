// 数据备份与恢复服务（PRD #29）
//
// - 收藏歌曲导出/导入 JSON
// - 歌单 M3U 导出/导入
// - 智能匹配：按 歌名+艺术家 精确/模糊匹配 NAS 音乐库

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/audio_models.dart';

/// 导入匹配结果
class ImportResult {
  ImportResult({
    required this.total,
    required this.matched,
    required this.unmatched,
    required this.skippedDuplicates,
  });
  final int total;
  final int matched;
  final List<String> unmatched;
  final int skippedDuplicates;
}

/// M3U 中解析出的一条
class M3uEntry {
  M3uEntry({required this.title, this.artist = ''});
  final String title;
  final String artist;
}

class DataBackupService {
  DataBackupService._();
  static final DataBackupService instance = DataBackupService._();

  // ============================
  // 收藏 JSON 导出
  // ============================
  Future<String> exportFavoritesJson(List<AudioPin> pins) async {
    final data = {
      'version': '1.0',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'favorites': pins
          .map((p) => {
                'songId': p.id,
                'title': p.title,
                'artist': p.artist ?? '',
                'album': p.album ?? '',
              })
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  // ============================
  // 收藏 JSON 导入
  // ============================
  /// 解析收藏 JSON 文件，返回 {songId,title,artist} 列表
  List<Map<String, String>> parseFavoritesJson(String content) {
    try {
      final m = jsonDecode(content) as Map<String, dynamic>;
      final list = m['favorites'] as List<dynamic>? ?? [];
      return list.map((e) {
        final j = e as Map<String, dynamic>;
        return {
          'songId': (j['songId'] ?? '') as String,
          'title': (j['title'] ?? '') as String,
          'artist': (j['artist'] ?? '') as String,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ============================
  // M3U 解析
  // ============================
  List<M3uEntry> parseM3U(String content) {
    final entries = <M3uEntry>[];
    final lines = const LineSplitter().convert(content);
    for (final line in lines) {
      final t = line.trim();
      if (!t.startsWith('#EXTINF:')) continue;
      // #EXTINF:180,周杰伦 - 晴天
      final comma = t.indexOf(',');
      if (comma < 0) continue;
      final namePart = t.substring(comma + 1).trim();
      final dash = namePart.indexOf(' - ');
      if (dash > 0) {
        entries.add(M3uEntry(
          artist: namePart.substring(0, dash).trim(),
          title: namePart.substring(dash + 3).trim(),
        ));
      } else {
        entries.add(M3uEntry(title: namePart));
      }
    }
    return entries;
  }

  /// 生成 M3U 文本
  String buildM3U(String playlistName, List<AudioSong> songs) {
    final buf = StringBuffer('#EXTM3U\n');
    for (final s in songs) {
      final dur = s.audio?.duration ?? 0;
      final artist = s.artistDisplay;
      buf.writeln('#EXTINF:$dur,$artist - ${s.title}');
      buf.writeln(s.path ?? s.title);
    }
    return buf.toString();
  }

  // ============================
  // 智能匹配
  // ============================
  /// 在 NAS 音乐库中按 title+artist 匹配。
  /// 返回匹配到的歌曲（与输入顺序一致，未匹配为 null）。
  List<AudioSong?> matchSongs(
      List<M3uEntry> entries, List<AudioSong> library) {
    AudioSong? exact(String title, String artist) {
      for (final s in library) {
        final st = s.title.toLowerCase().trim();
        final sa = s.artistDisplay.toLowerCase().trim();
        if (st == title.toLowerCase().trim() &&
            (artist.isEmpty || sa == artist.toLowerCase().trim())) {
          return s;
        }
      }
      return null;
    }

    AudioSong? fuzzy(String title, String artist) {
      final t = title.toLowerCase().trim();
      for (final s in library) {
        final st = s.title.toLowerCase().trim();
        final sa = s.artistDisplay.toLowerCase().trim();
        final titleHit = st.contains(t) || t.contains(st);
        final artistHit = artist.isEmpty ||
            sa.contains(artist.toLowerCase().trim()) ||
            artist.toLowerCase().trim().contains(sa);
        if (titleHit && artistHit) return s;
      }
      return null;
    }

    return entries.map((e) {
      return exact(e.title, e.artist) ?? fuzzy(e.title, e.artist);
    }).toList();
  }

  // ============================
  // 文件读写 + 分享
  // ============================
  Future<File> _writeTemp(String fileName, String content) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$fileName');
    await f.writeAsString(content);
    return f;
  }

  Future<void> shareTextFile(String fileName, String content) async {
    final f = await _writeTemp(fileName, content);
    await Share.shareXFiles([XFile(f.path)], subject: fileName);
  }

  /// 让用户选择一个文本文件，返回内容（取消返回 null）
  Future<String?> pickTextFile(List<String> extensions) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (result == null || result.files.single.path == null) return null;
    return File(result.files.single.path!).readAsString();
  }
}
