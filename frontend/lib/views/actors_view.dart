// 演员列表页面：展示 Emby 服务器上的所有演员，支持关注/取消关注

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';

class ActorsView extends ConsumerStatefulWidget {
  final bool useScaffold;

  const ActorsView({super.key, this.useScaffold = true});

  @override
  ConsumerState<ActorsView> createState() => _ActorsViewState();
}

class _ActorsViewState extends ConsumerState<ActorsView> {
  List<Person> _actors = const <Person>[];
  bool _loading = true;
  String? _error;
  Set<String> _favoritedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadActors());
  }

  Future<void> _loadActors() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final service = EmbytokService();

      // 获取所有演员
      final people = await service.getPeople(
        limit: 100,
        personTypes: ['Actor'],
        serverUrl: auth.embyServerUrl,
        token: auth.token,
      );

      // 获取已收藏的演员
      final favoritePeople = await service.getFavoritePeople(
        serverUrl: auth.embyServerUrl,
        token: auth.token,
      );

      if (mounted) {
        setState(() {
          _actors = people;
          _favoritedIds = Set.from(favoritePeople.map((p) => p.id));
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

  Future<void> _toggleFavorite(Person actor) async {
    final isFavorited = _favoritedIds.contains(actor.id);
    try {
      final auth = ref.read(authProvider);
      final service = EmbytokService();

      // 创建 MediaItem 用于收藏操作
      final mediaItem = MediaItem(
        id: actor.id ?? '',
        title: actor.name,
        type: 'Person',
        imageTags: actor.imageUrl != null ? {'Primary': actor.imageUrl!} : {},
      );

      await service.toggleFavorite(
        itemId: actor.id ?? '',
        isFavorite: !isFavorited,
        serverUrl: auth.embyServerUrl,
        token: auth.token,
      );

      if (mounted) {
        setState(() {
          if (isFavorited) {
            _favoritedIds.remove(actor.id);
          } else {
            _favoritedIds.add(actor.id ?? '');
          }
        });

        // 更新 favoritesProvider
        ref.read(favoritesProvider.notifier).toggleFavorite(mediaItem);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  void _navigateToPersonDetail(Person actor) {
    final mediaItem = MediaItem(
      id: actor.id ?? '',
      title: actor.name,
      type: 'Person',
      imageTags: actor.imageUrl != null ? {'Primary': actor.imageUrl!} : {},
    );
    context.push('/person/${actor.id}', extra: mediaItem);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final embyServerUrl = authState.embyServerUrl;
    final token = authState.token;

    final content = CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          title: const Text('演员', style: TextStyle(fontSize: 16)),
          pinned: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: _loading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
                  ? SliverFillRemaining(child: _buildError(scheme))
                  : _actors.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(child: Text('暂无演员')),
                        )
                      : SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 16,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final actor = _actors[index];
                              return _ActorCard(
                                actor: actor,
                                embyServerUrl: embyServerUrl,
                                token: token,
                                isFavorited: _favoritedIds.contains(actor.id),
                                onFavoriteTap: () => _toggleFavorite(actor),
                                onTap: () => _navigateToPersonDetail(actor),
                              );
                            },
                            childCount: _actors.length,
                          ),
                        ),
        ),
      ],
    );

    if (widget.useScaffold) {
      return Scaffold(
        backgroundColor: scheme.surface,
        body: content,
      );
    }

    return content;
  }

  Widget _buildError(ColorScheme scheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, color: scheme.error, size: 36),
        const SizedBox(height: 8),
        Text(
          _error ?? '加载失败',
          style: TextStyle(color: scheme.onSurface.withOpacity(0.7), fontSize: 14),
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
          onPressed: _loadActors,
        ),
      ],
    );
  }
}

class _ActorCard extends StatelessWidget {
  final Person actor;
  final String? embyServerUrl;
  final String? token;
  final bool isFavorited;
  final VoidCallback onFavoriteTap;
  final VoidCallback onTap;

  const _ActorCard({
    required this.actor,
    required this.embyServerUrl,
    required this.token,
    required this.isFavorited,
    required this.onFavoriteTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String? imageUrl;
    if (actor.imageUrl != null && actor.imageUrl!.isNotEmpty) {
      imageUrl = actor.imageUrl;
    } else if (actor.id != null && actor.id!.isNotEmpty && embyServerUrl != null) {
      imageUrl = '$embyServerUrl/Items/${actor.id!}/Images/Primary?MaxWidth=200'
          '${token != null ? '&api_key=$token' : ''}';
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    color: scheme.surface.withOpacity(0.3),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Center(
                              child: Icon(Icons.person, color: scheme.onSurface.withOpacity(0.5)),
                            ),
                            errorWidget: (_, __, ___) => Center(
                              child: Icon(Icons.person, color: scheme.onSurface.withOpacity(0.5)),
                            ),
                          )
                        : Center(
                            child: Icon(Icons.person, color: scheme.onSurface.withOpacity(0.5)),
                          ),
                  ),
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: GestureDetector(
                    onTap: onFavoriteTap,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFavorited ? scheme.primary : scheme.surface,
                        border: Border.all(color: scheme.onSurface.withOpacity(0.3), width: 2),
                      ),
                      child: Icon(
                        isFavorited ? Icons.favorite : Icons.favorite_border,
                        color: isFavorited ? scheme.onPrimary : scheme.onSurface,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            actor.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            isFavorited ? '已关注' : '未关注',
            style: TextStyle(
              color: isFavorited ? scheme.primary : scheme.onSurface.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}