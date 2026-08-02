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

// 格式化观看进度百分比：例如 "已观看 75%"
String formatWatchProgress(double current, double total) {
  if (total <= 0) return '已观看 0%';
  final pct = (current / total) * 100;
  final display = pct.clamp(0.0, 100.0);
  return '已观看 ${display.toInt()}%';
}

// HTML 实体解码：将 &#39; 转换为 ' 等
String htmlDecode(String input) {
  return input
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

// 格式化字节数为人类可读字符串：B / KB / MB / GB
String formatBytes(int bytes) {
  if (bytes <= 0) return '暂无缓存';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

// 将 Emby 人员类型英文代码转换为中文标签
// Actor→演员 / Director→导演 / Writer→编剧，其他非空→人物，null→全部
String personTypeLabelFromCode(String? type) {
  switch (type) {
    case 'Actor':
      return '演员';
    case 'Director':
      return '导演';
    case 'Writer':
      return '编剧';
    default:
      if (type == null || type.isEmpty) return '全部';
      return '人物';
  }
}

// 详情页作品区标题：根据人员类型返回「XX的作品」格式
// Actor→参演作品 / Director→执导作品 / Writer→编剧作品，其他→相关作品
String personWorksTitleFromCode(String? type) {
  switch (type) {
    case 'Actor':
      return '参演作品';
    case 'Director':
      return '执导作品';
    case 'Writer':
      return '编剧作品';
    default:
      return '相关作品';
  }
}

// Emby 媒体类型中文标签：Movie→电影 / Series→剧集 / BoxSet→合集 / Episode→单集
String mediaTypeLabelFromCode(String? type) {
  switch (type) {
    case 'Movie':
      return '电影';
    case 'Series':
      return '剧集';
    case 'BoxSet':
      return '合集';
    case 'Episode':
      return '单集';
    default:
      if (type == null || type.isEmpty) return '作品';
      return type; // fallback: 英文原文
  }
}
