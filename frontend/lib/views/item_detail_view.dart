// 媒体项详情页：展示海报、标题、评分、简介、演员、集数列表
// 支持影片/剧集/音乐视频等类型，剧集类显示集数列表
// 路由：/item/:itemId

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';
import '../utils/colors.dart';
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

  @override
  void initState() {
    super.initState();
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
      final service = EmbytokService();
      MediaItem item;
      if (_item != null && _item!.id == widget.itemId) {
        item = _item!;
      } else {
        item = await service.getItemDetail(
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
      final service = EmbytokService();
      final seasons = await service.getSeasons(
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
      if (_selectedSeasonId != null) {
        await _loadEpisodes(seriesId, _selectedSeasonId!);
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
      final service = EmbytokService();
      final resp = await service.getEpisodes(
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

  // 切换季
  void _selectSeason(String seasonId) {
    if (seasonId == _selectedSeasonId) return;
    setState(() {
      _selectedSeasonId = seasonId;
    });
    if (_item != null) {
      _loadEpisodes(_item!.id, seasonId);
    }
  }

  // 立即播放：跳转到 VideoPageItem 播放页
  void _playItem(MediaItem item) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _DetailPlayPage(item: item),
      ),
    );
  }

  // 切换收藏
  void _toggleFavorite() {
    final item = _item;
    if (item == null) return;
    ref.read(favoritesProvider.notifier).toggleFavorite(item);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final favorited = _item != null &&
        ref.watch(favoritesProvider).favoriteIds.contains(_item!.id);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        title: Text(
          _item?.title ?? '详情',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: _buildBody(authState, favorited),
    );
  }

  Widget _buildBody(AuthState authState, bool favorited) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryPink),
      );
    }
    if (_error != null) {
      return _buildErrorView();
    }
    if (_item == null) {
      return const Center(
        child: Text('未找到内容', style: TextStyle(color: textSecondary)),
      );
    }
    final item = _item!;
    return RefreshIndicator(
      color: primaryPink,
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
            if (item.overview != null && item.overview!.isNotEmpty)
              _buildOverview(item.overview!),
            // 演员区
            if (item.people != null && item.people!.isNotEmpty)
              _buildCast(item.people!, authState),
            // 集数区（仅 Series 类型）
            if (item.type == 'Series') _buildSeasonsAndEpisodes(authState),
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
              fit: BoxFit.cover,
              width: double.infinity,
              httpHeaders: headers.isNotEmpty ? headers : null,
              memCacheWidth: 1000,
              placeholder: (_, __) => Container(color: grey900),
              errorWidget: (_, __, ___) => _BackdropPlaceholder(type: item.type),
            )
          : _BackdropPlaceholder(type: item.type),
    );
  }

  // 主信息区：标题、类型标签、年份、评分 + 操作按钮
  Widget _buildMainInfo(MediaItem item, bool favorited) {
    final year = item.productionYear ?? item.year;
    final rating = item.communityRating ?? item.rating;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Text(
            item.title,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          // 类型标签 + 年份 + 评分
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
            ],
          ),
          const SizedBox(height: 16),
          // 操作栏：立即播放 + 收藏
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    foregroundColor: textPrimary,
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
              _buildFavoriteButton(favorited),
            ],
          ),
        ],
      ),
    );
  }

  // 收藏按钮
  Widget _buildFavoriteButton(bool favorited) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dividerColor),
      ),
      child: IconButton(
        icon: Icon(
          favorited ? Icons.favorite : Icons.favorite_border,
          color: favorited ? primaryPink : textPrimary,
          size: 22,
        ),
        onPressed: _toggleFavorite,
        tooltip: favorited ? '取消收藏' : '添加收藏',
      ),
    );
  }

  // 类型标签
  Widget _buildTypeChip(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: primaryPink,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: const TextStyle(
          color: textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // 普通信息标签
  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(color: textSecondary, fontSize: 12),
      ),
    );
  }

  // 评分标签（星标 + 数字）
  Widget _buildRatingChip(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x33FFC107),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: amberColor, size: 14),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: amberColor,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '简介',
            style: TextStyle(
              color: textPrimary,
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
              style: const TextStyle(
                color: textSecondary,
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
                style: const TextStyle(
                  color: primaryPink,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '演员',
              style: TextStyle(
                color: textPrimary,
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
                return _CastCard(key: Key(person.id ?? person.name), person: person);
              },
            ),
          ),
        ],
      ),
    );
  }

  // 季列表 + 集数列表
  Widget _buildSeasonsAndEpisodes(AuthState authState) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 季选择器（横向滚动）
          if (_seasons.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '分集',
                style: TextStyle(
                  color: textPrimary,
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
                            ? primaryPink
                            : const Color(0x1AFFFFFF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? primaryPink : dividerColor,
                        ),
                      ),
                      child: Text(
                        season.title,
                        style: TextStyle(
                          color: isSelected ? textPrimary : textSecondary,
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
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(color: primaryPink),
              ),
            )
          else if (_episodes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  '暂无集数',
                  style: TextStyle(color: textTertiary, fontSize: 14),
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

  // 错误视图
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: errorColor, size: 48),
            const SizedBox(height: 12),
            Text(
              _error ?? '加载失败',
              style: const TextStyle(color: textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPink,
                foregroundColor: textPrimary,
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
      color: grey900,
      child: Center(child: Icon(icon, color: textPlaceholder, size: 80)),
    );
  }
}

// 演员卡片：圆形头像 + 名称 + 角色
class _CastCard extends StatelessWidget {
  final Person person;
  const _CastCard({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          // 圆形头像
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: grey800,
            ),
            child: ClipOval(
              child: person.imageUrl != null && person.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: person.imageUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 144,
                      placeholder: (_, __) => const _AvatarPlaceholder(),
                      errorWidget: (_, __, ___) =>
                          const _AvatarPlaceholder(),
                    )
                  : const _AvatarPlaceholder(),
            ),
          ),
          const SizedBox(height: 6),
          // 名称
          Text(
            person.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          // 角色名（如果有）
          if (person.role != null && person.role!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                person.role!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: textTertiary, fontSize: 11),
                textAlign: TextAlign.center,
              ),
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
      color: grey800,
      child: const Icon(Icons.person, color: textPlaceholder, size: 32),
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

    return InkWell(
      onTap: onTap,
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
            // 缩略图
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
            // 标题 + 简介
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (seasonEp != null)
                    Text(
                      seasonEp,
                      style: const TextStyle(
                        color: primaryPink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    episode.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (episode.overview != null &&
                      episode.overview!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        episode.overview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.play_circle_fill, color: primaryPink, size: 32),
          ],
        ),
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 72,
      color: grey800,
      child: const Icon(Icons.movie_outlined, color: textPlaceholder),
    );
  }
}

// 详情页播放页：包装 VideoPageItem
class _DetailPlayPage extends StatelessWidget {
  final MediaItem item;
  const _DetailPlayPage({required this.item});

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
