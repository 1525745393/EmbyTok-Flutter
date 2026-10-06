import '../models/local_video_item.dart';
import '../models/media_item.dart';
import '../models/media_source.dart';
import '../models/person.dart';
import '../services/scrape_service.dart';
import '../services/tmdb_service.dart';

/// 本地视频 → Emby MediaItem 适配器
/// 让本地视频能直接注入主 feed 的 videoListProvider，
/// 复用 VideoPageItem 的全部叠加（底部信息条、右侧操作栏、进度记忆）。
class LocalVideoAdapter {
  static MediaItem toMediaItem(LocalVideoItem it, {ScrapedMedia? scraped}) {
    final isTv = scraped?.type == 'tv';
    // 演员列表：ScrapedMedia.cast 是 [{id,name,role,profilePath}]
    final people = scraped?.cast
        .map((c) => Person(
              name: c['name'] ?? '',
              id: c['id'],
              role: c['role'] ?? '',
              type: 'Actor',
              imageUrl: (c['profilePath']?.isNotEmpty ?? false)
                  ? TmdbService.personUrl(c['profilePath']!)
                  : null,
            ))
        .toList();
    return MediaItem(
      // id 加 local_ 前缀，避免与 Emby item id 冲突
      id: 'local_${it.id}',
      title: scraped?.episodeTitle ?? scraped?.title ?? it.name,
      type: isTv ? 'Episode' : 'Movie',
      seriesName: isTv ? scraped?.title : null,
      parentIndexNumber: isTv ? scraped?.season : null,
      indexNumber: isTv ? scraped?.episode : null,
      productionYear: scraped?.year ?? it.modifiedAt.year,
      year: scraped?.year ?? it.modifiedAt.year,
      durationSeconds: it.duration.inSeconds.toDouble(),
      overview: scraped?.overview ?? '',
      communityRating: scraped?.rating,
      genres: scraped?.genres,
      studioNames: scraped?.studios,
      people: people,
      // 本地刮削后：把 TMDB poster URL 放进 imageTags['Primary']，复用现有海报渲染
      imageTags: scraped?.posterPath != null
          ? {'Primary': 'https://image.tmdb.org/t/p/w300${scraped!.posterPath}'}
          : const {},
      backdropImageTags: scraped?.backdropPath != null
          ? ['https://image.tmdb.org/t/p/w780${scraped!.backdropPath}']
          : const [],
      isLocalFile: true,
      localPath: it.networkUrl != null && it.networkUrl!.isNotEmpty ? null : it.path,
      localNetworkUrl: it.networkUrl,
      // 传入视频宽高，让 BoxFit 根据横竖屏正确选择 contain/cover
      mediaSources: it.width > 0 && it.height > 0
          ? [MediaSource(id: 'local', name: 'local', width: it.width, height: it.height)]
          : null,
    );
  }

  static List<MediaItem> toMediaItems(List<LocalVideoItem> items,
      {Map<String, ScrapedMedia>? scrapedMap}) {
    return items
        .map((it) => toMediaItem(it, scraped: scrapedMap?[it.pathHash]))
        .toList();
  }
}
