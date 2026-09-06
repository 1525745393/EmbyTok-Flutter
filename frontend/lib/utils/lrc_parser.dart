// LRC 歌词解析器
//
// 支持格式：
// - 单/多时间戳行：[mm:ss.xx]歌词 或 [mm:ss:xx]歌词
// - 元数据标签：[ti:][ar:][al:][by:][offset:±毫秒]（跳过）
// - 一行多时间戳（如 [00:12.00][00:24.00]重复段）

/// 一行歌词（时间 + 文本）
class LrcLine {
  final Duration time;
  final String text;

  const LrcLine(this.time, this.text);

  @override
  String toString() => '[${time.inMilliseconds}ms] $text';
}

/// 解析 LRC 文本，返回按时间升序的歌词行
///
/// 返回空列表表示无有效歌词行（纯元数据或空文本）。
List<LrcLine> parseLrc(String lrc) {
  final lines = <LrcLine>[];
  final timeTag = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');

  var offsetMs = 0;
  for (final raw in lrc.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;

    // offset 元数据：[offset:+500] / [offset:-200]
    final offsetMatch = RegExp(r'\[offset:([+-]?\d+)\]').firstMatch(line);
    if (offsetMatch != null) {
      offsetMs = int.tryParse(offsetMatch.group(1)!) ?? 0;
      continue;
    }

    // 提取本行所有时间戳
    final matches = timeTag.allMatches(line).toList();
    if (matches.isEmpty) continue; // 元数据行（ti/ar/al/by）或纯文本跳过

    final text = line.replaceAll(timeTag, '').trim();
    for (final m in matches) {
      final mm = int.tryParse(m.group(1)!) ?? 0;
      final ss = int.tryParse(m.group(2)!) ?? 0;
      // 百分之一秒（.xx）或毫秒（.xxx）
      var frac = int.tryParse(m.group(3) ?? '0') ?? 0;
      final fracDigits = (m.group(3) ?? '').length;
      if (fracDigits == 2) frac *= 10; // .12 → 120ms
      final time = Duration(
        minutes: mm,
        seconds: ss,
        milliseconds: frac + offsetMs,
      );
      if (time < Duration.zero) continue;
      lines.add(LrcLine(time, text));
    }
  }

  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
}

/// 返回 [position] 时刻应高亮的歌词行索引
///
/// - 无行或尚未到首句：-1
/// - 超过最后一句时间：最后一行索引
int activeLrcIndex(List<LrcLine> lines, Duration position) {
  if (lines.isEmpty) return -1;
  var idx = -1;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].time <= position) {
      idx = i;
    } else {
      break;
    }
  }
  return idx;
}

/// 格式化时长 mm:ss
String formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = (d.inSeconds.remainder(60)).toString().padLeft(2, '0');
  return '$m:$s';
}
