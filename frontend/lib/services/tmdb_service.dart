// TMDB API Service
// 用于演示模式获取真实影片元数据和海报
// API key 来自用户申请: https://www.themoviedb.org/settings/api
import 'dart:convert';
import 'package:http/http.dart' as http;

class TmdbService {
  static const String _apiKey = '21e1b8e8a506b3247bbdeba79611c5e5';
  static const String _base = 'https://api.themoviedb.org/3';
  static const String _imgBase = 'https://image.tmdb.org/t/p';

  static String posterUrl(String path, {String size = 'w300'}) =>
      '$_imgBase/$size$path';
  static String backdropUrl(String path, {String size = 'w780'}) =>
      '$_imgBase/$size$path';

  /// 获取 Trending 电影（演示模式用）
  static Future<List<Map<String, dynamic>>> getTrendingMovies() async {
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

  /// 搜索影片
  static Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      final r = await http
          .get(Uri.parse('$_base/search/movie?api_key=$_apiKey&query=$query'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      final results = data['results'] as List? ?? [];
      return results.map((m) => m as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  /// 获取影片详情（含演员）
  static Future<Map<String, dynamic>?> getMovieDetail(int id) async {
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/movie/$id?api_key=$_apiKey&append_to_response=credits'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 将 TMDB movie JSON 转为 Emby item JSON
  static Map<String, dynamic> toEmbyItem(Map<String, dynamic> m, {int index = 0}) {
    final title = m['title'] ?? m['name'] ?? 'Unknown';
    final poster = m['poster_path'] as String? ?? '';
    final backdrop = m['backdrop_path'] as String? ?? '';
    final overview = m['overview'] ?? '';
    final voteAvg = (m['vote_average'] as num?)?.toDouble() ?? 0.0;
    final release = m['release_date'] ?? m['first_air_date'] ?? '';
    final year = release.isNotEmpty ? int.tryParse(release.substring(0, 4)) : 0;

    return {
      'Id': 'tmdb_$index',
      'Name': title,
      'Type': m['title'] != null ? 'Movie' : 'Series',
      'ProductionYear': year,
      'PremiereDate': release,
      'CommunityRating': voteAvg,
      'Overview': overview,
      'Genres': const [],
      'ImageTags': {'Primary': poster, 'Thumb': backdrop},
      'BackdropImageTags': [backdrop],
      'UserData': {'IsFavorite': false, 'PlaybackPositionTicks': 0, 'PlayCount': 0},
      'Studios': const [],
      'MediaSources': const [],
    };
  }
}
