// 媒体源与媒体流：播放信息（音轨/字幕轨）
class MediaSource {
  final String id;
  final String name;
  final String? directPlayUrl;       // 直接播放 URL
  final String? transcodingUrl;       // 转码播放 URL
  final String? container;             // 容器类型：mp4/mkv 等
  final int? runTimeTicks;             // 总时长
  final List<MediaStream> mediaStreams;
  final Map<String, String>? httpHeaders;  // 播放需要的请求头（如 X-Emby-Token）

  const MediaSource({
    required this.id,
    required this.name,
    this.directPlayUrl,
    this.transcodingUrl,
    this.container,
    this.runTimeTicks,
    this.mediaStreams = const [],
    this.httpHeaders,
  });

  factory MediaSource.fromJson(Map<String, dynamic> json) {
    final streamsDynamic = json['MediaStreams'] as List<dynamic>? ??
        json['media_streams'] as List<dynamic>? ??
        [];
    final streams = streamsDynamic
        .map((e) => MediaStream.fromJson(e as Map<String, dynamic>))
        .toList();

    return MediaSource(
      id: (json['Id'] as String?) ?? (json['id'] as String?) ?? '',
      name: (json['Name'] as String?) ?? (json['name'] as String?) ?? '',
      directPlayUrl: (json['DirectPlayUrl'] as String?) ??
          (json['direct_play_url'] as String?) ??
          (json['directPlayUrl'] as String?),
      transcodingUrl: (json['TranscodingUrl'] as String?) ??
          (json['transcoding_url'] as String?),
      container: (json['Container'] as String?) ?? (json['container'] as String?),
      runTimeTicks: (json['RunTimeTicks'] as int?) ??
          (json['run_time_ticks'] as int?),
      mediaStreams: streams,
      httpHeaders: null,
    );
  }

  List<MediaStream> get audioStreams =>
      mediaStreams.where((s) => s.type == 'Audio').toList();
  List<MediaStream> get subtitleStreams =>
      mediaStreams.where((s) => s.type == 'Subtitle').toList();
  MediaStream? get defaultAudioStream {
    try {
      return audioStreams.firstWhere((s) => s.isDefault);
    } catch (_) {
      return audioStreams.firstOrNull;
    }
  }
}

class MediaStream {
  final int index;
  final String type;              // 'Video' / 'Audio' / 'Subtitle'
  final String? language;         // 语言代码（如 eng / chi）
  final String? displayTitle;     // 显示名
  final bool isDefault;
  final bool isForced;
  final bool isExternal;          // 是否外挂字幕
  final String? deliveryUrl;      // 字幕轨的外部 URL
  final String? codec;            // 编码

  const MediaStream({
    required this.index,
    required this.type,
    this.language,
    this.displayTitle,
    this.isDefault = false,
    this.isForced = false,
    this.isExternal = false,
    this.deliveryUrl,
    this.codec,
  });

  factory MediaStream.fromJson(Map<String, dynamic> json) {
    return MediaStream(
      index: (json['Index'] as int?) ?? (json['index'] as int?) ?? 0,
      type: (json['Type'] as String?) ?? (json['type'] as String?) ?? 'Video',
      language: (json['Language'] as String?) ?? (json['language'] as String?),
      displayTitle: (json['DisplayTitle'] as String?) ??
          (json['display_title'] as String?) ??
          (json['displayTitle'] as String?),
      isDefault: (json['IsDefault'] as bool?) ??
          (json['is_default'] as bool?) ??
          false,
      isForced: (json['IsForced'] as bool?) ??
          (json['is_forced'] as bool?) ??
          false,
      isExternal: (json['IsExternal'] as bool?) ??
          (json['is_external'] as bool?) ??
          false,
      deliveryUrl: (json['DeliveryUrl'] as String?) ??
          (json['delivery_url'] as String?),
      codec: (json['Codec'] as String?) ?? (json['codec'] as String?),
    );
  }
}
