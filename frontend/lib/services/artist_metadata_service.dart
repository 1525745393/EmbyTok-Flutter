// 歌手元数据统一服务
//
// 歌手简介功能 V1.0
// 整合多数据源（Last.fm / Wikipedia），实现多源降级策略和二级缓存
// （L1 内存 / L2 SharedPreferences）。
//
// 多源降级策略：
// 1. Last.fm 中文简介（lang=zh）
// 2. Last.fm 英文简介（默认英文）
// 3. Wikipedia 中文简介
// 4. Wikipedia 英文简介
//
// 缓存策略：
// - L1 内存：Map（LRU 淘汰，最多 50 个）
// - L2 本地：SharedPreferences（JSON 字符串，持久化存储）
// - 缓存有效期：30 天（无简介标记 7 天）

import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/artist_metadata.dart';
import '../utils/logger.dart';
import 'deezer_service.dart';
import 'lastfm_service.dart';

/// 歌手元数据统一服务
///
/// 提供统一的歌手元数据获取接口，自动处理多源降级和缓存。
///
/// 多源降级策略（V1.1）：
/// 1. Last.fm 中文简介（lang=zh）
/// 2. Last.fm 英文简介（默认英文）
/// 3. Deezer（补源，头像质量高，简介多为英文）
/// 4. Wikipedia 中文简介（兜底源）
/// 5. Wikipedia 英文简介
class ArtistMetadataService {
  ArtistMetadataService({
    LastFmService? lastFmService,
    DeezerService? deezerService,
    SharedPreferences? prefs,
  })  : _lastFmService = lastFmService,
        _deezerService = deezerService ?? DeezerService(),
        _prefs = prefs;

  final LastFmService? _lastFmService;
  final DeezerService _deezerService;
  SharedPreferences? _prefs;

  /// L1 内存缓存：歌手名 → 元数据
  final Map<String, ArtistMetadata> _memoryCache = {};

  /// 内存缓存最大容量
  static const int _maxMemoryCacheSize = 50;

  /// SharedPreferences 存储 key 前缀
  static const String _prefsKeyPrefix = 'artist_metadata_';

  /// 缓存有效期（30 天）
  static const Duration _cacheValidity = Duration(days: 30);

  /// 无简介标记有效期（7 天）
  static const Duration _emptyCacheValidity = Duration(days: 7);

  /// 初始化（加载 SharedPreferences 实例）
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 获取歌手元数据（自动处理缓存和多源降级）
  ///
  /// [artistName] 歌手名称
  /// [forceRefresh] 是否强制刷新（忽略缓存）
  /// [lang] 首选语言（zh / en，默认 zh）
  Future<ArtistMetadata> getArtistMetadata(
    String artistName, {
    bool forceRefresh = false,
    String lang = 'zh',
  }) async {
    final key = artistName.trim();
    if (key.isEmpty) {
      return ArtistMetadata.empty(artistName);
    }

    // 1. 检查 L1 内存缓存（非强制刷新时）
    if (!forceRefresh) {
      final cached = _memoryCache[key];
      if (cached != null && !_isExpired(cached)) {
        AppLogger.debug('歌手元数据 L1 缓存命中', data: {'artist': key});
        return cached;
      }
    }

    // 2. 检查 L2 本地缓存（非强制刷新时）
    if (!forceRefresh) {
      final cached = await _loadFromPrefs(key);
      if (cached != null && !_isExpired(cached)) {
        AppLogger.debug('歌手元数据 L2 缓存命中', data: {'artist': key});
        _saveToMemory(key, cached);
        return cached;
      }
    }

    // 3. 多源降级获取
    AppLogger.debug('开始多源获取歌手元数据', data: {'artist': key, 'lang': lang});
    final metadata = await _fetchFromMultipleSources(key, lang: lang);

    // 4. 写入缓存（即使是空数据也写入，避免重复请求）
    _saveToMemory(key, metadata);
    await _saveToPrefs(key, metadata);

    return metadata;
  }

