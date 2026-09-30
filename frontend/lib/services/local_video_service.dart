// 本地视频服务：扫描手机系统媒体库 + App 专属目录，缓存到 SharedPreferences
// 对应 PRD《本地模式》§4.2 / §5.5
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/local_video_item.dart';

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
  Future<List<LocalVideoItem>> scan() async {
    final media = await _scanMediaStore();
    final app = await _scanAppDir();
    final all = [...media, ...app];
    // 按修改时间倒序
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

  /// 写本地视频续播位置（毫秒）
  Future<void> writeResumeMs(String pathHash, int ms) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_resumePrefix + pathHash, ms);
  }

  /// 清续播（播放完成后）
  Future<void> clearResume(String pathHash) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_resumePrefix + pathHash);
  }
}
