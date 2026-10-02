import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/local_video_item.dart';
import '../../providers/local_video_provider.dart';
import 'local_player_page.dart';

/// 本地视频流：抖音式上下滑播放本地媒体库视频
/// 可选 sourceId 只播放某个文件源
/// embedded=true 时由主 feed 嵌入，显示悬浮返回按钮（点击切回 Emby 推荐流）
class LocalFeedPage extends ConsumerStatefulWidget {
  final String? sourceId;
  final bool embedded;
  const LocalFeedPage({super.key, this.sourceId, this.embedded = false});

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
      body: Stack(
        children: [
          PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _controller,
            itemCount: items.length,
            physics: const PageScrollPhysics(),
            onPageChanged: (i) => ref.read(localFeedPlayingIndexProvider.notifier).state = i,
            itemBuilder: (_, i) => LocalPlayerPage(items: items, initialIndex: i),
          ),
          // 嵌入主 feed 时左上角悬浮返回按钮，点击切回 Emby 推荐流
          if (widget.embedded)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: SafeArea(
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: '返回推荐流',
                    onPressed: () =>
                        ref.read(localFeedSourceIdProvider.notifier).set(null),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