  /// 多源降级获取歌手元数据
  ///
  /// 优先级：Last.fm 中文 → Last.fm 英文 → Deezer → Wikipedia 中文 → Wikipedia 英文
  Future<ArtistMetadata> _fetchFromMultipleSources(
    String artistName, {
    String lang = 'zh',
  }) async {
    // 1. Last.fm（如果已配置 API Key）
    if (_lastFmService != null) {
      // 1a. Last.fm 中文
      try {
        final lastFmResult = await _fetchFromLastFm(artistName, lang: 'zh');
        if (lastFmResult != null && lastFmResult.hasBio) {
          AppLogger.debug('Last.fm(中文) 获取歌手元数据成功',
              data: {'artist': artistName, 'source': 'lastfm', 'lang': 'zh'});
          return lastFmResult;
        }
      } catch (e) {
        AppLogger.warn('Last.fm(中文) 获取歌手元数据失败',
            data: {'artist': artistName, 'error': e.toString()});
      }

      // 1b. Last.fm 英文
      try {
        final lastFmResult = await _fetchFromLastFm(artistName, lang: 'en');
        if (lastFmResult != null && lastFmResult.hasBio) {
          AppLogger.debug('Last.fm(英文) 获取歌手元数据成功',
              data: {'artist': artistName, 'source': 'lastfm', 'lang': 'en'});
          return lastFmResult;
        }
      } catch (e) {
        AppLogger.warn('Last.fm(英文) 获取歌手元数据失败',
            data: {'artist': artistName, 'error': e.toString()});
      }
    }

    // 2. Deezer（补源，头像质量高，简介多为英文）
    try {
      final deezerResult = await _fetchFromDeezer(artistName);
      if (deezerResult != null && (deezerResult.hasBio || deezerResult.hasImage)) {
        AppLogger.debug('Deezer 获取歌手元数据成功',
            data: {'artist': artistName, 'source': 'deezer'});
        return deezerResult;
      }
    } catch (e) {
      AppLogger.warn('Deezer 获取歌手元数据失败',
          data: {'artist': artistName, 'error': e.toString()});
    }

    // 3. Wikipedia（兜底源，无需 API Key）
    for (final wikiLang in [lang, 'en']) {
      try {
        final wikiResult = await _fetchFromWikipedia(artistName, lang: wikiLang);
        if (wikiResult != null && wikiResult.hasBio) {
          AppLogger.debug('Wikipedia 获取歌手元数据成功',
              data: {'artist': artistName, 'source': 'wikipedia', 'lang': wikiLang});
          return wikiResult;
        }
      } catch (e) {
        AppLogger.warn('Wikipedia 获取歌手元数据失败',
            data: {'artist': artistName, 'lang': wikiLang, 'error': e.toString()});
      }
    }

    // 4. 所有源都失败，返回空数据（标记为无简介）
    AppLogger.info('所有数据源均无歌手简介', data: {'artist': artistName});
    return ArtistMetadata.empty(artistName);
  }

  /// 从 Last.fm 获取歌手元数据
  Future<ArtistMetadata?> _fetchFromLastFm(
    String artistName, {
    String lang = 'zh',
  }) async {
    if (_lastFmService == null) return null;

    final info = await _lastFmService!.fetchArtistInfo(artistName);
    if (info == null) return null;

    return ArtistMetadata(
      name: artistName,
      imageUrl: info.imageUrl,
      imageSmallUrl: info.imageUrl, // Last.fm 只返回一个尺寸，暂用同一张
      bioSummary: info.bio,
      bioContent: info.bio, // Last.fm 简介已去 HTML，暂用同一份
      bioLang: lang,
      source: ArtistMetadataSource.lastFm,
      similarArtists: info.similarArtists
          .map((e) => SimilarArtist(name: e.name, imageUrl: e.imageUrl))
          .toList(),
      cachedAt: DateTime.now(),
    );
  }

  /// 从 Deezer 获取歌手元数据
  ///
  /// Deezer 头像质量高（最大 1000x1000），适合作为头像补源；
  /// 简介多为英文，中文覆盖率较低。
  Future<ArtistMetadata?> _fetchFromDeezer(String artistName) async {
    final info = await _deezerService.fetchArtistInfo(artistName);
    if (info == null) return null;

    // Deezer 简介可能为空，此时只返回头像（调用方会继续降级到其他源获取简介）
    return ArtistMetadata(
      name: artistName,
      imageUrl: info.bestImageUrl,
      imageSmallUrl: info.pictureMedium,
      bioSummary: info.description,
      bioContent: info.description,
      bioLang: 'en', // Deezer 简介多为英文
      listeners: info.nbFan,
      source: ArtistMetadataSource.deezer,
      cachedAt: DateTime.now(),
    );
  }

