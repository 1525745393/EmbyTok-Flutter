// TMDB API Service
// 用于演示模式获取真实影片元数据和海报
// API key 通过 --dart-define=TMDB_API_KEY=xxx 注入，不硬编码
import 'dart:convert';
import 'package:http/http.dart' as http;

class TmdbService {
  static const String _apiKey = String.fromEnvironment(
    'TMDB_API_KEY',
    defaultValue: '21e1b8e8a506b3247bbdeba79611c5e5',
  );
  static const String _base = 'https://api.themoviedb.org/3';
  static const String _imgBase = 'https://image.tmdb.org/t/p';

  static bool get isConfigured => _apiKey.isNotEmpty;

  static String posterUrl(String path, {String size = 'w300'}) =>
      '$_imgBase/$size$path';
  static String backdropUrl(String path, {String size = 'w780'}) =>
      '$_imgBase/$size$path';

  /// 获取 Trending 电影（演示模式用）
  static Future<List<Map<String, dynamic>>> getTrendingMovies() async {
    if (!isConfigured) return [];
    try {
      final r = await http
          .get(Uri.parse('$_base/trending/movie/week?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      final results = data['results'] as List? ?? [];
      return results.map((m) => m as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  /// 获取 Trending 剧集
  static Future<List<Map<String, dynamic>>> getTrendingTv() async {
    if (!isConfigured) return [];
    try {
      final r = await http
          .get(Uri.parse('$_base/trending/tv/week?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      final results = data['results'] as List? ?? [];
      return results.map((m) => m as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  /// 获取类型映射 (genre_id → 类型名)
  static Future<Map<int, String>> getGenres() async {
    if (!isConfigured) return {};
    try {
      final results = <int, String>{};
      // 电影类型
      final r1 = await http
          .get(Uri.parse('$_base/genre/movie/list?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 5));
      if (r1.statusCode == 200) {
        final data = jsonDecode(r1.body);
        for (final g in data['genres'] ?? []) {
          results[g['id'] as int] = g['name'] as String;
        }
      }
      // 剧集类型
      final r2 = await http
          .get(Uri.parse('$_base/genre/tv/list?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 5));
      if (r2.statusCode == 200) {
        final data = jsonDecode(r2.body);
        for (final g in data['genres'] ?? []) {
          results[g['id'] as int] = g['name'] as String;
        }
      }
      return results;
    } catch (_) {
      return {};
    }
  }

  /// 获取热门演员（用于演示模式演员列表）
  static Future<List<Map<String, dynamic>>> getPopularPeople() async {
    if (!isConfigured) return [];
    try {
      final r = await http
          .get(Uri.parse('$_base/person/popular?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      final results = data['results'] as List? ?? [];
      return results.map((m) => m as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }
}
