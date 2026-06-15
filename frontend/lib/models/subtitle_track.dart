// 字幕轨道模型

class SubtitleTrack {
  final String id;
  final String name;
  final String language;
  final String format;
  final String? url;
  final bool isDefault;
  final bool isForced;

  SubtitleTrack({
    required this.id,
    required this.name,
    required this.language,
    required this.format,
    this.url,
    this.isDefault = false,
    this.isForced = false,
  });

  // 显示名称：优先使用 name，否则使用 language
  String get displayName {
    if (name.isNotEmpty) return name;
    if (language.isNotEmpty) return language;
    return 'Unknown';
  }

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) => SubtitleTrack(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        language: json['language'] as String? ?? '',
        format: json['format'] as String? ?? '',
        url: json['url'] as String?,
        isDefault: json['isDefault'] as bool? ?? false,
        isForced: json['isForced'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'language': language,
        'format': format,
        'url': url,
        'isDefault': isDefault,
        'isForced': isForced,
      };
}
