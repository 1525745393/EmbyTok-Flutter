// 从 item_detail_view.dart 拆分（part 文件，无行为变化）

part of 'item_detail_view.dart';

// ==================== 详情页辅助组件 ====================

class _BackdropPlaceholder extends StatelessWidget {
  const _BackdropPlaceholder({required this.type});
  final String type;

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
      child: Center(
          child: Icon(icon,
              color: scheme.onSurface.withValues(alpha: 0.5), size: 80)),
    );
  }
}

// 演员卡片：圆形头像 + 名称 + 角色
class _CastCard extends StatelessWidget {
  const _CastCard(
      {super.key,
      required this.person,
      required this.httpHeaders,
      this.avatarUrl,
      this.onTap});
  final Person person;
  final Map<String, String> httpHeaders;
  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = avatarUrl ?? person.imageUrl;
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
                  color: scheme.onSurface.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: ClipOval(
                child: PersonAvatarImage(
                  imageUrl: imageUrl,
                  httpHeaders: httpHeaders.isNotEmpty ? httpHeaders : null,
                  size: 72,
                  memCacheWidth: 144,
                ),
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
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
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

// 集数条目：缩略图 + SxEy + 标题 + 简介
class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    super.key,
    required this.episode,
    required this.authState,
    required this.onTap,
  });
  final MediaItem episode;
  final AuthState authState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = episode.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
      maxWidth: 300,
    );
    final headers = episode.authHeaders(authState.token);
    final seasonEp =
        (episode.parentIndexNumber != null && episode.indexNumber != null)
            ? 'S${episode.parentIndexNumber}E${episode.indexNumber}'
            : null;
    final overview = episode.overview;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.1),
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
                      errorWidget: (_, __, ___) =>
                          _ThumbPlaceholder(scheme: scheme),
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
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
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
  const _ThumbPlaceholder({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 72,
      color: scheme.surface,
      child: Icon(Icons.movie_outlined,
          color: scheme.onSurface.withValues(alpha: 0.5)),
    );
  }
}

// 相似推荐卡片：竖屏海报 + 标题
class _SimilarCard extends StatelessWidget {
  const _SimilarCard({
    super.key,
    required this.item,
    required this.authState,
    required this.onTap,
  });
  final MediaItem item;
  final AuthState authState;
  final VoidCallback onTap;

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
                        placeholder: (_, __) =>
                            _PosterPlaceholder(scheme: scheme),
                        errorWidget: (_, __, ___) =>
                            _PosterPlaceholder(scheme: scheme),
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
  const _PosterPlaceholder({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: scheme.surface,
      child: Icon(Icons.movie_outlined,
          color: scheme.onSurface.withValues(alpha: 0.5), size: 32),
    );
  }
}

// 相似推荐卡片骨架屏
class _SimilarCardSkeleton extends StatelessWidget {
  const _SimilarCardSkeleton({required this.scheme});
  final ColorScheme scheme;

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
                color: scheme.onSurface.withValues(alpha: 0.05),
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
              color: scheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
