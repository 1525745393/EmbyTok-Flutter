// 群晖 Audio Station 音乐离线下载服务
//
// 将歌曲流（带 _sid 鉴权的 stream.cgi）下载到应用文档目录 downloads/，
// 支持下载队列、进度回调、暂停/取消、已下载管理与离线播放。
//
// V1.0 核心版：
// - 顺序下载队列（一次一个任务）
// - 进度实时回调
// - 取消任务并清理部分文件
// - 已下载歌曲元数据持久化到 SharedPreferences
// - 严格 HTTP Range 断点续传列为 V1.1 增强

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/audio_models.dart';
import '../utils/logger.dart';

/// 下载任务状态
enum DownloadStatus { waiting, downloading, paused, failed, completed }

/// 单个下载任务
class DownloadTask {
  final String songId;
  final String title;
  final String artist;
  final String? coverUrl;
  DownloadStatus status;
  double progress; // 0-1
  int downloadedBytes;
  int totalBytes;
  String? savedPath;
  final DateTime addedAt;
  String? errorMessage;

  DownloadTask({
    required this.songId,
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.status,
    this.progress = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.savedPath,
    required this.addedAt,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
        'songId': songId,
        'title': title,
        'artist': artist,
        'coverUrl': coverUrl,
        'status': status.name,
        'progress': progress,
        'downloadedBytes': downloadedBytes,
        'totalBytes': totalBytes,
        'savedPath': savedPath,
        'addedAtMs': addedAt.millisecondsSinceEpoch,
        'errorMessage': errorMessage,
      };

  factory DownloadTask.fromJson(Map<String, dynamic> j) => DownloadTask(
        songId: j['songId'] as String,
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? '',
        coverUrl: j['coverUrl'] as String?,
        status: DownloadStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => DownloadStatus.waiting,
        ),
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
        downloadedBytes: j['downloadedBytes'] as int? ?? 0,
        totalBytes: j['totalBytes'] as int? ?? 0,
        savedPath: j['savedPath'] as String?,
        addedAt: DateTime.fromMillisecondsSinceEpoch(
            j['addedAtMs'] as int? ?? 0),
        errorMessage: j['errorMessage'] as String?,
      );

  DownloadTask copyWith({
    DownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    String? savedPath,
    String? errorMessage,
  }) =>
      DownloadTask(
        songId: songId,
        title: title,
        artist: artist,
        coverUrl: coverUrl,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        downloadedBytes: downloadedBytes ?? this.downloadedBytes,
        totalBytes: totalBytes ?? this.totalBytes,
        savedPath: savedPath ?? this.savedPath,
        addedAt: addedAt,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

/// 已下载歌曲条目
class DownloadedSong {
  final String songId;
  final String path;
  final String title;
  final String artist;
  final int fileSize;
  final DateTime downloadedAt;

  DownloadedSong({
    required this.songId,
    required this.path,
    required this.title,
    required this.artist,
    required this.fileSize,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'title': title,
        'artist': artist,
        'fileSize': fileSize,
        'ts': downloadedAt.millisecondsSinceEpoch,
      };

  factory DownloadedSong.fromJson(String songId, Map<String, dynamic> j) =>
      DownloadedSong(
        songId: songId,
        path: j['path'] as String,
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? '',
        fileSize: j['fileSize'] as int? ?? 0,
        downloadedAt:
            DateTime.fromMillisecondsSinceEpoch(j['ts'] as int? ?? 0),
      );
}

class SynologyDownloadService {
  SynologyDownloadService._();
  static final SynologyDownloadService instance = SynologyDownloadService._();

  static const String _kTasksKey = 'download_tasks_v1';
  static const String _kDownloadedKey = 'downloaded_songs_v1';

  final Dio _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};
  Directory? _dir;

  /// 由 app 注入：按 songId 取带 _sid 的流 URL（未登录返回 null）
  String? Function(String songId)? streamUrlResolver;

  /// downloads/ 目录（惰性创建）
  Future<Directory> _downloadsDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/downloads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  // ============================
  // 持久化
  // ============================

  Future<List<DownloadTask>> loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kTasksKey);
      if (raw == null) return [];
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => DownloadTask.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveTasks(List<DownloadTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kTasksKey,
      json.encode(tasks.map((t) => t.toJson()).toList()),
    );
  }

