// TMDB API Service
// 用于演示模式获取真实影片元数据和海报
// API key 优先级：设置页用户配置 > --dart-define > 内置默认（仅演示）
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_translations.dart';
import '../utils/logger.dart';

class TmdbService {
  static const String _defaultKey = '21e1b8e8a506b3247bbdeba79611c5e5';
  static const String _spKey = 'tmdb_api_key';
  static final FlutterSecureStorage _secure = const FlutterSecureStorage();
  static String? _userKey;

  /// 用户在设置页配置的 key（运行时加载）
  ///
  /// 移动端专项 #1：改存 FlutterSecureStorage（Keychain/Keystore），
  /// 迁移时删除旧 SharedPreferences 明文键。
  static Future<void> setUserKey(String key) async {
    _userKey = key.trim().isEmpty ? null : key.trim();
    if (_userKey == null) {
      await _secure.delete(key: _spKey);
    } else {
      await _secure.write(key: _spKey, value: _userKey!);
    }
    await _removeLegacyPlainKey();
  }

  static Future<String?> getUserKey() async {
    if (_userKey != null) return _userKey;
    try {
      _userKey = await _secure.read(key: _spKey);
    } catch (e) {
      AppLogger.warn('读取 TMDB key 失败', data: {'error': e.toString()});
    }
    if (_userKey != null) return _userKey;
    // 旧版明文迁移：读取 SharedPreferences 中的旧值写入安全存储后删除
    try {
      final sp = await SharedPreferences.getInstance();
      final legacy = sp.getString(_spKey);
      if (legacy != null && legacy.isNotEmpty) {
        await _secure.write(key: _spKey, value: legacy);
        _userKey = legacy;
        await sp.remove(_spKey);
        AppLogger.info('TMDB key 已从明文存储迁移到安全存储');
      }
    } catch (e) {
      AppLogger.warn('TMDB key 明文迁移失败，忽略旧数据', data: {'error': e.toString()});
    }
    return _userKey;
  }

