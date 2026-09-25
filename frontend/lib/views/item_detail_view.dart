// 媒体项详情页：展示海报、标题、评分、简介、演员、集数列表
// 支持影片/剧集/音乐视频等类型，剧集类显示集数列表
// 路由：/item/:itemId

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../utils/constants.dart';
import '../providers/providers.dart';
import '../utils/image_cache_manager.dart';
import '../utils/logger.dart';
import '../widgets/person_avatar_image.dart';
part 'item_detail_widgets.dart';
part 'item_detail_loaders.dart';

class ItemDetailView extends ConsumerStatefulWidget {
  const ItemDetailView({
    super.key,
    required this.itemId,
    this.initialItem,
  });
  final String itemId;
  // 可选：直接传入已加载的 MediaItem，避免重复请求
  final MediaItem? initialItem;

  @override
  ConsumerState<ItemDetailView> createState() => _ItemDetailViewState();
}

class _ItemDetailViewState extends ConsumerState<ItemDetailView> {
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
  bool _studiosExpanded = false;
  bool _genresExpanded = false;
  // 相关推荐
  List<MediaItem> _similarItems = const <MediaItem>[];
  bool _loadingSimilar = false;

  @override
  void initState() {
    super.initState();
    _item = widget.initialItem;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }

  // 加载详情：若已有 initialItem 则只补全剧集信息，否则通过缓存仓库请求详情
  // 加载季列表 - 通过缓存仓库复用中 TTL 缓存
  // 加载指定季的集数列表 - 通过缓存仓库复用中 TTL 缓存
  // 加载相似推荐 - 通过缓存仓库复用中 TTL 缓存，避免重复请求
  // 切换季
  // 立即播放：跳转到 VideoPageItem 播放页
  // 切换收藏
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final currentItem = _item;
    final favorited = currentItem != null &&
        ref.watch(favoritesProvider).favoriteIds.contains(currentItem.id);
    final hasBackdrop = !_loading && _error == null && currentItem != null;

