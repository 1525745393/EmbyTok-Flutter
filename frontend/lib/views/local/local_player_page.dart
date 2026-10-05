// 本地视频全屏播放页：复用 VideoPlayerWidget（三引擎），isLocal=true
// 对应 PRD《本地模式》§4.4；支持连播（P3）+ 续播位置保存（P2）
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/local_video_item.dart';
import '../../models/media_item.dart';
import '../../services/local_chapter_service.dart';
import '../../services/local_video_service.dart';
import '../../services/tmdb_service.dart';
import '../../utils/pip_util.dart';
import '../../providers/local_video_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/app_preferences_providers.dart';
import '../../widgets/video/gesture_overlay.dart';
import '../../widgets/video/video_comments_sheet.dart';
import '../../widgets/video/video_player_widget.dart';
import '../../widgets/video/video_progress_bars.dart';

/// 方向锁定三态（对齐在线全屏页）
enum _OrientationPref { landscape, portrait, sensor }

class LocalPlayerPage extends ConsumerStatefulWidget {
  /// 播放列表（连播用）；单文件播放时传 [items.length=1]
  final List<LocalVideoItem> items;
  /// 起始索引
  final int initialIndex;
  /// embedded=true 时由 LocalFeedPage 嵌入：不包 Scaffold/AppBar，
  /// 让外层 PageView 直接看到播放器画面（抖音式上下滑）
  final bool embedded;
  const LocalPlayerPage({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.embedded = false,
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
  bool _showControls = true; // 控制栏显隐（单击切换）
  bool _showProgress = true; // 进度条显隐（拖动后3秒自动隐藏，点击进度条区域显示）
  Timer? _hideTimer;
  Timer? _progressHideTimer;
  double _playbackSpeed = 1.0;
  bool _locked = false; // 屏幕锁定（隐藏控制栏，禁用手势）
  VideoPlayerController? _activeController; // 当前控制器（供缓冲/错误监听）
  int _selectedSubtitleIdx = 0; // 0=关闭, >0=外挂字幕索引（从1开始）
  bool _nightMode = false; // 夜间模式（降低屏幕亮度）
  // 方向锁定三态：landscape=横屏锁定, portrait=竖屏锁定, sensor=自动旋转
  _OrientationPref _orientationPref = _OrientationPref.landscape;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1);
    _resolvePath();
    _loadPlaybackSpeed();
    // 每 5 秒保存一次播放进度，避免退出时子组件已 dispose 导致丢失
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveResume());
  }

  /// 加载上次保存的倍速
  Future<void> _loadPlaybackSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getDouble('local_playback_speed') ?? 1.0;
    if (mounted) setState(() => _playbackSpeed = s);
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

  /// 切换本地收藏（右侧操作栏）
  void _toggleFavorite(BuildContext context) {
    ref.read(localVideoProvider.notifier).toggleFavorite(item.pathHash);
    final fav = ref.read(localVideoProvider).favoriteHashes.contains(item.pathHash);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(fav ? '已收藏' : '已取消收藏'),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  /// 控制栏自动隐藏
  void _scheduleHide() {
    if (!_showControls) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  /// 显示进度条，3秒后自动隐藏（播放中）；暂停时常驻
  void _showProgressTemporarily() {
    _progressHideTimer?.cancel();
    if (mounted) setState(() => _showProgress = true);
    final c = _activeController;
    if (c != null && c.value.isPlaying) {
      _progressHideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _activeController?.value.isPlaying == true) {
          setState(() => _showProgress = false);
        }
      });
    }
  }

  /// 点按视频：直接切换播放/暂停；暂停时显示控制栏，播放时隐藏
  void _toggleControls() {
    if (_locked) return;
    final c = _activeController;
    if (c != null && c.value.isInitialized) {
      try {
        setState(() {
          if (c.value.isPlaying) {
            c.pause();
            _showControls = true; // 暂停时显示控制栏
          } else {
            c.play();
            _showControls = false; // 播放时隐藏控制栏
          }
        });
      } catch (_) {}
    }
  }

  String _formatDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// 字幕选择（切换后重建 VideoPlayerWidget 传入新的字幕列表）
  void _showSubtitlePicker(BuildContext context) {
    final subs = item.subtitlePaths ?? const [];
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('字幕轨道')),
            ListTile(
              title: const Text('关闭字幕'),
              trailing: _selectedSubtitleIdx == 0
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                setState(() => _selectedSubtitleIdx = 0);
                Navigator.pop(context);
              },
            ),
            ...subs.asMap().entries.map((e) {
              final idx = e.key + 1;
              return ListTile(
                title: Text(e.value.split('/').last),
                trailing: _selectedSubtitleIdx == idx
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() => _selectedSubtitleIdx = idx);
                  Navigator.pop(context);
                },
              );
            }),
            if (subs.isEmpty)
              const ListTile(title: Text('无外挂字幕')),
          ],
        ),
      ),
    );
  }

  /// 音轨选择（本地暂不支持多音轨切换，提示）
  void _showAudioPicker(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('本地视频暂不支持音轨切换')),
    );
  }

  /// 画面比例（复用全局 videoFitModeProvider）
  void _showAspectPicker(BuildContext context) {
    final notifier = ref.read(videoFitModeProvider.notifier);
    final current = ref.read(videoFitModeProvider);
    const labels = {
      VideoFitMode.fit: '适应',
      VideoFitMode.fill: '填充',
      VideoFitMode.stretch: '拉伸',
      VideoFitMode.sixteenNine: '16:9',
    };
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: VideoFitMode.values
              .map((m) => ListTile(
                    title: Text(labels[m] ?? m.name),
                    trailing: m == current
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () {
                      notifier.setMode(m);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  /// 评论（TMDB 评论）
  void _showComments(BuildContext context) {
    final scraped = ref.read(localVideoProvider).scrapedMap[item.pathHash];
    if (scraped == null || scraped.tmdbId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该视频未刮削，暂无评论')),
      );
      return;
    }
    showVideoCommentsSheet(
      context,
      'local_${item.id}',
      title: scraped.title ?? item.name,
      year: scraped.year,
      isTv: scraped.type == 'tv',
    );
  }

  /// 外部播放器打开
  Future<void> _playWithExternal() async {
    final path = item.isAppDirFile ? item.path : _resolvedPath;
    if (path == null || path.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法获取文件路径')),
        );
      }
      return;
    }
    try {
      await Share.shareXFiles([XFile(path)], subject: item.name);
    } catch (_) {}
  }

  /// 章节/剧集列表：电视剧显示集数列表，电影显示内嵌章节
  Future<void> _showChapters(BuildContext context) async {
    // 电视剧：显示所有集数
    if (widget.items.length > 1) {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E1E1E),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('剧集列表', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  itemBuilder: (_, i) {
                    final it = widget.items[i];
                    final scraped = ref.read(localVideoProvider).scrapedMap[it.pathHash];
                    final isCurrent = i == _index;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCurrent ? Colors.pinkAccent : Colors.white24,
                        child: Text('${i + 1}', style: TextStyle(color: isCurrent ? Colors.white : Colors.white70, fontSize: 13)),
                      ),
                      title: Text(scraped?.title ?? it.name,
                          style: TextStyle(color: isCurrent ? Colors.pinkAccent : Colors.white, fontSize: 14)),
                      subtitle: scraped != null && scraped.overview != null && scraped.overview!.isNotEmpty
                          ? Text(scraped.overview!, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54, fontSize: 12))
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        if (i != _index) _jumpTo(i);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }
    // 电影：读取内嵌章节
    final path = item.networkUrl ?? (item.isAppDirFile ? item.path : _resolvedPath);
    if (path == null) return;
    final chapters = await LocalChapterService.getChapters(path);
    if (!context.mounted) return;
    if (chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该文件无内嵌章节')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('章节', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: chapters.length,
                itemBuilder: (_, i) => ListTile(
                  leading: Text('${chapters[i].startPositionSeconds.toInt()}s', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  title: Text(chapters[i].name, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _playerKey.currentState?.seekTo(Duration(seconds: chapters[i].startPositionSeconds.toInt()));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 删除本地视频
  void _deleteVideo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除视频'),
        content: Text('确定删除 "${item.name}"？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await LocalVideoService().delete(item);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 画中画
  Future<void> _enterPip() async {
    final ok = await PipUtil.enterPip();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画中画不可用')),
      );
    }
  }

  /// 夜间模式切换（降低屏幕亮度到 0.2，恢复到系统亮度）
  Future<void> _toggleNightMode() async {
    setState(() => _nightMode = !_nightMode);
    try {
      if (_nightMode) {
        await ScreenBrightness().setScreenBrightness(0.2);
      } else {
        await ScreenBrightness().resetScreenBrightness();
      }
    } catch (_) {}
  }

  /// 睡眠定时器（定时暂停/退出）
  void _showSleepTimer(BuildContext context) {
    final options = [15, 30, 45, 60, 90];
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('睡眠定时器')),
            ...options.map((m) => ListTile(
                  title: Text('$m 分钟'),
                  onTap: () {
                    Navigator.pop(context);
                    Future.delayed(Duration(minutes: m), () {
                      if (mounted) {
                        _activeController?.pause();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已暂停播放（${m}分钟定时）')),
                        );
                      }
                    });
                  },
                )),
            ListTile(
              title: const Text('关闭定时器'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 设置面板（统一底部弹层：字幕/音轨/倍速/画面比例）
  void _showSettingsPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.subtitles, color: Colors.white),
              title: const Text('字幕', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () { Navigator.pop(context); _showSubtitlePicker(context); },
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack, color: Colors.white),
              title: const Text('音轨', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () { Navigator.pop(context); _showAudioPicker(context); },
            ),
            ListTile(
              leading: const Icon(Icons.speed, color: Colors.white),
              title: Text('播放速度  ${_playbackSpeed}x',
                  style: const TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () { Navigator.pop(context); _showSpeedPicker(context); },
            ),
            ListTile(
              leading: const Icon(Icons.aspect_ratio, color: Colors.white),
              title: const Text('画面比例', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () { Navigator.pop(context); _showAspectPicker(context); },
            ),
            if (widget.items.length > 1)
              ListTile(
                leading: const Icon(Icons.list, color: Colors.white),
                title: Text('剧集列表  (${widget.items.length}集)',
                    style: const TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () { Navigator.pop(context); _showEpisodeList(context); },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// 剧集列表（章节/集数选择，跳转到指定集）
  void _showEpisodeList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('剧集列表',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            Flexible(
              child: Consumer(
                builder: (_, ref, __) {
                  final scrapedMap = ref.watch(localVideoProvider).scrapedMap;
                  // 按季分组（从刮削数据读取 season，无季节归为"第1季"）
                  final Map<int, List<int>> seasonGroups = {};
                  for (var i = 0; i < widget.items.length; i++) {
                    final ep = widget.items[i];
                    final s = scrapedMap[ep.pathHash]?.season ?? 1;
                    seasonGroups.putIfAbsent(s, () => []).add(i);
                  }
                  final seasons = seasonGroups.keys.toList()..sort();
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: seasons.length,
                    itemBuilder: (_, si) {
                      final season = seasons[si];
                      final epIndices = seasonGroups[season]!;
                      return ExpansionTile(
                        initiallyExpanded: true,
                        title: Text('第 $season 季（${epIndices.length} 集）',
                            style: const TextStyle(color: Colors.white, fontSize: 14)),
                        iconColor: Colors.white,
                        collapsedIconColor: Colors.white54,
                        children: epIndices.map((i) {
                          final ep = widget.items[i];
                          final isCurrent = i == _index;
                          final scraped = scrapedMap[ep.pathHash];
                          final epNum = scraped?.episode ?? (i + 1);
                          final displayTitle = scraped?.episodeTitle ?? scraped?.title ?? ep.name;
                          return ListTile(
                            leading: scraped?.stillPath != null && scraped!.stillPath!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: CachedNetworkImage(
                                      imageUrl: TmdbService.stillUrl(scraped.stillPath!),
                                      width: 80, height: 45, fit: BoxFit.cover,
                                    ),
                                  )
                                : Text(
                                    '$epNum',
                                    style: TextStyle(
                                      color: isCurrent ? Colors.greenAccent : Colors.white54,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                            title: Text(
                              displayTitle,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${_formatDur(ep.duration)}${scraped?.overview != null && scraped!.overview!.isNotEmpty ? '  ·  ${scraped.overview}' : ''}',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: isCurrent
                                ? const Icon(Icons.play_arrow, color: Colors.greenAccent)
                                : null,
                            onTap: () {
                              Navigator.pop(context);
                              if (i != _index) _jumpTo(i);
                            },
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// 倍速选择
  void _showSpeedPicker(BuildContext context) {    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: speeds
              .map((s) => ListTile(
                    title: Text('${s}x'),
                    trailing: s == _playbackSpeed
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () async {
                      final c = _activeController;
                      if (c != null) c.setPlaybackSpeed(s);
                      setState(() => _playbackSpeed = s);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setDouble('local_playback_speed', s);
                      if (mounted) Navigator.pop(context);
                      _scheduleHide();
                    },
                  ))
              .toList(),
        ),
      ),
    );
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
    _hideTimer?.cancel();
    _saveResume(); // 最后再保存一次（此时子组件可能已销毁，但 timer 已积累最新位置）
    // 退出时恢复竖屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    // 退出时恢复系统亮度（夜间模式）
    if (_nightMode) {
      ScreenBrightness().resetScreenBrightness();
    }
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

  /// 构建演员头像（对齐在线 feed PosterAvatar）
  Widget _buildActorAvatar(BuildContext context) {
    final scraped = ref.read(localVideoProvider).scrapedMap[item.pathHash];
    String? avatarUrl;
    Map<String, String>? actor;
    if (scraped != null && scraped.cast.isNotEmpty) {
      actor = scraped.cast.first;
      final pp = actor['profilePath'];
      if (pp != null && pp.isNotEmpty) {
        avatarUrl = 'https://image.tmdb.org/t/p/w185$pp';
      }
    }
    return GestureDetector(
      onTap: actor != null && (actor['id'] ?? '').isNotEmpty
          ? () => Navigator.pushNamed(context, '/person',
              arguments: {'personId': actor!['id'], 'name': actor['name']})
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white38, width: 2),
                      color: Colors.white12,
                    ),
                    child: avatarUrl != null
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.person, color: Colors.white54, size: 24),
                          )
                        : const Icon(Icons.person, color: Colors.white54, size: 24),
                  ),
                ),
                // + 关注按钮
                if (actor != null && (actor['id'] ?? '').isNotEmpty)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () {
                        final actorId = actor!['id']!;
                        final isFav = ref.read(favoritesProvider).favoriteIds.contains(actorId);
                        ref.read(favoritesProvider.notifier).toggleFavorite(
                              MediaItem(
                                id: actorId,
                                title: actor['name'] ?? '',
                                type: 'Person',
                              ),
                            );
                      },
                      child: Consumer(
                        builder: (_, ref, __) {
                          final actorId = actor!['id']!;
                          final isFav = ref.watch(favoritesProvider
                              .select((s) => s.favoriteIds.contains(actorId)));
                          return Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFav ? Colors.green : Colors.amber,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Icon(isFav ? Icons.check : Icons.add,
                                color: Colors.white, size: 12),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 56,
            child: Text(
              actor?['name'] ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 本地视频流模式：监听当前可见页，非当前页暂停
    final playingIdx = ref.watch(localFeedPlayingIndexProvider);
    final isCurrent = playingIdx < 0 || playingIdx == widget.initialIndex;
    if (playingIdx >= 0 && !isCurrent) {
      // 后台页：延迟一帧暂停，避免构建中改状态
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playerKey.currentState?.pause();
      });
    } else if (playingIdx >= 0 && isCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playerKey.currentState?.play();
      });
    }
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

    final playerBody = Center(
      child: GestureOverlay(
        controller: _activeController,
        item: mediaItem,
        enableGestures: true,
        enableVerticalVolumeDrag: true,
        onSingleTap: _toggleControls,
        child: VideoPlayerWidget(
          key: _playerKey,
          item: mediaItem,
          isLocal: true,
          extraHttpHeaders: item.networkHeaders,
          autoPlay: true,
          loop: false,
          isCurrentPage: true,
          externalSubtitlePaths: _selectedSubtitleIdx == 0
              ? const []
              : (item.subtitlePaths ?? const []),
          onPlaybackEnded: _onPlaybackEnded,
          onControllerReady: (c) => _activeController = c,
        ),
      ),
    );

    // 嵌入模式：不包 Scaffold/AppBar，直接返回播放器画面 + 控制栏 + 右侧操作栏
    // 对齐主视频流 VideoPageItem / FullscreenVideoPage 的叠加风格
    if (widget.embedded) {
      return Container(
        color: Colors.black,
        child: Stack(
          children: [
            playerBody,
            // 缓冲/错误指示
            Center(
              child: _activeController == null
                  ? const CircularProgressIndicator(color: Colors.white)
                  : ValueListenableBuilder(
                      valueListenable: _activeController!,
                      builder: (_, value, __) {
                        if (value.hasError) {
                          return const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.white, size: 48),
                              SizedBox(height: 12),
                              Text('播放失败',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          );
                        }
                        if (!value.isInitialized || value.isBuffering) {
                          return const CircularProgressIndicator(
                              color: Colors.white);
                        }
                        return const SizedBox.shrink();
                      },
                    ),
            ),
            // 顶部渐变 + 返回 + 标题
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 8,
                      right: 16,
                      bottom: 8,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white, size: 22),
                          onPressed: () => _showSettingsPanel(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 播放信息 OSD（左上角半透明：分辨率/时长）
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  opacity: _showControls ? 0.7 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (_activeController?.value.size != null &&
                              _activeController!.value.size.width > 0)
                          ? '${_activeController!.value.size.width.toInt()}×${_activeController!.value.size.height.toInt()}  ${_formatDur(_activeController!.value.duration)}'
                          : '缓冲中…',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),
            // 右侧操作栏：与独立页一致
            Positioned(
              right: 12,
              bottom: MediaQuery.of(context).padding.bottom + 110,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 演员头像
                      _buildActorAvatar(context),
                      const SizedBox(height: 12),
                      // 收藏
                      Consumer(
                        builder: (_, ref, __) {
                          final isFav = ref.watch(localVideoProvider
                              .select((s) => s.favoriteHashes.contains(item.pathHash)));
                          return IconButton(
                            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                                color: isFav ? Colors.red : Colors.white, size: 26),
                            onPressed: () => _toggleFavorite(context),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(Icons.share_outlined,
                            color: Colors.white, size: 26),
                        onPressed: () => _share(context),
                      ),
                      const SizedBox(height: 8),
                      // 外部播放
                      IconButton(
                        icon: const Icon(Icons.open_in_new,
                            color: Colors.white, size: 26),
                        onPressed: _playWithExternal,
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(Icons.picture_in_picture_alt,
                            color: Colors.white, size: 26),
                        onPressed: () => _enterPip(),
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline,
                            color: Colors.white, size: 26),
                        onPressed: () => _showComments(context),
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        icon: Icon(Icons.info_outline,
                            color: Colors.white, size: 26),
                        onPressed: () => _showInfo(context),
                      ),
                      const SizedBox(height: 8),
                      // 章节
                      IconButton(
                        icon: const Icon(Icons.list_alt_outlined,
                            color: Colors.white, size: 26),
                        onPressed: () => _showChapters(context),
                      ),
                      const SizedBox(height: 8),
                      // 删除
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white, size: 26),
                        onPressed: () => _deleteVideo(context),
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(Icons.subtitles,
                            color: Colors.white, size: 26),
                        onPressed: () => _showSubtitlePicker(context),
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(Icons.audiotrack,
                            color: Colors.white, size: 26),
                        onPressed: () => _showAudioPicker(context),
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(Icons.aspect_ratio,
                            color: Colors.white, size: 26),
                        onPressed: () => _showAspectPicker(context),
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        icon: Icon(
                          _nightMode ? Icons.bedtime : Icons.bedtime_outlined,
                          color: _nightMode ? Colors.amber : Colors.white,
                          size: 26,
                        ),
                        onPressed: _toggleNightMode,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 底部控制栏：播放/暂停 + 进度条 + 时间 + 倍速 + 全屏
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: MediaQuery.of(context).padding.bottom + 8,
                      top: 8,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _activeController != null
                            ? SeekableProgressBar(
                                controller: _activeController!,
                                formatDuration: _formatDur,
                              )
                            : const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 上一集（对齐在线 fullscreen_builders）
                            IconButton(
                              icon: const Icon(Icons.skip_previous, color: Colors.white),
                              onPressed: _index > 0 ? () => _jumpTo(_index - 1) : null,
                            ),
                            IconButton(
                              icon: Icon(
                                _activeController?.value.isPlaying ?? false
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                                color: Colors.white,
                                size: 44,
                              ),
                              onPressed: () {
                                final c = _activeController;
                                if (c == null) return;
                                setState(() {
                                  c.value.isPlaying ? c.pause() : c.play();
                                });
                                _scheduleHide();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_next, color: Colors.white),
                              onPressed: _index < widget.items.length - 1
                                  ? () => _jumpTo(_index + 1)
                                  : null,
                            ),
                            const Spacer(),
                            // 剧集列表按钮（多集时显示，对齐在线）
                            if (widget.items.length > 1)
                              IconButton(
                                icon: const Icon(Icons.playlist_play,
                                    color: Colors.white, size: 22),
                                onPressed: () => _showEpisodeList(context),
                              ),
                            GestureDetector(
                              onTap: () => _showSpeedPicker(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_playbackSpeed}x',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 屏幕锁定
                            IconButton(
                              icon: Icon(
                                _locked ? Icons.lock : Icons.lock_open,
                                color: Colors.white,
                                size: 22,
                              ),
                              onPressed: () {
                                setState(() {
                                  _locked = !_locked;
                                  if (_locked) {
                                    _hideTimer?.cancel();
                                    _showControls = false;
                                  } else {
                                    _showControls = true;
                                    _scheduleHide();
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.fullscreen,
                                  color: Colors.white, size: 24),
                              onPressed: () {
                                // 横屏：锁定方向
                                SystemChrome.setPreferredOrientations([
                                  DeviceOrientation.landscapeLeft,
                                  DeviceOrientation.landscapeRight,
                                ]);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 独立播放页：纯 Stack 覆盖层（无 Scaffold/AppBar），对齐在线 FullscreenVideoPage 沉浸模式
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          playerBody,
          // 缓冲/错误指示
          Center(
            child: _activeController == null
                ? const CircularProgressIndicator(color: Colors.white)
                : ValueListenableBuilder(
                    valueListenable: _activeController!,
                    builder: (_, value, __) {
                      if (value.hasError) {
                        return const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, color: Colors.white, size: 48),
                            SizedBox(height: 12),
                            Text('播放失败', style: TextStyle(color: Colors.white)),
                          ],
                        );
                      }
                      if (!value.isInitialized || value.isBuffering) {
                        return const CircularProgressIndicator(color: Colors.white);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
          ),
          // 顶部栏（透明覆盖，无 AppBar）
          Positioned(
            top: 0, left: 0, right: 0,
            child: IgnorePointer(
              ignoring: !_showControls,
              child: AnimatedOpacity(
                opacity: _showControls ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 4, left: 4, right: 4),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.fullscreen, color: Colors.white, size: 22),
                        onPressed: () {
                          setState(() {
                            _orientationPref = _orientationPref == _OrientationPref.landscape
                                ? _OrientationPref.portrait
                                : _OrientationPref.landscape;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 右侧操作栏
          Positioned(
            right: 8,
            top: MediaQuery.of(context).padding.top + 50,
            bottom: MediaQuery.of(context).padding.bottom + 100,
            child: IgnorePointer(
              ignoring: !_showControls,
              child: AnimatedOpacity(
                opacity: _showControls ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 演员头像
                      _buildActorAvatar(context),
                      const SizedBox(height: 8),
                    // 按钮顺序对齐在线 feed：点赞→分享→外部播放→画中画→评论→信息→章节→删除→字幕→音轨→比例→夜间模式
                    Consumer(
                      builder: (_, ref, __) {
                        final isFav = ref.watch(localVideoProvider
                            .select((s) => s.favoriteHashes.contains(item.pathHash)));
                        return IconButton(
                          icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? Colors.red : Colors.white, size: 26),
                          onPressed: () => _toggleFavorite(context),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: const Icon(Icons.share_outlined,
                          color: Colors.white, size: 26),
                      onPressed: () => _share(context),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: const Icon(Icons.open_in_new,
                          color: Colors.white, size: 26),
                      onPressed: _playWithExternal,
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: const Icon(Icons.picture_in_picture_alt,
                          color: Colors.white, size: 26),
                      onPressed: () => _enterPip(),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline,
                          color: Colors.white, size: 26),
                      onPressed: () => _showComments(context),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: Icon(Icons.info_outline,
                          color: Colors.white, size: 26),
                      onPressed: () => _showInfo(context),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: const Icon(Icons.list_alt_outlined,
                          color: Colors.white, size: 26),
                      onPressed: () => _showChapters(context),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.white, size: 26),
                      onPressed: () => _deleteVideo(context),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: const Icon(Icons.subtitles,
                          color: Colors.white, size: 26),
                      onPressed: () => _showSubtitlePicker(context),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: const Icon(Icons.audiotrack,
                          color: Colors.white, size: 26),
                      onPressed: () => _showAudioPicker(context),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: const Icon(Icons.aspect_ratio,
                          color: Colors.white, size: 26),
                      onPressed: () => _showAspectPicker(context),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: Icon(
                        _nightMode ? Icons.bedtime : Icons.bedtime_outlined,
                        color: _nightMode ? Colors.amber : Colors.white,
                        size: 26,
                      ),
                      onPressed: _toggleNightMode,
                    ),
                    const SizedBox(height: 8),
                    // 剧集列表
                    if (widget.items.length > 1)
                      IconButton(
                        icon: const Icon(Icons.playlist_play, color: Colors.white, size: 26),
                        onPressed: () => _showEpisodeList(context),
                      ),
                    if (widget.items.length > 1) const SizedBox(height: 8),
                    // 倍速
                    GestureDetector(
                      onTap: () => _showSpeedPicker(context),
                      child: Container(
                        width: 44, height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(22)),
                        child: Text('${_playbackSpeed}x', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 锁屏
                    IconButton(
                      icon: Icon(_locked ? Icons.lock : Icons.lock_open, color: Colors.white, size: 26),
                      onPressed: () => setState(() => _locked = !_locked),
                    ),
                    const SizedBox(height: 8),
                    // 旋转
                    IconButton(
                      icon: Icon(
                        _orientationPref == _OrientationPref.landscape
                            ? Icons.screen_lock_rotation
                            : _orientationPref == _OrientationPref.portrait
                                ? Icons.stay_current_portrait
                                : Icons.screen_rotation,
                        color: Colors.white, size: 26,
                      ),
                      onPressed: () {
                        setState(() {
                          switch (_orientationPref) {
                            case _OrientationPref.landscape:
                              _orientationPref = _OrientationPref.portrait;
                              break;
                            case _OrientationPref.portrait:
                              _orientationPref = _OrientationPref.sensor;
                              break;
                            case _OrientationPref.sensor:
                              _orientationPref = _OrientationPref.landscape;
                              break;
                          }
                        });
                        switch (_orientationPref) {
                          case _OrientationPref.landscape:
                            SystemChrome.setPreferredOrientations([
                              DeviceOrientation.landscapeLeft,
                              DeviceOrientation.landscapeRight,
                            ]);
                            break;
                          case _OrientationPref.portrait:
                            SystemChrome.setPreferredOrientations([
                              DeviceOrientation.portraitUp,
                              DeviceOrientation.portraitDown,
                            ]);
                            break;
                          case _OrientationPref.sensor:
                            SystemChrome.setPreferredOrientations([
                              DeviceOrientation.portraitUp,
                              DeviceOrientation.landscapeLeft,
                              DeviceOrientation.landscapeRight,
                              DeviceOrientation.portraitDown,
                            ]);
                            break;
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              ),
            ),
          ),
          // 底部信息卡（随控制栏显隐）
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: IgnorePointer(
              ignoring: !_showControls,
              child: AnimatedOpacity(
                opacity: _showControls ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 40,
                    top: 8,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 信息卡（对齐在线 feed：类型标签+标题+评分+简介+导演主演）
                      Consumer(
                        builder: (_, ref, __) {
                          final scraped = ref.watch(localVideoProvider
                              .select((s) => s.scrapedMap[item.pathHash]));
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (scraped != null && scraped.genres.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.pinkAccent.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    scraped.genres.first,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      scraped?.title ?? item.name,
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (scraped != null && scraped.year != null && scraped.year! > 0)
                                    Text(' (${scraped.year})', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                ],
                              ),
                              if (scraped != null && (scraped.rating != null && scraped.rating! > 0 || item.duration.inSeconds > 0))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      if (scraped.rating != null && scraped.rating! > 0) ...[
                                        const Icon(Icons.star, color: Colors.pinkAccent, size: 16),
                                        const SizedBox(width: 4),
                                        Text(scraped.rating!.toStringAsFixed(1), style: const TextStyle(color: Colors.pinkAccent, fontSize: 14, fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 12),
                                      ],
                                      if (item.duration.inSeconds > 0)
                                        Text(_formatDur(item.duration),
                                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              if (scraped != null && scraped.overview != null && scraped.overview!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    scraped.overview!,
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              if (scraped != null && (scraped.directors.isNotEmpty || scraped.cast.isNotEmpty))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '导演：${scraped.directors.take(1).join("")} ｜ 主演：${scraped.cast.take(3).map((c) => c["name"] ?? "").join("、")}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 进度条（播放中3秒自动隐藏，点击底部区域显示）
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: GestureDetector(
              onTap: _showProgressTemporarily,
              behavior: HitTestBehavior.opaque,
              child: IgnorePointer(
                ignoring: !_showProgress,
                child: AnimatedOpacity(
                  opacity: _showProgress ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: MediaQuery.of(context).padding.bottom + 8,
                    ),
                    child: _activeController != null
                        ? SeekableProgressBar(controller: _activeController!, formatDuration: _formatDur)
                        : const SizedBox(height: 2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 详情弹窗：刮削元数据 + 文件信息
  void _showInfo(BuildContext context) {
    final scraped = ref.read(localVideoProvider).scrapedMap[item.pathHash];
    final backdropUrl = scraped?.backdropPath != null && scraped!.backdropPath!.isNotEmpty
        ? 'https://image.tmdb.org/t/p/w1280${scraped.backdropPath}'
        : null;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Stack(
            children: [
              // 背景模糊 backdrop
              if (backdropUrl != null)
                Positioned.fill(
                  child: Image.network(backdropUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1E1E))),
                ),
              if (backdropUrl != null)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(color: const Color(0xFF1E1E1E).withValues(alpha: 0.7)),
                  ),
                ),
              if (backdropUrl == null)
                Container(color: const Color(0xFF1E1E1E)),
              // 内容
              SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 海报 + 缩略图
                    if (scraped?.posterPath != null && scraped!.posterPath!.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: 'https://image.tmdb.org/t/p/w342${scraped.posterPath}',
                              width: 110, height: 165, fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (scraped.backdropPath != null && scraped.backdropPath!.isNotEmpty)
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: 'https://image.tmdb.org/t/p/w300${scraped.backdropPath}',
                                  height: 165, fit: BoxFit.cover,
                                ),
                              ),
                            ),
                        ],
                      ),
                    if (scraped?.posterPath != null) const SizedBox(height: 16),
                // 标题
                Text(scraped?.title ?? item.name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                // 季集信息
                if (scraped != null && scraped.season != null && scraped.episode != null)
                  Text('第${scraped.season}季 第${scraped.episode}集',
                      style: const TextStyle(color: Colors.pinkAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                if (scraped?.episodeTitle != null && scraped!.episodeTitle!.isNotEmpty)
                  Text(scraped.episodeTitle!,
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                if (scraped != null && scraped.year != null)
                  Text('${scraped.year}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 16),
                // 评分 + 类型
                if (scraped != null && (scraped.rating != null || scraped.genres.isNotEmpty))
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (scraped.rating != null && scraped.rating! > 0)
                        Chip(
                          backgroundColor: Colors.pinkAccent.withValues(alpha: 0.2),
                          label: Text('★ ${scraped.rating!.toStringAsFixed(1)}',
                              style: const TextStyle(color: Colors.pinkAccent, fontSize: 12)),
                        ),
                      ...scraped.genres.take(4).map((g) => Chip(
                            backgroundColor: Colors.white12,
                            label: Text(g, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          )),
                    ],
                  ),
                if (scraped != null && (scraped.rating != null || scraped.genres.isNotEmpty))
                  const SizedBox(height: 16),
                // 简介
                if (scraped != null && scraped.overview != null && scraped.overview!.isNotEmpty) ...[
                  const Text('简介', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(scraped.overview!, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
                  const SizedBox(height: 16),
                ],
                // 导演
                if (scraped != null && scraped.directors.isNotEmpty) ...[
                  _infoRow('导演', scraped.directors.join('、')),
                  const SizedBox(height: 8),
                ],
                // 演员
                if (scraped != null && scraped.cast.isNotEmpty) ...[
                  const Text('演职人员', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...scraped.cast.take(8).map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white12,
                              backgroundImage: c['profilePath'] != null && c['profilePath']!.isNotEmpty
                                  ? NetworkImage('https://image.tmdb.org/t/p/w92${c['profilePath']}')
                                  : null,
                              child: c['profilePath'] == null || c['profilePath']!.isEmpty
                                  ? const Icon(Icons.person, size: 16, color: Colors.white54)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  if (c['character'] != null && c['character']!.isNotEmpty)
                                    Text(c['character']!, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
                // 媒体信息
                const Text('媒体信息', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _infoRow('文件名', item.name),
                _infoRow('分辨率', item.resolutionLabel),
                _infoRow('时长', item.durationLabel),
                _infoRow('大小', item.sizeLabel),
                _infoRow('修改时间',
                    '${item.modifiedAt.year}-${item.modifiedAt.month.toString().padLeft(2, '0')}-${item.modifiedAt.day.toString().padLeft(2, '0')}'),
                if (item.isAppDirFile) _infoRow('路径', item.relativePath ?? item.path),
              ],
            ),
          ),
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
