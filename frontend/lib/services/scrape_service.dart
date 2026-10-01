// 本地模式刮削服务：文件名解析 + TMDB 匹配 + 本地缓存
// 参考 VidHub：仅按文件名匹配，与文件夹名无关
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'tmdb_service.dart';

/// 文件名解析结果
class ParsedName {
  final String type; // movie | tv
  final String title;
  final int? year;
  final int? season;
  final int? episode;

  const ParsedName({
    required this.type,
    required this.title,
    this.year,
    this.season,
    this.episode,
  });
}

/// 刮削结果
class ScrapedMedia {
  final int tmdbId;
  final String type; // movie | tv
  final String title;
  final int? year;
  final String? posterPath;
  final String? backdropPath;
  final String? overview;
  final double? rating;
  final List<String> genres;
  final List<Map<String, String>> cast; // {name, role}
  final int? season;
  final int? episode;
  final int? tvId; // 剧集聚合用
  final int scrapedAt;

  const ScrapedMedia({
    required this.tmdbId,
    required this.type,
    required this.title,
    this.year,
    this.posterPath,
    this.backdropPath,
    this.overview,
    this.rating,
    this.genres = const [],
    this.cast = const [],
    this.season,
    this.episode,
    this.tvId,
    required this.scrapedAt,
  });

  Map<String, dynamic> toJson() => {
        'tmdbId': tmdbId,
        'type': type,
        'title': title,
        'year': year,
        'posterPath': posterPath,
        'backdropPath': backdropPath,
        'overview': overview,
        'rating': rating,
        'genres': genres,
        'cast': cast,
        'season': season,
        'episode': episode,
        'tvId': tvId,
        'scrapedAt': scrapedAt,
      };

  factory ScrapedMedia.fromJson(Map<String, dynamic> j) => ScrapedMedia(
        tmdbId: j['tmdbId'] as int,
        type: j['type'] as String,
        title: j['title'] as String,
        year: j['year'] as int?,
        posterPath: j['posterPath'] as String?,
        backdropPath: j['backdropPath'] as String?,
        overview: j['overview'] as String?,
        rating: (j['rating'] as num?)?.toDouble(),
        genres: (j['genres'] as List?)?.cast<String>() ?? const [],
        cast: (j['cast'] as List?)
                ?.map((e) => Map<String, String>.from(e as Map))
                .toList() ??
            const [],
        season: j['season'] as int?,
        episode: j['episode'] as int?,
        tvId: j['tvId'] as int?,
        scrapedAt: j['scrapedAt'] as int? ?? 0,
      );
}

class ScrapeService {
  static const _prefix = 'scrape_';