  /// 从 Wikipedia 获取歌手元数据
  Future<ArtistMetadata?> _fetchFromWikipedia(
    String artistName, {
    String lang = 'zh',
  }) async {
    // 使用 Wikipedia REST Summary API（无需 Key）
    // 中文优先，失败回退英文
    for (final wikiLang in [lang, 'en']) {
      try {
        final encoded = Uri.encodeComponent(artistName);
        final url = Uri.parse(
            'https://$wikiLang.wikipedia.org/api/rest_v1/page/summary/$encoded');

        final response = await _httpClient.get(
          url,
          headers: const {'User-Agent': 'EmbyTok-Flutter/1.0'},
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode != 200) continue;

        // HttpClientResponse 是 Stream<List<int>>，需要转换为字符串
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        final extract = json['extract'] as String?;
        if (extract == null || extract.trim().isEmpty) continue;

        final thumbnail = json['thumbnail'] as Map<String, dynamic>?;
        final imageUrl = thumbnail?['source'] as String?;

        // 截断过长的简介（摘要约 200 字符）
        final bioSummary = extract.trim().length > 200
            ? '${extract.trim().substring(0, 200)}…'
            : extract.trim();

        return ArtistMetadata(
          name: artistName,
          imageUrl: imageUrl,
          imageSmallUrl: imageUrl,
          bioSummary: bioSummary,
          bioContent: extract.trim(),
          bioLang: wikiLang,
          source: ArtistMetadataSource.wikipedia,
          cachedAt: DateTime.now(),
        );
      } catch (e) {
        AppLogger.debug('Wikipedia 获取失败',
            data: {'artist': artistName, 'lang': wikiLang, 'error': e.toString()});
        continue;
      }
    }
    return null;
  }

  // ===== 缓存管理 =====

  /// 判断缓存是否过期
  bool _isExpired(ArtistMetadata metadata) {
    final validity =
        metadata.isEmpty ? _emptyCacheValidity : _cacheValidity;
    return DateTime.now().difference(metadata.cachedAt) > validity;
  }

  /// 保存到 L1 内存缓存（LRU 淘汰）
  void _saveToMemory(String key, ArtistMetadata metadata) {
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      // 移除最早的条目（简单 LRU）
      final firstKey = _memoryCache.keys.first;
      _memoryCache.remove(firstKey);
    }
    _memoryCache[key] = metadata;
  }

  /// 保存到 L2 本地缓存（SharedPreferences）
  Future<void> _saveToPrefs(String key, ArtistMetadata metadata) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final prefsKey = '$_prefsKeyPrefix$key';
      await _prefs!.setString(prefsKey, metadata.toJsonString());
    } catch (e) {
      AppLogger.warn('保存歌手元数据到本地缓存失败',
          data: {'artist': key, 'error': e.toString()});
    }
  }

  /// 从 L2 本地缓存加载
  Future<ArtistMetadata?> _loadFromPrefs(String key) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final prefsKey = '$_prefsKeyPrefix$key';
      final jsonString = _prefs!.getString(prefsKey);
      if (jsonString == null || jsonString.isEmpty) return null;
      return ArtistMetadata.fromJsonString(jsonString);
    } catch (e) {
      AppLogger.warn('从本地缓存加载歌手元数据失败',
          data: {'artist': key, 'error': e.toString()});
      return null;
    }
  }

  /// 清除指定歌手的缓存
  Future<void> clearCache(String artistName) async {
    final key = artistName.trim();
    _memoryCache.remove(key);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove('$_prefsKeyPrefix$key');
    } catch (e) {
      AppLogger.warn('清除歌手元数据缓存失败',
          data: {'artist': key, 'error': e.toString()});
    }
  }

  /// 清除所有歌手元数据缓存
  Future<void> clearAllCache() async {
    _memoryCache.clear();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final keys = _prefs!
          .getKeys()
          .where((k) => k.startsWith(_prefsKeyPrefix))
          .toList();
      for (final key in keys) {
        await _prefs!.remove(key);
      }
      AppLogger.info('已清除所有歌手元数据缓存', data: {'count': keys.length});
    } catch (e) {
      AppLogger.warn('清除所有歌手元数据缓存失败',
          data: {'error': e.toString()});
    }
  }

  /// 获取缓存大小（近似值，字节数）
  Future<int> getCacheSize() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final keys = _prefs!
          .getKeys()
          .where((k) => k.startsWith(_prefsKeyPrefix))
          .toList();
      int totalSize = 0;
      for (final key in keys) {
        final value = _prefs!.getString(key);
        if (value != null) {
          totalSize += value.length;
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// 简易 HTTP 客户端（用于 Wikipedia API）
  final _httpClient = _SimpleHttpClient();
}

/// 简易 HTTP 客户端（避免引入新依赖，使用 dart:io HttpClient）
class _SimpleHttpClient {
  Future<HttpClientResponse> get(Uri url, {Map<String, String>? headers}) {
    final client = HttpClient();
    return client.getUrl(url).then((request) {
      headers?.forEach((key, value) {
        request.headers.set(key, value);
      });
      return request.close();
    }).whenComplete(client.close);
  }
}