    return Scaffold(
      backgroundColor: scheme.surface,
      extendBodyBehindAppBar: hasBackdrop,
      appBar: AppBar(
        backgroundColor: hasBackdrop ? Colors.transparent : scheme.surface,
        foregroundColor: hasBackdrop ? Colors.white : scheme.onSurface,
        elevation: hasBackdrop ? 0 : null,
        title: const Text(''),
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
        // 底部避让刘海屏黑条区域
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部大图（横屏海报）
            _buildBackdrop(item, authState),
            // 主信息区 + 操作栏
            _buildMainInfo(item),
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

  // 顶部沉浸式背景大图 + 叠加标题/操作
  Widget _buildBackdrop(MediaItem item, AuthState authState) {
    final imageUrl = item.backdropUrl(
          embyServerUrl: authState.embyServerUrl,
          apiKey: authState.token,
        ) ??
        item.primaryUrl(
          embyServerUrl: authState.embyServerUrl,
          apiKey: authState.token,
        );
    final headers = item.authHeaders(authState.token);
    final scheme = Theme.of(context).colorScheme;
    final progress = item.progressPercent;

    return Stack(
      children: [
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
                  placeholder: (_, __) => Container(
                      color: Theme.of(context).colorScheme.surface),
                  errorWidget: (_, __, ___) =>
                      _BackdropPlaceholder(type: item.type),
                )
              : _BackdropPlaceholder(type: item.type),
        ),
        // 底部渐变遮罩，使下面的文字可读
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  scheme.surface.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
        ),
        // 叠加标题和播放按钮
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(blurRadius: 4, color: Colors.black54),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // 播放按钮
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text(
                      progress > 0 ? '继续观看 ${(progress * 100).round()}%' : '立即播放',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => _playItem(item),
                  ),
                  const SizedBox(width: 8),
                  // 收藏按钮
                  _buildFavoriteButton(
                      ref.watch(favoritesProvider).favoriteIds.contains(item.id),
                      scheme,
                      dark: true),
                  const SizedBox(width: 8),
                  // 标记已观看/未观看
                  _buildWatchedButton(item, scheme, authState),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 主信息区：类型标签、年份、评分 + 导演 + 时长
  Widget _buildMainInfo(MediaItem item) {
    final scheme = Theme.of(context).colorScheme;
    final year = item.productionYear ?? item.year;
    final rating = item.communityRating ?? item.rating;
    final director =
        item.people?.where((p) => p.type == 'Director').firstOrNull;
    final directorName = director?.name;
    final durationText = item.formattedDuration;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 影片类型标签 + 年份 + 评分 + 导演 + 时长 + 评级
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 影片类型（动作/冒险/科幻等），超过4个可展开
              ...() {
                final genres = item.displayGenres;
                final visible = _genresExpanded ? genres : genres.take(4).toList();
                return [
                  ...visible.map((g) => _buildInfoChip(g)),
                  if (genres.length > 4)
                    _buildExpandChip(
                      _genresExpanded ? '收起' : '展开全部(${genres.length})',
                      () => setState(() => _genresExpanded = !_genresExpanded),
                    ),
                ];
              }(),
              if (year != null) _buildInfoChip(year.toString()),
              if (rating != null && rating > 0) _buildRatingChip(rating),
              // 家长评级（如 PG-13/R）
              if (item.officialRating != null && item.officialRating!.isNotEmpty)
                _buildInfoChip(item.officialRating!),
              if (directorName != null && directorName.isNotEmpty)
                _buildInfoChip('导演：$directorName'),
              if (durationText.isNotEmpty) _buildInfoChip(durationText),
            ],
          ),
          // 制作公司（超过3家可展开）
          if (item.studioNames != null && item.studioNames!.isNotEmpty) ...[
            const SizedBox(height: 10),
            StatefulBuilder(
              builder: (context, setState) {
                final studios = item.studioNames!;
                final expanded = _studiosExpanded;
                final visible = expanded ? studios : studios.take(3).toList();
                return GestureDetector(
                  onTap: () => setState(() => _studiosExpanded = !_studiosExpanded),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      children: [
                        TextSpan(text: '出品：${visible.join("、")}'),
                        if (studios.length > 3)
                          TextSpan(
                            text: expanded ? ' 收起' : ' 展开全部(${studios.length})',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // 收藏按钮
  Widget _buildFavoriteButton(bool favorited, ColorScheme scheme,
      {bool dark = false}) {
    final bg = dark ? Colors.white.withValues(alpha: 0.25) : scheme.onSurface.withValues(alpha: 0.1);
    // dark 模式下收藏变红，未收藏白色；普通模式收藏用 primary
    final iconColor = favorited
        ? (dark ? Colors.red : scheme.primary)
        : (dark ? Colors.white : scheme.onSurface);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dark ? Colors.white24 : scheme.outlineVariant),
      ),
      child: IconButton(
        icon: Icon(
          favorited ? Icons.favorite : Icons.favorite_border,
          color: iconColor,
          size: 20,
        ),
        onPressed: _toggleFavorite,
        tooltip: favorited ? '取消收藏' : '添加收藏',
      ),
    );
  }

  // 标记已观看/未观看按钮
  Widget _buildWatchedButton(MediaItem item, ColorScheme scheme,
      AuthState authState) {
    final watched = item.isWatched;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: IconButton(
        icon: Icon(
          watched ? Icons.done_all : Icons.remove_done,
          color: Colors.white,
          size: 20,
        ),
        tooltip: watched ? '标记为未观看' : '标记为已观看',
        onPressed: () async {
          final service = ref.read(embytokServiceProvider);
          if (watched) {
            await service.markAsUnplayed(item.id,
                serverUrl: authState.embyServerUrl, token: authState.token);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已标记为未观看')),
              );
            }
          } else {
            await service.markAsPlayed(item.id,
                serverUrl: authState.embyServerUrl, token: authState.token);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已标记为已观看')),
              );
            }
          }
          _loadDetail();
        },
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
        color: scheme.onSurface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      ),
    );
  }

  // 展开/收起标签
  Widget _buildExpandChip(String text, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: scheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // 评分标签（星标 + 数字）
  Widget _buildRatingChip(double rating) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.tertiary.withValues(alpha: 0.2),
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
    final httpHeaders = authState.token != null && authState.token!.isNotEmpty
        ? embyAuthHeaders(authState.token!)
        : <String, String>{};
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
                // 构建演员头像完整 URL（Emby People 数组通常不返回完整 ImageUrl）
                String? avatarUrl;
                if (person.id != null && person.id!.isNotEmpty &&
                    authState.embyServerUrl != null &&
                    authState.token != null) {
                  avatarUrl =
                      '${authState.embyServerUrl}/Items/${person.id}/Images/Primary?MaxWidth=200&api_key=${authState.token}';
                } else if (person.imageUrl != null &&
                    person.imageUrl!.startsWith('http')) {
                  avatarUrl = person.imageUrl;
                }
                return _CastCard(
                  key: Key(person.id ?? person.name),
                  person: person,
                  avatarUrl: avatarUrl,
                  httpHeaders: httpHeaders,
                  onTap: () {
                    final pid = person.id;
                    if (pid == null || pid.isEmpty) return;
                    context.push('/person/$pid', extra: {
                      'item': MediaItem(
                        id: pid,
                        title: person.name,
                        type: 'Person',
                        thumbnailUrl: avatarUrl,
                        overview: person.overview,
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
                            : scheme.onSurface.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? scheme.primary
                              : scheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        season.title,
                        style: TextStyle(
                          color: isSelected
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
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
                  style: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      fontSize: 14),
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
                    itemBuilder: (_, __) =>
                        _SimilarCardSkeleton(scheme: scheme),
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
                        // 点击相似推荐：进入该影片详情页
                        onTap: () => context.push('/item/${item.id}', extra: item),
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
