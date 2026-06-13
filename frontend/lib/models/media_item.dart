// 媒体项模型：对应 Emby BaseItemDto，用于电影、剧集、音乐视频等
//
// 本文件同时兼容旧的 "后端已计算好" 响应（如 thumbnail_url / playback_url 字段）
// 与 Emby 原生 API 的 BaseItemDto 响应（PascalCase 键）。

import 'media_source.dart';
import 'person.dart';
import 'user_data.dart';

class MediaItem {
  // ============ 基础字段 ============
  final String id;
  final String title;
  final String type; // Movie / Series / Episode / MusicVideo / Trailer / ...
  final String? overview;
  final int? year; // 与 productionYear 同义，保留以兼容旧代码
  final double? rating; // 与 communityRating 同义，保留以兼容旧代码
  final List<String>? genres; // 与 genreNames 同义，保留以兼容旧代码

  // ============ 向后兼容字段 ============
  // 这些字段可能由旧代码或后端直接计算好，保留以避免破坏调用方。
  final double? durationSeconds; // 以秒为单位的时长；若 runtimeTicks 存在则由其推导
  final String? thumbnailUrl; // 缩略图 URL（优先使用 imageTags + imageUrl() 动态构造）
  final String? playbackUrl; // 视频流 URL（优先使用 withEmbyUrls 动态构造）
  final Map<String, String>? playbackHttpHeaders; // 视频流认证头
  final bool? isFavorite; // 与 userData?.isFavorite 同义，保留以兼容旧代码

  // ============ Emby BaseItemDto 原生字段 ============
  // 演员 / 导演 / 编剧 / 制作人等人员列表
  final List<Person>? people;

  // 类型名称列表（如 ["科幻", "冒险"]）
  final List<String>? genreNames;

  // 制作公司名称列表（如 ["HBO", "Warner Bros."]）
  final List<String>? studioNames;

  // 图片标签映射：key 为 Primary/Backdrop/Logo/Thumb/Art/Banner/Menu/Box/BoxRear，value 为 image tag
  // 示例：{'Primary': 'abc123', 'Backdrop': 'def456'}
  final Map<String, String>? imageTags;

  // 社区评分（IMDB/TMDB 等综合评分，范围 0-10）
  final double? communityRating;

  // 影评人评分（Rotten Tomatoes/Metacritic 等，范围 0-100）
  final double? criticRating;

  // 官方分级（如 "PG-13", "NR", "R", "TV-MA"）
  final String? officialRating;

  // Emby 时长 ticks（每 tick = 100 纳秒）。使用 durationSecondsFromTicks 转为秒
  final int? runtimeTicks;

  // 制作年份（如 2023）
  final int? productionYear;

  // 首映日期（ISO8601 字符串）
  final String? premiereDate;

  // 创建/加入库的日期（ISO8601 字符串）
  final String? dateCreated;

  // 剧集名（当 item 是一集时，如 "Game of Thrones"）
  final String? seriesName;

  // 季名（如 "Season 2"）
  final String? seasonName;

  // 集号（Ep05 = 5）
  final int? indexNumber;

  // 季号（S02 = 2）
  final int? parentIndexNumber;

  // 所属剧集 ID
  final String? seriesId;

  // 所属季 ID
  final String? seasonId;

  // 媒体源列表（可能包含多个分辨率/格式的源）
  final List<MediaSource>? mediaSources;

  // 用户数据（播放进度、收藏、观看次数等）
  final UserData? userData;

  // 多张背景图 tag 列表（用于轮播）
  final List<String>? backdropImageTags;

