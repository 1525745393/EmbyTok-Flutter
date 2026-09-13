// 歌手元数据模型
//
// P2-5 / 歌手简介功能 V1.0
// 统一的歌手元数据模型，支持多数据源（Last.fm / Deezer / Wikipedia）
// 和三级缓存（L1 内存 / L2 SharedPreferences / L3 NAS）。

import 'dart:convert';

/// 数据来源枚举
enum ArtistMetadataSource {
  /// Last.fm（主源）
  lastFm,

  /// Deezer（补源）
  deezer,

  /// Wikipedia（兜底）
  wikipedia,

  /// 群晖 Audio Station（本地数据）
  synology,

  /// 用户手动修正
  manual,

  /// 无数据
  none,
}

/// 相似歌手模型
class SimilarArtist {

  const SimilarArtist({
    required this.name,
    this.imageUrl,
  });

  factory SimilarArtist.fromJson(Map<String, dynamic> json) => SimilarArtist(
        name: json['name'] as String,
        imageUrl: json['imageUrl'] as String?,
      );
  /// 歌手名称
  final String name;

  /// 歌手头像URL
  final String? imageUrl;

  Map<String, dynamic> toJson() => {
        'name': name,
        'imageUrl': imageUrl,
      };
}

/// 歌手元数据模型
///
/// 包含歌手头像、简介、风格标签、听众数、相似歌手等富元数据。
/// 所有字段均可空（无数据时为 null），UI 层需处理空状态。
class ArtistMetadata {

  const ArtistMetadata({
    required this.name,
    this.musicBrainzId,
    this.imageUrl,
    this.imageSmallUrl,
    this.bioSummary,
    this.bioContent,
    this.bioLang,
    this.tags = const [],
    this.listeners,
    this.playcount,
    this.similarArtists = const [],
    this.source = ArtistMetadataSource.none,
    required this.cachedAt,
    this.version = 1,
    this.isManualOverride = false,
  });

