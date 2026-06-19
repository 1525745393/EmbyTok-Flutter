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

class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;

  const SubtitleCue(this.start, this.end, this.text);
}

List<SubtitleCue> parseSrt(String content) {
  final result = <SubtitleCue>[];
  final blocks = content.replaceAll('\r\n', '\n').split('\n\n');
  for (final block in blocks) {
    final lines = block.split('\n');
    if (lines.length < 2) continue;
    final timing = lines.firstWhere(
      (l) => l.contains('-->'),
      orElse: () => '',
    );
    if (timing.isEmpty) continue;
    final parts = timing.split('-->');
    if (parts.length < 2) continue;
    final start = _parseSrtTime(parts.first.trim());
    final end = _parseSrtTime(parts[1].trim());
    if (start == null || end == null) continue;
    final text = lines
        .skipWhile((l) => l.contains('-->')).where((l) => l.isNotEmpty).join('\n');
    if (text.isEmpty) continue;
    result.add(SubtitleCue(start, end, text));
  }
  return result;
}

Duration? _parseSrtTime(String s) {
  try {
    final cleaned = s.replaceAll(',', '.');
    final parts = cleaned.split(':');
    if (parts.length < 3) return null;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    final secondsParts = parts[2].split('.');
    final seconds = int.tryParse(secondsParts[0]) ?? 0;
    final millis = secondsParts.length > 1
        ? (int.tryParse(secondsParts[1].padRight(3, '0')) ?? 0)
        : 0;
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: millis,
    );
  } catch (_) {
    return null;
  }
}
