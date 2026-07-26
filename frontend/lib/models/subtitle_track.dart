// 字幕轨道模型

class SubtitleTrack {
  final String id;
  final String name;
  final String language;
  final String format;
  final String? url;
  final bool isDefault;
  final bool isForced;
  /// 本地外挂字幕文件路径（服务器字幕为 null）
  final String? localFilePath;

  SubtitleTrack({
    required this.id,
    required this.name,
    required this.language,
    required this.format,
    this.url,
    this.isDefault = false,
    this.isForced = false,
    this.localFilePath,
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
  final bool isBold;
  final bool isItalic;
  final String? color;
  final String? alignment;

  const SubtitleCue(
    this.start,
    this.end,
    this.text, {
    this.isBold = false,
    this.isItalic = false,
    this.color,
    this.alignment,
  });
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

// ============================
// VTT 字幕解析
// ============================

/// 解析 WebVTT 格式字幕
List<SubtitleCue> parseVtt(String content) {
  final result = <SubtitleCue>[];
  final normalized = content.replaceAll('\r\n', '\n');
  final lines = normalized.split('\n');

  // 跳过 WEBVTT 头和 NOTE/STYLE 块
  int i = 0;
  while (i < lines.length) {
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('WEBVTT') || line.startsWith('NOTE') ||
        line.startsWith('STYLE') || line.startsWith('REGION')) {
      i++;
      continue;
    }
    break;
  }

  while (i < lines.length) {
    // 跳过空行
    while (i < lines.length && lines[i].trim().isEmpty) {
      i++;
    }
    if (i >= lines.length) break;

    // 可能有可选的 cue 标识符行（不含 -->）
    String timingLine = lines[i].trim();
    if (!timingLine.contains('-->')) {
      i++;
      if (i >= lines.length) break;
      timingLine = lines[i].trim();
    }

    if (!timingLine.contains('-->')) {
      i++;
      continue;
    }

    final parts = timingLine.split('-->');
    if (parts.length < 2) {
      i++;
      continue;
    }

    final start = _parseVttTime(parts.first.trim());
    // 结束时间可能带设置（如 align:middle），取第一个空格前的部分
    final endPart = parts[1].trim().split(' ').first;
    final end = _parseVttTime(endPart);

    if (start == null || end == null) {
      i++;
      continue;
    }

    i++;

    // 收集字幕文本（直到空行或文件结束）
    final textLines = <String>[];
    while (i < lines.length && lines[i].trim().isNotEmpty) {
      textLines.add(_stripVttTags(lines[i]));
      i++;
    }

    final text = textLines.join('\n');
    if (text.isEmpty) continue;

    result.add(SubtitleCue(start, end, text));
  }

  return result;
}

/// 解析 VTT 时间格式 HH:MM:SS.mmm 或 MM:SS.mmm
Duration? _parseVttTime(String s) {
  try {
    final parts = s.split(':');
    int hours = 0;
    int minutes = 0;
    int seconds = 0;
    int millis = 0;

    if (parts.length == 3) {
      // HH:MM:SS.mmm
      hours = int.tryParse(parts[0]) ?? 0;
      minutes = int.tryParse(parts[1]) ?? 0;
      final secParts = parts[2].split('.');
      seconds = int.tryParse(secParts[0]) ?? 0;
      if (secParts.length > 1) {
        millis = int.tryParse(secParts[1].padRight(3, '0').substring(0, 3)) ?? 0;
      }
    } else if (parts.length == 2) {
      // MM:SS.mmm
      minutes = int.tryParse(parts[0]) ?? 0;
      final secParts = parts[1].split('.');
      seconds = int.tryParse(secParts[0]) ?? 0;
      if (secParts.length > 1) {
        millis = int.tryParse(secParts[1].padRight(3, '0').substring(0, 3)) ?? 0;
      }
    } else {
      return null;
    }

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

/// 移除 VTT 标签（<c>、<i>、<b>、<u>、<ruby>、<rt> 等）
String _stripVttTags(String text) {
  return text.replaceAll(RegExp(r'<[^>]*>'), '');
}

// ============================
// ASS/SSA 字幕解析
// ============================

/// 解析 ASS/SSA 格式字幕
/// 仅提取核心信息：时间、文本、粗体、斜体、颜色
List<SubtitleCue> parseAss(String content) {
  final result = <SubtitleCue>[];
  final normalized = content.replaceAll('\r\n', '\n');
  final lines = normalized.split('\n');

  // 查找 [Events] 段
  bool inEvents = false;
  List<String>? formatFields;

  for (final line in lines) {
    final trimmed = line.trim();

    if (trimmed.toLowerCase() == '[events]') {
      inEvents = true;
      continue;
    }
    // 遇到新的段（[开头），退出 Events 段
    if (inEvents && trimmed.startsWith('[') && trimmed.endsWith(']')) {
      break;
    }
    if (!inEvents) continue;

    if (trimmed.toLowerCase().startsWith('format:')) {
      // 解析 Format 行，确定各字段位置
      final formatStr = trimmed.substring('Format:'.length).trim();
      formatFields = formatStr.split(',').map((f) => f.trim()).toList();
      continue;
    }

    if (trimmed.toLowerCase().startsWith('dialogue:')) {
      if (formatFields == null) continue;

      final dialogueStr = line.substring(line.indexOf(':') + 1);
      // ASS 字段用逗号分隔，但文本中可能包含逗号，需按字段数分割
      final fieldCount = formatFields.length;
      final parts = _splitAssFields(dialogueStr, fieldCount);
      if (parts.length < fieldCount) continue;

      // 找到 Start、End、Text 字段的索引
      final startIndex = _findFieldIndex(formatFields, 'Start');
      final endIndex = _findFieldIndex(formatFields, 'End');
      final textIndex = _findFieldIndex(formatFields, 'Text');

      if (startIndex < 0 || endIndex < 0 || textIndex < 0) continue;

      final start = _parseAssTime(parts[startIndex].trim());
      final end = _parseAssTime(parts[endIndex].trim());
      if (start == null || end == null) continue;

      final rawText = parts[textIndex];
      final parsed = _parseAssDialogueText(rawText);
      if (parsed.text.isEmpty) continue;

      result.add(SubtitleCue(
        start,
        end,
        parsed.text,
        isBold: parsed.isBold,
        isItalic: parsed.isItalic,
        color: parsed.color,
      ));
    }
  }

  return result;
}

/// ASS 对话文本解析结果
class _AssTextResult {
  final String text;
  final bool isBold;
  final bool isItalic;
  final String? color;

  const _AssTextResult({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.color,
  });
}

/// 解析 ASS 对话文本，提取样式覆写并清理标签
_AssTextResult _parseAssDialogueText(String raw) {
  bool isBold = false;
  bool isItalic = false;
  String? color;

  // 处理 \b1 / \b0 粗体
  if (raw.contains(RegExp(r'\\b[1-9]'))) {
    isBold = true;
  }
  // 处理 \i1 / \i0 斜体
  if (raw.contains(RegExp(r'\\i[1-9]'))) {
    isItalic = true;
  }
  // 处理 \c&HFFFFFF& 颜色（BGR 格式）
  final colorMatch = RegExp(r'\\c&H([0-9A-Fa-f]{6})&').firstMatch(raw);
  if (colorMatch != null) {
    // ASS 颜色是 BGR 格式，转为 RGB
    final bgr = colorMatch.group(1)!;
    final r = bgr.substring(4, 6);
    final g = bgr.substring(2, 4);
    final b = bgr.substring(0, 2);
    color = '#$r$g$b';
  }

  // 移除所有大括号包裹的覆写代码 {\...}
  final cleanText = raw.replaceAll(RegExp(r'\{[^}]*\}'), '');
  // 替换 \N 和 \n 为换行
  final withNewlines = cleanText.replaceAll('\\N', '\n').replaceAll('\\n', '\n');

  return _AssTextResult(
    text: withNewlines.trim(),
    isBold: isBold,
    isItalic: isItalic,
    color: color,
  );
}

/// 按字段数分割 ASS 对话行（文本字段可能包含逗号）
List<String> _splitAssFields(String line, int fieldCount) {
  final parts = <String>[];
  int currentPos = 0;

  for (int i = 0; i < fieldCount - 1; i++) {
    final commaPos = line.indexOf(',', currentPos);
    if (commaPos < 0) break;
    parts.add(line.substring(currentPos, commaPos));
    currentPos = commaPos + 1;
  }

  // 最后一个字段（Text）包含剩余所有内容
  if (currentPos < line.length) {
    parts.add(line.substring(currentPos));
  }

  return parts;
}

/// 查找字段索引（不区分大小写）
int _findFieldIndex(List<String> fields, String name) {
  for (int i = 0; i < fields.length; i++) {
    if (fields[i].toLowerCase() == name.toLowerCase()) return i;
  }
  return -1;
}

/// 解析 ASS 时间格式 H:MM:SS.cc（百分秒）
Duration? _parseAssTime(String s) {
  try {
    final parts = s.split(':');
    if (parts.length < 3) return null;

    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    final secParts = parts[2].split('.');
    final seconds = int.tryParse(secParts[0]) ?? 0;
    // ASS 用百分秒（两位），转毫秒需乘 10
    final centis = secParts.length > 1
        ? int.tryParse(secParts[1].padRight(2, '0').substring(0, 2)) ?? 0
        : 0;

    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: centis * 10,
    );
  } catch (_) {
    return null;
  }
}

// ============================
// 统一入口：根据格式选择解析器
// ============================

/// 根据字幕格式自动选择解析器
/// format: 'srt' / 'vtt' / 'ass' / 'ssa' 等
List<SubtitleCue> parseSubtitle(String content, String format) {
  switch (format.toLowerCase()) {
    case 'vtt':
    case 'webvtt':
      return parseVtt(content);
    case 'ass':
    case 'ssa':
      return parseAss(content);
    case 'srt':
    case 'subrip':
    default:
      return parseSrt(content);
  }
}
