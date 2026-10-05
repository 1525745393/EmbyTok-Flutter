// 本地视频独立播放页：直接复用 VideoPageItem（与在线 feed 同一组件），
// 不再自己维护一套 Stack UI，避免与在线版本漂移。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/local_video_item.dart';
import '../../providers/local_video_provider.dart';
import '../../utils/local_video_adapter.dart';
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

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scrapedMap = ref.watch(localVideoProvider).scrapedMap;
    final list = widget.items.isNotEmpty ? widget.items : [widget.item!];
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: list.length,
        onPageChanged: (i) => _index = i,
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
          );
        },
      ),
    );
  }
}