  /// 已下载歌曲元数据（songId -> DownloadedSong）
  Future<Map<String, DownloadedSong>> loadDownloaded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kDownloadedKey);
      if (raw == null) return {};
      final m = json.decode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(
          k, DownloadedSong.fromJson(k, v as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveDownloaded(Map<String, DownloadedSong> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kDownloadedKey,
      json.encode(map.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  /// 查询某歌曲是否已下载，返回本地路径（未下载返回 null）
  Future<String?> localPathFor(String songId) async {
    final map = await loadDownloaded();
    final song = map[songId];
    if (song == null) return null;
    final f = File(song.path);
    if (await f.exists()) return song.path;
    // 记录里有但文件不在，清理脏记录
    map.remove(songId);
    await _saveDownloaded(map);
    return null;
  }

  // ============================
  // 下载
  // ============================

  /// 将歌曲加入下载队列并自动开始顺序下载
  Future<void> enqueue({
    required AudioSong song,
    required void Function(List<DownloadTask> tasks) onProgress,
  }) async {
    final tasks = await loadTasks();
    // 已存在未完成任务则跳过
    if (tasks.any((t) =>
        t.songId == song.id &&
        (t.status == DownloadStatus.downloading ||
            t.status == DownloadStatus.waiting ||
            t.status == DownloadStatus.paused))) {
      return;
    }
    final dir = await _downloadsDir();
    final savedPath = "${dir.path}/${song.id}.audio";
    tasks.add(DownloadTask(
      songId: song.id,
      title: song.title,
      artist: song.artistDisplay,
      coverUrl: null,
      status: DownloadStatus.waiting,
      savedPath: savedPath,
      addedAt: DateTime.now(),
    ));
    await _saveTasks(tasks);
    onProgress(tasks);
    await _runQueue(onProgress);
  }

  bool _queueRunning = false;

  /// 顺序跑队列：每次取一个 waiting/failed 任务下载
  Future<void> _runQueue(
      void Function(List<DownloadTask> tasks) onProgress) async {
    if (_queueRunning) return;
    _queueRunning = true;
    while (true) {
      final tasks = await loadTasks();
      final next = tasks.where((t) =>
          t.status == DownloadStatus.waiting ||
          t.status == DownloadStatus.failed ||
          t.status == DownloadStatus.paused);
      if (next.isEmpty) break;
      final task = next.first;
      final url = streamUrlResolver?.call(task.songId);
      await _downloadOne(task: task, streamUrl: url, onProgress: onProgress);
    }
    _queueRunning = false;
  }

  Future<void> _downloadOne({
    required DownloadTask task,
    required String? streamUrl,
    required void Function(List<DownloadTask> tasks) onProgress,
  }) async {
    if (streamUrl == null) {
      await _updateTask(task.copyWith(
        status: DownloadStatus.failed,
        errorMessage: '流地址不可用',
      ));
      onProgress(await loadTasks());
      return;
    }
    final cancelToken = CancelToken();
    _cancelTokens[task.songId] = cancelToken;
    try {
      await _updateTask(task.copyWith(status: DownloadStatus.downloading));
      onProgress(await loadTasks());

      await _dio.download(
        streamUrl,
        task.savedPath,
        cancelToken: cancelToken,
        onReceiveProgress: (got, total) async {
          final t = (await loadTasks()).firstWhere((e) => e.songId == task.songId);
          await _updateTask(t.copyWith(
            progress: total > 0 ? got / total : 0,
            downloadedBytes: got,
            totalBytes: total > 0 ? total : t.totalBytes,
          ));
          onProgress(await loadTasks());
        },
      );

      // 完成
      await _updateTask(task.copyWith(
        status: DownloadStatus.completed,
        progress: 1,
      ));
      // 写入已下载索引
      final downloaded = await loadDownloaded();
      final file = File(task.savedPath!);
      final size = await file.exists() ? await file.length() : 0;
      downloaded[task.songId] = DownloadedSong(
        songId: task.songId,
        path: task.savedPath!,
        title: task.title,
        artist: task.artist,
        fileSize: size,
        downloadedAt: DateTime.now(),
      );
      await _saveDownloaded(downloaded);
      AppLogger.info('下载完成', data: {'song': task.title});
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        // 用户取消：保留 partial 文件由 cancel 处理
        AppLogger.info('下载取消', data: {'song': task.title});
      } else {
        await _updateTask(task.copyWith(
          status: DownloadStatus.failed,
          errorMessage: e.message ?? '下载失败',
        ));
        AppLogger.warn('下载失败', data: {'song': task.title, 'error': e.message});
      }
    } catch (e) {
      await _updateTask(task.copyWith(
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      ));
    } finally {
      _cancelTokens.remove(task.songId);
      onProgress(await loadTasks());
    }
  }

  Future<void> _updateTask(DownloadTask updated) async {
    final tasks = await loadTasks();
    final idx = tasks.indexWhere((t) => t.songId == updated.songId);
    if (idx < 0) return;
    tasks[idx] = updated;
    await _saveTasks(tasks);
  }

  /// 取消下载任务并删除已下载部分文件
  Future<void> cancel(String songId) async {
    _cancelTokens[songId]?.cancel('user canceled');
    final tasks = await loadTasks();
    final idx = tasks.indexWhere((t) => t.songId == songId);
    if (idx >= 0) {
      final path = tasks[idx].savedPath;
      if (path != null) {
        final f = File(path);
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
      tasks.removeAt(idx);
      await _saveTasks(tasks);
    }
  }

  /// 重试失败的任务（重新排队）
  Future<void> retry(String songId,
      void Function(List<DownloadTask> tasks) onProgress) async {
    final tasks = await loadTasks();
    final idx = tasks.indexWhere((t) => t.songId == songId);
    if (idx < 0) return;
    tasks[idx] = tasks[idx].copyWith(
      status: DownloadStatus.waiting,
      progress: 0,
      errorMessage: null,
    );
    await _saveTasks(tasks);
    await _runQueue(onProgress);
  }

  /// 删除已下载歌曲（文件 + 索引）
  Future<void> deleteDownloaded(String songId) async {
    final downloaded = await loadDownloaded();
    final song = downloaded.remove(songId);
    if (song != null) {
      final f = File(song.path);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    await _saveDownloaded(downloaded);
  }

  /// 已下载占用总字节
  Future<int> downloadedSizeBytes() async {
    final downloaded = await loadDownloaded();
    var total = 0;
    for (final s in downloaded.values) {
      final f = File(s.path);
      if (await f.exists()) {
        total += await f.length();
      }
    }
    return total;
  }
}
