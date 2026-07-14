// 媒体项详情页：展示海报、标题、评分、简介、演员、集数列表
// 支持影片/剧集/音乐视频等类型，剧集类显示集数列表
// 路由：/item/:itemId

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';
import '../utils/image_cache_manager.dart';
import '../widgets/video_page_item.dart';

class ItemDetailView extends ConsumerStatefulWidget {
  final String itemId;
  // 可选：直接传入已加载的 MediaItem，避免重复请求
  final MediaItem? initialItem;

  const ItemDetailView({
    super.key,
    required this.itemId,
    this.initialItem,
  });

  @override
  ConsumerState<ItemDetailView> createState() => _ItemDetailViewState();
}

class _ItemDetailViewState extends ConsumerState<ItemDetailView> {
  // 复用 EmbytokService 实例，避免每次调用方法都创建新实例
  // EmbytokService 内部可能持有 HTTP client，频繁创建会浪费资源
  late final EmbytokService _service;

  MediaItem? _item;
  bool _loading = true;
  String? _error;
  // 剧集类：季列表和当前选中季的集数列表
  List<MediaItem> _seasons = const <MediaItem>[];
  List<MediaItem> _episodes = const <MediaItem>[];
  String? _selectedSeasonId;
  bool _loadingEpisodes = false;
  // 简介展开状态
  bool _overviewExpanded = false;
  // 相关推荐
  List<MediaItem> _similarItems = const <MediaItem>[];
  bool _loadingSimilar = false;

  @override
  void initState() {
    super.initState();
    _service = EmbytokService();
    _item = widget.initialItem;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }

  // 加载详情：若已有 initialItem 则只补全剧集信息，否则请求详情
  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final currentItem = _item;
      MediaItem item;
      if (currentItem != null && currentItem.id == widget.itemId) {
        item = currentItem;
      } else {
        item = await _service.getItemDetail(
          widget.itemId,
          serverUrl: auth.embyServerUrl,
          token: auth.token,
          userId: auth.user?.id,
        );
      }
      if (!mounted) return;
      setState(() {
        _item = item;
        _loading = false;
      });
      // 剧集类：加载季列表
      if (item.type == 'Series') {
        await _loadSeasons(item.id);
      }
      // 异步加载相似推荐（不阻塞主流程）
      _loadSimilarItems(item.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // 加载季列表
  Future<void> _loadSeasons(String seriesId) async {
    try {
      final auth = ref.read(authProvider);
      final seasons = await _service.getSeasons(
        seriesId,
        serverUrl: auth.embyServerUrl,
        token: auth.token,
      );
      if (!mounted) return;
      setState(() {
        _seasons = seasons;
        // 默认选中第一季（如果有）
        _selectedSeasonId = seasons.isNotEmpty ? seasons.first.id : null;
      });
      final seasonId = _selectedSeasonId;
      if (seasonId != null) {
        await _loadEpisodes(seriesId, seasonId);
      }
    } catch (_) {
      // 季列表加载失败不阻塞详情页展示
    }
  }

  // 加载指定季的集数列表
  Future<void> _loadEpisodes(String seriesId, String seasonId) async {
    setState(() {
      _loadingEpisodes = true;
    });
    try {
      final auth = ref.read(authProvider);
      final resp = await _service.getEpisodes(
        seriesId,
        seasonId: seasonId,
        serverUrl: auth.embyServerUrl,
        token: auth.token,
      );
      if (!mounted) return;
      setState(() {
        _episodes = resp.items;
        _loadingEpisodes = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _episodes = const <MediaItem>[];
          _loadingEpisodes = false;
        });
      }
    }
  }