  /// 文件名解析：提取片名、年份、季集号
  static ParsedName parseFilename(String filename, {String? parentDir}) {
    // 去扩展名
    var name = filename;
    final dotIdx = name.lastIndexOf('.');
    if (dotIdx > 0) name = name.substring(0, dotIdx);

    // 替换分隔符为空格
    name = name.replaceAll(RegExp(r'[.\[\]_]'), ' ').trim();

    // 剧集：S01E01 或 s01e01
    final seMatch = RegExp(r'[Ss](\d{1,2})\s*[Ee](\d{1,2})').firstMatch(name);
    if (seMatch != null) {
      final season = int.tryParse(seMatch.group(1)!);
      final episode = int.tryParse(seMatch.group(2)!);
      var title = name.substring(0, seMatch.start).trim();
      title = _cleanNoise(title);
      return ParsedName(
          type: 'tv', title: title, season: season, episode: episode);
    }

    // 剧集：1x01 / 1X01
    final xMatch = RegExp(r'(?<!\d)(\d{1,2})[xX](\d{1,2})(?!\d)').firstMatch(name);
    if (xMatch != null) {
      final season = int.tryParse(xMatch.group(1)!);
      final episode = int.tryParse(xMatch.group(2)!);
      var title = name.substring(0, xMatch.start).trim();
      title = _cleanNoise(title);
      return ParsedName(
          type: 'tv', title: title, season: season, episode: episode);
    }

    // 中文剧集：第一季第一集 / 第1季第1集
    final cnMatch = RegExp(r'第([一二三四五六七八九十\d]+)季第([一二三四五六七八九十\d]+)集')
        .firstMatch(name);
    if (cnMatch != null) {
      final season = _cnToInt(cnMatch.group(1)!);
      final episode = _cnToInt(cnMatch.group(2)!);
      var title = name.substring(0, cnMatch.start).trim();
      title = _cleanNoise(title);
      return ParsedName(
          type: 'tv', title: title, season: season, episode: episode);
    }

    // 纯数字文件名（如 01.mp4、02.mp4）：当作剧集单集，标题用父目录名
    final pureNum = RegExp(r'^\s*(\d{1,3})\s*$').firstMatch(name);
    if (pureNum != null) {
      final episode = int.tryParse(pureNum.group(1)!);
      var title = parentDir ?? '';
      // 清理父目录名中的 "Season X"、"第X季" 等
      title = title.replaceAll(RegExp(r'[Ss]eason\s*\d+'), '').trim();
      title = title.replaceAll(RegExp(r'第[一二三四五六七八九十\d]+季'), '').trim();
      title = _cleanNoise(title);
      return ParsedName(type: 'tv', title: title, season: 1, episode: episode);
    }

    // 电影：提取年份
    final yearMatch =
        RegExp(r'(?:^|\s)(19|20)\d{2}(?:\s|$)').firstMatch(name);
    int? year;
    String title;
    if (yearMatch != null) {
      year = int.tryParse(yearMatch.group(0)!.trim());
      title = name.substring(0, yearMatch.start).trim();
    } else {
      title = name;
    }
    title = _cleanNoise(title);
    return ParsedName(type: 'movie', title: title, year: year);
  }

