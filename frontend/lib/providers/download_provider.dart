// 下载管理状态（Riverpod 桥接）
//
// 桥接 SynologyDownloadService，向 UI 暴露任务列表与已下载歌曲。
// 进度回调时 setState 重建状态。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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

  /// 当前是否允许下载（仅 WiFi/以太网）。未知时默认放行，避免启动误暂停。
  bool _wifiOk = true;

  /// 连接状态订阅（dispose 时取消）
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  Future<void> _init() async {
    // 注入流 URL 解析器：按 songId 取带 _sid 的播放地址
    SynologyDownloadService.instance.streamUrlResolver = (songId) {
      try {
        return _ref.read(synologyAuthProvider.notifier).api.getStreamUrl(songId);
      } catch (_) {
        return null;
      }
    };
    // batch91-F1: 网络门控接入真实连接状态——订阅 Connectivity 变化，
    // wifi/ethernet 才放行下载（此前恒 true，移动网络也会下载，与注释声称
    // 的"移动网时由状态监听处理"不符；现行为与注释一致）。
    // connectivity_plus 5.x：onConnectivityChanged 回调为单值 ConnectivityResult
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      _wifiOk =
          result == ConnectivityResult.wifi || result == ConnectivityResult.ethernet;
    });
    // 启动时读取一次当前状态，避免订阅回调迟迟不来导致门控未知
    // checkConnectivity 异步，最终状态由订阅流收敛；此处不阻塞初始化
    try {
      unawaited(Connectivity().checkConnectivity());
    } catch (_) {}
    SynologyDownloadService.instance.canDownloadOnNetwork = () => _wifiOk;
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

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  return DownloadNotifier(ref);
});
