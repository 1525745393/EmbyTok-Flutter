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
  final Map<String, String>? playbackHttpHeaders; // 视频流认证头
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
    this.playbackHttpHeaders,
    this.isFavorite,
  });

  // 从 Emby 原生响应格式解析
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
    final type = (json['Type'] as String?) ??
        json['type'] as String? ??
        'Video';

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

  // 序列化（供持久化使用）
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

  // 返回一条新 MediaItem，使用 Emby 标准 URL 格式
  //
  // 缩略图 URL: {server}/Items/{id}/Images/Primary?MaxWidth=800&Format=jpg&api_key={token}
  // 视频流 URL: {server}/Videos/{id}/stream?static=true&api_key={token}
  // httpHeaders:  { X-Emby-Token: <token>, X-Emby-Authorization: ... } （双重保险）
  MediaItem withEmbyUrls(String embyServerUrl, String apiKey) {
    final base = embyServerUrl.endsWith('/')
        ? embyServerUrl.substring(0, embyServerUrl.length - 1)
        : embyServerUrl;
    final safeKey = apiKey;

    // Emby 标准图片 URL：带 MaxWidth 和 Format 参数以获得合适大小的图片
    // api_key 作为查询参数，兼容不支持请求头的图片加载器（如 Image.network）
    final thumb =
        '$base/Items/$id/Images/Primary?MaxWidth=800&Format=jpg&Quality=80&api_key=$safeKey';

    // Emby 标准视频流 URL：
    // /Videos/{id}/stream 是 Emby 官方推荐的直接流访问路径
    // static=true 告诉服务器这是一个稳定 URL（非转码会话）
    final play = '$base/Videos/$id/stream?static=true&api_key=$safeKey';

    // 构造 video_player 需要的认证头
    final headers = <String, String>{
      // 主要认证方式：X-Emby-Token
      'X-Emby-Token': safeKey,
      // Emby 标准客户端标识头
      'X-Emby-Client': 'EmbyTok',
      'X-Emby-Device-Name': 'Mobile',
      'X-Emby-Client-Version': '1.0.0',
      // Accept 头
      'Accept': '*/*',
    };

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
      playbackHttpHeaders: headers,
      isFavorite: isFavorite,
    );
  }
}
