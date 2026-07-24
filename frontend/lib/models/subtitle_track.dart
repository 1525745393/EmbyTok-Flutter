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
    // SRT 格式至少需要 3 行：序号、时间轴、至少一行文本
    if (lines.length < 3) continue;

    // 找到时间轴行（包含 -->）
    int timingLineIndex = -1;
    String timing = '';
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('-->')) {
        timing = lines[i];
        timingLineIndex = i;
        break;
      }
    }
    if (timingLineIndex < 0 || timing.isEmpty) continue;

    // 解析时间
    final parts = timing.split('-->');
    if (parts.length < 2) continue;
    final start = _parseSrtTime(parts.first.trim());
    final end = _parseSrtTime(parts[1].trim());
    if (start == null || end == null) continue;

    // 提取文本：时间轴行之后的所有行都是字幕文本
    final textLines = lines
        .skip(timingLineIndex + 1)
        .where((l) => l.isNotEmpty)
        .map(_stripHtmlTags)
        .toList();
    final text = textLines.join('\n');
    if (text.isEmpty) continue;

    result.add(SubtitleCue(start, end, text));
  }
  return result;
}

/// 移除 SRT 中的 HTML 标签（<i>、<b>、<font> 等）
String _stripHtmlTags(String text) {
  return text.replaceAll(RegExp(r'<[^>]*>'), '');
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
    // 毫秒：取前 3 位，不足补 0
    final millis = secondsParts.length > 1
        ? int.tryParse(
            secondsParts[1].padRight(3, '0').substring(0, 3),
          ) ?? 0
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

/// 在已排序的字幕列表中二分查找当前时间对应的字幕
/// 时间复杂度 O(log n)，优于 firstWhere 的 O(n)
SubtitleCue? findCueAtPosition(List<SubtitleCue> cues, Duration position) {
  if (cues.isEmpty) return null;

  int low = 0;
  int high = cues.length - 1;

  while (low <= high) {
    final mid = (low + high) ~/ 2;
    final cue = cues[mid];

    if (position < cue.start) {
      high = mid - 1;
    } else if (position > cue.end) {
      low = mid + 1;
    } else {
      return cue;
    }
  }

  return null;
}
