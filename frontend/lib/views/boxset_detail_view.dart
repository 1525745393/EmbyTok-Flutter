// 合集（BoxSet）详情页：展示合集海报 + 简介 + 包含的影片列表

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';
import '../utils/colors.dart';
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
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
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
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      headers: headers.isNotEmpty ? headers : null,
                      errorBuilder: (_, __, ___) =>
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
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _subtitleText,
                    style: TextStyle(
                      color: textTertiary,
                      fontSize: 13,
                    ),
                  ),
                  if (widget.item.overview != null &&
                      widget.item.overview!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      widget.item.overview!,
                      style: TextStyle(
                        color: textSecondary,
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
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: primaryPink),
                ),
              )
            else if (_error != null)
              _buildError()
            else if (_children.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    '暂无影片',
                    style: TextStyle(color: textTertiary, fontSize: 14),
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
                  return _ChildTile(item: child);
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

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: errorColor, size: 36),
          const SizedBox(height: 8),
          Text(
            _error ?? '加载失败',
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPink,
              foregroundColor: textPrimary,
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
    return Container(
      color: Colors.grey[900],
      child: Icon(Icons.featured_play_list, color: textPlaceholder, size: 80),
    );
  }
}

class _ChildTile extends ConsumerWidget {
  final MediaItem item;
  const _ChildTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final imageUrl = item.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
      maxWidth: 300,
    );
    final headers = item.authHeaders(authState.token);

    return InkWell(
      onTap: () {
        Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => _PlayPage(item: item),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dividerColor),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 120,
                      height: 72,
                      fit: BoxFit.cover,
                      headers: headers.isNotEmpty ? headers : null,
                      errorBuilder: (_, __, ___) => const _ThumbPlaceholder(),
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
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _yearText,
                    style: TextStyle(color: textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.play_circle_fill, color: historyPink, size: 32),
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
    return Container(
      width: 120,
      height: 72,
      color: Colors.grey[800],
      child: Icon(Icons.movie_outlined, color: textPlaceholder),
    );
  }
}

class _PlayPage extends StatelessWidget {
  final MediaItem item;
  const _PlayPage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        title: Text(item.title, style: const TextStyle(fontSize: 16)),
      ),
      body: VideoPageItem(item: item),
    );
  }
}