  // logo 图片 tag（从 imageTags['Logo'] 便捷取值）
  final String? logoImageTag;

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
    this.people,
    this.genreNames,
    this.studioNames,
    this.imageTags,
    this.communityRating,
    this.criticRating,
    this.officialRating,
    this.runtimeTicks,
    this.productionYear,
    this.premiereDate,
    this.dateCreated,
    this.seriesName,
    this.seasonName,
    this.indexNumber,
    this.parentIndexNumber,
    this.seriesId,
    this.seasonId,
    this.mediaSources,
    this.userData,
    this.backdropImageTags,
    this.logoImageTag,
  });

  // ============ fromJson ============
  // 从 Emby 原生响应格式或旧的简化格式解析
  factory MediaItem.fromJson(Map<String, dynamic> json) {
    // 辅助：ticks -> 秒（Emby 使用 100ns 为单位的 tick）
    double? ticksToSeconds(dynamic ticks) {
      if (ticks == null) return null;
      if (ticks is int) return ticks / 10000000.0;
      if (ticks is num) return ticks / 10000000.0;
      return null;
    }

    // 向后兼容字段（优先后端计算好的 URL）
    final thumbnailUrl = json['thumbnail_url'] as String? ??
        json['thumb_url'] as String?;
    final playbackUrl = json['playback_url'] as String?;

    // runtimeTicks（Emby 原生字段）与 durationSeconds 都保留
    final runtimeTicks = json['RunTimeTicks'] as int?;
    final runtime = ticksToSeconds(runtimeTicks) ??
        (json['duration_seconds'] as num?)?.toDouble();

    // 年份：productionYear 与 year 同时填充
    final productionYear = json['ProductionYear'] as int? ??
        json['year'] as int?;

    // 社区评分
    final communityRating = (json['CommunityRating'] as num?)?.toDouble() ??
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

    // 类型列表（同时填充 genres 与 genreNames）
    List<String>? genres;
    final genresDynamic = json['Genres'] as List<dynamic>? ??
        json['genres'] as List<dynamic>?;
    if (genresDynamic != null) {
      genres = genresDynamic.map((e) => e.toString()).toList();
    }

    // 制作公司列表
    List<String>? studioNames;
    final studiosDynamic = json['Studios'] as List<dynamic>?;
    if (studiosDynamic != null) {
      // Studios 是对象列表（含 Name 字段）或字符串列表
      studioNames = studiosDynamic.map((e) {
        if (e is Map<String, dynamic>) {
          return (e['Name'] as String?) ?? '';
        }
        return e.toString();
      }).toList();
    }

    // 人员列表（演员/导演等）
    List<Person>? people;
    final peopleDynamic = json['People'] as List<dynamic>?;
    if (peopleDynamic != null) {
      people = peopleDynamic
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // imageTags 映射（Primary/Backdrop/Logo/Thumb/Art/Banner/Menu/Box/BoxRear）
    Map<String, String>? imageTags;
    final imageTagsDynamic = json['ImageTags'] as Map<String, dynamic>?;
    if (imageTagsDynamic != null) {
      imageTags = <String, String>{};
      imageTagsDynamic.forEach((key, value) {
        imageTags![key] = value.toString();
      });
    }

    // backdropImageTags
    List<String>? backdropImageTags;
    final backdropDynamic = json['BackdropImageTags'] as List<dynamic>?;
    if (backdropDynamic != null) {
      backdropImageTags = backdropDynamic.map((e) => e.toString()).toList();
    }

    // logoImageTag（从 imageTags 便捷取值）
    final logoImageTag = imageTags?['Logo'];

    // mediaSources
    List<MediaSource>? mediaSources;
    final mediaSourcesDynamic = json['MediaSources'] as List<dynamic>?;
    if (mediaSourcesDynamic != null) {
      mediaSources = mediaSourcesDynamic
          .map((e) => MediaSource.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // userData
    final userDataDynamic = json['UserData'] as Map<String, dynamic>?;
    final userData = userDataDynamic != null
        ? UserData.fromJson(userDataDynamic)
        : null;
    final isFavorite = userData?.isFavorite ??
        json['is_favorite'] as bool?;

    return MediaItem(
      id: (json['Id'] as String?) ?? json['id'] as String? ?? '',
      title: title,
      type: type,
      durationSeconds: runtime,
      thumbnailUrl: thumbnailUrl,
      overview: overview,
      year: productionYear,
      rating: communityRating,
      genres: genres,
      playbackUrl: playbackUrl,
      playbackHttpHeaders: null,
      isFavorite: isFavorite,
      // Emby 原生字段
      people: people,
      genreNames: genres,
      studioNames: studioNames,
      imageTags: imageTags,
      communityRating: communityRating,
      criticRating: (json['CriticRating'] as num?)?.toDouble(),
      officialRating: json['OfficialRating'] as String?,
      runtimeTicks: runtimeTicks,
      productionYear: productionYear,
      premiereDate: json['PremiereDate'] as String?,
      dateCreated: json['DateCreated'] as String?,
      seriesName: json['SeriesName'] as String?,
      seasonName: json['SeasonName'] as String?,
      indexNumber: json['IndexNumber'] as int?,
      parentIndexNumber: json['ParentIndexNumber'] as int?,
      seriesId: json['SeriesId'] as String?,
      seasonId: json['SeasonId'] as String?,
      mediaSources: mediaSources,
      userData: userData,
      backdropImageTags: backdropImageTags,
      logoImageTag: logoImageTag,
    );
  }

  // ============ toJson ============
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
        'runtime_ticks': runtimeTicks,
        'production_year': productionYear,
        'premiere_date': premiereDate,
        'date_created': dateCreated,
        'series_name': seriesName,
        'season_name': seasonName,
        'index_number': indexNumber,
        'parent_index_number': parentIndexNumber,
        'series_id': seriesId,
        'season_id': seasonId,
        'community_rating': communityRating,
        'critic_rating': criticRating,
        'official_rating': officialRating,
        'genre_names': genreNames,
        'studio_names': studioNames,
      };

  // ============ 计算字段与辅助方法 ============

  // runtimeTicks 转为秒（Emby tick = 100ns）
  double? get durationSecondsFromTicks =>
      runtimeTicks != null ? runtimeTicks! / 10000000.0 : null;

  // 判断某类型图片是否存在（Primary/Backdrop/Logo/Thumb/Art/Banner 等）
  bool hasImage(String type) {
    if (imageTags == null) return false;
    return imageTags!.containsKey(type);
  }

  // 根据 imageTags 构造指定类型的 Emby 图片 URL
  //
  // 示例：imageUrl('Backdrop', maxWidth: 1920)
  //    -> {server}/Items/{id}/Images/Backdrop?MaxWidth=1920&...&api_key={token}
  //
  // 注意：此方法需要调用方先调用 withEmbyUrls() 来记录 server 和 apiKey。
  // 为保持最小改动，这里在方法内部使用外部注入方式——
  // 推荐通过 withEmbyUrls 后使用 thumbnailUrl；或自行使用 MediaItem.imageUrlFor 的静态方法。
  //
  // 为支持此方法签名，本方法接受可选参数 embyServerUrl/apiKey。
  // 若未提供，则回退到从现有 thumbnailUrl 推导（如果可能），否则返回 null。
  String? imageUrl(
    String type, {
    int maxWidth = 800,
    String? embyServerUrl,
    String? apiKey,
  }) {
    if (!hasImage(type)) return null;

    if (embyServerUrl != null && apiKey != null) {
      final base = embyServerUrl.endsWith('/')
          ? embyServerUrl.substring(0, embyServerUrl.length - 1)
          : embyServerUrl;
      final tag = imageTags![type];
      final tagQuery = tag != null && tag.isNotEmpty ? '&Tag=$tag' : '';
      return '$base/Items/$id/Images/$type?MaxWidth=$maxWidth&Format=jpg&Quality=80$tagQuery&api_key=$apiKey';
    }

    // 尝试从现有 thumbnailUrl 推导（替换 Primary 为目标 type）
    final thumb = thumbnailUrl;
    if (thumb != null) {
      return thumb.replaceFirst('/Images/Primary', '/Images/$type');
    }
    return null;
  }

  // ============ withEmbyUrls ============
  //
  // 返回一条新 MediaItem，使用 Emby 标准 URL 格式。
  //
  // 缩略图 URL: {server}/Items/{id}/Images/Primary?MaxWidth=800&Format=jpg&api_key={token}
  // 视频流 URL: {server}/Videos/{id}/stream?static=true&api_key={token}
  // httpHeaders:  { X-Emby-Token: <token>, X-Emby-Authorization: ... }
  MediaItem withEmbyUrls(String embyServerUrl, String apiKey) {
    final base = embyServerUrl.endsWith('/')
        ? embyServerUrl.substring(0, embyServerUrl.length - 1)
        : embyServerUrl;
    final safeKey = apiKey;

    // Emby 标准图片 URL：带 MaxWidth 和 Format 参数以获得合适大小的图片
    final thumb =
        '$base/Items/$id/Images/Primary?MaxWidth=800&Format=jpg&Quality=80&api_key=$safeKey';

    // Emby 标准视频流 URL
    final play = '$base/Videos/$id/stream?static=true&api_key=$safeKey';

    // 构造 video_player 需要的认证头
    final headers = <String, String>{
      'X-Emby-Token': safeKey,
      'X-Emby-Client': 'EmbyTok',
      'X-Emby-Device-Name': 'Mobile',
      'X-Emby-Client-Version': '1.0.0',
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
      // 保留原生字段
      people: people,
      genreNames: genreNames,
      studioNames: studioNames,
      imageTags: imageTags,
      communityRating: communityRating,
      criticRating: criticRating,
      officialRating: officialRating,
      runtimeTicks: runtimeTicks,
      productionYear: productionYear,
      premiereDate: premiereDate,
      dateCreated: dateCreated,
      seriesName: seriesName,
      seasonName: seasonName,
      indexNumber: indexNumber,
      parentIndexNumber: parentIndexNumber,
      seriesId: seriesId,
      seasonId: seasonId,
      mediaSources: mediaSources,
      userData: userData,
      backdropImageTags: backdropImageTags,
      logoImageTag: logoImageTag,
    );
  }
}
