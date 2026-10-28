import 'dart:convert';
import 'package:http/http.dart' as http;

/// 弹幕数据模型
class DanmakuItem {
  final double time; // 出现时间（秒）
  final String text;
  final String color; // 颜色 hex
  final int type; // 1=滚动 4=底部 5=顶部
  final int size; // 字号

  DanmakuItem({
    required this.time,
    required this.text,
    required this.color,
    required this.type,
    required this.size,
  });
}

/// 弹弹Play弹幕服务
/// 文档：https://api.dandanplay.net/
class DanmakuService {
  static const String _base = 'https://api.dandanplay.net/api/v2';

  /// 搜索动画，返回候选作品列表
  /// 返回: [{ 'animeId': int, 'animeTitle': String, 'episodeId': int, 'episodeTitle': String }]
  static Future<List<Map<String, dynamic>>> searchEpisodes(String title) async {
    try {
      final r = await http
          .get(Uri.parse('$_base/search/episodes?anime=${Uri.encodeComponent(title)}'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      if (data['success'] != true) return [];
      final list = data['animes'] as List? ?? [];
      final results = <Map<String, dynamic>>[];
      for (final a in list) {
        for (final ep in a['episodes'] ?? []) {
          results.add({
            'animeId': a['animeId'],
            'animeTitle': a['animeTitle'],
            'episodeId': ep['episodeId'],
            'episodeTitle': ep['episodeTitle'],
          });
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// 获取某集的弹幕列表
  static Future<List<DanmakuItem>> getComments(int episodeId) async {
    try {
      final r = await http
          .get(Uri.parse('$_base/comment/$episodeId'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      if (data['success'] != true) return [];
      final comments = data['comments'] as List? ?? [];
      return comments.map((c) {
        // batch64-F1：按官方 v2 schema 解析——comments 为对象数组 {cid, p, m}
        // p = "出现时间,模式,颜色,用户ID"（CSV）；m = 弹幕内容。
        // 旧实现读 c['time']/c['mode']/c['color']/c['text'] 全为 null，
        // 导致 text 恒空被过滤，弹幕源实际不显示任何弹幕。
        if (c is Map) {
          final p = c['p']?.toString() ?? '';
          final parts = p.split(',');
          final time =
              parts.isNotEmpty ? (double.tryParse(parts[0]) ?? 0.0) : 0.0;
          final mode = parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1;
          final color =
              parts.length > 2 ? (int.tryParse(parts[2]) ?? 0xFFFFFF) : 0xFFFFFF;
          final text = c['m']?.toString() ?? '';
          if (text.isEmpty) return null;
          return DanmakuItem(
            time: time,
            text: text,
            color: '#${color.toRadixString(16).padLeft(6, '0')}',
            type: mode, // 1=滚动 4=底部 5=顶部（与官方 mode 一致）
            size: 25, // API 无字号字段，用默认值
          );
        }
        return null;
      }).whereType<DanmakuItem>().toList();
    } catch (_) {
      return [];
    }
  }

  /// 便捷方法：按片名+集号直接获取弹幕
  /// title: 作品名（中文优先）
  /// episode: 集号（从1开始）
  static Future<List<DanmakuItem>> getDanmaku(String title, int episode) async {
    final eps = await searchEpisodes(title);
    if (eps.isEmpty) return [];
    // 优先匹配集号
    for (final ep in eps) {
      final epTitle = ep['episodeTitle']?.toString() ?? '';
      // 集号匹配：第X集、X、EPX
      if (_matchEpisodeNumber(epTitle, episode)) {
        return getComments(ep['episodeId'] as int);
      }
    }
    // 回退：取第一个作品的第 episode 集。
    // batch157-F1：eps 是跨作品的扁平集列表，旧实现 eps[episode-1] 在
    // 多作品时取到其他作品的集（弹幕错集）；改为按 animeId 分组后
    // 取第一个作品内的第 episode 集。
    final byAnime = <int, List<Map<String, dynamic>>>{};
    for (final ep in eps) {
      byAnime.putIfAbsent(ep['animeId'] as int, () => []).add(ep);
    }
    if (byAnime.isNotEmpty) {
      final firstAnime = byAnime.values.first;
      if (firstAnime.length >= episode) {
        return getComments(firstAnime[episode - 1]['episodeId'] as int);
      }
    }
    return [];
  }

  static bool _matchEpisodeNumber(String epTitle, int target) {
    final s = epTitle.toLowerCase();
    // "第X集"
    final cnMatch = RegExp(r'第\s*(\d+)\s*集').firstMatch(s);
    if (cnMatch != null && int.parse(cnMatch.group(1)!) == target) return true;
    // "EP01" / "E01"
    final epMatch = RegExp(r'e[ps]?\s*0*(\d+)').firstMatch(s);
    if (epMatch != null && int.parse(epMatch.group(1)!) == target) return true;
    // 纯数字
    final numMatch = RegExp(r'^0*(\d+)$').firstMatch(s.trim());
    if (numMatch != null && int.parse(numMatch.group(1)!) == target) return true;
    return false;
  }
}
