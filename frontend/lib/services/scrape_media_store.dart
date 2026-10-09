// 刮削元数据与图片本地落盘（双轨）
// - App 目录视频（isAppDirFile=true）：存视频旁 {name}.nfo + {name}-poster/backdrop/still.jpg
// - 媒体库视频（assetId）：集中存 scrape_media/{metadata,posters,backdrops,stills}/{pathHash}.xxx
// - 演员头像共享：scrape_media/cast/{personId}.jpg
// 展示时本地文件优先，缺失时 fallback TMDB CDN URL
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/local_video_item.dart';
import '../utils/logger.dart';
import 'scrape_service.dart';
import 'tmdb_service.dart';

class ScrapeMediaStore {
  static const _centralDir = 'scrape_media';

  // ---- 路径拼接（不依赖 path 包）----
  static String _join(String a, String b) =>
      a.endsWith('/') ? '$a$b' : '$a/$b';

  static String _extOf(String p) {
    final i = p.lastIndexOf('.');
    final s = p.lastIndexOf('/');
    if (i < 0 || i < s) return '';
    return p.substring(i);
  }

  static String _baseName(String p) {
    final s = p.lastIndexOf('/');
    final b = s >= 0 ? p.substring(s + 1) : p;
    final i = b.lastIndexOf('.');
    return i > 0 ? b.substring(0, i) : b;
  }

  // pathHash 可能含 / : 等字符，做 md5 作为安全文件名
  static String _safeName(String pathHash) =>
      md5.convert(utf8.encode(pathHash)).toString();

  // ---- 目录 ----
  static Future<Directory> _centralRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory(_join(docs.path, _centralDir));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<Directory> _subDir(String sub) async {
    final root = await _centralRoot();
    final d = Directory(_join(root.path, sub));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// 视频旁 base path（去扩展名）：localDir 共享存储和 App 目录都写视频旁
  static String? _siblingBase(LocalVideoItem item) {
    final p = item.path;
    if (p.isEmpty) return null;
    // asset 路径走中央目录，真实文件路径都写视频旁
    if (item.assetId != null && p.isEmpty) return null;
    return p.substring(0, p.length - _extOf(p).length);
  }

  // ---- 保存 ----
  // 双写策略：中央目录（App 沙箱，一定成功）作为权威副本；
  // 视频旁 .nfo/-poster.jpg（共享存储，可能因 Android 11+ 权限失败）尽力而为。
  static Future<void> save(LocalVideoItem item, ScrapedMedia media) async {
    // 1) 中央目录元数据（一定成功）
    try {
      final dir = await _subDir('metadata');
      await File(_join(dir.path, '${_safeName(item.pathHash)}.json'))
          .writeAsString(jsonEncode({'id': item.pathHash, 'media': media.toJson()}));
    } catch (e) {
      AppLogger.warn('写中央元数据失败', data: {'error': e.toString()});
    }

    // 2) 视频旁 .nfo（尽力而为，权限失败不影响后续海报下载）
    final base = _siblingBase(item);
    if (base != null) {
      try {
        await File('$base.nfo').writeAsString(jsonEncode(media.toJson()));
      } catch (e) {
        AppLogger.warn('写视频旁 .nfo 失败（共享存储权限不足）',
            data: {'path': '$base.nfo', 'error': e.toString()});
      }
    }

    // 3) 海报/背景/缩略图：先下中央目录，再尽力复制到视频旁
    final jobs = <Future<void>>[];
    Future<void> dl(String? tmdbPath, String Function() url, String centralSubDir, String siblingSuffix) async {
      if (tmdbPath == null || tmdbPath.isEmpty) return;
      final dir = await _subDir(centralSubDir);
      final centralPath = _join(dir.path, '${_safeName(item.pathHash)}.jpg');
      await _downloadImage(url(), centralPath);
      if (base != null) {
        try {
          final f = File('$base$siblingSuffix');
          if (!await f.exists()) {
            final cf = File(centralPath);
            if (await cf.exists()) await f.writeAsBytes(await cf.readAsBytes());
          }
        } catch (_) {}
      }
    }

    if (media.posterPath != null && media.posterPath!.isNotEmpty) {
      jobs.add(dl(media.posterPath,
          () => TmdbService.posterUrl(media.posterPath!, size: 'w342'), 'posters', '-poster.jpg'));
    }
    if (media.backdropPath != null && media.backdropPath!.isNotEmpty) {
      jobs.add(dl(media.backdropPath,
          () => TmdbService.backdropUrl(media.backdropPath!, size: 'w780'), 'backdrops', '-backdrop.jpg'));
    }
    if (media.stillPath != null && media.stillPath!.isNotEmpty) {
      jobs.add(dl(media.stillPath,
          () => TmdbService.posterUrl(media.stillPath!, size: 'w300'), 'stills', '-still.jpg'));
    }

    // 4) 演员头像
    for (final c in media.cast) {
      final pid = c['id'];
      final profile = c['profilePath'];
      if (pid != null && profile != null && profile.isNotEmpty) {
        final castDir = await _subDir('cast');
        final f = File(_join(castDir.path, '$pid.jpg'));
        if (!await f.exists()) {
          jobs.add(_downloadImage(
              TmdbService.posterUrl(profile, size: 'w185'), f.path));
        }
      }
    }

    await Future.wait(jobs);
  }

  // 查找本地图片文件：先视频旁，不存在则回退中央目录
  static Future<File?> _findImage(LocalVideoItem item, String subDir, String siblingSuffix) async {
    // 1) 视频旁
    final base = _siblingBase(item);
    if (base != null) {
      final sibling = File('$base$siblingSuffix');
      if (await sibling.exists() && await sibling.length() > 0) return sibling;
    }
    // 2) 中央目录
    final dir = await _subDir(subDir);
    final central = File(_join(dir.path, '${_safeName(item.pathHash)}.jpg'));
    if (await central.exists() && await central.length() > 0) return central;
    return null;
  }

  static Future<File?> posterFile(LocalVideoItem item) async =>
      _findImage(item, 'posters', '-poster.jpg');

  static Future<File?> backdropFile(LocalVideoItem item) async =>
      _findImage(item, 'backdrops', '-backdrop.jpg');

  static Future<File?> stillFile(LocalVideoItem item) async =>
      _findImage(item, 'stills', '-still.jpg');

  static Future<File?> castFile(int personId) async {
    final dir = await _subDir('cast');
    final f = File(_join(dir.path, '$personId.jpg'));
    return await f.exists() ? f : null;
  }

  // ---- 删除 / 重命名 ----
  static Future<void> delete(LocalVideoItem item) async {
    try {
      final base = _siblingBase(item);
      if (base != null) {
        for (final s in ['.nfo', '-poster.jpg', '-backdrop.jpg', '-still.jpg']) {
          final f = File('$base$s');
          if (await f.exists()) await f.delete();
        }
      }
      // 同时清理 App 沙箱内中央目录缓存
      final metaDir = await _subDir('metadata');
      for (final sub in ['posters', 'backdrops', 'stills']) {
        final dir = await _subDir(sub);
        final f = File(_join(dir.path, '${_safeName(item.pathHash)}.jpg'));
        if (await f.exists()) await f.delete();
      }
      final mf = File(_join(metaDir.path, '${_safeName(item.pathHash)}.json'));
      if (await mf.exists()) await mf.delete();
    } catch (e) {
      AppLogger.warn('ScrapeMediaStore.delete 失败', data: {'error': e.toString()});
    }
  }

  static Future<void> rename(String oldPath, String newPath) async {
    try {
      final oldBase = oldPath.substring(0, oldPath.length - _extOf(oldPath).length);
      final newBase = newPath.substring(0, newPath.length - _extOf(newPath).length);
      for (final s in ['.nfo', '-poster.jpg', '-backdrop.jpg', '-still.jpg']) {
        final oldF = File('$oldBase$s');
        if (await oldF.exists()) await oldF.rename('$newBase$s');
      }
    } catch (e) {
      AppLogger.warn('ScrapeMediaStore.rename 失败', data: {'error': e.toString()});
    }
  }

  static Future<void> clearCentral() async {
    final root = await _centralRoot();
    if (await root.exists()) await root.delete(recursive: true);
  }

  // ---- 下载 ----
  static Future<void> _downloadImage(String url, String? savePath) async {
    if (url.isEmpty || savePath == null) return;
    try {
      final f = File(savePath);
      if (await f.exists() && await f.length() > 0) return;
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
        await f.parent.create(recursive: true);
        await f.writeAsBytes(r.bodyBytes);
      }
    } catch (e) { AppLogger.warn('下载海报失败', data: {'url': url, 'error': e.toString()}); }
  }

