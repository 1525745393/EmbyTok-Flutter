// 合集（BoxSet）详情页：展示合集海报 + 简介 + 包含的影片列表

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';
import '../utils/image_cache_manager.dart';
import '../widgets/video_page_item.dart';

class BoxsetDetailView extends ConsumerStatefulWidget {
  final MediaItem item;

  const BoxsetDetailView({super.key, required this.item});

  @override
  ConsumerState<BoxsetDetailView> createState() => _BoxsetDetailViewState();
}

class _BoxsetDetailViewState extends ConsumerState<BoxsetDetailView> {
  List<MediaItem> _children = const <MediaItem>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadChildren());
  }

  Future<void> _loadChildren() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final service = EmbytokService();
      final items = await service.getChildren(
        widget.item.id,
        serverUrl: auth.embyServerUrl,
        token: auth.token,
      );
      if (mounted) {
        setState(() {
          _children = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final imageUrl = widget.item.backdropUrl(
      embyServerUrl: authState.embyServerUrl,
      apiKey: authState.token,
    ) ?? widget.item.primaryUrl(
      embyServerUrl: authState.embyServerUrl,
      apiKey: authState.token,
    );
    final headers = widget.item.authHeaders(authState.token);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: Text(widget.item.title, style: const TextStyle(fontSize: 16)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 海报区域
            AspectRatio(
              aspectRatio: 16 / 9,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      cacheManager: AppImageCacheManager.largeImage,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      httpHeaders: headers.isNotEmpty ? headers : null,
                      memCacheWidth: 1000,
                      placeholder: (_, __) =>
                          Container(color: scheme.surface.withOpacity(0.3)),
                      errorWidget: (_, __, ___) =>
                          const _CoverPlaceholder(),
                    )
                  : const _CoverPlaceholder(),
            ),

            // 标题和信息
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _subtitleText,
                    style: TextStyle(
                      color: scheme.onSurface.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                  if (widget.item.overview != null &&
                      widget.item.overview!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      widget.item.overview!,
                      style: TextStyle(
                        color: scheme.onSurface.withOpacity(0.7),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 包含的影片列表
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Text(
                '包含的影片 (${_children.length})',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            if (_loading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: scheme.primary),
                ),
              )
            else if (_error != null)
              _buildError(scheme)
            else if (_children.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    '暂无影片',
                    style: TextStyle(
                        color: scheme.onSurface.withOpacity(0.5), fontSize: 14),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _children.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final child = _children[index];
                  return _ChildTile(key: Key(child.id), item: child, allItems: _children);
                },
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String get _subtitleText {
    final year = widget.item.productionYear ?? widget.item.year;
    if (year != null) {
      return '合集 · $year';
    }
    return '合集';
  }

  Widget _buildError(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 36),
          const SizedBox(height: 8),
          Text(
            _error ?? '加载失败',
            style: TextStyle(
                color: scheme.onSurface.withOpacity(0.7), fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重试'),
            onPressed: _loadChildren,
          ),
        ],
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surface.withOpacity(0.3),
      child:
          Icon(Icons.featured_play_list, color: scheme.onSurface.withOpacity(0.5), size: 80),
    );
  }
}

class _ChildTile extends ConsumerWidget {
  final MediaItem item;
  final List<MediaItem> allItems; // 完整列表
  const _ChildTile({super.key, required this.item, required this.allItems});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final imageUrl = item.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
      maxWidth: 300,
    );
    final headers = item.authHeaders(authState.token);

    return InkWell(
      onTap: () {
        // 设置播放列表后再跳转
        ref.read(playbackListProvider.notifier).setPlaybackList(allItems, item.id);
        context.push('/play/${item.id}', extra: item);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.onSurface.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      cacheManager: AppImageCacheManager.thumbnail,
                      width: 120,
                      height: 72,
                      fit: BoxFit.cover,
                      httpHeaders: headers.isNotEmpty ? headers : null,
                      memCacheWidth: 240,
                      placeholder: (_, __) => const _ThumbPlaceholder(),
                      errorWidget: (_, __, ___) => const _ThumbPlaceholder(),
                    )
                  : const _ThumbPlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _yearText,
                    style: TextStyle(
                        color: scheme.onSurface.withOpacity(0.5), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.play_circle_fill, color: scheme.primary, size: 32),
          ],
        ),
      ),
    );
  }

  String get _yearText {
    final year = item.productionYear ?? item.year;
    if (year != null) return year.toString();
    return item.type;
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 120,
      height: 72,
      color: scheme.surface.withOpacity(0.3),
      child: Icon(Icons.movie_outlined, color: scheme.onSurface.withOpacity(0.5)),
    );
  }
}

class _PlayPage extends StatelessWidget {
  final MediaItem item;
  const _PlayPage({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: Text(item.title, style: const TextStyle(fontSize: 16)),
      ),
      body: VideoPageItem(item: item),
    );
  }
}
