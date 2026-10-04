import '../models/local_video_item.dart';
import '../models/media_item.dart';
import '../services/scrape_service.dart';

/// 本地视频 → Emby MediaItem 适配器
/// 让本地视频能直接注入主 feed 的 videoListProvider，
/// 复用 VideoPageItem 的全部叠加（底部信息条、右侧操作栏、进度记忆）。
class LocalVideoAdapter {
  static MediaItem toMediaItem(LocalVideoItem it, {ScrapedMedia? scraped}) {
    final isTv = scraped?.type == 'tv';
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
      imageTags: const {},
      backdropImageTags: const [],
      isLocalFile: true,
      localPath: it.networkUrl != null && it.networkUrl!.isNotEmpty ? null : it.path,
      localNetworkUrl: it.networkUrl,
    );
  }

  static List<MediaItem> toMediaItems(List<LocalVideoItem> items,
      {Map<String, ScrapedMedia>? scrapedMap}) {
    return items
        .map((it) => toMediaItem(it, scraped: scrapedMap?[it.pathHash]))
        .toList();
  }
}
