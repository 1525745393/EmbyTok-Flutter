// 字幕轨道模型

class SubtitleTrack {
  final String id;
  final String name;
  final String language;
  final String format;
  final String? url;

  SubtitleTrack({
    required this.id,
    required this.name,
    required this.language,
    required this.format,
    this.url,
  });

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) => SubtitleTrack(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        language: json['language'] as String? ?? '',
        format: json['format'] as String? ?? '',
        url: json['url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'language': language,
        'format': format,
        'url': url,
      };
}
