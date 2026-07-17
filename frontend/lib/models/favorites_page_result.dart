// 收藏分页结果：包含条目列表和总数（用于判断是否还有更多）
import 'media_item.dart';

class FavoritesPageResult {
  final List<MediaItem> items;
  final int totalCount;

  const FavoritesPageResult({required this.items, required this.totalCount});

  bool get hasMore => items.length < totalCount;
}
