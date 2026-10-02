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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localVideoProvider);
    final items = List<LocalVideoItem>.from(state.items);
    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('本地视频流')),
        body: const Center(child: Text('暂无本地视频，请先在设置里添加文件源并刮削')),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('本地视频流 · ${items.length}', style: const TextStyle(color: Colors.white)),
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _controller,
        itemCount: items.length,
        itemBuilder: (_, i) => LocalPlayerPage(items: items, initialIndex: i),
      ),
    );
  }
}