  // ---- 加载 ----
  static Future<Map<String, ScrapedMedia>> loadCentralAll() async {
    final out = <String, ScrapedMedia>{};
    try {
      final dir = await _subDir('metadata');
      await for (final e in dir.list()) {
        if (e is! File || !e.path.endsWith('.json')) continue;
        try {
          final raw = jsonDecode(await e.readAsString()) as Map<String, dynamic>;
          // wrapper: {"id": pathHash, "media": {...}}; 兼容旧格式直接 media map
          final id = raw['id'] as String?;
          final mediaMap = raw['media'] as Map<String, dynamic>? ?? raw;
          final m = ScrapedMedia.fromJson(mediaMap);
          out[id ?? _baseName(e.path)] = m;
        } catch (err) { AppLogger.warn('元数据文件解析失败', data: {'file': e.path, 'error': err.toString()}); }
      }
    } catch (err) { AppLogger.warn('加载中央元数据失败', data: {'error': err.toString()}); }
    return out;
  }

  static Future<ScrapedMedia?> loadSibling(String videoPath) async {
    try {
      final nfo = File('${videoPath.substring(0, videoPath.length - _extOf(videoPath).length)}.nfo');
      if (!await nfo.exists()) return null;
      final raw = await nfo.readAsString();
      return ScrapedMedia.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ---- 迁移 ----
  static const _migratedFlag = 'scrape_migrated_v2';

  static Future<void> migrateFromPrefs() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (sp.getBool(_migratedFlag) == true) return;
      final old = <String, String>{};
      for (final k in sp.getKeys().where((k) => k.startsWith('scrape_'))) {
        if (k == _migratedFlag) continue;
        final v = sp.getString(k);
        if (v != null) old[k] = v;
      }
      if (old.isNotEmpty) {
        final metaDir = await _subDir('metadata');
        final futures = <Future<File>>[];
        old.forEach((k, v) {
          final pathHash = k.substring('scrape_'.length);
          try {
            final mediaMap = jsonDecode(v) as Map<String, dynamic>;
            final wrapped = jsonEncode({'id': pathHash, 'media': mediaMap});
            final f = File(_join(metaDir.path, '${_safeName(pathHash)}.json'));
            futures.add(f.writeAsString(wrapped));
          } catch (_) {
            // 单条解析失败跳过，不阻塞其他条目
          }
        });
        await Future.wait(futures);
      }
      await sp.setBool(_migratedFlag, true);
    } catch (e) {
      debugPrint('migrateFromPrefs: $e');
    }
  }
}
