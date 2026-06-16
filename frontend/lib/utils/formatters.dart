// 通用格式化工具函数（支持 num，以便调用方传入 int/double）

/// 将秒数格式化为 "12:34"，超过 1 小时则格式化为 "2h 14m"
String formatDuration(num? seconds) {
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

/// 格式化观看进度百分比：例如 "已观看 75%"
String formatWatchProgress(num current, num total) {
  if (total <= 0) return '已观看 0%';
  final pct = (current / total) * 100.0;
  final display = pct.clamp(0.0, 100.0);
  return '已观看 ${display.toInt()}%';
}
