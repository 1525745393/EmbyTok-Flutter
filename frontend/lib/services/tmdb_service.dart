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
  static String personUrl(String path, {String size = 'w185'}) =>
      '$_imgBase/$size$path';

  /// 获取演员详情
  static Future<Map<String, dynamic>?> getPersonDetails(int personId) async {
    if (!isConfigured) return null;
    try {
      final r = await http
          .get(Uri.parse('$_base/person/$personId?api_key=$_apiKey'));
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  /// 获取演员作品（combined credits，电影+电视剧）
  static Future<Map<String, dynamic>?> getPersonCredits(int personId) async {
    if (!isConfigured) return null;
    try {
      final r = await http
          .get(Uri.parse('$_base/person/$personId/combined_credits?api_key=$_apiKey'));
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

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

  /// 搜索影片
  static Future<List<Map<String, dynamic>>> searchMovies(String query,
      {int? year, String language = 'zh-CN'}) async {
    if (!isConfigured || query.isEmpty) return [];
    try {
      final encoded = Uri.encodeQueryComponent(query);
      final yp = year != null ? '&year=$year' : '';
      final r = await http
          .get(Uri.parse('$_base/search/movie?api_key=$_apiKey&query=$encoded$yp&language=$language'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      final results = data['results'] as List? ?? [];
      return results.map((m) => m as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  /// 按类型发现影片
  static Future<List<Map<String, dynamic>>> discoverByGenre(
      int genreId) async {
    if (!isConfigured) return [];
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/discover/movie?api_key=$_apiKey&with_genres=$genreId&sort_by=popularity.desc'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      final results = data['results'] as List? ?? [];
      return results.map((m) => m as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  /// 获取影片推荐
  static Future<List<Map<String, dynamic>>> getRecommendations(
      int movieId) async {
    if (!isConfigured) return [];
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/movie/$movieId/recommendations?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      final results = data['results'] as List? ?? [];
      return results.map((m) => m as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  /// 电视剧推荐
  static Future<List<Map<String, dynamic>>> getTvRecommendations(
      int tvId) async {
    if (!isConfigured) return [];
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/tv/$tvId/recommendations?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      final results = data['results'] as List? ?? [];
      return results.map((m) => m as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  /// 获取影片演职员（导演+演员）
  static Future<Map<String, dynamic>> getMovieCredits(int movieId) async {
    if (!isConfigured) return {};
    try {
      final r = await http
          .get(Uri.parse('$_base/movie/$movieId/credits?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return {};
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// 按分类获取影片列表
  /// category: popular / top_rated / upcoming / now_playing
  static Future<List<Map<String, dynamic>>> getMovieList(
      String category) async {
    if (!isConfigured) return [];
    try {
      final r = await http
          .get(Uri.parse('$_base/movie/$category?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      final results = data['results'] as List? ?? [];
      return results.map((m) => m as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  /// 获取演员作品
  static Future<List<Map<String, dynamic>>> getPersonMovieCredits(
      int personId) async {
    if (!isConfigured) return [];
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/person/$personId/combined_credits?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      final cast = (data['cast'] as List?) ?? [];
      return cast.map((m) => m as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  // ---- 本地模式刮削扩展（P0）----

  /// 搜索剧集
  static Future<List<Map<String, dynamic>>> searchTv(String query,
      {int? year}) async {
    if (!isConfigured || query.isEmpty) return [];
    try {
      final encoded = Uri.encodeQueryComponent(query);
      final yp = year != null ? '&first_air_date_year=$year' : '';
      final r = await http
          .get(Uri.parse(
              '$_base/search/tv?api_key=$_apiKey&query=$encoded$yp&language=zh-CN'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      final results = data['results'] as List? ?? [];
      return results.map((m) => m as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  /// 电影详情（含演职员）
  static Future<Map<String, dynamic>> getMovieDetails(int movieId) async {
    if (!isConfigured) return {};
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/movie/$movieId?api_key=$_apiKey&append_to_response=credits,external_ids,release_dates&language=zh-CN'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return {};
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// 剧集详情（含演职员）
  static Future<Map<String, dynamic>> getTvDetails(int tvId) async {
    if (!isConfigured) return {};
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/tv/$tvId?api_key=$_apiKey&append_to_response=credits,external_ids,content_ratings&language=zh-CN'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return {};
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// 获取单集详情（集标题、简介、剧照）
  static Future<Map<String, dynamic>> getTvEpisodeDetails(
      int tvId, int season, int episode) async {
    if (!isConfigured) return {};
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/tv/$tvId/season/$season/episode/$episode?api_key=$_apiKey&language=zh-CN'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return {};
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// 剧照 URL（episode still_path）
  static String stillUrl(String path, {String size = 'w300'}) {
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  /// 影片评论（reviews）
  static Future<List<Map<String, dynamic>>> getMovieReviews(int movieId) async {
    if (!isConfigured) return [];
    try {
      final r = await http
          .get(Uri.parse('$_base/movie/$movieId/reviews?api_key=$_apiKey&language=zh-CN'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      return (data['results'] as List? ?? [])
          .map((m) => m as Map<String, dynamic>)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 剧集评论
  static Future<List<Map<String, dynamic>>> getTvReviews(int tvId) async {
    if (!isConfigured) return [];
    try {
      final r = await http
          .get(Uri.parse('$_base/tv/$tvId/reviews?api_key=$_apiKey&language=zh-CN'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      return (data['results'] as List? ?? [])
          .map((m) => m as Map<String, dynamic>)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
