// 人员（Person）详情页：展示人员头像 + 姓名 + 出演的作品列表

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';
import '../utils/colors.dart';
import '../widgets/video_page_item.dart';

class PersonDetailView extends ConsumerStatefulWidget {
  final MediaItem person;

  const PersonDetailView({super.key, required this.person});

  @override
  ConsumerState<PersonDetailView> createState() => _PersonDetailViewState();
}

class _PersonDetailViewState extends ConsumerState<PersonDetailView> {
  List<MediaItem> _works = const <MediaItem>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWorks());
  }

  Future<void> _loadWorks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final service = EmbytokService();
      final response = await service.getPersonItems(
        widget.person.id,
        serverUrl: auth.embyServerUrl,
        token: auth.token,
      );
      if (mounted) {
        setState(() {
          _works = response.items;
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
    final imageUrl = widget.person.primaryUrl(
      embyServerUrl: authState.embyServerUrl,
      apiKey: authState.token,
      maxWidth: 400,
    );
    final headers = widget.person.authHeaders(authState.token);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        title: Text(widget.person.title, style: const TextStyle(fontSize: 16)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 人员头像/信息区域
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 120,
                      height: 160,
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              httpHeaders: headers.isNotEmpty ? headers : null,
                              memCacheWidth: 240,
                              placeholder: (_, __) => const _AvatarPlaceholder(),
                              errorWidget: (_, __, ___) =>
                                  const _AvatarPlaceholder(),
                            )
                          : const _AvatarPlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          widget.person.title,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '演员/导演',
                          style: TextStyle(color: textTertiary, fontSize: 13),
                        ),
                        if (widget.person.overview != null &&
                            widget.person.overview!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.person.overview!,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 出演的作品列表
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Text(
                '出演的作品 (${_works.length})',
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
            else if (_works.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    '暂无作品',
                    style: TextStyle(color: textTertiary, fontSize: 14),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _works.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _works[index];
                  return _WorkTile(key: Key(item.id), item: item);
                },
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
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
            onPressed: _loadWorks,
          ),
        ],
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[800],
      child: Icon(Icons.person, color: textPlaceholder, size: 64),
    );
  }
}

class _WorkTile extends ConsumerWidget {
  final MediaItem item;
  const _WorkTile({super.key, required this.item});

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
            builder: (_) => _WorkPlayPage(item: item),
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
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
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

class _WorkPlayPage extends StatelessWidget {
  final MediaItem item;
  const _WorkPlayPage({required this.item});

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
