// 通用格式化工具函数

// 将秒数格式化为 "12:34"，超过 1 小时则格式化为 "2h 14m"
String formatDuration(double? seconds) {
  if (seconds == null || seconds <= 0) return '0:00';
  final total = seconds.toInt();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final secs = total % 60;
  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
  return '${minutes.toString()}:${secs.toString().padLeft(2, '0')}';
}

// 将 Emby ticks（1 tick = 100ns）格式化为 "1h 23m" 或 "45m"
String formatRuntimeTicks(int? ticks) {
  if (ticks == null || ticks <= 0) return '';
  // 1 tick = 100ns = 0.0001ms = 0.0000001s
  final seconds = ticks / 10000000.0;
  return formatDuration(seconds);
}

// 格式化观看进度百分比：例如 "已观看 75%"
String formatWatchProgress(double current, double total) {
  if (total <= 0) return '已观看 0%';
  final pct = (current / total) * 100;
  final display = pct.clamp(0.0, 100.0);
  return '已观看 ${display.toInt()}%';
}
