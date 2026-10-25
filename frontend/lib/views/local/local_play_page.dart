// 本地视频独立播放页：直接复用 VideoPageItem（与在线 feed 同一组件），
// 不再自己维护一套 Stack UI，避免与在线版本漂移。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/local_video_item.dart';
import '../../providers/app_preferences_providers_extra.dart';
import '../../providers/local_video_provider.dart';
import '../../providers/video_playback_controller.dart';
import '../../utils/local_video_adapter.dart';
import '../../utils/safe_unawaited.dart';
import '../../widgets/video/video_page_item.dart';

class LocalPlayPage extends ConsumerStatefulWidget {
  const LocalPlayPage({
    super.key,
    this.item,
    this.items = const [],
    this.initialIndex = 0,
  });

  final LocalVideoItem? item;
  final List<LocalVideoItem> items;
  final int initialIndex;

  @override
  ConsumerState<LocalPlayPage> createState() => _LocalPlayPageState();
}

class _LocalPlayPageState extends ConsumerState<LocalPlayPage> {
  late PageController _controller;
  late int _index;

  List<LocalVideoItem> get _list =>
      widget.items.isNotEmpty ? widget.items : [widget.item!];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  /// 保存指定页本地视频的续播位置 + 最近播放时间戳
  /// （key 与 LocalVideoService 一致：local_resume_<pathHash> /
  ///   local_resume_time_<pathHash>，供详情页"继续观看"与首页"播放记录"使用）
  void _savePosition(int index) {
    if (index < 0 || index >= _list.length) return;
    try {
      final ctrl = ref.read(currentVideoControllerProvider);
      if (ctrl == null || !ctrl.value.isInitialized) return;
      final hash = _list[index].pathHash;
      safeUnawaited(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
            'local_resume_$hash', ctrl.value.position.inMilliseconds);
        await prefs.setInt('local_resume_time_$hash',
            DateTime.now().millisecondsSinceEpoch);
      }());
    } catch (_) {}
  }

  @override
  void dispose() {
    // 退出播放页时保存当前页位置
    _savePosition(_index);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scrapedMap = ref.watch(localVideoProvider).scrapedMap;
    final list = _list;
    // 自动连播：监听播放结束触发事件，切到下一集（与在线 PlaybackShell 行为一致，
    // batch 26；VideoPageItem 播放结束时 trigger++ 仅触发一次）
    ref.listen<int>(autoPlayNextTriggerProvider, (prev, next) {
      if (next != prev && mounted && _controller.hasClients) {
        final nextIndex = _index + 1;
        if (nextIndex < list.length) {
          _controller.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: list.length,
        onPageChanged: (i) {
          // 离开当前页时保存该页位置
          _savePosition(_index);
          _index = i;
        },
        itemBuilder: (_, i) {
          final m = LocalVideoAdapter.toMediaItem(
            list[i],
            scraped: scrapedMap[list[i].pathHash],
          );
          return VideoPageItem(
            key: ValueKey(m.id),
            item: m,
            isCurrentPage: i == _index,
            source: 'local_play',
            // 删除当前视频后退出播放页（与在线 feed 删除后退出行为一致，batch 26）
            onVideoEnded: () {
              if (mounted) Navigator.of(context).pop();
            },
          );
        },
      ),
    );
  }
}
