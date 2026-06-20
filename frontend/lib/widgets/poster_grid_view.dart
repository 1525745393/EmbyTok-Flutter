import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import 'tv_focusable.dart';
import 'video_page_item.dart';

/// 海报墙视图：网格布局展示视频缩略图
class PosterGridView extends ConsumerStatefulWidget {
  const PosterGridView({super.key});

  @override
  ConsumerState<PosterGridView> createState() => _PosterGridViewState();
}

class _PosterGridViewState extends ConsumerState<PosterGridView> {
  @override
  Widget build(BuildContext context) {
    final videoState = ref.watch(videoListProvider);

    if (videoState.items.isEmpty && videoState.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)));
    }
    if (videoState.items.isEmpty) {
      return const Center(
        child: Text('暂无视频', style: TextStyle(color: Colors.white70, fontSize: 16)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: videoState.items.length + (videoState.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // 分页加载触发
        if (videoState.hasMore && index >= videoState.items.length - 3 && !videoState.isLoading) {
          ref.read(videoListProvider.notifier).loadMore();
        }
        // 末尾加载指示器
        if (index >= videoState.items.length) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)));
        }
        final item = videoState.items[index];
        return _PosterCard(key: Key(item.id), item: item);
      },
    );
  }
}

/// 单个海报卡片
class _PosterCard extends ConsumerWidget {
  final MediaItem item;
  const _PosterCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final thumbnailUrl = item.thumbnailUrlWithAuth(authState.embyServerUrl, authState.token);

    return TvFocusable(
      onTap: () {
        // 点击海报进入视频播放
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            body: VideoPageItem(item: item),
          ),
        ));
      },
      borderRadius: 8,
      borderWidth: 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                httpHeaders: item.authHeaders(authState.token),
                memCacheWidth: 400,
                placeholder: (_, __) => Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE91E63), strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[900],
                  child: const Icon(Icons.broken_image, color: Colors.white30),
                ),
              )
            else
              Container(color: Colors.grey[900], child: const Icon(Icons.movie, color: Colors.white30)),
            // 底部渐变 + 标题
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            // 继续观看进度条：当有播放位置时在底部显示细粉色条
            if (item.userData != null && item.userData!.playbackPositionTicks > 0 && item.runtimeTicks != null && item.runtimeTicks! > 0)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: LinearProgressIndicator(
                  value: (item.userData!.playbackPositionTicks / item.runtimeTicks!).clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE91E63)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
