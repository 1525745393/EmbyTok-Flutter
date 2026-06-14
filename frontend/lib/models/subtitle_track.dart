// 字幕轨道模型

class SubtitleTrack {
  final String id;
  final String name;
  final String language;
  final String format;
  final String? url;
  final String? displayTitle;
  final bool isDefault;

  SubtitleTrack({
    required this.id,
    required this.name,
    required this.language,
    required this.format,
    this.url,
    this.displayTitle,
    this.isDefault = false,
  });

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) => SubtitleTrack(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        language: json['language'] as String? ?? '',
        format: json['format'] as String? ?? '',
        url: json['url'] as String?,
        displayTitle: json['displayTitle'] as String? ?? json['display_title'] as String?,
        isDefault: json['isDefault'] as bool? ?? json['is_default'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'language': language,
        'format': format,
        'url': url,
        'displayTitle': displayTitle,
        'isDefault': isDefault,
      };

  // 获取显示名称（优先使用 displayTitle，其次 name，最后 language）
  String get displayName {
    if (displayTitle != null && displayTitle!.isNotEmpty) return displayTitle!;
    if (name.isNotEmpty) return name;
    return language.isNotEmpty ? language : 'Unknown';
  }
}
