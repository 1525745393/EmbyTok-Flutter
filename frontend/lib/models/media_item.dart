// 媒体项模型：对应 Emby BaseItemDto，用于电影、剧集、音乐视频等

class MediaItem {
  final String id;
  final String title;
  final String type;
  final double? durationSeconds;
  final String? thumbnailUrl;
  final String? overview;
  final int? year;
  final double? rating;
  final List<String>? genres;
  final String? playbackUrl;
  final bool? isFavorite;

  MediaItem({
    required this.id,
    required this.title,
    required this.type,
    this.durationSeconds,
    this.thumbnailUrl,
    this.overview,
    this.year,
    this.rating,
    this.genres,
    this.playbackUrl,
    this.isFavorite,
  });

  // 从 Emby 原生响应格式解析：
  // {
  //   "Id": "...",
  //   "Name": "...",
  //   "Type": "Movie" | "Episode" | "MusicVideo" | ...,
  //   "RuntimeTicks": 12345678901,
  //   "Overview": "...",
  //   "ProductionYear": 2023,
  //   "CommunityRating": 8.5,
  //   "Genres": ["动作", "科幻"],
  //   "ImageTags": {"Primary": "abc123"},
  //   "UserData": {"IsFavorite": true, "PlaybackPositionTicks": 0},
  //   ...
  // }
  // 同时兼容后端 snake_case 格式（向前兼容）
  factory MediaItem.fromJson(Map<String, dynamic> json) {
    // 辅助函数：从 tick 转换为秒（Emby 使用 100ns 为单位的 tick）
    double? ticksToSeconds(dynamic ticks) {
      if (ticks == null) return null;
      if (ticks is int) return ticks / 10000000.0;
      if (ticks is num) return ticks / 10000000.0;
      return null;
    }

    // 从后端计算得来的 URL 优先使用（向后兼容），否则用原始字段
    final thumbnailUrl = json['thumbnail_url'] as String? ??
        json['thumb_url'] as String?;
    final playbackUrl = json['playback_url'] as String?;

    // 计算时长
    final runtime = ticksToSeconds(json['RuntimeTicks']) ??
        (json['duration_seconds'] as num?)?.toDouble();

    // 年份
    final year = (json['ProductionYear'] as int?) ??
        (json['year'] as int?);

    // 评分
    final rating = (json['CommunityRating'] as num?)?.toDouble() ??
        (json['rating'] as num?)?.toDouble();

    // 类型
    final type = (json['Type'] as String?) ?? json['type'] as String? ?? '';

    // 标题/名称
    final title = (json['Name'] as String?) ??
        json['title'] as String? ??
        '';

    // 简介
    final overview = (json['Overview'] as String?) ??
        json['overview'] as String?;

    // 类型列表
    List<String>? genres;
    final genresDynamic = json['Genres'] as List<dynamic>? ??
        json['genres'] as List<dynamic>?;
    if (genresDynamic != null) {
      genres = genresDynamic.map((e) => e.toString()).toList();
    }

    // 收藏状态（来自 UserData）
    final userData = json['UserData'] as Map<String, dynamic>?;
    final isFavorite = userData?['IsFavorite'] as bool? ??
        json['is_favorite'] as bool?;

    return MediaItem(
      id: (json['Id'] as String?) ?? json['id'] as String? ?? '',
      title: title,
      type: type,
      durationSeconds: runtime,
      thumbnailUrl: thumbnailUrl,
      overview: overview,
      year: year,
      rating: rating,
      genres: genres,
      playbackUrl: playbackUrl,
      isFavorite: isFavorite,
    );
  }

  // 序列化（供持久化使用，与旧的 JSON 字段保持一致）
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'duration_seconds': durationSeconds,
        'thumbnail_url': thumbnailUrl,
        'overview': overview,
        'year': year,
        'rating': rating,
        'genres': genres,
        'playback_url': playbackUrl,
      };

  // 返回一条新 MediaItem，使用提供的服务器地址与令牌生成缩略图与播放地址
  MediaItem withEmbyUrls(String embyServerUrl, String apiKey) {
    final base = embyServerUrl.endsWith('/')
        ? embyServerUrl.substring(0, embyServerUrl.length - 1)
        : embyServerUrl;
    final safeKey = apiKey;
    final thumb = '$base/Items/$id/Images/Primary?api_key=$safeKey';
    final play = '$base/Videos/$id/stream?api_key=$safeKey';
    return MediaItem(
      id: id,
      title: title,
      durationSeconds: durationSeconds,
      type: type,
      thumbnailUrl: thumb,
      overview: overview,
      year: year,
      rating: rating,
      genres: genres,
      playbackUrl: play,
      isFavorite: isFavorite,
    );
  }
}
