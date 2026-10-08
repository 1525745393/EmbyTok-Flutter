// 本地模式刮削服务：文件名解析 + TMDB 匹配 + 本地缓存
// 参考 VidHub：仅按文件名匹配，与文件夹名无关
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'tmdb_service.dart';

/// 文件名解析结果
class ParsedName {

  const ParsedName({
    required this.type,
    required this.title,
    this.year,
    this.season,
    this.episode,
  });
  final String type; // movie | tv
  final String title;
  final int? year;
  final int? season;
  final int? episode;
}

/// 刮削结果
class ScrapedMedia { // P2#2：年份未精确匹配时标记

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
    this.directors = const [],
    this.studios = const [],
    this.imdbId,
    this.stillPath,
    this.episodeTitle,
    this.season,
    this.episode,
    this.tvId,
    this.certification,
    required this.scrapedAt,
    this.lowConfidence = false,
  });

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
        directors: (j['directors'] as List?)?.cast<String>() ?? const [],
        studios: (j['studios'] as List?)?.cast<String>() ?? const [],
        imdbId: j['imdbId'] as String?,
        stillPath: j['stillPath'] as String?,
        episodeTitle: j['episodeTitle'] as String?,
        season: j['season'] as int?,
        episode: j['episode'] as int?,
        tvId: j['tvId'] as int?,
        certification: j['certification'] as String?,
        scrapedAt: j['scrapedAt'] as int? ?? 0,
        lowConfidence: j['lowConfidence'] as bool? ?? false,
      );
  final int tmdbId;
  final String type; // movie | tv
  final String title;
  final int? year;
  final String? posterPath;
  final String? backdropPath;
  final String? overview;
  final double? rating;
  final List<String> genres;
  final List<Map<String, String>> cast; // {name, role, character, profilePath, id}
  final List<String> directors; // 导演
  final List<String> studios; // 出品公司
  final String? imdbId; // IMDb ID
  final String? stillPath; // 单集剧照
  final String? episodeTitle; // 单集标题
  final int? season;
  final int? episode;
  final int? tvId; // 剧集聚合用
  final String? certification; // 家长分级（如 PG-13 / 15+）
  final int scrapedAt;
  final bool lowConfidence;

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
        'directors': directors,
        'studios': studios,
        'imdbId': imdbId,
        'stillPath': stillPath,
        'episodeTitle': episodeTitle,
        'season': season,
        'episode': episode,
        'tvId': tvId,
        'certification': certification,
        'scrapedAt': scrapedAt,
        'lowConfidence': lowConfidence,
      };
}

class ScrapeService {
  static const _prefix = 'scrape_';

  /// TV 系列详情缓存（同一部剧只拉一次 getTvDetails）
  static final Map<int, Map<String, dynamic>> _tvDetailsCache = {};
  static final Map<int, Map<String, dynamic>> _movieDetailsCache = {};

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