  /// 从 JSON 反序列化
  factory ArtistMetadata.fromJson(Map<String, dynamic> json) {
    return ArtistMetadata(
      name: json['name'] as String,
      musicBrainzId: json['musicBrainzId'] as String?,
      imageUrl: json['imageUrl'] as String?,
      imageSmallUrl: json['imageSmallUrl'] as String?,
      bioSummary: json['bioSummary'] as String?,
      bioContent: json['bioContent'] as String?,
      bioLang: json['bioLang'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      listeners: json['listeners'] as int?,
      playcount: json['playcount'] as int?,
      similarArtists: (json['similarArtists'] as List<dynamic>?)
              ?.map((e) => SimilarArtist.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      source: ArtistMetadataSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => ArtistMetadataSource.none,
      ),
      cachedAt: DateTime.tryParse(json['cachedAt'] as String? ?? '') ??
          DateTime.now(),
      version: json['version'] as int? ?? 1,
      isManualOverride: json['isManualOverride'] as bool? ?? false,
    );
  }

  /// 从 JSON 字符串反序列化
  factory ArtistMetadata.fromJsonString(String jsonString) =>
      ArtistMetadata.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  /// 创建无数据的空元数据（用于缓存"无简介"标记）
  factory ArtistMetadata.empty(String name) => ArtistMetadata(
        name: name,
        source: ArtistMetadataSource.none,
        cachedAt: DateTime.now(),
      );
  /// 歌手名称（主键）
  final String name;

  /// MusicBrainz ID（跨数据源唯一标识）
  final String? musicBrainzId;

  /// 歌手头像URL（最大尺寸）
  final String? imageUrl;

  /// 歌手头像缩略图URL
  final String? imageSmallUrl;

  /// 简介摘要（纯文本，约2-3句，用于列表展示）
  final String? bioSummary;

  /// 简介全文（HTML格式，用于详情页展开）
  final String? bioContent;

  /// 简介语言（zh / en）
  final String? bioLang;

  /// 风格标签列表
  final List<String> tags;

  /// Last.fm 听众数
  final int? listeners;

  /// Last.fm 播放数
  final int? playcount;

  /// 相似歌手列表
  final List<SimilarArtist> similarArtists;

  /// 数据来源
  final ArtistMetadataSource source;

  /// 缓存时间（用于判断是否过期）
  final DateTime cachedAt;

  /// 数据格式版本号（当前为1，用于未来迁移）
  final int version;

  /// 是否为用户手动修正（V1.2）
  ///
  /// 为 true 时表示该元数据由用户手动编辑，优先于自动获取的数据。
  final bool isManualOverride;

  /// 是否有头像
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// 是否有简介
  bool get hasBio => bioSummary != null && bioSummary!.isNotEmpty;

  /// 是否有风格标签
  bool get hasTags => tags.isNotEmpty;

  /// 是否有相似歌手
  bool get hasSimilarArtists => similarArtists.isNotEmpty;

  /// 数据来源的中文显示名
  String get sourceDisplayName {
    switch (source) {
      case ArtistMetadataSource.lastFm:
        return 'Last.fm';
      case ArtistMetadataSource.deezer:
        return 'Deezer';
      case ArtistMetadataSource.wikipedia:
        return 'Wikipedia';
      case ArtistMetadataSource.synology:
        return '群晖 Audio Station';
      case ArtistMetadataSource.manual:
        return '用户手动修正';
      case ArtistMetadataSource.none:
        return '无';
    }
  }

  /// 格式化听众数（如 1.2M、500K）
  String get formattedListeners {
    if (listeners == null) return '';
    if (listeners! >= 1000000) {
      return '${(listeners! / 1000000).toStringAsFixed(1)}M';
    }
    if (listeners! >= 1000) {
      return '${(listeners! / 1000).toStringAsFixed(1)}K';
    }
    return listeners.toString();
  }

  /// 复制并修改指定字段
  ArtistMetadata copyWith({
    String? name,
    String? musicBrainzId,
    String? imageUrl,
    String? imageSmallUrl,
    String? bioSummary,
    String? bioContent,
    String? bioLang,
    List<String>? tags,
    int? listeners,
    int? playcount,
    List<SimilarArtist>? similarArtists,
    ArtistMetadataSource? source,
    DateTime? cachedAt,
    int? version,
    bool? isManualOverride,
  }) {
    return ArtistMetadata(
      name: name ?? this.name,
      musicBrainzId: musicBrainzId ?? this.musicBrainzId,
      imageUrl: imageUrl ?? this.imageUrl,
      imageSmallUrl: imageSmallUrl ?? this.imageSmallUrl,
      bioSummary: bioSummary ?? this.bioSummary,
      bioContent: bioContent ?? this.bioContent,
      bioLang: bioLang ?? this.bioLang,
      tags: tags ?? this.tags,
      listeners: listeners ?? this.listeners,
      playcount: playcount ?? this.playcount,
      similarArtists: similarArtists ?? this.similarArtists,
      source: source ?? this.source,
      cachedAt: cachedAt ?? this.cachedAt,
      version: version ?? this.version,
      isManualOverride: isManualOverride ?? this.isManualOverride,
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {
        'name': name,
        'musicBrainzId': musicBrainzId,
        'imageUrl': imageUrl,
        'imageSmallUrl': imageSmallUrl,
        'bioSummary': bioSummary,
        'bioContent': bioContent,
        'bioLang': bioLang,
        'tags': tags,
        'listeners': listeners,
        'playcount': playcount,
        'similarArtists': similarArtists.map((e) => e.toJson()).toList(),
        'source': source.name,
        'cachedAt': cachedAt.toIso8601String(),
        'version': version,
        'isManualOverride': isManualOverride,
      };

  /// 序列化为 JSON 字符串
  String toJsonString() => jsonEncode(toJson());

  /// 判断缓存是否过期（默认30天，空数据7天）
  bool isExpired({
    Duration maxAge = const Duration(days: 30),
    Duration emptyMaxAge = const Duration(days: 7),
  }) {
    final effectiveMaxAge = isEmpty ? emptyMaxAge : maxAge;
    return DateTime.now().difference(cachedAt) > effectiveMaxAge;
  }

  /// 判断是否为"无数据"标记
  bool get isEmpty => source == ArtistMetadataSource.none && !hasImage && !hasBio;
}
