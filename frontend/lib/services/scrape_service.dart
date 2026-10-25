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

/// 刮削完整性状态（P3）：用于列表标记与筛选
enum ScrapeStatus { unscraped, incomplete, complete }

class ScrapeService {
  static const _prefix = 'scrape_';

  /// 元数据完整性判定：
  /// - unscraped：无刮削结果
  /// - incomplete：有刮削但缺关键字段（简介/海报/演员），用户可单独补全
  /// - complete：关键字段齐全
  static ScrapeStatus statusOf(ScrapedMedia? m) {
    if (m == null) return ScrapeStatus.unscraped;
    final overviewOk = m.overview != null && m.overview!.trim().isNotEmpty;
    final posterOk = m.posterPath != null && m.posterPath!.isNotEmpty;
    if (!overviewOk || !posterOk || m.cast.isEmpty) return ScrapeStatus.incomplete;
    return ScrapeStatus.complete;
  }

  /// TV 系列详情缓存（同一部剧只拉一次 getTvDetails）
  static final Map<int, Map<String, dynamic>> _tvDetailsCache = {};
  static final Map<int, Map<String, dynamic>> _movieDetailsCache = {};
  /// TV 单集详情缓存（key: "$tvId-$season-$episode"），避免同剧多集重复调 API
  static final Map<String, Map<String, dynamic>> _tvEpisodeCache = {};
  static const _maxCacheEntries = 200;

  static void _cachePut(Map<int, Map<String, dynamic>> cache, int key, Map<String, dynamic> value) {
    if (cache.length >= _maxCacheEntries) {
      cache.remove(cache.keys.first);
    }
    cache[key] = value;
  }

  // ---- 评论缓存（P3） ----
  /// key: "$type:$id"，仅成功（非空）结果入缓存，避免详情页/评论弹层重复请求 TMDB
  static final Map<String, List<Map<String, dynamic>>> _reviewsCache = {};

  /// 获取 TMDB 评论（带缓存）；[force]=true 绕过缓存重新请求（用户手动刷新/失败重试）
  static Future<List<Map<String, dynamic>>> fetchReviews(
      String type, int id, {bool force = false}) async {
    final key = '$type:$id';
    if (!force) {
      final cached = _reviewsCache[key];
      if (cached != null) return cached;
    }
    final list = type == 'tv'
        ? await TmdbService.getTvReviews(id)
        : await TmdbService.getMovieReviews(id);
    if (list.isNotEmpty) _reviewsCache[key] = list;
    return list;
  }

  /// 清空评论缓存（设置页"清除刮削缓存"时联动调用）
  static void clearReviewsCache() => _reviewsCache.clear();

