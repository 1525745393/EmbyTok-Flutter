import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/local_video_item.dart';
import '../../providers/local_video_provider.dart';
import '../../utils/local_video_adapter.dart';
import '../../widgets/video/video_page_item.dart';

/// 本地视频流：抖音式上下滑播放本地媒体库视频
/// 可选 sourceId 只播放某个文件源
/// embedded=true 时由主 feed 嵌入，显示悬浮返回按钮（点击切回 Emby 推荐流）
class LocalFeedPage extends ConsumerStatefulWidget {
  const LocalFeedPage({super.key, this.sourceId, this.embedded = false});
  final String? sourceId;
  final bool embedded;

  @override
  ConsumerState<LocalFeedPage> createState() => _LocalFeedPageState();
}

class _LocalFeedPageState extends ConsumerState<LocalFeedPage> {
  final _controller = PageController();
  // 当前可见页索引：与 feed_view 同一模式，onPageChanged 后必须 setState
  // 重建 PageView。VideoPageItem 只在 widget.isCurrentPage 变化时才暂停/
  // 恢复（didUpdateWidget），并不监听 localFeedPlayingIndexProvider。
  // 原问题：下方硬编码 i == 0（注释误以为"由 onPageChanged 驱动"），
  // 滑到第 2 页起新页 isCurrentPage 恒 false 不自动播放，而第 1 页
  // 因 isCurrentPage 仍为 true 音频继续在后台响。
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(localFeedPlayingIndexProvider.notifier).state = 0;
    });
  }

  @override
  void dispose() {
    // 通知播放链路：本地 feed 页已退出。
    // widget dispose 阶段 context.mounted 已为 false，riverpod 2.6 的
    // _assertNotDisposed 会让 ref.read 抛 StateError（与 feed_view.dispose 同类
    // 问题），用 try/catch 兜底；该 provider 当前无监听方，写不成都不影响行为。
    try {
      ref.read(localFeedPlayingIndexProvider.notifier).state = -1;
    } catch (_) {
      // 忽略：dispose 阶段 ref 已不可用
    }
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
      if (widget.embedded) {
        return const Center(
          child: Text('暂无本地视频，请先在设置里添加文件源并刮削',
              style: TextStyle(color: Colors.white54)),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('本地视频流')),
        body: const Center(child: Text('暂无本地视频，请先在设置里添加文件源并刮削')),
      );
    }
    // 嵌入模式：不包 Scaffold，直接返回 PageView，让主 feed 的 Stack 接管 chrome
    final pageView = PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _controller,
      itemCount: items.length,
      physics: const PageScrollPhysics(),
      onPageChanged: (i) {
        // setState 重建 PageView，让新页 isCurrentPage=true、旧页=false
        setState(() => _currentIndex = i);
        ref.read(localFeedPlayingIndexProvider.notifier).state = i;
      },
      itemBuilder: (_, i) {
        final m = LocalVideoAdapter.toMediaItem(
          items[i],
          scraped: state.scrapedMap[items[i].pathHash],
        );
        return VideoPageItem(
          key: ValueKey(m.id),
          item: m,
          isCurrentPage: i == _currentIndex,
          source: 'local_feed',
        );
      },
    );
    if (widget.embedded) {
      // 嵌入主 feed：直接返回 PageView，由主 feed 的顶部标签/底部导航接管 chrome。
      // 用户切换顶部标签或在"视频流使用"里选 Emby 库即自动退出本地流。
      return Container(color: Colors.black, child: pageView);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          pageView,
          // 独立打开时左上角返回按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: SafeArea(
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: '返回',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