  /// 删除 SharedPreferences 中的旧明文键（幂等，key 不存在时无操作）
  static Future<void> _removeLegacyPlainKey() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_spKey);
    } catch (_) {
      // 清理旧明文失败不影响主流程
    }
  }

  /// 仅测试用：重置内存缓存，模拟冷启动读取路径
  @visibleForTesting
  static void resetForTest() {
    _userKey = null;
  }

  static String get _apiKey {
    if (_userKey != null && _userKey!.isNotEmpty) return _userKey!;
    const env = String.fromEnvironment('TMDB_API_KEY');
    if (env.isNotEmpty) return env;
    return _defaultKey;
  }

  static const String _base = 'https://api.themoviedb.org/3';
  static const String _imgBase = 'https://image.tmdb.org/t/p';

  static bool get isConfigured => _apiKey.isNotEmpty;

  static String posterUrl(String path, {String size = 'w500'}) =>
      '$_imgBase/$size$path';
  static String backdropUrl(String path, {String size = 'w1280'}) =>
      '$_imgBase/$size$path';
  static String personUrl(String path, {String size = 'h632'}) =>
      '$_imgBase/$size$path';

  /// 当前 UI 语言对应的 TMDB language 参数（zh→zh-CN，en→en-US；未保存则跟随系统）
  static Future<String> _currentLanguage() async {
    final loc = await AppLocale.load();
    return loc?.languageCode == 'en' ? 'en-US' : 'zh-CN';
  }

  /// 获取演员详情
  static Future<Map<String, dynamic>?> getPersonDetails(int personId) async {
    if (!isConfigured) return null;
    final lang = await _currentLanguage();
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/person/$personId?api_key=$_apiKey&language=$lang'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200)
        return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.warn('TMDB 演员接口失败（网络/超时），已 rethrow 触发错误态',
          data: {'error': e.toString()});
      rethrow;
    }
    return null;
  }

  /// 获取演员作品（combined credits，电影+电视剧）
  static Future<Map<String, dynamic>?> getPersonCredits(int personId) async {
    if (!isConfigured) return null;
    final lang = await _currentLanguage();
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/person/$personId/combined_credits?api_key=$_apiKey&language=$lang'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200)
        return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.warn('TMDB 演员接口失败（网络/超时），已 rethrow 触发错误态',
          data: {'error': e.toString()});
      rethrow;
    }
    return null;
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
          results[(g['id'] as int?) ?? 0] = (g['name'] as String?) ?? '';
        }
      }
      // 剧集类型
      final r2 = await http
          .get(Uri.parse('$_base/genre/tv/list?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 5));
      if (r2.statusCode == 200) {
        final data = jsonDecode(r2.body);
        for (final g in data['genres'] ?? []) {
          results[(g['id'] as int?) ?? 0] = (g['name'] as String?) ?? '';
        }
      }
      return results;
    } catch (_) {
      return {};
    }
  }

  /// 搜索影片
  static Future<List<Map<String, dynamic>>> searchMovies(String query,
      {int? year, String? language}) async {
    if (!isConfigured || query.isEmpty) return [];
    final lang = language ?? await _currentLanguage();
    try {
      final encoded = Uri.encodeQueryComponent(query);
      List<Map<String, dynamic>> results;
      // 第一次：带年份精确过滤；异常时静默降级到不带年份兜底搜索
      if (year != null) {
        try {
          final yp = '&year=$year';
          final r = await http
              .get(Uri.parse(
                  '$_base/search/movie?api_key=$_apiKey&query=$encoded$yp&language=$lang&include_adult=false'))
              .timeout(const Duration(seconds: 6));
          if (r.statusCode == 200) {
            final data = jsonDecode(r.body);
            results = (data['results'] as List? ?? [])
                .map((m) => m as Map<String, dynamic>)
                .toList();
            if (results.isNotEmpty) return results;
          }
        } catch (_) {
          // 网络异常/超时：继续不带年份重试，避免单次抖动导致整次刮削失败
        }
      }
      final r = await http
          .get(Uri.parse(
              '$_base/search/movie?api_key=$_apiKey&query=$encoded&language=$lang&include_adult=false'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      results = (data['results'] as List? ?? [])
          .map((m) => m as Map<String, dynamic>)
          .toList();
      return results;
    } catch (_) {
      return [];
    }
  }

  /// 获取影片推荐
  static Future<List<Map<String, dynamic>>> getRecommendations(
      int movieId) async {
    if (!isConfigured) return [];
    final lang = await _currentLanguage();
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/movie/$movieId/recommendations?api_key=$_apiKey&language=$lang'))
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
    final lang = await _currentLanguage();
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/tv/$tvId/recommendations?api_key=$_apiKey&language=$lang'))
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
  ///
  /// batch141-F1: 补 language=zh-CN——否则 combined_credits 默认 en-US，
  /// 演员详情页作品标题/角色名为英文，与 getPersonDetails（zh-CN）不一致。
  static Future<List<Map<String, dynamic>>> getPersonMovieCredits(
      int personId) async {
    if (!isConfigured) return [];
    final lang = await _currentLanguage();
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/person/$personId/combined_credits?api_key=$_apiKey&language=$lang'))
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
    final lang = await _currentLanguage();
    try {
      final encoded = Uri.encodeQueryComponent(query);
      List<Map<String, dynamic>> results;
      // 第一次：带年份精确过滤；异常时静默降级到不带年份兜底搜索
      if (year != null) {
        try {
          final yp = '&first_air_date_year=$year';
          final r = await http
              .get(Uri.parse(
                  '$_base/search/tv?api_key=$_apiKey&query=$encoded$yp&language=$lang'))
              .timeout(const Duration(seconds: 6));
          if (r.statusCode == 200) {
            final data = jsonDecode(r.body);
            results = (data['results'] as List? ?? [])
                .map((m) => m as Map<String, dynamic>)
                .toList();
            if (results.isNotEmpty) return results;
          }
        } catch (_) {
          // 网络异常/超时：继续不带年份重试，避免单次抖动导致整次刮削失败
        }
      }
      // 第二次：去掉年份重试（避免首播日期不精确导致漏搜）
      final r = await http
          .get(Uri.parse(
              '$_base/search/tv?api_key=$_apiKey&query=$encoded&language=$lang'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      results = (data['results'] as List? ?? [])
          .map((m) => m as Map<String, dynamic>)
          .toList();
      return results;
    } catch (_) {
      return [];
    }
  }

  /// 电影详情（含演职员）
  static Future<Map<String, dynamic>> getMovieDetails(int movieId) async {
    if (!isConfigured) return {};
    final lang = await _currentLanguage();
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/movie/$movieId?api_key=$_apiKey&append_to_response=credits,external_ids,release_dates&language=$lang'))
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
    final lang = await _currentLanguage();
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/tv/$tvId?api_key=$_apiKey&append_to_response=credits,external_ids,content_ratings&language=$lang'))
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
    final lang = await _currentLanguage();
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/tv/$tvId/season/$season/episode/$episode?api_key=$_apiKey&language=$lang'))
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

  /// 获取电影全部海报和背景图（用户选择用哪张）
  static Future<({List<String> posters, List<String> backdrops})>
      getMovieImages(int movieId) async {
    if (!isConfigured) return (posters: <String>[], backdrops: <String>[]);
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/movie/$movieId/images?api_key=$_apiKey&include_image_language=zh,en,null'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200)
        return (posters: <String>[], backdrops: <String>[]);
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final posters = <String>[
        for (final m in (data['posters'] as List? ?? []))
          if (((m as Map<String, dynamic>)['file_path'] as String? ?? '')
              .isNotEmpty)
            (m['file_path'] as String?) ?? '',
      ];
      final backdrops = <String>[
        for (final m in (data['backdrops'] as List? ?? []))
          if (((m as Map<String, dynamic>)['file_path'] as String? ?? '')
              .isNotEmpty)
            (m['file_path'] as String?) ?? '',
      ];
      return (posters: posters, backdrops: backdrops);
    } catch (_) {
      return (posters: <String>[], backdrops: <String>[]);
    }
  }

  /// 获取电视剧全部海报和背景图
  static Future<({List<String> posters, List<String> backdrops})> getTvImages(
      int tvId) async {
    if (!isConfigured) return (posters: <String>[], backdrops: <String>[]);
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/tv/$tvId/images?api_key=$_apiKey&include_image_language=zh,en,null'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200)
        return (posters: <String>[], backdrops: <String>[]);
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final posters = <String>[
        for (final m in (data['posters'] as List? ?? []))
          if (((m as Map<String, dynamic>)['file_path'] as String? ?? '')
              .isNotEmpty)
            (m['file_path'] as String?) ?? '',
      ];
      final backdrops = <String>[
        for (final m in (data['backdrops'] as List? ?? []))
          if (((m as Map<String, dynamic>)['file_path'] as String? ?? '')
              .isNotEmpty)
            (m['file_path'] as String?) ?? '',
      ];
      return (posters: posters, backdrops: backdrops);
    } catch (_) {
      return (posters: <String>[], backdrops: <String>[]);
    }
  }

  /// 影片评论（reviews，按 total_pages 分页聚合，上限 3 页防滥用）
  static Future<List<Map<String, dynamic>>> getMovieReviews(int movieId) async {
    if (!isConfigured) return [];
    final lang = await _currentLanguage();
    final reviews = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      try {
        final r = await http
            .get(Uri.parse(
                '$_base/movie/$movieId/reviews?api_key=$_apiKey&language=$lang&page=$page'))
            .timeout(const Duration(seconds: 6));
        if (r.statusCode != 200) break;
        final data = jsonDecode(r.body);
        reviews.addAll((data['results'] as List? ?? [])
            .map((m) => m as Map<String, dynamic>));
        final totalPages = (data['total_pages'] as num?)?.toInt() ?? 1;
        if (page >= totalPages || page >= 3) break;
        page++;
      } catch (_) {
        break; // 单页失败保留已聚合结果
      }
    }
    return reviews;
  }

  /// 剧集评论（reviews，按 total_pages 分页聚合，上限 3 页防滥用）
  static Future<List<Map<String, dynamic>>> getTvReviews(int tvId) async {
    if (!isConfigured) return [];
    final reviews = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final lang = await _currentLanguage();
      try {
        final r = await http
            .get(Uri.parse(
                '$_base/tv/$tvId/reviews?api_key=$_apiKey&language=$lang&page=$page'))
            .timeout(const Duration(seconds: 6));
        if (r.statusCode != 200) break;
        final data = jsonDecode(r.body);
        reviews.addAll((data['results'] as List? ?? [])
            .map((m) => m as Map<String, dynamic>));
        final totalPages = (data['total_pages'] as num?)?.toInt() ?? 1;
        if (page >= totalPages || page >= 3) break;
        page++;
      } catch (_) {
        break; // 单页失败保留已聚合结果
      }
    }
    return reviews;
  }
}
