import 'media_item.dart';

/// Emby 原生电影推荐分组（/Movies/Recommendations）
///
/// Emby 按观看历史把推荐电影分组成若干"理由"，例如：
/// - 因为你看过《盗梦空间》（SimilarToRecentlyPlayed）
/// - 与你喜欢的电影相似（SimilarToLikedItem）
/// - 你喜欢的演员参演（HasActorFromRecentlyPlayed）
///
/// [baselineName] 为基准影片名，UI 展示为分组标题；
/// [items] 为该分组下的推荐影片。
class NativeRecGroup {
  const NativeRecGroup({
    required this.baselineName,
    required this.items,
  });

  factory NativeRecGroup.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['Items'] as List<dynamic>?) ?? const [];
    return NativeRecGroup(
      baselineName: (json['BaselineItemName'] as String? ?? '').trim(),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(MediaItem.fromJson)
          .toList(growable: false),
    );
  }

  /// 分组标题（"因为你看过 {BaselineItemName}"）
  final String baselineName;

  /// 该分组下的推荐影片
  final List<MediaItem> items;

  bool get isEmpty => items.isEmpty;
}
