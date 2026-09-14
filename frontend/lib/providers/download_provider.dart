// 下载管理状态（Riverpod 桥接）
//
// 桥接 SynologyDownloadService，向 UI 暴露任务列表与已下载歌曲。
// 进度回调时 setState 重建状态。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audio_models.dart';
import '../services/synology_download_service.dart';
import 'synology_auth_provider.dart';

class DownloadState {
  const DownloadState({
    this.tasks = const [],
    this.downloaded = const {},
  });

  /// 未完成/进行中的下载任务
  final List<DownloadTask> tasks;

  /// 已下载歌曲 songId -> DownloadedSong
  final Map<String, DownloadedSong> downloaded;

  List<DownloadTask> get activeTasks => tasks
      .where((t) =>
          t.status == DownloadStatus.downloading ||
          t.status == DownloadStatus.waiting ||
          t.status == DownloadStatus.paused ||
          t.status == DownloadStatus.failed)
      .toList();
}

class DownloadNotifier extends StateNotifier<DownloadState> {
  DownloadNotifier(this._ref) : super(const DownloadState()) {
    _init();
  }

  final Ref _ref;
  SynologyDownloadService get _svc => SynologyDownloadService.instance;

  Future<void> _init() async {
    // 注入流 URL 解析器：按 songId 取带 _sid 的播放地址
    SynologyDownloadService.instance.streamUrlResolver = (songId) {
      try {
        return _ref.read(synologyAuthProvider.notifier).api.getStreamUrl(songId);
      } catch (_) {
        return null;
      }
    };
    final tasks = await _svc.loadTasks();
    final downloaded = await _svc.loadDownloaded();
    if (!mounted) return;
    state = DownloadState(tasks: tasks, downloaded: downloaded);
  }

  void _refresh() {
    () async {
      final tasks = await _svc.loadTasks();
      final downloaded = await _svc.loadDownloaded();
      if (!mounted) return;
      state = DownloadState(tasks: tasks, downloaded: downloaded);
    }();
  }

  /// 加入下载队列
  Future<void> enqueue(AudioSong song) async {
    await _svc.enqueue(song: song, onProgress: (_) => _refresh());
    _refresh();
  }

  /// 取消任务
  Future<void> cancel(String songId) async {
    await _svc.cancel(songId);
    _refresh();
  }

  /// 重试失败任务
  Future<void> retry(String songId) async {
    await _svc.retry(songId, (_) => _refresh());
    _refresh();
  }

  /// 删除已下载歌曲
  Future<void> deleteDownloaded(String songId) async {
    await _svc.deleteDownloaded(songId);
    _refresh();
  }
}

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  return DownloadNotifier(ref);
});
