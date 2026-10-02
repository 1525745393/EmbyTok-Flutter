import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/local_video_item.dart';
import '../../providers/local_video_provider.dart';
import 'local_player_page.dart';

/// 本地视频流：抖音式上下滑播放本地媒体库视频
class LocalFeedPage extends ConsumerStatefulWidget {
  const LocalFeedPage({super.key});

  @override
  ConsumerState<LocalFeedPage> createState() => _LocalFeedPageState();
}

class _LocalFeedPageState extends ConsumerState<LocalFeedPage> {
  final _controller = PageController();

  @override
  void initState() {
    super.initState();
    // 初始第一页播放
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(localFeedPlayingIndexProvider.notifier).state = 0;
    });
  }

  @override
  void dispose() {
    // 退出本地视频流时重置为 -1，避免影响独立打开的 LocalPlayerPage
    ref.read(localFeedPlayingIndexProvider.notifier).state = -1;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localVideoProvider);
    // 按最近添加倒序，新刮削的视频在前面
    final items = List<LocalVideoItem>.from(state.items);
    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('本地视频流')),
        body: const Center(child: Text('暂无本地视频，请先在设置里添加文件源并刮削')),
      );
    }
    // 直接全屏，LocalPlayerPage 自带 AppBar；避免双层标题栏
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