  // 加载相似推荐
  Future<void> _loadSimilarItems(String itemId) async {
    setState(() {
      _loadingSimilar = true;
    });
    try {
      final auth = ref.read(authProvider);
      final items = await _service.getSimilarItems(
        itemId,
        limit: 12,
        serverUrl: auth.embyServerUrl,
        token: auth.token,
      );
      if (!mounted) return;
      setState(() {
        _similarItems = items;
        _loadingSimilar = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _similarItems = const <MediaItem>[];
          _loadingSimilar = false;
        });
      }
    }
  }

  // 切换季
  void _selectSeason(String seasonId) {
    if (seasonId == _selectedSeasonId) return;
    setState(() {
      _selectedSeasonId = seasonId;
    });
    final item = _item;
    if (item != null) {
      _loadEpisodes(item.id, seasonId);
    }
  }

  // 立即播放：跳转到 VideoPageItem 播放页
  void _playItem(MediaItem item) {
    // 设置播放列表后再跳转（剧集使用 _episodes 作为播放列表）
    final items = item.type == 'Episode' ? _episodes : [item];
    ref.read(playbackListProvider.notifier).setPlaybackList(items, item.id);
    context.push('/play/${item.id}', extra: item);
  }

  // 切换收藏
  void _toggleFavorite() {
    final item = _item;
    if (item == null) return;
    ref.read(favoritesProvider.notifier).toggleFavorite(item);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final currentItem = _item;
    final favorited = currentItem != null &&
        ref.watch(favoritesProvider).favoriteIds.contains(currentItem.id);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: Text(
          _item?.title ?? '详情',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: _buildBody(authState, favorited, scheme),
    );
  }

  Widget _buildBody(AuthState authState, bool favorited, ColorScheme scheme) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: scheme.primary),
      );
    }
    if (_error != null) {
      return _buildErrorView(scheme);
    }
    final item = _item;
    if (item == null) {
      return Center(
        child: Text('未找到内容', style: TextStyle(color: scheme.onSurfaceVariant)),
      );
    }
    final overview = item.overview;
    final people = item.people;
    return RefreshIndicator(
      color: scheme.primary,
      onRefresh: _loadDetail,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部大图（横屏海报）
            _buildBackdrop(item, authState),
            // 主信息区 + 操作栏
            _buildMainInfo(item, favorited),
            // 简介区（可展开折叠）
            if (overview != null && overview.isNotEmpty)
              _buildOverview(overview),
            // 演员区
            if (people != null && people.isNotEmpty)
              _buildCast(people, authState),
            // 集数区（仅 Series 类型）
            if (item.type == 'Series') _buildSeasonsAndEpisodes(authState),
            // 相关推荐区
            _buildSimilarItems(authState),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // 顶部背景大图
  Widget _buildBackdrop(MediaItem item, AuthState authState) {
    final imageUrl = item.backdropUrl(
      embyServerUrl: authState.embyServerUrl,
      apiKey: authState.token,
    ) ?? item.primaryUrl(
      embyServerUrl: authState.embyServerUrl,
      apiKey: authState.token,
    );
    final headers = item.authHeaders(authState.token);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: imageUrl != null && imageUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              cacheManager: AppImageCacheManager.largeImage,
              fit: BoxFit.cover,
              width: double.infinity,
              httpHeaders: headers.isNotEmpty ? headers : null,
              memCacheWidth: 1000,
              placeholder: (_, __) => Container(color: Theme.of(context).colorScheme.surface),
              errorWidget: (_, __, ___) => _BackdropPlaceholder(type: item.type),
            )
          : _BackdropPlaceholder(type: item.type),
    );
  }

  // 主信息区：标题、类型标签、年份、评分 + 操作按钮
  Widget _buildMainInfo(MediaItem item, bool favorited) {
    final scheme = Theme.of(context).colorScheme;
    final year = item.productionYear ?? item.year;
    final rating = item.communityRating ?? item.rating;
    // 导演：从 people 中过滤 type 为 Director 的人，取第一个
    final director = item.people
        ?.where((p) => p.type == 'Director')
        .firstOrNull;
    final directorName = director?.name;
    // 时长
    final durationText = item.formattedDuration;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Text(
            item.title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          // 类型标签 + 年份 + 评分 + 导演 + 时长
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildTypeChip(item.type),
              if (year != null)
                _buildInfoChip(year.toString()),
              if (rating != null && rating > 0)
                _buildRatingChip(rating),
              if (directorName != null && directorName.isNotEmpty)
                _buildInfoChip('导演：$directorName'),
              if (durationText.isNotEmpty)
                _buildInfoChip(durationText),
            ],
          ),
          const SizedBox(height: 16),
          // 操作栏：立即播放 + 收藏
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text(
                    '立即播放',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => _playItem(item),
                ),
              ),
              const SizedBox(width: 12),
              _buildFavoriteButton(favorited, scheme),
            ],
          ),
        ],
      ),
    );
  }

  // 收藏按钮
  Widget _buildFavoriteButton(bool favorited, ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.onSurface.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: IconButton(
        icon: Icon(
          favorited ? Icons.favorite : Icons.favorite_border,
          color: favorited ? scheme.primary : scheme.onSurface,
          size: 22,
        ),
        onPressed: _toggleFavorite,
        tooltip: favorited ? '取消收藏' : '添加收藏',
      ),
    );
  }

  // 类型标签
  Widget _buildTypeChip(String type) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: scheme.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // 普通信息标签
  Widget _buildInfoChip(String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.onSurface.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      ),
    );
  }

  // 评分标签（星标 + 数字）
  Widget _buildRatingChip(double rating) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.tertiary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, color: scheme.tertiary, size: 14),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: scheme.tertiary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // 简介区（可展开折叠）
  Widget _buildOverview(String overview) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '简介',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _overviewExpanded = !_overviewExpanded;
              });
            },
            child: Text(
              overview,
              maxLines: _overviewExpanded ? null : 3,
              overflow: _overviewExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _overviewExpanded = !_overviewExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _overviewExpanded ? '收起' : '展开',
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 演员区：横向滚动头像 + 名称
  Widget _buildCast(List<Person> people, AuthState authState) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '演员',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: people.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final person = people[index];
                return _CastCard(
                  key: Key(person.id ?? person.name),
                  person: person,
                  onTap: () {
                    final pid = person.id;
                    if (pid == null || pid.isEmpty) return;
                    context.push('/person/$pid', extra: {
                      'item': MediaItem(
                        id: pid,
                        title: person.name,
                        type: 'Person',
                        thumbnailUrl: person.imageUrl,
                      ),
                      'personType': person.type,
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 季列表 + 集数列表
  Widget _buildSeasonsAndEpisodes(AuthState authState) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 季选择器（横向滚动）
          if (_seasons.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '分集',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _seasons.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final season = _seasons[index];
                  final isSelected = season.id == _selectedSeasonId;
                  return GestureDetector(
                    onTap: () => _selectSeason(season.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.primary
                            : scheme.onSurface.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? scheme.primary : scheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        season.title,
                        style: TextStyle(
                          color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          // 集数列表
          if (_loadingEpisodes)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(color: scheme.primary),
              ),
            )
          else if (_episodes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  '暂无集数',
                  style: TextStyle(color: scheme.onSurfaceVariant.withOpacity(0.7), fontSize: 14),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _episodes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final ep = _episodes[index];
                return _EpisodeTile(
                  key: Key(ep.id),
                  episode: ep,
                  authState: authState,
                  onTap: () => _playItem(ep),
                );
              },
            ),
        ],
      ),
    );
  }

  // 相关推荐区：横向滚动卡片列表
  Widget _buildSimilarItems(AuthState authState) {
    final scheme = Theme.of(context).colorScheme;
    // 加载完成但无数据，不显示
    if (!_loadingSimilar && _similarItems.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '相关推荐',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: _loadingSimilar
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 7,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, __) => _SimilarCardSkeleton(scheme: scheme),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _similarItems.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = _similarItems[index];
                      return _SimilarCard(
                        key: Key(item.id),
                        item: item,
                        authState: authState,
                        // 点击相似推荐：跳转到播放页，并注入相似推荐列表作为播放队列
                        onTap: () => context.push('/play/${item.id}', extra: {
                          'item': item,
                          'items': _similarItems,
                        }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 错误视图
  Widget _buildErrorView(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: scheme.error, size: 48),
            const SizedBox(height: 12),
            Text(
              _error ?? '加载失败',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重试'),
              onPressed: _loadDetail,
            ),
          ],
        ),
      ),
    );
  }
}

