// 观看历史项：记录用户最近播放的媒体条目

class WatchHistoryItem {
  final String itemId;
  final String itemTitle;
  final String? thumbnailUrl;
  final DateTime watchedAt;
  final int progressSeconds;
  final int totalSeconds;

  WatchHistoryItem({
    required this.itemId,
    required this.itemTitle,
    this.thumbnailUrl,
    required this.watchedAt,
    required this.progressSeconds,
    required this.totalSeconds,
  });

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) =>
      WatchHistoryItem(
        itemId: json['item_id'] as String? ?? '',
        itemTitle: json['item_title'] as String? ?? '',
        thumbnailUrl: json['thumbnail_url'] as String?,
        watchedAt: json['watched_at'] == null
            ? DateTime.now()
            : DateTime.parse(json['watched_at'] as String),
        progressSeconds: json['progress_seconds'] as int? ?? 0,
        totalSeconds: json['total_seconds'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'item_title': itemTitle,
        'thumbnail_url': thumbnailUrl,
        'watched_at': watchedAt.toIso8601String(),
        'progress_seconds': progressSeconds,
        'total_seconds': totalSeconds,
      };
}
