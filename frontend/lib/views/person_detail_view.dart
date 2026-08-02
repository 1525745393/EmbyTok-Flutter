// 人员（Person）详情页：展示人员头像 + 姓名 + 出演的作品列表

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/image_cache_manager.dart';
import '../utils/utils.dart';

class PersonDetailView extends ConsumerStatefulWidget {
  final MediaItem person;

  /// 演员类型（Actor/Director/Writer），从导航来源传递，用于显示类型标签
  final String? personType;

  const PersonDetailView({super.key, required this.person, this.personType});

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
  final Map<String, bool> _groupOpen = {'Movie': true, 'Series': true};

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
      final cachedRepo = ref.read(cachedMediaRepositoryProvider);
      final serverUrl = auth.embyServerUrl;
      final token = auth.token;
      final userId = auth.user?.id;

      // 会话过期或未登录时（serverUrl/token 为 null）友好提示并提前返回，
      // 避免对 null 强制解包触发空指针崩溃；
      // 此处不调用 getPersonItems / getPersonDetail，
      // 详情区域在 build 中仍 fallback 到 widget.person，不阻塞已加载内容
      if (serverUrl == null || token == null) {
        if (mounted) {
          setState(() {
            _error = '登录已过期，请重新登录';
            _loading = false;
          });
        }
        return;
      }

      // 作品列表优先加载：先显示作品，再等详情
      // 避免 getPersonDetail 超时/失败阻塞整个页面
      final worksFuture = cachedRepo.getPersonItems(
        widget.person.id,
        serverUrl: serverUrl,
        token: token,
      );
      final detailFuture = cachedRepo.getPersonDetail(
        widget.person.id,
        serverUrl: serverUrl,
        token: token,
        userId: userId,
      );

      // 作品列表加载完成后先渲染（减少白屏时间）
      worksFuture.then((worksResponse) {
        if (mounted) {
          setState(() {
            _works = worksResponse.items;
            _total = worksResponse.total;
            _loading = false;
          });
        }
      }).catchError((Object e) {
        if (mounted) {
          setState(() {
            _error = e.toString();
            _loading = false;
          });
        }
      });

