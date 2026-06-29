// 用户数据模型：播放进度、收藏、已观看、用户评分等状态
class UserData {
  final double playbackPositionTicks;  // 已播放时长（tick 单位）
  final bool isFavorite;                // 是否已收藏
  final bool played;                    // 是否已完整观看
  final int unplayedItemCount;          // 未看集数（用于剧集/季）
  final String? lastPlayedDate;         // 最后播放日期
  final int playCount;                  // 播放次数
  // PR #89：用户对该 item 的评分（0-10，null = 未评分）
  // - 来源：Emby `UserData.Rating`
  // - 区别于 communityRating（社区评分）
  // - 用法：推荐时按用户评分加权（高分优先）
  final double? rating;

  const UserData({
    this.playbackPositionTicks = 0.0,
    this.isFavorite = false,
    this.played = false,
    this.unplayedItemCount = 0,
    this.lastPlayedDate,
    this.playCount = 0,
    this.rating,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    // 同时支持 Emby 原生字段（PascalCase）与简化字段
    final posTicks = json['PlaybackPositionTicks'] as int? ??
        (json['playback_position_ticks'] as num?)?.toInt() ??
        (json['playbackPositionTicks'] as int?) ??
        0;
    // PR #89：解析用户评分（Emby `UserData.Rating`，0-10）
    final rating = (json['Rating'] as num?)?.toDouble() ??
        (json['rating'] as num?)?.toDouble() ??
        (json['user_rating'] as num?)?.toDouble();
    return UserData(
      playbackPositionTicks: posTicks.toDouble(),
      isFavorite: (json['IsFavorite'] as bool?) ??
          (json['is_favorite'] as bool?) ??
          (json['isFavorite'] as bool?) ??
          false,
      played: (json['Played'] as bool?) ??
          (json['played'] as bool?) ??
          false,
      unplayedItemCount: (json['UnplayedItemCount'] as int?) ??
          (json['unplayed_item_count'] as int?) ??
          0,
      lastPlayedDate: (json['LastPlayedDate'] as String?) ??
          (json['last_played_date'] as String?),
      playCount: (json['PlayCount'] as int?) ??
          (json['play_count'] as int?) ??
          (json['playCount'] as int?) ??
          0,
      rating: rating,
    );
  }

  Map<String, dynamic> toJson() => {
        'playback_position_ticks': playbackPositionTicks,
        'is_favorite': isFavorite,
        'played': played,
        'unplayed_item_count': unplayedItemCount,
        'last_played_date': lastPlayedDate,
        'play_count': playCount,
        'rating': rating,
      };
}
