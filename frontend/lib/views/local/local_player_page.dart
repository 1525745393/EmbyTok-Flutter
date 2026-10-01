// 本地视频全屏播放页：复用 VideoPlayerWidget（三引擎），isLocal=true
// 对应 PRD《本地模式》§4.4；支持连播（P3）+ 续播位置保存（P2）
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/local_video_item.dart';
import '../../models/media_item.dart';
import '../../services/local_video_service.dart';
import '../../widgets/video/video_player_widget.dart';

class LocalPlayerPage extends ConsumerStatefulWidget {
  /// 播放列表（连播用）；单文件播放时传 [items.length=1]
  final List<LocalVideoItem> items;
  /// 起始索引
  final int initialIndex;
  const LocalPlayerPage({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<LocalPlayerPage> createState() => _LocalPlayerPageState();
}

class _LocalPlayerPageState extends ConsumerState<LocalPlayerPage> {
  late int _index;
  String? _resolvedPath; // 系统媒体库视频的真实文件路径（异步获取）
  final _playerKey = GlobalKey<VideoPlayerWidgetState>();
  bool _initialized = false; // 是否已 seek 到续播位置
  int _seekToken = 0; // 续播 seek 竞态保护：快速切换视频时使旧 seek 失效
  Timer? _saveTimer; // 周期保存播放位置（dispose 时子组件已销毁，无法在 dispose 中读位置）

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1);
    _resolvePath();
    // 每 5 秒保存一次播放进度，避免退出时子组件已 dispose 导致丢失
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveResume());
  }

  LocalVideoItem get item => widget.items[_index];

  /// 系统媒体库视频：用 photo_manager AssetEntity 拿真实文件路径
  /// content:// URI EXO/MPV 都不支持，必须拿到 file:// 路径
  /// 网络源（WebDAV）不需要解析本地路径
  Future<void> _resolvePath() async {
    if (item.networkUrl != null && item.networkUrl!.isNotEmpty) return;
    if (item.isAppDirFile || item.assetId == null) return;
    try {
      final asset = AssetEntity(
        id: item.assetId!,
        typeInt: 1,
        width: item.width,
        height: item.height,
        duration: item.duration.inSeconds,
      );
      final file = await asset.file;
      if (mounted && file != null) {
        setState(() => _resolvedPath = file.path);
      }
    } catch (_) {}
  }

  /// 分享本地视频文件（P1）
  Future<void> _share(BuildContext context) async {
    try {
      final path = item.isAppDirFile ? item.path : null;
      if (path == null || path.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('系统媒体库文件暂不支持分享')),
          );
        }
        return;
      }
      await Share.shareXFiles(
        [XFile(path)],
        subject: item.name,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败：$e')),
        );
      }
    }
  }

  /// 切换索引（上一个/下一个/连播）
  void _jumpTo(int newIndex) {
    // 切换前保存当前视频的播放进度
    _saveResume();
    // 使进行中的续播 seek 失效，避免旧位置 seek 到新播放器
    _seekToken++;
    setState(() {
      _index = newIndex.clamp(0, widget.items.length - 1);
      _resolvedPath = null;
      _initialized = false;
    });
    _resolvePath();
  }

  /// 连播：播放完自动播下一个（P3）
  void _onPlaybackEnded() {
    // 播放完成：清除续播记录
    LocalVideoService().clearResume(item.pathHash);
    if (_index < widget.items.length - 1) {
      _jumpTo(_index + 1);
    }
  }

  /// 保存当前播放位置到 SharedPreferences（续播用）
  void _saveResume() {
    try {
      final pos = _playerKey.currentState?.currentPosition;
      if (pos != null && pos.inSeconds > 5) {
        LocalVideoService().writeResumeMs(item.pathHash, pos.inMilliseconds);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveResume(); // 最后再保存一次（此时子组件可能已销毁，但 timer 已积累最新位置）
    super.dispose();
  }

  /// 播放器初始化后 seek 到上次续播位置（P2）
  void _seekToResume() async {
    if (_initialized) return;
    _initialized = true;
    final token = ++_seekToken;
    final ms = await LocalVideoService().readResumeMs(item.pathHash);
    // 等待期间用户可能已切换视频，token 变化则放弃本次 seek
    if (token != _seekToken || !mounted) return;
    if (ms != null && ms > 5000) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (token != _seekToken || !mounted) return;
      try {
        await _playerKey.currentState?.seekTo(Duration(milliseconds: ms));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    // 把 LocalVideoItem 转成 MediaItem
    // 网络源（WebDAV）：直接用 networkUrl
    // App 目录文件：直接用 file:// 路径
    // 系统媒体库：异步拿真实文件路径（content:// 播放器不支持）
    String? playbackUrl;
    if (item.networkUrl != null && item.networkUrl!.isNotEmpty) {
      playbackUrl = item.networkUrl;
    } else if (item.isAppDirFile) {
      playbackUrl = 'file://${item.path}';
    } else if (_resolvedPath != null) {
      playbackUrl = 'file://$_resolvedPath';
    } else {
      // 还在解析真实路径，显示 loading
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final mediaItem = MediaItem(
      id: item.id,
      title: item.name,
      type: 'Movie',
      playbackUrl: playbackUrl,
      durationSeconds: item.duration.inSeconds.toDouble(),
    );

    // 播放器构建后 seek 到上次续播位置（P2）
    if (!_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _seekToResume());
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.items.length > 1)
              Text(
                '${_index + 1} / ${widget.items.length}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
          ],
        ),
        actions: [
          // 上一个
          if (widget.items.length > 1 && _index > 0)
            IconButton(
              icon: const Icon(Icons.skip_previous, color: Colors.white),
              onPressed: () => _jumpTo(_index - 1),
            ),
          // 下一个
          if (widget.items.length > 1 && _index < widget.items.length - 1)
            IconButton(
              icon: const Icon(Icons.skip_next, color: Colors.white),
              onPressed: () => _jumpTo(_index + 1),
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            tooltip: '分享',
            onPressed: () => _share(context),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: '详情',
            onPressed: () => _showInfo(context),
          ),
        ],
      ),
      body: Center(
        child: VideoPlayerWidget(
          key: _playerKey,
          item: mediaItem,
          isLocal: true,
          extraHttpHeaders: item.networkHeaders,
          autoPlay: true,
          loop: false,
          isCurrentPage: true,
          externalSubtitlePaths: item.subtitlePaths,
          onPlaybackEnded: _onPlaybackEnded,
        ),
      ),
    );
  }

  /// 详情弹窗（P1：文件名/大小/分辨率/时长/路径）
  void _showInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              _infoRow('分辨率', item.resolutionLabel),
              _infoRow('时长', item.durationLabel),
              _infoRow('大小', item.sizeLabel),
              _infoRow('修改时间',
                  '${item.modifiedAt.year}-${item.modifiedAt.month.toString().padLeft(2, '0')}-${item.modifiedAt.day.toString().padLeft(2, '0')}'),
              if (item.isAppDirFile) _infoRow('路径', item.relativePath ?? item.path),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
