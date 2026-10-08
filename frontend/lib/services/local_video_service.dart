// 本地视频服务：根据启用的文件源聚合扫描，缓存到 SharedPreferences
// 对应 PRD《本地模式》§4.2 / §5.5
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/local_video_item.dart';
import 'local_dir_scanner.dart';
import 'scrape_service.dart' show ScrapedMedia;
import 'scrape_media_store.dart';

class LocalVideoService {
  static const _cacheKey = 'local_video_cache_v1';
  static const _resumePrefix = 'local_resume_';

  /// 已声明的视频扩展名
  static const _videoExt = {
    '.mp4', '.mkv', '.avi', '.mov', '.webm', '.flv', '.ts', '.m2ts',
    '.3gp', '.wmv', '.m4v',
  };

  /// 已声明的字幕扩展名
  static const _subtitleExt = {'.srt', '.ass', '.vtt'};

  /// 请求媒体权限（Android 13+ photo_manager 自动分版本）
  /// 返回授权状态；用户拒绝后调用方引导去设置
  static Future<PermissionState> requestPermission() =>
      PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(),
      );

  /// 当前权限状态
  static Future<PermissionState> currentPermission() =>
      PhotoManager.getPermissionState(
        requestOption: const PermissionRequestOption(),
      );

  /// 打开系统设置
  static Future<void> openSetting() => PhotoManager.openSetting();

  /// 扫描系统媒体库视频（photo_manager）
  Future<List<LocalVideoItem>> _scanMediaStore() async {
    final result = <LocalVideoItem>[];
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      hasAll: true,
    );
    for (final path in paths) {
      // 每个路径最多取 500 条避免一次拉太多
      final assets = await path.getAssetListRange(start: 0, end: 500);
      for (final a in assets) {
        // AssetEntity.duration 单位是秒；fileSize 是异步 Future<int>
        final fileSize = await a.fileSize;
        result.add(LocalVideoItem(
          id: a.id,
          name: a.title ?? a.id,
          path: '', // 延迟到需要时再取 file.path
          relativePath: a.relativePath,
          sizeBytes: fileSize,
          duration: Duration(seconds: a.duration),
          width: a.width,
          height: a.height,
          mimeType: 'video/*',
          modifiedAt: a.modifiedDateTime,
          isAppDirFile: false,
          assetId: a.id,
        ));
      }
    }
    return result;
  }

  /// 扫描 App 专属目录（递归常见视频扩展名）
  Future<List<LocalVideoItem>> _scanAppDir() async {
    final result = <LocalVideoItem>[];
    try {
      final dirs = <Directory?>[
        await getApplicationDocumentsDirectory(),
        await getApplicationSupportDirectory(),
        await getExternalStorageDirectory(),
      ].whereType<Directory>().toList();

      for (final dir in dirs) {
        if (!dir.existsSync()) continue;
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final ext = _ext(entity.path);
          if (!_videoExt.contains(ext)) continue;
          try {
            final stat = entity.statSync();
            final hash = md5.convert(utf8.encode(entity.path)).toString();
            // 扫描同目录下同名字幕文件（.srt/.ass/.vtt）
            final subtitlePaths = <String>[];
            final dirName = entity.parent.path;
            final baseName = entity.path.split('/').last.replaceAll(ext, '');
            try {
              final dirEntities = Directory(dirName).listSync();
              for (final e in dirEntities) {
                if (e is! File) continue;
                final se = _ext(e.path);
                if (!_subtitleExt.contains(se)) continue;
                final sBase = e.path.split('/').last.replaceAll(se, '');
                // 匹配 "视频名" 或 "视频名.zh" / "视频名.en" 等
                if (sBase == baseName || sBase.startsWith('$baseName.')) {
                  subtitlePaths.add(e.path);
                }
              }
            } catch (_) {}
            result.add(LocalVideoItem(
              id: 'app_$hash',
              name: baseName,
              path: entity.path,
              sizeBytes: stat.size,
              duration: Duration.zero, // App 目录文件时长需 MediaMetadataRetriever，懒取
              width: 0,
              height: 0,
              mimeType: 'video/$ext',
              modifiedAt: stat.modified,
              isAppDirFile: true,
              subtitlePaths: subtitlePaths,
            ));
          } catch (_) {
            // 单个文件读取失败跳过
          }
        }
      }
    } catch (_) {
      // App 目录扫描失败不影响媒体库
    }
    return result;
  }

  static String _ext(String p) {
    final i = p.lastIndexOf('.');
    return i < 0 ? '' : p.substring(i).toLowerCase();
  }

  /// 全量扫描（媒体库 + App 目录），写缓存并返回
  /// 根据启用的文件源聚合扫描
  ///
  /// 文件源存储在 SharedPreferences（key: file_sources_v1），
  /// local 源走 photo_manager，localDir 走 LocalDirScanner，禁用源跳过。
  Future<List<LocalVideoItem>> scan() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('file_sources_v1');
    final List<Map<String, dynamic>> sources = raw == null
        ? [
            // 默认：手机媒体库
            {'id': 'local_default', 'type': 'local', 'name': '手机媒体库', 'enabled': true}
          ]
        : (json.decode(raw) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    final all = <LocalVideoItem>[];
    for (final s in sources) {
      final enabled = s['enabled'] as bool? ?? true;
      if (!enabled) continue;
      final type = s['type'] as String? ?? 'local';
      final sid = s['id'] as String? ?? 'local_default';
      try {
        switch (type) {
          case 'local':
            for (final it in await _scanMediaStore()) {
              all.add(it.copyWith(sourceId: sid));
            }
            break;
          case 'localDir':
            final cfg = s['config'] is Map ? (s['config'] as Map) : const {};
            // 支持多文件夹挂载：config['paths'] 逗号分隔；兼容旧 config['path']
            final paths = <String>[];
            final rawPaths = cfg['paths']?.toString();
            if (rawPaths != null && rawPaths.isNotEmpty) {
              paths.addAll(rawPaths.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
            }
            final oldPath = cfg['path']?.toString();
            if (oldPath != null && oldPath.isNotEmpty && !paths.contains(oldPath)) {
              paths.add(oldPath);
            }
            // 用户指定的媒体类型（movie/tv/short）
            final mediaType = cfg['mediaType']?.toString();
            if (paths.isNotEmpty) {
              for (final it in await LocalDirScanner().scan(paths)) {
                all.add(it.copyWith(sourceId: sid, mediaType: mediaType));
              }
            }
            break;
          // webdav/smb 源的视频通过文件源浏览页单独管理，不合并到首页
        }
      } catch (_) {}
    }
    // App 专属目录始终包含（用户下载的视频）
    all.addAll(await _scanAppDir());
    // 去重（按 pathHash：asset 用 assetId，localDir 用真实路径，避免 path='' 空串 collapse）
    final seen = <String>{};
    all.retainWhere((e) => seen.add(e.pathHash));
    all.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    await _writeCache(all);
    return all;
  }

  /// 读缓存（无权限时仍可显示上次扫描结果）
  Future<List<LocalVideoItem>> loadCache() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_cacheKey);
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => LocalVideoItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeCache(List<LocalVideoItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final json = items.map((e) => e.toJson()).toList();
    await sp.setString(_cacheKey, jsonEncode(json));
  }

  /// 删除视频：系统媒体库走 photo_manager（系统确认弹窗），App 目录走 File.delete
  Future<bool> delete(LocalVideoItem item) async {
    try {
      if (item.isAppDirFile) {
        final f = File(item.path);
        if (f.existsSync()) await f.delete();
        return true;
      } else if (item.assetId != null) {
        final ok = await PhotoManager.editor.deleteWithIds([item.assetId!]);
        return ok.contains(item.assetId);
      }
    } catch (_) {}
    return false;
  }

  // ==================== 续播位置 ====================

  /// 读本地视频续播位置（毫秒）；未记录返回 null
  Future<int?> readResumeMs(String pathHash) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_resumePrefix + pathHash);
  }

  /// 写本地视频续播位置（毫秒），同时记录最近播放时间戳
  Future<void> writeResumeMs(String pathHash, int ms) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_resumePrefix + pathHash, ms);
    // 记录最近播放时间戳（用于"继续观看"横滑区块）
    await sp.setInt('${_resumePrefix}time_$pathHash',
        DateTime.now().millisecondsSinceEpoch);
  }

  /// 清续播（播放完成后）
  Future<void> clearResume(String pathHash) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_resumePrefix + pathHash);
    await sp.remove('${_resumePrefix}time_$pathHash');
  }

  /// 获取最近播放的视频 pathHash 列表（按播放时间倒序，最多 10 条）
  Future<List<String>> getRecentPlayHashes() async {
    final sp = await SharedPreferences.getInstance();
    const prefix = '${_resumePrefix}time_';
    final entries = <MapEntry<String, int>>[];
    for (final key in sp.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final v = sp.getInt(key);
      if (v != null) entries.add(MapEntry(key.substring(prefix.length), v));
    }
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(10).map((e) => e.key).toList();
  }

  // ---- 本地收藏（P3）----
  static const _favoritePrefix = 'local_favorite_';

  Future<Set<String>> getFavorites() async {
    final sp = await SharedPreferences.getInstance();
    final keys = sp.getKeys().where((k) => k.startsWith(_favoritePrefix));
    return keys.map((k) => k.substring(_favoritePrefix.length)).toSet();
  }

  Future<bool> isFavorite(String pathHash) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_favoritePrefix + pathHash) ?? false;
  }

  Future<void> setFavorite(String pathHash, bool fav) async {
    final sp = await SharedPreferences.getInstance();
    if (fav) {
      await sp.setBool(_favoritePrefix + pathHash, true);
    } else {
      await sp.remove(_favoritePrefix + pathHash);
    }
  }

  /// 重命名本地文件（仅 isAppDirFile=true 的真实文件路径可用）
  /// 返回新的路径；失败抛异常
  Future<String> renameFile(LocalVideoItem item, String newName) async {
    if (!item.isAppDirFile) {
      throw Exception('系统媒体库文件不支持重命名');
    }
    final oldFile = File(item.path);
    if (!await oldFile.exists()) throw Exception('文件不存在');
    final ext = item.path.contains('.') ? item.path.substring(item.path.lastIndexOf('.')) : '';
    final parent = item.path.substring(0, item.path.lastIndexOf('/'));
    final newPath = '$parent/$newName$ext';
    final target = File(newPath);
    if (await target.exists()) throw Exception('目标文件名已存在');
    await oldFile.rename(newPath);
    // P2#10 记录重命名历史用于撤销
    await _recordRename(item.path, newPath);
    // 双轨落盘：同步重命名视频旁刮削文件
    try {
      await ScrapeMediaStore.rename(item.path, newPath);
    } catch (_) {}
    return newPath;
  }

  static const _renameHistoryKey = 'rename_history';

  /// 记录重命名（old→new），最多保留 50 条
  Future<void> _recordRename(String oldPath, String newPath) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final list = sp.getStringList(_renameHistoryKey) ?? [];
      list.insert(0, '$oldPath|$newPath');
      if (list.length > 50) list.removeRange(50, list.length);
      await sp.setStringList(_renameHistoryKey, list);
    } catch (_) {}
  }

  /// 获取最近重命名历史：list of (oldPath, newPath)
  Future<List<MapEntry<String, String>>> getRenameHistory() async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_renameHistoryKey) ?? [];
    return list.map((s) {
      final i = s.indexOf('|');
      return MapEntry(s.substring(0, i), s.substring(i + 1));
    }).toList();
  }

  /// 撤销最近一次重命名（把 newPath 改回 oldPath）
  Future<String> undoLastRename() async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_renameHistoryKey) ?? [];
    if (list.isEmpty) throw Exception('没有可撤销的重命名');
    final first = list.first;
    final i = first.indexOf('|');
    final oldPath = first.substring(0, i);
    final newPath = first.substring(i + 1);
    final f = File(newPath);
    if (!await f.exists()) throw Exception('文件已不存在，无法撤销');
    await f.rename(oldPath);
    list.removeAt(0);
    await sp.setStringList(_renameHistoryKey, list);
    return oldPath;
  }

  /// 根据刮削元数据一键重命名文件
  /// 电影: "标题 (年份).ext"
  /// 剧集: "标题 S01E01.ext"（从文件名/父目录解析集数）
  Future<String> renameByScraped(LocalVideoItem item, ScrapedMedia s) async {
    if (!item.isAppDirFile) throw Exception('系统媒体库文件不支持重命名');
    final safeTitle = (s.title).replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
    String newName;
    if (s.type == 'tv') {
      // 从原文件名或父目录提取 SxxExx
      final epMatch = RegExp(r'[Ss](\d{1,2})[._ -]?[Ee](\d{1,2})').firstMatch(item.name);
      if (epMatch != null) {
        final se = 'S${epMatch.group(1)!.padLeft(2, '0')}E${epMatch.group(2)!.padLeft(2, '0')}';
        newName = '$safeTitle $se';
      } else {
        newName = safeTitle;
      }
    } else if (s.year != null) {
      newName = '$safeTitle (${s.year})';
    } else {
      newName = safeTitle;
    }
    return renameFile(item, newName);
  }
}