      // 详情稍后更新（不阻塞作品列表）
      // 修复：详情加载失败不影响作品列表显示，仅 fallback 到原始 person 数据
      try {
        final detail = await detailFuture;
        if (mounted && detail != null) {
          setState(() {
            _personDetail = detail;
          });
        }
      } catch (e) {
        // 详情加载失败，保留 widget.person 作为 fallback，不设置 _error
        // 仅记录日志便于排查
        AppLogger.error('加载人员详情失败', error: e);
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
    final auth = ref.read(authProvider);
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    // 会话过期或未登录时停止分页，避免强制解包触发空指针崩溃
    if (serverUrl == null || token == null) {
      return;
    }
    setState(() => _isLoadingMore = true);
    try {
      final cachedRepo = ref.read(cachedMediaRepositoryProvider);
      final response = await cachedRepo.getPersonItems(
        widget.person.id,
        serverUrl: serverUrl,
        token: token,
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
    final actorsState = ref.watch(actorsProvider);

    // 使用加载的详情数据，fallback 到原始 person
    final person = _personDetail ?? widget.person;

    // personType 为空时优先用 _personDetail.type 兜底（deeplink 场景）
    final effectiveType = widget.personType ?? _personDetail?.type;

    final isFavorited = actorsState.favoritedIds.contains(person.id);

    // 演员使用 thumbnailUrl（已构建完整URL），避免 imageTag 格式问题
    final imageUrl = person.thumbnailUrl ??
        person.primaryUrl(
          embyServerUrl: authState.embyServerUrl,
          apiKey: authState.token,
          maxWidth: 400,
        );
    final headers = person.authHeaders(authState.token);

    // 组装 toggleFavorite 需要的 Person 对象
    Person buildFavoritePerson() {
      return Person(
        id: person.id,
        name: person.title,
        type: effectiveType ?? 'Actor',
        imageUrl: person.thumbnailUrl ??
            person.primaryUrl(
              embyServerUrl: authState.embyServerUrl,
              apiKey: authState.token,
              maxWidth: 200,
            ),
      );
    }

    // 按媒体类型分组作品：先 Movie 再 Series，其余按 type 字母序
    final groupedWorks = <String, List<MediaItem>>{};
    for (final item in _works) {
      final type = item.type.isEmpty ? 'Other' : item.type;
      groupedWorks.putIfAbsent(type, () => <MediaItem>[]);
      groupedWorks[type]!.add(item);
    }
    final groupOrder = <String>[];
    if (groupedWorks.containsKey('Movie')) groupOrder.add('Movie');
    if (groupedWorks.containsKey('Series')) groupOrder.add('Series');
    final otherTypes = groupedWorks.keys
        .where((k) => k != 'Movie' && k != 'Series')
        .toList()
      ..sort();
    groupOrder.addAll(otherTypes);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: Text(person.title, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(
              isFavorited ? Icons.favorite : Icons.favorite_border,
              color: isFavorited ? scheme.primary : scheme.onSurfaceVariant,
            ),
            tooltip: isFavorited ? '取消关注' : '关注',
            onPressed: () {
              ref.read(actorsProvider.notifier).toggleFavorite(
                    buildFavoritePerson(),
                  );
            },
          ),
        ],
      ),
      // 使用 CustomScrollView + SliverList 实现长列表懒加载，
      // 避免原 SingleChildScrollView + Column + ListView(shrinkWrap) 全量构建
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 人员头像/信息区域
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 120,
                          height: 160,
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  cacheManager: AppImageCacheManager.thumbnail,
                                  fit: BoxFit.cover,
                                  fadeInDuration:
                                      const Duration(milliseconds: 300),
                                  httpHeaders:
                                      headers.isNotEmpty ? headers : null,
                                  memCacheWidth: 240,
                                  placeholder: (_, __) =>
                                      const _AvatarPlaceholder(),
                                  errorWidget: (_, __, ___) =>
                                      const _AvatarPlaceholder(),
                                )
                              : const _AvatarPlaceholder(),
                        ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              ref.read(actorsProvider.notifier).toggleFavorite(
                                    buildFavoritePerson(),
                                  );
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: scheme.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: scheme.onSurface.withValues(alpha: 0.1),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                isFavorited
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isFavorited
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: () {
                      final overview = person.overview;
                      return Column(
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
                            personTypeLabelFromCode(effectiveType),
                            style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.5),
                                fontSize: 13),
                          ),
                          if (overview != null && overview.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _ExpandableText(
                              text: overview,
                              maxLines: 6,
                              style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 12),
                            Text(
                              '暂无简介',
                              style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.4),
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      );
                    }(),
                  ),
                ],
              ),
            ),
          ),

          // 出演的作品列表标题
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Text(
                '${personWorksTitleFromCode(effectiveType)} (${_works.length})',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          // 作品列表 / loading / error / empty
          if (_loading)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: scheme.primary),
                ),
              ),
            )
          else if (_error != null)
            SliverToBoxAdapter(child: _buildError(scheme))
          else if (_works.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    '暂无作品',
                    style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 14),
                  ),
                ),
              ),
            )
          else
            ...groupOrder.map((typeCode) {
              final items = groupedWorks[typeCode]!;
              if (items.isEmpty) return <Widget>[const SliverToBoxAdapter(child: SizedBox.shrink())];
              final isOpen = _groupOpen[typeCode] ?? true;
              return <Widget>[
                // 分组头
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${mediaTypeLabelFromCode(typeCode)} (${items.length})',
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isOpen
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_right,
                            color: scheme.onSurfaceVariant,
                            size: 24,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setState(() {
                              _groupOpen[typeCode] = !isOpen;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // 分组内容（展开时才渲染）
                if (isOpen)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
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
                        final people = item.people;
                        final itemWithActor =
                            people == null || people.isEmpty
                                ? item.copyWith(people: [currentActor])
                                : item.copyWith(people: [
                                    currentActor,
                                    ...people.where(
                                        (p) => p.id != currentActor.id)
                                  ]);
                        String? currentActorRole;
                        final idMatchRole = people
                            ?.where((p) => p.id == currentPerson.id)
                            .firstOrNull
                            ?.role;
                        if (idMatchRole != null && idMatchRole.isNotEmpty) {
                          currentActorRole = idMatchRole;
                        } else {
                          final nameMatchRole = people
                              ?.where((p) =>
                                  p.name == currentPerson.title &&
                                  p.role != null &&
                                  p.role!.isNotEmpty)
                              .firstOrNull
                              ?.role;
                          if (nameMatchRole != null && nameMatchRole.isNotEmpty) {
                            currentActorRole = nameMatchRole;
                          }
                        }
                        // 用 Padding 模拟 separator 的间距：组内第一个 item top=0，其余 12px
                        return Padding(
                          padding:
                              EdgeInsets.only(top: index == 0 ? 0 : 12),
                          child: _WorkTile(
                              key: Key(item.id),
                              item: itemWithActor,
                              allItems: _works,
                              currentActorRole: currentActorRole),
                        );
                      },
                    ),
                  ),
              ];
            }).expand((list) => list),
          // 加载更多指示器
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          // 底部间距
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
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
                color: scheme.onSurface.withValues(alpha: 0.7), fontSize: 14),
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
      color: scheme.surface.withValues(alpha: 0.3),
      child: Icon(Icons.person,
          color: scheme.onSurface.withValues(alpha: 0.5), size: 64),
    );
  }
}

class _WorkTile extends ConsumerWidget {
  final MediaItem item;
  final List<MediaItem> allItems;
  final String? currentActorRole;
  const _WorkTile({super.key, required this.item, required this.allItems, this.currentActorRole});

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
        ref
            .read(playbackListProvider.notifier)
            .setPlaybackList(allItems, item.id);
        context.push('/play/${item.id}', extra: item);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
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
                  if (currentActorRole != null && (currentActorRole?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 3),
                    Text(
                      '饰：$currentActorRole',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.primary.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _yearText,
                    style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12),
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
    return mediaTypeLabelFromCode(item.type);
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
      color: scheme.surface.withValues(alpha: 0.3),
      child: Icon(Icons.movie_outlined,
          color: scheme.onSurface.withValues(alpha: 0.5)),
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
    final renderObject =
        _textKey.currentContext?.findRenderObject() as RenderBox?;
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