  /// 中文数字转 int（支持 一~十 和阿拉伯数字）
  static int _cnToInt(String s) {
    final n = int.tryParse(s);
    if (n != null) return n;
    const map = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '十': 10};
    if (s.length == 1) return map[s] ?? 1;
    if (s.startsWith('十')) return 10 + (map[s.substring(1)] ?? 0);
    if (s.endsWith('十')) return (map[s.substring(0, 1)] ?? 1) * 10;
    return 1;
  }

  /// 清洗噪音：分辨率、编码、来源、音频
  static String _cleanNoise(String s) {
    return s
        .replaceAll(
            RegExp(r'\b(1080p|1080i|720p|4K|2160p|2160i|480p|REMUX|WEB|HD|SD)\b',
                caseSensitive: false),
            '')
        .replaceAll(
            RegExp(r'\b(x264|x265|h264|h265|HEVC|HDR|BluRay|BLURAY|AMZN|NF|NETFLIX|DSNP|WEB-DL|WEBDL|WEBRip|Blu-Ray)\b',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'\b(DDP?\d\.?\d?|AAC|AC3|DTS|5\.1|7\.1|Atmos)\b',
            caseSensitive: false),
            '')
        .replaceAll(RegExp(r'\b(EP?\d{1,4}|EP\s*\d+)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[【】\[\]()（）]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 刮削单个文件
  /// [parentDir] 父目录名（用作剧名兜底）
  /// [mediaTypeHint] 文件源指定的媒体类型（movie/tv/short）
  static Future<ScrapedMedia?> scrapeFile(
      String pathHash, String filename,
      {String? parentDir, String? mediaTypeHint}) async {
    if (mediaTypeHint == 'short') return null; // 短视频不刮削
    var parsed = parseFilename(filename, parentDir: parentDir);
    // 文件源指定为电视剧时，补充纯数字编号（01.02.03）作为集数
    if (mediaTypeHint == 'tv' && parsed.type != 'tv') {
      final numMatch =
          RegExp(r'(?:^|[.\s_-])(\d{1,3})(?:[.\s_-]|$)').firstMatch(filename);
      if (numMatch != null) {
        final ep = int.tryParse(numMatch.group(1)!);
        if (ep != null && ep > 0 && ep <= 999) {
          var title = parentDir ?? filename;
          final dotIdx = title.lastIndexOf('.');
          if (dotIdx > 0) title = title.substring(0, dotIdx);
          title = title.replaceAll(RegExp(r'[.\[\]_]'), ' ').trim();
          title = _cleanNoise(title);
          parsed = ParsedName(type: 'tv', title: title, season: 1, episode: ep);
        }
      }
    }
    if (parsed.title.isEmpty) return null;

    if (parsed.type == 'tv') {
      final results = await TmdbService.searchTv(parsed.title, year: parsed.year);
      if (results.isEmpty) return null;
      final first = results.first;
      final tvId = first['id'] as int;
      final details = await TmdbService.getTvDetails(tvId);
      return _fromTvDetails(details, first, parsed, tvId);
    } else {
      final results = await TmdbService.searchMovies(parsed.title);
      if (results.isEmpty) return null;
      final first = results.first;
      final movieId = first['id'] as int;
      final details = await TmdbService.getMovieDetails(movieId);
      return _fromMovieDetails(details, first, parsed, movieId);
    }
  }

  static ScrapedMedia? _fromMovieDetails(Map<String, dynamic> d,
      Map<String, dynamic> searchResult, ParsedName p, int id) {
    if (d.isEmpty) {
      // 用搜索结果兜底
      return ScrapedMedia(
        tmdbId: id,
        type: 'movie',
        title: searchResult['title'] ?? p.title,
        year: p.year,
        posterPath: searchResult['poster_path'] as String?,
        backdropPath: searchResult['backdrop_path'] as String?,
        overview: searchResult['overview'] as String?,
        rating: (searchResult['vote_average'] as num?)?.toDouble(),
        scrapedAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
    return ScrapedMedia(
      tmdbId: id,
      type: 'movie',
      title: d['title'] ?? p.title,
      year: p.year,
      posterPath: d['poster_path'] as String?,
      backdropPath: d['backdrop_path'] as String?,
      overview: d['overview'] as String?,
      rating: (d['vote_average'] as num?)?.toDouble(),
      genres: (d['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? const [],
      cast: ((d['credits']?['cast'] as List?) ?? [])
          .take(10)
          .map((c) => {
                'name': c['name'] as String? ?? '',
                'role': c['character'] as String? ?? '',
                'profilePath': c['profile_path'] as String? ?? '',
              })
          .toList(),
      scrapedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static ScrapedMedia? _fromTvDetails(Map<String, dynamic> d,
      Map<String, dynamic> searchResult, ParsedName p, int tvId) {
    if (d.isEmpty) {
      return ScrapedMedia(
        tmdbId: tvId,
        type: 'tv',
        title: searchResult['name'] ?? p.title,
        season: p.season,
        episode: p.episode,
        tvId: tvId,
        posterPath: searchResult['poster_path'] as String?,
        backdropPath: searchResult['backdrop_path'] as String?,
        overview: searchResult['overview'] as String?,
        rating: (searchResult['vote_average'] as num?)?.toDouble(),
        scrapedAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
    return ScrapedMedia(
      tmdbId: tvId,
      type: 'tv',
      title: d['name'] ?? p.title,
      season: p.season,
      episode: p.episode,
      tvId: tvId,
      posterPath: d['poster_path'] as String?,
      backdropPath: d['backdrop_path'] as String?,
      overview: d['overview'] as String?,
      rating: (d['vote_average'] as num?)?.toDouble(),
      genres: (d['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? const [],
      cast: ((d['credits']?['cast'] as List?) ?? [])
          .take(10)
          .map((c) => {
                'name': c['name'] as String? ?? '',
                'role': c['character'] as String? ?? '',
                'profilePath': c['profile_path'] as String? ?? '',
              })
          .toList(),
      scrapedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ---- 缓存 ----

  static Future<Map<String, ScrapedMedia>> loadCache() async {
    final sp = await SharedPreferences.getInstance();
    final result = <String, ScrapedMedia>{};
    for (final key in sp.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final raw = sp.getString(key);
      if (raw == null) continue;
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        result[key.substring(_prefix.length)] = ScrapedMedia.fromJson(j);
      } catch (_) {}
    }
    return result;
  }

  static Future<void> saveCache(String pathHash, ScrapedMedia media) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_prefix + pathHash, jsonEncode(media.toJson()));
  }

  static Future<void> clearCache() async {
    final sp = await SharedPreferences.getInstance();
    for (final key in sp.getKeys().where((k) => k.startsWith(_prefix))) {
      await sp.remove(key);
    }
  }
}