// 顶部背景图占位
class _BackdropPlaceholder extends StatelessWidget {
  final String type;
  const _BackdropPlaceholder({required this.type});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    IconData icon;
    switch (type) {
      case 'Series':
        icon = Icons.tv;
        break;
      case 'MusicVideo':
        icon = Icons.music_video;
        break;
      case 'BoxSet':
        icon = Icons.collections;
        break;
      default:
        icon = Icons.movie;
    }
    return Container(
      color: scheme.surface,
      child: Center(child: Icon(icon, color: scheme.onSurface.withOpacity(0.5), size: 80)),
    );
  }
}

// 演员卡片：圆形头像 + 名称 + 角色
class _CastCard extends StatelessWidget {
  final Person person;
  final VoidCallback? onTap;
  const _CastCard({super.key, required this.person, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = person.imageUrl;
    final role = person.role;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            // 圆形头像
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surface,
                border: Border.all(
                  color: scheme.onSurface.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
              child: ClipOval(
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        cacheManager: AppImageCacheManager.thumbnail,
                        fit: BoxFit.cover,
                        memCacheWidth: 144,
                        placeholder: (_, __) => _AvatarPlaceholder(scheme: scheme),
                        errorWidget: (_, __, ___) => _AvatarPlaceholder(scheme: scheme),
                      )
                    : _AvatarPlaceholder(scheme: scheme),
              ),
            ),
            const SizedBox(height: 6),
            // 名称
            Text(
              person.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            // 角色名（如果有）
            if (role != null && role.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant.withOpacity(0.7),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  final ColorScheme scheme;
  const _AvatarPlaceholder({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: scheme.surface,
      child: Icon(Icons.person, color: scheme.onSurface.withOpacity(0.5), size: 32),
    );
  }
}

// 集数条目：缩略图 + SxEy + 标题 + 简介
class _EpisodeTile extends StatelessWidget {
  final MediaItem episode;
  final AuthState authState;
  final VoidCallback onTap;

  const _EpisodeTile({
    super.key,
    required this.episode,
    required this.authState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = episode.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
      maxWidth: 300,
    );
    final headers = episode.authHeaders(authState.token);
    final seasonEp = (episode.parentIndexNumber != null &&
            episode.indexNumber != null)
        ? 'S${episode.parentIndexNumber}E${episode.indexNumber}'
        : null;
    final overview = episode.overview;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.onSurface.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            // 缩略图
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
                      placeholder: (_, __) => _ThumbPlaceholder(scheme: scheme),
                      errorWidget: (_, __, ___) => _ThumbPlaceholder(scheme: scheme),
                    )
                  : _ThumbPlaceholder(scheme: scheme),
            ),
            const SizedBox(width: 12),
            // 标题 + 简介
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (seasonEp != null)
                    Text(
                      seasonEp,
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    episode.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (overview != null && overview.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
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
}

class _ThumbPlaceholder extends StatelessWidget {
  final ColorScheme scheme;
  const _ThumbPlaceholder({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 72,
      color: scheme.surface,
      child: Icon(Icons.movie_outlined, color: scheme.onSurface.withOpacity(0.5)),
    );
  }
}

// 相似推荐卡片：竖屏海报 + 标题
class _SimilarCard extends StatelessWidget {
  final MediaItem item;
  final AuthState authState;
  final VoidCallback onTap;

  const _SimilarCard({
    super.key,
    required this.item,
    required this.authState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = item.primaryUrl(
      embyServerUrl: authState.embyServerUrl,
      apiKey: authState.token,
      maxWidth: 300,
    );
    final headers = item.authHeaders(authState.token);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 竖屏海报（3:4 比例）
            AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        cacheManager: AppImageCacheManager.thumbnail,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        httpHeaders: headers.isNotEmpty ? headers : null,
                        memCacheWidth: 200,
                        placeholder: (_, __) => _PosterPlaceholder(scheme: scheme),
                        errorWidget: (_, __, ___) => _PosterPlaceholder(scheme: scheme),
                      )
                    : _PosterPlaceholder(scheme: scheme),
              ),
            ),
            const SizedBox(height: 6),
            // 标题（1行截断）
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 海报占位图
class _PosterPlaceholder extends StatelessWidget {
  final ColorScheme scheme;
  const _PosterPlaceholder({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: scheme.surface,
      child: Icon(Icons.movie_outlined, color: scheme.onSurface.withOpacity(0.5), size: 32),
    );
  }
}

// 相似推荐卡片骨架屏
class _SimilarCardSkeleton extends StatelessWidget {
  final ColorScheme scheme;
  const _SimilarCardSkeleton({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 海报骨架
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              decoration: BoxDecoration(
                color: scheme.onSurface.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // 标题骨架
          Container(
            width: double.infinity,
            height: 12,
            decoration: BoxDecoration(
              color: scheme.onSurface.withOpacity(0.05),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

// 详情页播放页：包装 VideoPageItem
class _DetailPlayPage extends StatelessWidget {
  final MediaItem item;
  const _DetailPlayPage({required this.item});

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