  /// 当单集 cast 为空时，从 TMDB 拉取整剧演员列表。
  /// 返回 cast 列表（[{name, role, id, profilePath}]），失败返回空列表。
  static Future<List<Map<String, String>>> fetchShowCast(int tvId) async {
    try {
      var details = _tvDetailsCache[tvId];
      if (details == null || details['credits'] == null) {
        details = await TmdbService.getTvDetails(tvId);
        if (details.isNotEmpty) _tvDetailsCache[tvId] = details;
      }
      final castList = (details['credits']?['cast'] as List?) ?? [];
      return castList.take(10).map<Map<String, String>>((c) {
        return {
          'name': c['name'] as String? ?? '',
          'role': c['character'] as String? ?? '',
          'id': (c['id'] as num?)?.toString() ?? '',
          'profilePath': c['profile_path'] as String? ?? '',
        };
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  /// 检测 genre 是否全是英文（无中文字符），说明缓存是早期非中文数据。
  static bool needsChineseRefetch(ScrapedMedia m) {
    if (m.genres.isEmpty) return false;
    final hasChinese = m.genres.any((g) => RegExp(r'[\u4e00-\u9fff]').hasMatch(g));
    return !hasChinese;
  }

  /// 从 TMDB details 提取 cast 列表（{name, role, id, profilePath}）；无 credits 时返回空
  static List<Map<String, String>> _castFromDetails(Map<String, dynamic> d) {
    return ((d['credits']?['cast'] as List?) ?? [])
        .take(10)
        .map<Map<String, String>>((c) => {
              'id': (c['id'] as num?)?.toString() ?? '',
              'name': c['name'] as String? ?? '',
              'role': c['character'] as String? ?? '',
              'profilePath': c['profile_path'] as String? ?? '',
            })
        .toList();
  }

  /// 重新从 TMDB 拉取中文元数据（genre/overview/title 等）。
  /// 返回更新后的 ScrapedMedia，保留 episode/still 等单集字段。
  /// cast 一并重取：早期英文响应缓存的角色名（character）随中文重取同步更新。
  static Future<ScrapedMedia?> refetchChinese(ScrapedMedia m) async {
    try {
      if (m.type == 'tv' && m.tvId != null) {
        final details = await TmdbService.getTvDetails(m.tvId!);
        if (details.isEmpty) return null;
        _tvDetailsCache[m.tvId!] = details;
        final refreshedCast = _castFromDetails(details);
        return ScrapedMedia(
          tmdbId: m.tmdbId,
          type: 'tv',
          title: details['name'] as String? ?? m.title,
          year: m.year,
          posterPath: details['poster_path'] as String? ?? m.posterPath,
          backdropPath: details['backdrop_path'] as String? ?? m.backdropPath,
          overview: details['overview'] as String? ?? m.overview,
          rating: (details['vote_average'] as num?)?.toDouble() ?? m.rating,
          genres: (details['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? m.genres,
          cast: refreshedCast.isNotEmpty ? refreshedCast : m.cast,
          directors: m.directors,
          studios: m.studios,
          imdbId: m.imdbId,
          stillPath: m.stillPath,
          episodeTitle: m.episodeTitle,
          season: m.season,
          episode: m.episode,
          tvId: m.tvId,
          certification: m.certification,
          lowConfidence: m.lowConfidence,
          scrapedAt: DateTime.now().millisecondsSinceEpoch,
        );
      } else if (m.type == 'movie' && m.tmdbId > 0) {
        final details = await TmdbService.getMovieDetails(m.tmdbId);
        if (details.isEmpty) return null;
        final refreshedCast = _castFromDetails(details);
        return ScrapedMedia(
          tmdbId: m.tmdbId,
          type: 'movie',
          title: details['title'] as String? ?? m.title,
          year: m.year,
          posterPath: details['poster_path'] as String? ?? m.posterPath,
          backdropPath: details['backdrop_path'] as String? ?? m.backdropPath,
          overview: details['overview'] as String? ?? m.overview,
          rating: (details['vote_average'] as num?)?.toDouble() ?? m.rating,
          genres: (details['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? m.genres,
          cast: refreshedCast.isNotEmpty ? refreshedCast : m.cast,
          directors: m.directors,
          studios: m.studios,
          imdbId: m.imdbId,
          stillPath: m.stillPath,
          episodeTitle: m.episodeTitle,
          season: m.season,
          episode: m.episode,
          tvId: m.tvId,
          certification: m.certification,
          lowConfidence: m.lowConfidence,
          scrapedAt: DateTime.now().millisecondsSinceEpoch,
        );
      }
    } catch (_) {}
    return null;
  }

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
      // 剥离剧名末尾的"第X季"（如"庆余年第二季"→"庆余年"）
      title = title.replaceAll(RegExp(r'第[一二三四五六七八九十\d]+季$'), '').trim();
      // 提取年份（未来年份视为片名一部分，如 Blade Runner 2049，不剥离）
      int? tvYear;
      final nowYear = DateTime.now().year;
      final yMatch = RegExp(r'(19|20)\d{2}').firstMatch(title);
      if (yMatch != null) {
        final y = int.tryParse(yMatch.group(0)!);
        if (y != null && y <= nowYear) {
          tvYear = y;
          title = title.replaceAll(RegExp(r'\(?\s*(19|20)\d{2}\s*\)?'), '').trim();
        }
      }
      return ParsedName(
          type: 'tv', title: title, year: tvYear, season: season, episode: episode);
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

    // 剧集：EP01 / EP1 / 第1集 / 第一集（无季信息，默认季 1；与 episodeRegex 同套解析）
    // 剧名留空由调用方用父目录剧名兜底，避免此类命名被误判为电影或刮削短路
    final epOnlyMatch = RegExp(
      r'(?:[Ee][Pp]?\s*(\d{1,2}))|(?:第\s*(\d{1,2})\s*集)|(?:第([一二三四五六七八九十\d]+)集)',
      caseSensitive: false,
    ).firstMatch(name);
    if (epOnlyMatch != null) {
      final episode =
          _cnToInt(epOnlyMatch.group(1) ?? epOnlyMatch.group(2) ?? epOnlyMatch.group(3)!);
      var title = name.substring(0, epOnlyMatch.start).trim();
      title = _cleanNoise(title);
      return ParsedName(type: 'tv', title: title, season: 1, episode: episode);
    }

    // 电影：提取年份（支持 "片名 2008" 和 "片名 (2008)" 两种格式）
    // 防御误判：未来年份（如 Blade Runner 2049）不剥离；年份在开头的文件名
    // （如 "2023 荒岛求生"）先剥离提取，仅剥离后为空（片名即年份，如 2012）才保留原名
    final nowYear = DateTime.now().year;
    final yearMatch =
        RegExp(r'(?<=^|\s|\()(19|20)\d{2}(?=\s|\)|$)').firstMatch(name);
    int? year;
    String title;
    if (yearMatch != null) {
      year = int.tryParse(yearMatch.group(0)!);
      if (year != null && year > nowYear) {
        year = null;
        title = name;
      } else if (yearMatch.start == 0) {
        // 剥离开头的年份；剥离后标题为空说明片名即年份（如 2012），保留原名不提取
        final stripped = name.replaceAll(RegExp(r'^\s*(19|20)\d{2}\s*'), '').trim();
        if (stripped.isEmpty) {
          year = null;
          title = name;
        } else {
          year = int.tryParse(yearMatch.group(0)!);
          title = stripped;
        }
      } else {
        title = name.substring(0, yearMatch.start).trim();
      }
    } else {
      title = name;
    }
    title = _cleanNoise(title);
    return ParsedName(type: 'movie', title: title, year: year);
  }

  /// 中文数字转 int（支持 一~十、十X、X十、X十Y（如二十一）和阿拉伯数字）
  static int _cnToInt(String s) {
    final n = int.tryParse(s);
    if (n != null) return n;
    const map = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '十': 10};
    if (s.length == 1) return map[s] ?? 1;
    if (s.startsWith('十')) return 10 + (map[s.substring(1)] ?? 0);
    if (s.endsWith('十')) return (map[s.substring(0, 1)] ?? 1) * 10;
    // 几十几（如二十一、三十五）：十位×10 + 个位
    if (s.length >= 2 && s[s.length - 2] == '十') {
      return (map[s.substring(0, s.length - 2)] ?? 1) * 10 + (map[s[s.length - 1]] ?? 0);
    }
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

  /// 目录名是否为季文件夹（Season 1 / Season.1 / S01 / 第1季 / 第一季 等变体）
  /// 供剧名提取与刮削落盘复用，避免各组件维护多套季目录正则
  static bool isSeasonDirName(String dirName) {
    if (dirName.isEmpty) return false;
    final seg = dirName;
    if (RegExp(r'^[Ss]eason[.\s_-]*\d+', caseSensitive: false).hasMatch(seg)) return true;
    if (RegExp(r'^第[一二三四五六七八九十\d]+季').hasMatch(seg)) return true;
    if (RegExp(r'^[Ss]\d{1,2}$', caseSensitive: false).hasMatch(seg)) return true;
    return false;
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
      // 是季文件夹吗？（兼容 Season.1 / Season 1 / S1 / 第1季 等变体，避免被误当剧名）
      if (isSeasonDirName(seg)) {
        i--;
        continue;
      }
      return cleaned;
    }
    var last = segments.isNotEmpty ? segments.last : '';
    last = _cleanNoise(last.replaceAll(RegExp(r'[.\[\]_]'), ' '));
    last = last.replaceAll(RegExp(r'第[一二三四五六七八九十\d]+季$'), '').trim();
    return last.isEmpty ? null : last;
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

  /// 统一的季集号解析正则（文件管理页 _parseSeasonEpisode / 刮削 / 按刮削重命名共用）
  /// 支持：S01E01 / S01.E01 / Season 1 Episode 1 / E01 / EP01 / 第1集 / 第一集（默认季1）
  static final RegExp episodeRegex = RegExp(
    r'(?:[Ss](\d{1,2})[._ -]?[Ee](\d{1,2}))|(?:[Ss]eason\s*(\d{1,2})\s*[Ee]pisode\s*(\d{1,2}))|(?:[Ee][Pp]?\s*(\d{1,2}))|(?:第\s*(\d{1,2})\s*集)|(?:第([一二三四五六七八九十\d]+)集)',
    caseSensitive: false,
  );

  /// 从文件名提取季集号：优先匹配统一正则，其次纯数字编号（01.02.03）作集号
  /// 纯数字兜底要求前后为分隔符，避免误匹配 X264/1080P 等编码标记
  static ({int season, int episode})? extractEpisode(String filename) {
    final m = episodeRegex.firstMatch(filename);
    if (m != null) {
      // SxxExx: group(1)=season, group(2)=episode；Season X Episode Y: group(3)/(4)
      // E01/EP01: group(5)=episode；第Y集(阿拉伯): group(6)；第Y集(中文): group(7)，season 默认 1
      final s = m.group(1) ?? m.group(3);
      final e = m.group(2) ?? m.group(4) ?? m.group(5) ?? m.group(6) ?? m.group(7);
      if (e != null) {
        // _cnToInt 兼容阿拉伯与中文数字（一~十）
        return (season: s != null ? int.tryParse(s) ?? 1 : 1, episode: _cnToInt(e));
      }
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
      directors: base.directors,
      studios: base.studios,
      imdbId: base.imdbId,
      certification: base.certification,
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
    // 文件源指定为电影时，纠正纯数字文件名被误判为 TV 的情况
    if (mediaTypeHint == 'movie' && parsed.type != 'movie') {
      var movieName = filename;
      final dotIdx = movieName.lastIndexOf('.');
      if (dotIdx > 0) movieName = movieName.substring(0, dotIdx);
      movieName = movieName.replaceAll(RegExp(r'[.\[\]_]'), ' ').trim();
      final yearMatch =
          RegExp(r'(?<=^|\s|\()(19|20)\d{2}(?=\s|\)|$)').firstMatch(movieName);
      int? year;
      String title;
      if (yearMatch != null) {
        year = int.tryParse(yearMatch.group(0)!);
        title = movieName.substring(0, yearMatch.start).trim();
      } else {
        title = movieName;
      }
      title = _cleanNoise(title);
      if (title.isNotEmpty) {
        parsed = ParsedName(type: 'movie', title: title, year: year);
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
        if (details.isNotEmpty) _cachePut(_tvDetailsCache, tvId, details);
      }
      var base = _fromTvDetails(details, first, parsed, tvId);
      if (base != null && best.lowConfidence) {
        base = _copyWithLowConfidence(base, true);
      }
      // 拉取单集剧照和标题（剧名保留，集名单独存）
      if (base != null && parsed.season != null && parsed.episode != null) {
        try {
          final epKey = '${tvId}_${parsed.season}_${parsed.episode}';
          var ep = _tvEpisodeCache[epKey];
          if (ep == null) {
            ep = await TmdbService.getTvEpisodeDetails(tvId, parsed.season!, parsed.episode!);
            if (ep.isNotEmpty) {
              if (_tvEpisodeCache.length >= _maxCacheEntries) {
                _tvEpisodeCache.remove(_tvEpisodeCache.keys.first);
              }
              _tvEpisodeCache[epKey] = ep;
            }
          }
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
        if (details.isNotEmpty) _cachePut(_movieDetailsCache, movieId, details);
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
      final rd = searchResult['release_date'] as String?;
      final tmdbYear = rd != null && rd.length >= 4 ? int.tryParse(rd.substring(0, 4)) : null;
      return ScrapedMedia(
        tmdbId: id,
        type: 'movie',
        title: searchResult['title'] ?? p.title,
        year: p.year ?? tmdbYear,
        posterPath: searchResult['poster_path'] as String?,
        backdropPath: searchResult['backdrop_path'] as String?,
        overview: searchResult['overview'] as String?,
        rating: (searchResult['vote_average'] as num?)?.toDouble(),
        scrapedAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
    final rd = d['release_date'] as String?;
    final tmdbYear = rd != null && rd.length >= 4 ? int.tryParse(rd.substring(0, 4)) : null;
    return ScrapedMedia(
      tmdbId: id,
      type: 'movie',
      title: d['title'] ?? p.title,
      year: p.year ?? tmdbYear,
      posterPath: d['poster_path'] as String?,
      backdropPath: d['backdrop_path'] as String?,
      overview: d['overview'] as String?,
      rating: (d['vote_average'] as num?)?.toDouble(),
      genres: (d['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? const [],
      cast: _castFromDetails(d),
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
      final ffd = searchResult['first_air_date'] as String?;
      final tmdbYear = ffd != null && ffd.length >= 4 ? int.tryParse(ffd.substring(0, 4)) : null;
      return ScrapedMedia(
        tmdbId: tvId,
        type: 'tv',
        title: searchResult['name'] ?? p.title,
        year: p.year ?? tmdbYear,
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
    final ffd = d['first_air_date'] as String?;
    final tmdbYear = ffd != null && ffd.length >= 4 ? int.tryParse(ffd.substring(0, 4)) : null;
    return ScrapedMedia(
      tmdbId: tvId,
      type: 'tv',
      title: d['name'] ?? p.title,
      year: p.year ?? tmdbYear,
      season: p.season,
      episode: p.episode,
      tvId: tvId,
      posterPath: d['poster_path'] as String?,
      backdropPath: d['backdrop_path'] as String?,
      overview: d['overview'] as String?,
      rating: (d['vote_average'] as num?)?.toDouble(),
      genres: (d['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? const [],
      cast: _castFromDetails(d),
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

  /// 刮削缓存的内存镜像：同状态周期内复用，避免页面多次进入/操作反复全量 JSON decode
  static Map<String, ScrapedMedia>? _cache;

  static Future<Map<String, ScrapedMedia>> loadCache() async {
    if (_cache != null) return Map.of(_cache!); // 浅拷贝，防调用方污染共享实例
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
    _cache = result;
    return Map.of(result);
  }

  static Future<void> saveCache(String pathHash, ScrapedMedia media) async {
    // 已有缓存时保留旧 scrapedAt（首次入库/刮削时间）：
    // 详情页重刮、文件源重刮、整剧重刮均不应把"加入时间"漂移成重刮时刻（batch 24）
    final prev = _cache?[pathHash];
    final ScrapedMedia finalMedia;
    if (prev != null && prev.scrapedAt > 0 && media.scrapedAt != prev.scrapedAt) {
      finalMedia = ScrapedMedia(
        tmdbId: media.tmdbId,
        type: media.type,
        title: media.title,
        year: media.year,
        posterPath: media.posterPath,
        backdropPath: media.backdropPath,
        overview: media.overview,
        rating: media.rating,
        genres: media.genres,
        cast: media.cast,
        directors: media.directors,
        studios: media.studios,
        imdbId: media.imdbId,
        stillPath: media.stillPath,
        episodeTitle: media.episodeTitle,
        season: media.season,
        episode: media.episode,
        tvId: media.tvId,
        certification: media.certification,
        lowConfidence: media.lowConfidence,
        scrapedAt: prev.scrapedAt,
      );
    } else {
      finalMedia = media;
    }
    _cache?[pathHash] = finalMedia; // 同步内存镜像，下次 loadCache 不再读盘
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_prefix + pathHash, jsonEncode(finalMedia.toJson()));
  }

  /// 删除单个刮削缓存条目（内存镜像 + SharedPreferences），供 ScrapeMediaStore 删视频/重命名时清理孤儿键
  static Future<void> removeCacheEntry(String pathHash) async {
    _cache?.remove(pathHash);
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_prefix + pathHash);
  }

  static Future<void> clearCache() async {
    _cache = null; // 内存镜像失效
    final sp = await SharedPreferences.getInstance();
    for (final key in sp.getKeys().where((k) => k.startsWith(_prefix))) {
      await sp.remove(key);
    }
    // P3：同步清空内存评论缓存
    clearReviewsCache();
  }
}