    // 电影：提取年份（支持 "片名 2008" 和 "片名 (2008)" 两种格式）
    final yearMatch =
        RegExp(r'(?<=^|\s|\()(19|20)\d{2}(?=\s|\)|$)').firstMatch(name);
    int? year;
    String title;
    if (yearMatch != null) {
      year = int.tryParse(yearMatch.group(0)!);
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

  /// 从完整父目录路径提取剧名文件夹名
  /// 若直接父目录是 "Season X"/"第X季"，则向上取一级作为剧名
  static String? extractSeriesName(String? parentPath) {
    if (parentPath == null || parentPath.isEmpty) return null;
    final segments = parentPath.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    // 从最后一段开始找，跳过 Season X / 第X季 / S01 等季文件夹
    int i = segments.length - 1;
    while (i >= 0) {
      final seg = segments[i];
      final cleaned = _cleanNoise(seg.replaceAll(RegExp(r'[.\[\]_]'), ' '));
      if (cleaned.isEmpty) { i--; continue; }
      // 是季文件夹吗？
      if (RegExp(r'^[Ss]eason\s*\d+').hasMatch(seg) ||
          RegExp(r'^第[一二三四五六七八九十\d]+季').hasMatch(seg) ||
          RegExp(r'^[Ss]\d{1,2}$').hasMatch(seg)) {
        i--;
        continue;
      }
      return cleaned;
    }
    return segments.isNotEmpty ? _cleanNoise(segments.last.replaceAll(RegExp(r'[.\[\]_]'), ' ')) : null;
  }

  /// 刮削一部电视剧（只搜一次 TMDB），返回基础元数据
  /// 调用方再用 [applyEpisodeInfo] 给每集叠加 SxxExx
  static Future<ScrapedMedia?> scrapeTvSeries(String seriesName) async {
    final results = await TmdbService.searchTv(seriesName);
    if (results.isEmpty) return null;
    final first = results.first;
    final tvId = first['id'] as int;
    final details = await TmdbService.getTvDetails(tvId);
    final parsed = ParsedName(type: 'tv', title: seriesName);
    return _fromTvDetails(details, first, parsed, tvId);
  }

  /// 从文件名提取 SxxExx
  static ({int season, int episode})? extractEpisode(String filename) {
    final m = RegExp(r'[Ss](\d{1,2})[._ -]?[Ee](\d{1,2})').firstMatch(filename);
    if (m != null) {
      return (season: int.tryParse(m.group(1)!) ?? 1, episode: int.tryParse(m.group(2)!) ?? 1);
    }
    final num = RegExp(r'(?:^|[.\s_-])(\d{1,3})(?:[.\s_-]|$)').firstMatch(filename);
    if (num != null) {
      final ep = int.tryParse(num.group(1)!);
      if (ep != null && ep > 0 && ep <= 999) return (season: 1, episode: ep);
    }
    return null;
  }

  /// 给单集生成缓存条目（复用系列元数据，仅替换季集号）
  static ScrapedMedia applyEpisodeInfo(ScrapedMedia base, int season, int episode) {
    return ScrapedMedia(
      tmdbId: base.tmdbId,
      type: 'tv',
      title: base.title,
      year: base.year,
      posterPath: base.posterPath,
      backdropPath: base.backdropPath,
      overview: base.overview,
      rating: base.rating,
      genres: base.genres,
      cast: base.cast,
      season: season,
      episode: episode,
      tvId: base.tvId,
      scrapedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 刮削单个文件
  /// [parentDir] 父目录路径（用作剧名兜底，自动跳过 Season 文件夹）
  /// [mediaTypeHint] 文件源指定的媒体类型（movie/tv/short）
  static Future<ScrapedMedia?> scrapeFile(
      String pathHash, String filename,
      {String? parentDir, String? mediaTypeHint}) async {
    if (mediaTypeHint == 'short') return null; // 短视频不刮削
    // 从父目录路径提取剧名（跳过 Season 子目录）
    final seriesName = extractSeriesName(parentDir);
    var parsed = parseFilename(filename, parentDir: seriesName);
    // 文件源指定为电视剧时，补充纯数字编号（01.02.03）作为集数
    if (mediaTypeHint == 'tv' && parsed.type != 'tv') {
      final numMatch =
          RegExp(r'(?:^|[.\s_-])(\d{1,3})(?:[.\s_-]|$)').firstMatch(filename);
      if (numMatch != null) {
        final ep = int.tryParse(numMatch.group(1)!);
        if (ep != null && ep > 0 && ep <= 999) {
          var title = seriesName ?? filename;
          final dotIdx = title.lastIndexOf('.');
          if (dotIdx > 0) title = title.substring(0, dotIdx);
          title = title.replaceAll(RegExp(r'[.\[\]_]'), ' ').trim();
          title = _cleanNoise(title);
          parsed = ParsedName(type: 'tv', title: title, season: 1, episode: ep);
        }
      }
    }
    // 文件名只有 SxxExx（如 S01E01.mp4）时，用父目录剧名兜底
    if (parsed.type == 'tv' && parsed.title.isEmpty && seriesName != null && seriesName.isNotEmpty) {
      parsed = ParsedName(
        type: 'tv',
        title: seriesName,
        season: parsed.season,
        episode: parsed.episode,
      );
    }
    if (parsed.title.isEmpty) return null;

    if (parsed.type == 'tv') {
      final results = await TmdbService.searchTv(parsed.title, year: parsed.year);
      if (results.isEmpty) return null;
      final best = _pickBestTv(results, parsed);
      final first = best.result;
      final tvId = first['id'] as int;
      var details = _tvDetailsCache[tvId];
      if (details == null) {
        details = await TmdbService.getTvDetails(tvId);
        if (details.isNotEmpty) _tvDetailsCache[tvId] = details;
      }
      var base = _fromTvDetails(details, first, parsed, tvId);
      if (base != null && best.lowConfidence) {
        base = _copyWithLowConfidence(base, true);
      }
      // 拉取单集剧照和标题（剧名保留，集名单独存）
      if (base != null && parsed.season != null && parsed.episode != null) {
        try {
          final ep = await TmdbService.getTvEpisodeDetails(tvId, parsed.season!, parsed.episode!);
          if (ep.isNotEmpty) {
            return ScrapedMedia(
              tmdbId: base.tmdbId,
              type: base.type,
              title: base.title, // 保留剧名
              year: base.year,
              posterPath: base.posterPath,
              backdropPath: base.backdropPath,
              overview: ep['overview'] as String? ?? base.overview,
              rating: base.rating,
              genres: base.genres,
              cast: base.cast,
              directors: base.directors,
              studios: base.studios,
              imdbId: base.imdbId,
              stillPath: ep['still_path'] as String?,
              episodeTitle: ep['name'] as String?,
              season: base.season,
              episode: base.episode,
              tvId: base.tvId,
              scrapedAt: base.scrapedAt,
            );
          }
        } catch (e) {
          AppLogger.warn('刮削单集详情失败', data: {'error': e.toString()});
        }
      }
      return base;
    } else {
      final results = await TmdbService.searchMovies(parsed.title, year: parsed.year);
      if (results.isEmpty) return null;
      final best = _pickBestMovie(results, parsed);
      final movieId = best.result['id'] as int;
      var details = _movieDetailsCache[movieId];
      if (details == null) {
        details = await TmdbService.getMovieDetails(movieId);
        if (details.isNotEmpty) _movieDetailsCache[movieId] = details;
      }
      final m = _fromMovieDetails(details, best.result, parsed, movieId);
      return m == null ? null : _copyWithLowConfidence(m, best.lowConfidence);
    }
  }

  static ScrapedMedia _copyWithLowConfidence(ScrapedMedia m, bool lc) {
    return ScrapedMedia(
      tmdbId: m.tmdbId, type: m.type, title: m.title, year: m.year,
      posterPath: m.posterPath, backdropPath: m.backdropPath,
      overview: m.overview, rating: m.rating, genres: m.genres,
      cast: m.cast, directors: m.directors, studios: m.studios,
      imdbId: m.imdbId, stillPath: m.stillPath, episodeTitle: m.episodeTitle,
      season: m.season, episode: m.episode, tvId: m.tvId,
      certification: m.certification, scrapedAt: m.scrapedAt,
      lowConfidence: lc,
    );
  }

  /// 从搜索结果中选最佳匹配：优先年份吻合，其次标题相似
  static ({Map<String, dynamic> result, bool lowConfidence}) _pickBestMovie(
      List<Map<String, dynamic>> results, ParsedName p) {
    if (results.length == 1) return (result: results.first, lowConfidence: false);
    if (p.year == null) return (result: results.first, lowConfidence: false);
    // 优先年份精确匹配
    for (final r in results) {
      final rd = r['release_date'] as String?;
      if (rd != null && rd.startsWith('${p.year}')) return (result: r, lowConfidence: false);
    }
    // 容差 ±1 年
    for (final r in results) {
      final rd = r['release_date'] as String?;
      if (rd == null) continue;
      final y = int.tryParse(rd.substring(0, 4));
      if (y != null && (y - p.year!).abs() <= 1) return (result: r, lowConfidence: false);
    }
    return (result: results.first, lowConfidence: true);
  }

  /// TV 版最佳匹配：用 first_air_date 做年份校验
  static ({Map<String, dynamic> result, bool lowConfidence}) _pickBestTv(
      List<Map<String, dynamic>> results, ParsedName p) {
    if (results.length == 1) return (result: results.first, lowConfidence: false);
    if (p.year == null) return (result: results.first, lowConfidence: false);
    for (final r in results) {
      final rd = r['first_air_date'] as String?;
      if (rd != null && rd.startsWith('${p.year}')) return (result: r, lowConfidence: false);
    }
    for (final r in results) {
      final rd = r['first_air_date'] as String?;
      if (rd == null) continue;
      final y = int.tryParse(rd.substring(0, 4));
      if (y != null && (y - p.year!).abs() <= 1) return (result: r, lowConfidence: false);
    }
    return (result: results.first, lowConfidence: true);
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
                'id': (c['id'] as num?)?.toString() ?? '',
                'name': c['name'] as String? ?? '',
                'role': c['character'] as String? ?? '',
                'profilePath': c['profile_path'] as String? ?? '',
              })
          .toList(),
      directors: ((d['credits']?['crew'] as List?) ?? [])
          .where((c) => c['job'] == 'Director')
          .map((c) => c['name'] as String)
          .toList(),
      studios: (d['production_companies'] as List?)
              ?.map((c) => c['name'] as String)
              .take(5)
              .toList() ??
          const [],
      imdbId: d['external_ids']?['imdb_id'] as String?,
      certification: _extractMovieCert(d),
      scrapedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 从 TMDB movie details 提取美国分级
  static String? _extractMovieCert(Map<String, dynamic> d) {
    final rd = d['release_dates'] as Map<String, dynamic>?;
    final results = rd?['results'] as List?;
    if (results == null) return null;
    for (final r in results) {
      if (r['iso_3166_1'] == 'US') {
        final dates = r['release_dates'] as List?;
        for (final dd in dates ?? []) {
          final c = dd['certification'] as String?;
          if (c != null && c.isNotEmpty) return c;
        }
      }
    }
    return null;
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
                'id': (c['id'] as num?)?.toString() ?? '',
                'name': c['name'] as String? ?? '',
                'role': c['character'] as String? ?? '',
                'profilePath': c['profile_path'] as String? ?? '',
              })
          .toList(),
      directors: ((d['credits']?['crew'] as List?) ?? [])
          .where((c) => c['job'] == 'Director' || c['job'] == 'Executive Producer')
          .map((c) => c['name'] as String)
          .toSet()
          .toList(),
      studios: (d['production_companies'] as List?)
              ?.map((c) => c['name'] as String)
              .take(5)
              .toList() ??
          const [],
      imdbId: d['external_ids']?['imdb_id'] as String?,
      certification: _extractTvCert(d),
      scrapedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 从 TMDB TV details 提取美国分级
  static String? _extractTvCert(Map<String, dynamic> d) {
    final ratings = d['content_ratings']?['results'] as List?;
    if (ratings == null) return null;
    for (final r in ratings) {
      if (r['iso_3166_1'] == 'US') {
        final c = r['rating'] as String?;
        if (c != null && c.isNotEmpty) return c;
      }
    }
    return null;
  }

  static Future<Map<String, ScrapedMedia>> loadCache() async {
    final sp = await SharedPreferences.getInstance();
    final result = <String, ScrapedMedia>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    const movieTtl = 30 * 24 * 3600 * 1000;
    const tvTtl = 14 * 24 * 3600 * 1000;
    for (final key in sp.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      // 防御：旧数据可能把 bool 写到了这个 key 下，sp.getString 会抛类型转换异常
      final raw = sp.get(key);
      if (raw is! String) continue;
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final media = ScrapedMedia.fromJson(j);
        // scrapedAt=0 表示旧版本缓存，视为永不过期（不丢弃）
        if (media.scrapedAt > 0) {
          final age = now - media.scrapedAt;
          final ttl = media.type == 'tv' ? tvTtl : movieTtl;
          if (age > ttl) continue;
        }
        result[key.substring(_prefix.length)] = media;
      } catch (e) { AppLogger.warn('刮削缓存解析失败', data: {'key': key, 'error': e.toString()}); }
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
