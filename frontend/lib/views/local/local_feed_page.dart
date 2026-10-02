import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/local_video_item.dart';
import '../../providers/local_video_provider.dart';
import 'local_player_page.dart';

/// 本地视频流：抖音式上下滑播放本地媒体库视频
/// 可选 sourceId 只播放某个文件源
class LocalFeedPage extends ConsumerStatefulWidget {
  final String? sourceId;
  const LocalFeedPage({super.key, this.sourceId});

  @override
  ConsumerState<LocalFeedPage> createState() => _LocalFeedPageState();
}

class _LocalFeedPageState extends ConsumerState<LocalFeedPage> {
  final _controller = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(localFeedPlayingIndexProvider.notifier).state = 0;
    });
  }

  @override
  void dispose() {
    ref.read(localFeedPlayingIndexProvider.notifier).state = -1;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localVideoProvider);
    var items = List<LocalVideoItem>.from(state.items);
    // 按文件源过滤
    if (widget.sourceId != null) {
      items = items.where((it) => it.sourceId == widget.sourceId).toList();
    }
    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('本地视频流')),
        body: const Center(child: Text('暂无本地视频，请先在设置里添加文件源并刮削')),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _controller,
        itemCount: items.length,
        physics: const PageScrollPhysics(),
        onPageChanged: (i) => ref.read(localFeedPlayingIndexProvider.notifier).state = i,
        itemBuilder: (_, i) => LocalPlayerPage(items: items, initialIndex: i),
      ),
    );
  }
}
