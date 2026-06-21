// 媒体项模型：电影/剧集/集数/音乐视频等（支持 Emby 原生字段与简化字段）

import 'media_source.dart';
import 'person.dart';
import 'subtitle_track.dart';
import 'user_data.dart';

class MediaItem {
  // 基本信息
  final String id;
  final String title;
  final String type;                    // Movie/Series/Episode/MusicVideo/...
  final String? seriesName;             // 剧集名（集数项的归属剧集）
  final String? seriesId;              // 剧集 ID（用于 NextUp 查询）
  final int? indexNumber;              // 集序号（集数）
  final int? parentIndexNumber;        // 季序号
  final int? productionYear;            // 制作年份
  final int? runtimeTicks;             // 时长（Emby tick，1 tick = 100ns）
  final double? durationSeconds;        // 时长（秒），可选，若 runtimeTicks 存在则用其计算
  final String? overview;               // 简介
  final double? communityRating;        // 社区评分（1-10）
  final double? rating;                 // 兼容字段，与 communityRating 同义
  final int? year;                      // 兼容字段，与 productionYear 同义
  // 类型/演员/工作室
  final List<String>? genres;
  final List<String>? genreNames;
  final List<String>? studioNames;
  final List<Person>? people;

  // 图片
  final Map<String, String>? imageTags; // Primary/Backdrop/Thumb/Logo/Art...
  final List<String>? backdropImageTags; // 背景图列表
  final String? thumbnailUrl;           // 兼容字段

  // 状态（收藏、播放进度等）
  final UserData? userData;
  final bool? isFavorite;               // 兼容字段，与 userData.isFavorite 同义

  // 播放
  final List<MediaSource>? mediaSources;
  final String? playbackUrl;            // 兼容字段
  final int playbackLevel;              // 当前播放降级等级：0=DirectPlay,1=DirectStream,2=HLS（瞬时字段，不参与序列化）

  // 原始 JSON（用于访问未映射字段，如 PlaylistItemId）
  final Map<String, dynamic>? rawJson;

  const MediaItem({
    required this.id,
    required this.title,
    required this.type,
    this.seriesName,
    this.seriesId,
    this.indexNumber,
    this.parentIndexNumber,
    this.productionYear,
    this.runtimeTicks,
    this.durationSeconds,
    this.overview,
    this.communityRating,
    this.rating,
    this.year,
    this.genres,
    this.genreNames,
    this.studioNames,
    this.people,
    this.imageTags,
    this.backdropImageTags,
    this.thumbnailUrl,
    this.userData,
    this.isFavorite,
    this.mediaSources,
    this.playbackUrl,
    this.playbackLevel = 0,
    this.rawJson,
  });

