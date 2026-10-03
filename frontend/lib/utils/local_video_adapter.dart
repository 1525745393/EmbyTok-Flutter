import '../models/local_video_item.dart';
import '../models/media_item.dart';

/// 本地视频 → Emby MediaItem 适配器
/// 让本地视频能直接注入主 feed 的 videoListProvider，
/// 复用 VideoPageItem 的全部叠加（底部信息条、右侧操作栏、进度记忆）。
class LocalVideoAdapter {
  static MediaItem toMediaItem(LocalVideoItem it) {
    return MediaItem(
      // id 加 local_ 前缀，避免与 Emby item id 冲突
      id: 'local_${it.id}',
      title: it.name,
      type: 'Movie',
      productionYear: _extractYear(it),
      durationSeconds: it.duration.inSeconds.toDouble(),
      overview: '',
      imageTags: const {},
      backdropImageTags: const [],
      isLocalFile: true,
      localPath: it.networkUrl != null && it.networkUrl!.isNotEmpty ? null : it.path,
      localNetworkUrl: it.networkUrl,
    );
  }

  static List<MediaItem> toMediaItems(List<LocalVideoItem> items) =>
      items.map(toMediaItem).toList();

  static int? _extractYear(LocalVideoItem it) {
    // 从 modifiedAt 兜底年份
    return it.modifiedAt.year;
  }
}
