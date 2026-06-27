// 人员（Person）详情页：展示人员头像 + 姓名 + 出演的作品列表

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';
import '../utils/image_cache_manager.dart';

class PersonDetailView extends ConsumerStatefulWidget {
  final MediaItem person;

  const PersonDetailView({super.key, required this.person});

  @override
  ConsumerState<PersonDetailView> createState() => _PersonDetailViewState();
}

class _PersonDetailViewState extends ConsumerState<PersonDetailView> {
  List<MediaItem> _works = const <MediaItem>[];
  MediaItem? _personDetail;
  bool _loading = true;
  String? _error;
  int _total = 0;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动监听：距底部 200px 时触发加载更多
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final service = EmbytokService();

      // 并行加载：演员详情和出演作品
      final results = await Future.wait([
        service.getPersonDetail(
          widget.person.id,
          serverUrl: auth.embyServerUrl,
          token: auth.token,
        ),
        service.getPersonItems(
          widget.person.id,
          serverUrl: auth.embyServerUrl,
          token: auth.token,
        ),
      ]);

      if (mounted) {
        setState(() {
          _personDetail = results[0] as MediaItem?;
          final worksResponse = results[1] as PaginatedResponse<MediaItem>;
          _works = worksResponse.items;
          _total = worksResponse.total;
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

  /// 分页加载更多作品
  Future<void> _loadMore() async {
    if (_isLoadingMore || _works.length >= _total) return;
    setState(() => _isLoadingMore = true);
    try {
      final auth = ref.read(authProvider);
      final service = EmbytokService();
      final response = await service.getPersonItems(
        widget.person.id,
        serverUrl: auth.embyServerUrl,
        token: auth.token,
        limit: 30,
        offset: _works.length,
      );
      if (mounted) {
        setState(() {
          _works = [..._works, ...response.items];
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    
    // 使用加载的详情数据，fallback 到原始 person
    final person = _personDetail ?? widget.person;
    
    // 演员使用 thumbnailUrl（已构建完整URL），避免 imageTag 格式问题
    final imageUrl = person.thumbnailUrl ??
        person.primaryUrl(
          embyServerUrl: authState.embyServerUrl,
          apiKey: authState.token,
          maxWidth: 400,
        );
    final headers = person.authHeaders(authState.token);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: Text(person.title, style: const TextStyle(fontSize: 16)),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
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
                              cacheManager: AppImageCacheManager.largeImage,
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
                          person.title,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '演员/导演',
                          style: TextStyle(
                              color: scheme.onSurface.withOpacity(0.5), fontSize: 13),
                        ),
                        if (person.overview != null &&
                            person.overview!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _ExpandableText(
                            text: person.overview!,
                            maxLines: 6,
                            style: TextStyle(
                              color: scheme.onSurface.withOpacity(0.7),
                              fontSize: 13,
                              height: 1.4,
                            ),
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
            else if (_works.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    '暂无作品',
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
                itemCount: _works.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _works[index];
                  // 将当前演员信息注入作品，以便播放页显示正确的演员头像
                  final currentPerson = _personDetail ?? widget.person;
                  final currentActor = Person(
                    id: currentPerson.id,
                    name: currentPerson.title,
                    type: 'Actor',
                    imageUrl: currentPerson.thumbnailUrl ??
                        currentPerson.primaryUrl(
                          embyServerUrl: authState.embyServerUrl,
                          apiKey: authState.token,
                          maxWidth: 200,
                        ),
                  );
                  final itemWithActor = item.people == null || item.people!.isEmpty
                      ? item.copyWith(people: [currentActor])
                      : item.copyWith(people: [
                          currentActor,
                          ...item.people!
                              .where((p) => p.id != currentActor.id)
                        ]);
                  return _WorkTile(key: Key(item.id), item: itemWithActor, allItems: _works);
                },
              ),
            if (_isLoadingMore)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
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
            onPressed: _loadData,
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surface.withOpacity(0.3),
      child: Icon(Icons.person, color: scheme.onSurface.withOpacity(0.5), size: 64),
    );
  }
}

class _WorkTile extends ConsumerWidget {
  final MediaItem item;
  final List<MediaItem> allItems; // 完整列表
  const _WorkTile({super.key, required this.item, required this.allItems});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.read(authProvider);
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

/// 可折叠文本组件：超过 maxLines 时显示展开/收起按钮
class _ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle style;

  const _ExpandableText({
    required this.text,
    this.maxLines = 6,
    required this.style,
  });

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _isExpanded = false;
  bool _hasOverflow = false;
  final GlobalKey _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 异步检查文本是否溢出
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverflow();
    });
  }

  void _checkOverflow() {
    final renderObject = _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderObject != null) {
      final textPainter = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: widget.maxLines,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: renderObject.size.width);
      setState(() {
        _hasOverflow = textPainter.didExceedMaxLines;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          key: _textKey,
          style: widget.style,
          maxLines: _isExpanded ? null : widget.maxLines,
          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (_hasOverflow) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _isExpanded ? '收起' : '展开',
              style: TextStyle(
                color: scheme.primary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}