  // 从 JSON 解析（同时支持 Emby 原生 PascalCase 与简化 snake_case）
  factory MediaItem.fromJson(Map<String, dynamic> json) {
    // 字段兼容解析
    final id = (json['Id'] as String?) ?? (json['id'] as String?) ?? '';
    final title = (json['Name'] as String?) ??
        (json['title'] as String?) ??
        '';
    final type = (json['Type'] as String?) ??
        (json['type'] as String?) ??
        'Movie';
    final seriesName = (json['SeriesName'] as String?) ??
        (json['series_name'] as String?) ??
        (json['seriesName'] as String?);
    final seriesId = (json['SeriesId'] as String?) ??
        (json['series_id'] as String?) ??
        (json['seriesId'] as String?);
    final indexNumber = (json['IndexNumber'] as int?) ??
        (json['index_number'] as int?) ??
        (json['indexNumber'] as int?);
    final parentIndexNumber = (json['ParentIndexNumber'] as int?) ??
        (json['parent_index_number'] as int?) ??
        (json['parentIndexNumber'] as int?);

    // 年份
    final productionYear = (json['ProductionYear'] as int?) ??
        (json['production_year'] as int?) ??
        (json['year'] as int?) ??
        (json['year'] as int?);

    // 评分
    final communityRating = (json['CommunityRating'] as num?)?.toDouble() ??
        (json['community_rating'] as num?)?.toDouble() ??
        (json['communityRating'] as num?)?.toDouble() ??
        (json['rating'] as num?)?.toDouble();

    // 时长
    final runtimeTicks = json['RunTimeTicks'] as int? ??
        json['run_time_ticks'] as int? ??
        json['runtimeTicks'] as int?;
    final runtimeSec = runtimeTicks != null
        ? runtimeTicks / 10000000.0
        : (json['duration_seconds'] as num?)?.toDouble() ??
            (json['durationSeconds'] as num?)?.toDouble();

    // 简介
    final overview = (json['Overview'] as String?) ??
        (json['overview'] as String?);

    // 类型
    List<String>? genres;
    List<String>? genreNames;
    final genresDynamic = json['Genres'] as List<dynamic>? ??
        json['genres'] as List<dynamic>?;
    if (genresDynamic != null) {
      genreNames = genresDynamic.map((e) => e.toString()).toList();
      genres = genreNames;
    }

    // 工作室
    List<String>? studioNames;
    final studiosDynamic = json['Studios'] as List<dynamic>?;
    if (studiosDynamic != null) {
      studioNames = studiosDynamic.map((e) {
        if (e is Map) return (e['Name'] as String?) ?? e.toString();
        return e.toString();
      }).toList();
    }

    // 人员
    List<Person>? people;
    final peopleDynamic = json['People'] as List<dynamic>?;
    if (peopleDynamic != null && peopleDynamic.isNotEmpty) {
      people = peopleDynamic
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // 图片 tags
    Map<String, String>? imageTags;
    final imageTagsDynamic = json['ImageTags'] as Map<String, dynamic>? ??
        json['image_tags'] as Map<String, dynamic>?;
    if (imageTagsDynamic != null && imageTagsDynamic.isNotEmpty) {
      imageTags = <String, String>{};
      imageTagsDynamic.forEach((key, value) {
        imageTags![key] = value.toString();
      });
    }

    // 背景图 tag 列表
    List<String>? backdropImageTags;
    final backdropDynamic = json['BackdropImageTags'] as List<dynamic>?;
    if (backdropDynamic != null && backdropDynamic.isNotEmpty) {
      backdropImageTags =
          backdropDynamic.map((e) => e.toString()).toList();
    }

    // 缩略图 URL（直接构造，简化字段）
    final thumbnailUrl = json['thumbnail_url'] as String? ??
        json['thumbnailUrl'] as String?;

    // 播放源
    List<MediaSource>? mediaSources;
    final mediaSourcesDynamic = json['MediaSources'] as List<dynamic>? ??
        json['media_sources'] as List<dynamic>?;
    if (mediaSourcesDynamic != null && mediaSourcesDynamic.isNotEmpty) {
      mediaSources = mediaSourcesDynamic
          .map((e) => MediaSource.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // 用户数据
    final userDataDynamic = json['UserData'] as Map<String, dynamic>? ??
        json['user_data'] as Map<String, dynamic>?;
    final userData = userDataDynamic != null
        ? UserData.fromJson(userDataDynamic)
        : null;

    // 兼容字段：收藏、播放 URL
    final isFavorite = userData?.isFavorite ??
        (json['is_favorite'] as bool?) ??
        (json['isFavorite'] as bool?) ??
        false;
    final playbackUrl = json['playback_url'] as String? ??
        json['playbackUrl'] as String?;

    return MediaItem(
      id: id,
      title: title,
      type: type,
      seriesName: seriesName,
      seriesId: seriesId,
      indexNumber: indexNumber,
      parentIndexNumber: parentIndexNumber,
      productionYear: productionYear,
      year: productionYear,
      runtimeTicks: runtimeTicks,
      durationSeconds: runtimeSec,
      overview: overview,
      communityRating: communityRating,
      rating: communityRating,
      genres: genres,
      genreNames: genreNames,
      studioNames: studioNames,
      people: people,
      imageTags: imageTags,
      backdropImageTags: backdropImageTags,
      thumbnailUrl: thumbnailUrl,
      userData: userData,
      isFavorite: isFavorite,
      mediaSources: mediaSources,
      playbackUrl: playbackUrl,
      rawJson: json,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'series_name': seriesName,
        'series_id': seriesId,
        'index_number': indexNumber,
        'parent_index_number': parentIndexNumber,
        'production_year': productionYear,
        'runtime_ticks': runtimeTicks,
        'duration_seconds': durationSeconds,
        'overview': overview,
        'community_rating': communityRating,
        'rating': communityRating,
        'year': productionYear,
        'genre_names': genreNames,
        'studio_names': studioNames,
        'people': people?.map((p) => p.toJson()).toList(),
        'image_tags': imageTags,
        'backdrop_image_tags': backdropImageTags,
        'thumbnail_url': thumbnailUrl,
        'user_data': userData?.toJson(),
        'is_favorite': isFavorite,
      };

  // ============================
  // 便捷属性
  // ============================

  // 统一的时长读取（秒）：优先 runtimeTicks，其次 durationSeconds
  double get durationSec {
    if (runtimeTicks != null) return runtimeTicks! / 10000000.0;
    return durationSeconds ?? 0.0;
  }

  // 格式化的时长显示（如 "1h 30m" 或 "45 分钟"）
  String get formattedDuration {
    final sec = durationSec;
    if (sec <= 0) return '';
    final totalMinutes = sec ~/ 60;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    return '${minutes} 分钟';
  }

  // 最终展示用的年份（productionYear / year 都兼容）
  int? get displayYear => productionYear ?? year;

  // 合并的类型名称列表（取第一个非空）
  List<String> get displayGenres =>
      genreNames ?? genres ?? const <String>[];

  // 有效评分：取 communityRating / rating 第一个有效值
  double? get displayRating => communityRating ?? rating;

  bool get hasImage =>
      imageTags != null && imageTags!.isNotEmpty;

  bool get hasBackdrop =>
      backdropImageTags != null && backdropImageTags!.isNotEmpty;

  bool get hasProgress =>
      userData != null && userData!.playbackPositionTicks > 0;

  // 播放进度百分比（0.0 ~ 1.0），统一进度计算逻辑
  double get progressPercent {
    if (userData == null || userData!.playbackPositionTicks <= 0) return 0.0;
    final durSec = durationSec;
    if (durSec <= 0) return 0.0;
    return (userData!.playbackPositionTicks / 10000000.0 / durSec).clamp(0.0, 1.0);
  }

  bool get isWatched => userData?.played ?? false;

  // 判断是否为横屏视频（根据媒体源的宽高）
  bool get isLandscape {
    if (mediaSources == null || mediaSources!.isEmpty) return true; // 默认显示为横屏
    for (final source in mediaSources!) {
      if (source.isLandscape) return true;
      if (source.isPortrait) return false;
    }
    return true; // 默认显示为横屏
  }

  // 判断是否为竖屏视频（根据媒体源的宽高）
  bool get isPortrait {
    if (mediaSources == null || mediaSources!.isEmpty) return false;
    for (final source in mediaSources!) {
      if (source.isPortrait) return true;
      if (source.isLandscape) return false;
    }
    return false;
  }

  // 获取所有字幕轨道（从 mediaSources 的 subtitleStreams 提取）
  List<SubtitleTrack> get subtitleTracks {
    if (mediaSources == null || mediaSources!.isEmpty) {
      return const <SubtitleTrack>[];
    }
    final tracks = <SubtitleTrack>[];
    for (final source in mediaSources!) {
      for (final stream in source.subtitleStreams) {
        tracks.add(SubtitleTrack(
          id: stream.index.toString(),
          name: stream.displayTitle ?? '',
          language: stream.language ?? '',
          format: stream.codec ?? '',
          isDefault: stream.isDefault,
          isForced: stream.isForced,
        ));
      }
    }
    return tracks;
  }

  // 字幕 cues（从 subtitleCues 字段，或从 mediaSources 的 subtitleCues ）
  List<SubtitleCue>? get subtitleCues {
    // 优先从 rawJson 读取（如果已缓存的话）
    final cuesJson = rawJson?['subtitleCues'] as List<dynamic>?;
    if (cuesJson != null && cuesJson.isNotEmpty) {
      return cuesJson
          .map((c) => SubtitleCue(
                Duration(milliseconds: c['start_ms'] as int? ?? 0),
                Duration(milliseconds: c['end_ms'] as int? ?? 0),
                c['text'] as String? ?? '',
              ))
          .toList();
    }
    return null;
  }

  // 生成图片 URL（需要 Emby 服务器 URL 与 api_key/token）
  // type: Primary/Backdrop/Thumb/Art/Logo/Box/BoxRear
  String? imageUrl(
    String type, {
    String? embyServerUrl,
    String? apiKey,
    int maxWidth = 800,
  }) {
    final url = embyServerUrl;
    if (url == null || url.isEmpty) return thumbnailUrl;
    if (imageTags == null || !imageTags!.containsKey(type)) return null;
    final tag = imageTags![type]!;
    final key = apiKey ?? '';
    final tagParam = Uri.encodeQueryComponent(tag);
    return '$url/Items/$id/Images/$type?MaxWidth=$maxWidth&Tag=$tagParam&Format=jpg${key.isNotEmpty ? '&api_key=$key' : ''}';
  }

  // 获取主要海报/封面 URL（Primary 类型）
  String? primaryUrl({String? embyServerUrl, String? apiKey, int maxWidth = 500}) {
    return imageUrl('Primary', embyServerUrl: embyServerUrl, apiKey: apiKey, maxWidth: maxWidth);
  }

  // 获取背景图 URL
  String? backdropUrl({String? embyServerUrl, String? apiKey, int maxWidth = 1280}) {
    return imageUrl('Backdrop', embyServerUrl: embyServerUrl, apiKey: apiKey, maxWidth: maxWidth);
  }

  // 动态构造 Emby 视频流播放 URL
  // Emby API 不返回 playbackUrl，需要根据服务器地址和 token 动态构造
  String? computePlaybackUrl(String? embyServerUrl, String? token) {
    if (embyServerUrl == null || embyServerUrl.isEmpty) return null;
    if (token == null || token.isEmpty) return null;
    final encodedToken = Uri.encodeQueryComponent(token);
    return '$embyServerUrl/Videos/$id/stream?api_key=$encodedToken&Static=true';
  }

  // 构造 Direct Stream URL（Remux 不重编码）
  // 用于 Direct Play 失败后的第一级降级
  String? computeDirectStreamUrl(String? embyServerUrl, String? token) {
    if (embyServerUrl == null || embyServerUrl.isEmpty) return null;
    if (token == null || token.isEmpty) return null;
    final encodedToken = Uri.encodeQueryComponent(token);
    final mediaSourceId = mediaSources?.isNotEmpty == true ? mediaSources!.first.id : null;
    final msIdParam = mediaSourceId != null ? '&MediaSourceId=$mediaSourceId' : '';
    return '$embyServerUrl/Videos/$id/stream.mp4?api_key=$encodedToken'
        '&VideoCodec=h264,hevc,av1&AudioCodec=aac,mp3,ac3'
        '&AllowVideoStreamCopy=true&AllowAudioStreamCopy=true$msIdParam';
  }

  // 构造 HLS 转码 URL（最后一级降级）
  String? computeHlsUrl(String? embyServerUrl, String? token, {String? playSessionId}) {
    if (embyServerUrl == null || embyServerUrl.isEmpty) return null;
    if (token == null || token.isEmpty) return null;
    final encodedToken = Uri.encodeQueryComponent(token);
    final mediaSourceId = mediaSources?.isNotEmpty == true ? mediaSources!.first.id : null;
    final msIdParam = mediaSourceId != null ? '&MediaSourceId=$mediaSourceId' : '';
    final sessionParam = playSessionId != null ? '&PlaySessionId=$playSessionId' : '';
    return '$embyServerUrl/Videos/$id/master.m3u8?api_key=$encodedToken'
        '&VideoCodec=h264&AudioCodec=aac,mp3,ac3'
        '&VideoBitrate=20000000&AudioBitrate=320000'
        '&TranscodingMaxAudioChannels=2'
        '&SegmentContainer=ts&MinSegments=1&BreakOnNonKeyFrames=True'
        '&AllowVideoStreamCopy=true&AllowAudioStreamCopy=true'
        '$msIdParam$sessionParam';
  }

  // 获取认证 HTTP 请求头（用于 video_player 插件）
  Map<String, String> authHeaders(String? token) {
    if (token == null || token.isEmpty) return {};
    return {'X-Emby-Token': token};
  }

  // 获取缩略图 URL（带认证信息）
  // 优先使用 Emby 图片 URL，fallback 到 thumbnailUrl
  String? thumbnailUrlWithAuth(String? embyServerUrl, String? apiKey, {int maxWidth = 400}) {
    // 如果有 Emby 服务器地址和图片标签，构造 Emby 图片 URL
    if (embyServerUrl != null && embyServerUrl.isNotEmpty) {
      final embUrl = primaryUrl(embyServerUrl: embyServerUrl, apiKey: apiKey, maxWidth: maxWidth);
      if (embUrl != null) return embUrl;
    }
    // Fallback 到直接 URL
    return thumbnailUrl;
  }

  // 带 Emby URL 的副本（便捷构造）
  MediaItem withEmbyUrls(String embyServerUrl, String apiKey) => this;

  // 复制并修改部分字段
  MediaItem copyWith({
    String? id,
    String? title,
    String? type,
    String? seriesName,
    String? seriesId,
    int? indexNumber,
    int? parentIndexNumber,
    int? productionYear,
    int? runtimeTicks,
    double? durationSeconds,
    String? overview,
    double? communityRating,
    List<String>? genres,
    List<String>? genreNames,
    List<String>? studioNames,
    List<Person>? people,
    Map<String, String>? imageTags,
    List<String>? backdropImageTags,
    String? thumbnailUrl,
    UserData? userData,
    bool? isFavorite,
    List<MediaSource>? mediaSources,
    String? playbackUrl,
    int? playbackLevel,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      seriesName: seriesName ?? this.seriesName,
      seriesId: seriesId ?? this.seriesId,
      indexNumber: indexNumber ?? this.indexNumber,
      parentIndexNumber: parentIndexNumber ?? this.parentIndexNumber,
      productionYear: productionYear ?? this.productionYear,
      year: productionYear ?? this.year,
      runtimeTicks: runtimeTicks ?? this.runtimeTicks,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      overview: overview ?? this.overview,
      communityRating: communityRating ?? this.communityRating,
      rating: communityRating ?? this.communityRating ?? this.rating,
      genres: genres ?? this.genres,
      genreNames: genreNames ?? this.genreNames,
      studioNames: studioNames ?? this.studioNames,
      people: people ?? this.people,
      imageTags: imageTags ?? this.imageTags,
      backdropImageTags: backdropImageTags ?? this.backdropImageTags,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      userData: userData ?? this.userData,
      isFavorite: isFavorite ?? this.isFavorite,
      mediaSources: mediaSources ?? this.mediaSources,
      playbackUrl: playbackUrl ?? this.playbackUrl,
      playbackLevel: playbackLevel ?? this.playbackLevel,
    );
  }
}
