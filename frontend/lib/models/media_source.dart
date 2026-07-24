// 媒体源与媒体流：播放信息（音轨/字幕轨）
class MediaSource {
  final String id;
  final String name;
  final String? directPlayUrl;
  final String? transcodingUrl;
  final String? container;
  final int? runTimeTicks;
  final int? width;
  final int? height;
  final int? size;
  final int? bitrate;
  final String? videoCodec;
  final int? videoBitDepth;
  final int? videoLevel;
  final List<MediaStream> mediaStreams;
  final Map<String, String>? httpHeaders;

  const MediaSource({
    required this.id,
    required this.name,
    this.directPlayUrl,
    this.transcodingUrl,
    this.container,
    this.runTimeTicks,
    this.width,
    this.height,
    this.size,
    this.bitrate,
    this.videoCodec,
    this.videoBitDepth,
    this.videoLevel,
    this.mediaStreams = const [],
    this.httpHeaders,
  });

  // 判断是否为横屏视频（宽度大于高度）
  bool get isLandscape {
    final w = width;
    final h = height;
    return w != null && h != null && w > h;
  }

  // 判断是否为竖屏视频（高度大于宽度）
  bool get isPortrait {
    final w = width;
    final h = height;
    return w != null && h != null && h > w;
  }

  factory MediaSource.fromJson(Map<String, dynamic> json) {
    final streamsDynamic = json['MediaStreams'] as List<dynamic>? ??
        json['media_streams'] as List<dynamic>? ??
        [];
    final streams = streamsDynamic
        .map((e) => MediaStream.fromJson(e as Map<String, dynamic>))
        .toList();

    // 从 MediaStreams 中提取视频宽高和编解码信息
    int? videoWidth;
    int? videoHeight;
    String? videoCodec;
    int? videoBitDepth;
    int? videoLevel;
    for (final stream in streams) {
      if (stream.type == 'Video') {
        videoWidth ??= stream.width;
        videoHeight ??= stream.height;
        videoCodec ??= stream.codec;
        videoBitDepth ??= stream.bitDepth;
        videoLevel ??= stream.level;
      }
    }

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
          (json['run_time_ticks'] as int?) ??
          (json['runtimeTicks'] as int?),
      width: videoWidth ?? (json['Width'] as int?) ?? (json['width'] as int?),
      height: videoHeight ?? (json['Height'] as int?) ?? (json['height'] as int?),
      size: (json['Size'] as int?) ?? (json['size'] as int?),
      bitrate: (json['Bitrate'] as int?) ?? (json['bitrate'] as int?),
      videoCodec: videoCodec,
      videoBitDepth: videoBitDepth,
      videoLevel: videoLevel,
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
  final int? bitDepth;           // 色深 (8/10)
  final int? level;              // 编码级别
  final int? width;               // 视频宽度
  final int? height;              // 视频高度

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
    this.bitDepth,
    this.level,
    this.width,
    this.height,
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
      bitDepth: (json['BitDepth'] as int?) ?? (json['bitDepth'] as int?),
      level: (json['Level'] as int?) ?? (json['level'] as int?),
      width: (json['Width'] as int?) ?? (json['width'] as int?),
      height: (json['Height'] as int?) ?? (json['height'] as int?),
    );
  }
}
