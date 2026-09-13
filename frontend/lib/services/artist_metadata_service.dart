// 歌手元数据统一服务
//
// 歌手简介功能 V1.0
// 整合多数据源（Last.fm / Deezer / Wikipedia），实现多源降级策略和三级缓存
// （L1 内存 / L2 SharedPreferences / L3 NAS）。
//
// 多源降级策略（V1.1）：
// 1. Last.fm 中文简介（lang=zh）
// 2. Last.fm 英文简介（默认英文）
// 3. Deezer（补源，头像质量高，简介多为英文）
// 4. Wikipedia 中文简介（兜底源）
// 5. Wikipedia 英文简介
//
// 缓存策略（V1.1）：
// - L1 内存：Map（LRU 淘汰，最多 50 个）
// - L2 本地：SharedPreferences（JSON 字符串，持久化存储）
// - L3 NAS：群晖 File Station（可选，需开启，多设备共享）
// - 缓存有效期：30 天（无简介标记 7 天）

import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/artist_metadata.dart';
import '../utils/logger.dart';
import 'deezer_service.dart';
import 'lastfm_service.dart';
import 'nas_metadata_sync_service.dart';
import 'synology_audio_api.dart';

/// 歌手元数据统一服务
///
/// 提供统一的歌手元数据获取接口，自动处理多源降级和三级缓存。
///
/// 三级缓存架构（V1.1）：
/// - L1 内存缓存：Map LRU 淘汰，最多 50 个，最快
/// - L2 本地缓存：SharedPreferences 持久化，应用重启后仍有效
/// - L3 NAS 缓存：群晖 File Station 存储，多设备共享（可选，需开启）
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
    NasMetadataSyncService? nasSyncService,
    SynologyAudioApi? synologyApi,
    SharedPreferences? prefs,
  })  : _lastFmService = lastFmService,
        _deezerService = deezerService ?? DeezerService(),
        _nasSyncService = nasSyncService ?? NasMetadataSyncService(),
        _synologyApi = synologyApi,
        _prefs = prefs;

  final LastFmService? _lastFmService;
  final DeezerService _deezerService;
  final NasMetadataSyncService _nasSyncService;
  final SynologyAudioApi? _synologyApi;
  SharedPreferences? _prefs;

  /// 获取 Last.fm 服务（可空，未配置 API Key 时为 null）
  LastFmService? get lastFmService => _lastFmService;

  /// 获取 Deezer 服务
  DeezerService get deezerService => _deezerService;

  /// 是否启用 NAS 同步（L3 缓存）
  bool nasSyncEnabled = false;

  /// L1 内存缓存：歌手名 → 元数据
  final Map<String, ArtistMetadata> _memoryCache = {};

  /// 内存缓存最大容量
  static const int _maxMemoryCacheSize = 50;

  /// SharedPreferences 存储 key 前缀
  static const String _prefsKeyPrefix = 'artist_metadata_';

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
      final cached = _getFromMemory(key);
      if (cached != null && !cached.isExpired()) {
        AppLogger.debug('歌手元数据 L1 缓存命中', data: {'artist': key});
        return cached;
      }
    }

    // 2. 检查 L2 本地缓存（非强制刷新时）
    if (!forceRefresh) {
      final cached = await _loadFromPrefs(key);
      if (cached != null && !cached.isExpired()) {
        AppLogger.debug('歌手元数据 L2 缓存命中', data: {'artist': key});
        _saveToMemory(key, cached);
        return cached;
      }
    }

    // 3. 检查 L3 NAS 缓存（非强制刷新时，需启用 NAS 同步且已登录）
    if (!forceRefresh && nasSyncEnabled && _synologyApi != null) {
      try {
        final nasCached = await _nasSyncService.downloadMetadata(
          key,
          api: _synologyApi!,
        );
        if (nasCached != null && !nasCached.isExpired()) {
          AppLogger.debug('歌手元数据 L3 NAS 缓存命中', data: {'artist': key});
          _saveToMemory(key, nasCached);
          await _saveToPrefs(key, nasCached);
          return nasCached;
        }
      } catch (e) {
        AppLogger.warn('歌手元数据 L3 NAS 缓存读取失败',
            data: {'artist': key, 'error': e.toString()});
      }
    }

    // 4. 多源降级获取
    AppLogger.debug('开始多源获取歌手元数据', data: {'artist': key, 'lang': lang});
    final metadata = await _fetchFromMultipleSources(key, lang: lang);

    // 5. 写入缓存（即使是空数据也写入，避免重复请求）
    _saveToMemory(key, metadata);
    await _saveToPrefs(key, metadata);

    // 6. 异步上传到 NAS（L3 缓存，需启用且已登录，非空数据才上传）
    if (nasSyncEnabled && _synologyApi != null && metadata.hasBio) {
      _nasSyncService
          .uploadMetadata(metadata, api: _synologyApi!)
          .catchError((e) {
        AppLogger.warn('歌手元数据 L3 NAS 上传失败',
            data: {'artist': key, 'error': e.toString()});
        return false; // 修复：catchError 必须返回值
      });
    }

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
    // 修复：分离头像和简介获取，避免只有头像时停止降级
    ArtistMetadata? deezerResult;
    try {
      deezerResult = await _fetchFromDeezer(artistName);
      if (deezerResult != null && deezerResult.hasBio) {
        AppLogger.debug('Deezer 获取歌手简介成功',
            data: {'artist': artistName, 'source': 'deezer'});
        return deezerResult;
      }
      // Deezer 只有头像无简介时，记录头像，继续降级获取简介
      if (deezerResult != null && deezerResult.hasImage) {
        AppLogger.debug('Deezer 仅获取到头像，继续降级获取简介',
            data: {'artist': artistName, 'source': 'deezer'});
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
          // 如果 Deezer 有头像但 Wikipedia 有简介，合并两者
          if (deezerResult != null && deezerResult.hasImage) {
            AppLogger.debug('合并 Deezer 头像和 Wikipedia 简介',
                data: {'artist': artistName});
            return wikiResult.copyWith(
              imageUrl: deezerResult.imageUrl,
              imageSmallUrl: deezerResult.imageSmallUrl,
              listeners: deezerResult.listeners,
            );
          }
          return wikiResult;
        }
      } catch (e) {
        AppLogger.warn('Wikipedia 获取歌手元数据失败',
            data: {'artist': artistName, 'lang': wikiLang, 'error': e.toString()});
      }
    }

    // 4. 如果 Wikipedia 也无简介，但 Deezer 有头像，返回 Deezer 结果
    if (deezerResult != null && deezerResult.hasImage) {
      AppLogger.debug('Wikipedia 无简介，返回 Deezer 头像数据',
          data: {'artist': artistName});
      return deezerResult;
    }

    // 5. 所有源都失败，返回空数据（标记为无简介）
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

  /// 从 Wikipedia 获取歌手元数据（指定语言）
  ///
  /// [lang] 语言代码（zh / en），默认中文
  Future<ArtistMetadata?> _fetchFromWikipedia(
    String artistName, {
    String lang = 'zh',
  }) async {
    // 使用 Wikipedia REST Summary API（无需 Key）
    try {
      final encoded = Uri.encodeComponent(artistName);
      final url = Uri.parse(
          'https://$lang.wikipedia.org/api/rest_v1/page/summary/$encoded');

      final response = await _httpClient.get(
        url,
        headers: const {'User-Agent': 'EmbyTok-Flutter/1.0'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      // HttpClientResponse 是 Stream<List<int>>，需要转换为字符串
      final responseBody = await response.transform(utf8.decoder).join();
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final extract = json['extract'] as String?;
      if (extract == null || extract.trim().isEmpty) return null;

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
        bioLang: lang,
        source: ArtistMetadataSource.wikipedia,
        cachedAt: DateTime.now(),
      );
    } catch (e) {
      AppLogger.warn('Wikipedia($lang) 获取歌手元数据失败',
          data: {'artist': artistName, 'lang': lang, 'error': e.toString()});
      return null;
    }
  }

  // ===== 缓存管理 =====

  /// 保存到 L1 内存缓存（LRU 淘汰）
  void _saveToMemory(String key, ArtistMetadata metadata) {
    // 如果 key 已存在，先移除以更新插入顺序（实现 LRU）
    if (_memoryCache.containsKey(key)) {
      _memoryCache.remove(key);
    }

    // 超出容量时移除最早的条目（最久未使用）
    while (_memoryCache.length >= _maxMemoryCacheSize) {
      final firstKey = _memoryCache.keys.first;
      _memoryCache.remove(firstKey);
    }

    _memoryCache[key] = metadata;
  }

  /// 从 L1 内存缓存读取（更新 LRU 顺序）
  ArtistMetadata? _getFromMemory(String key) {
    final cached = _memoryCache[key];
    if (cached != null) {
      // 命中时更新 LRU 顺序：移除再插入到末尾
      _memoryCache.remove(key);
      _memoryCache[key] = cached;
    }
    return cached;
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

  /// 手动修正歌手元数据（V1.2）
  ///
  /// 用户可以手动修改歌手头像和简介，覆盖自动获取的元数据。
  /// 修正后的数据会标记为手动修正，并优先于自动获取的数据。
  ///
  /// [artistName] 歌手名称
  /// [imageUrl] 新的头像 URL（可空，表示不修改）
  /// [bioSummary] 新的简介摘要（可空，表示不修改）
  /// [bioContent] 新的简介全文（可空，表示不修改）
  Future<ArtistMetadata> updateArtistMetadata({
    required String artistName,
    String? imageUrl,
    String? bioSummary,
    String? bioContent,
  }) async {
    final key = artistName.trim();

    // 获取当前元数据（从缓存或网络）
    final current = await getArtistMetadata(key);

    // 创建新的元数据，标记为手动修正
    final updated = ArtistMetadata(
      name: key,
      imageUrl: imageUrl ?? current.imageUrl,
      imageSmallUrl: imageUrl ?? current.imageSmallUrl,
      bioSummary: bioSummary ?? current.bioSummary,
      bioContent: bioContent ?? current.bioContent,
      bioLang: current.bioLang,
      tags: current.tags,
      listeners: current.listeners,
      similarArtists: current.similarArtists,
      source: ArtistMetadataSource.manual,
      isManualOverride: true,
      cachedAt: DateTime.now(),
    );

    // 写入缓存
    _saveToMemory(key, updated);
    await _saveToPrefs(key, updated);

    AppLogger.info('歌手元数据已手动修正',
        data: {'artist': key, 'hasImage': updated.hasImage, 'hasBio': updated.hasBio});

    return updated;
  }

  /// 重置歌手元数据（清除手动修正，重新从网络获取）
  ///
  /// [artistName] 歌手名称
  Future<ArtistMetadata> resetArtistMetadata(String artistName) async {
    final key = artistName.trim();

    // 清除缓存
    await clearCache(key);

    // 重新从网络获取
    return getArtistMetadata(key, forceRefresh: true);
  }

  /// 检查歌手元数据是否为手动修正
  Future<bool> isManualOverride(String artistName) async {
    final key = artistName.trim();
    final cached = _getFromMemory(key) ?? await _loadFromPrefs(key);
    return cached?.isManualOverride ?? false;
  }

  /// 批量扫描歌手元数据（V1.2）
  ///
  /// 扫描音乐库中所有歌手，批量获取缺失的头像和简介。
  ///
  /// [artistNames] 歌手名称列表
  /// [onProgress] 进度回调（当前索引，总数，当前歌手名）
  /// [skipExisting] 是否跳过已有完整元数据的歌手（默认 true）
  /// [concurrency] 并发数（默认 3）
  Future<BatchScanResult> batchScanArtists({
    required List<String> artistNames,
    void Function(int current, int total, String artistName)? onProgress,
    bool skipExisting = true,
    int concurrency = 3,
  }) async {
    final total = artistNames.length;
    var success = 0;
    var failed = 0;
    var skipped = 0;
    final failedArtists = <String>[];

    // 过滤掉空名称和重复名称
    final uniqueNames = artistNames
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    AppLogger.info('开始批量扫描歌手元数据',
        data: {'total': total, 'unique': uniqueNames.length, 'skipExisting': skipExisting});

    // 使用线程安全的索引分配（Dart 单线程，但保持代码清晰）
    var nextIndex = 0;
    int? getNextIndex() {
      if (nextIndex >= uniqueNames.length) return null;
      return nextIndex++;
    }

    // 并发 worker
    final workers = List.generate(concurrency, (_) async {
      while (true) {
        final currentIndex = getNextIndex();
        if (currentIndex == null) break;
        final artistName = uniqueNames[currentIndex];

        try {
          // 检查是否已有完整元数据（头像 + 简介）
          if (skipExisting) {
            final cached = _getFromMemory(artistName) ?? await _loadFromPrefs(artistName);
            if (cached != null && cached.hasImage && cached.hasBio) {
              skipped++;
              onProgress?.call(currentIndex + 1, total, artistName);
              continue;
            }
          }

          // 获取元数据
          // 优化：只有完全没有数据的歌手才强制刷新，已有部分数据的歌手使用缓存逻辑
          final cached = _getFromMemory(artistName) ?? await _loadFromPrefs(artistName);
          final hasPartialData = cached != null && (cached.hasImage || cached.hasBio);
          final metadata = await getArtistMetadata(
            artistName,
            forceRefresh: !hasPartialData,
          );

          if (metadata.hasImage || metadata.hasBio) {
            success++;
          } else {
            failed++;
            failedArtists.add(artistName);
          }
        } catch (e) {
          failed++;
          failedArtists.add(artistName);
          AppLogger.warn('批量扫描歌手元数据失败',
              data: {'artist': artistName, 'error': e.toString()});
        }

        onProgress?.call(currentIndex + 1, total, artistName);
      }
    });

    await Future.wait(workers);

    final result = BatchScanResult(
      total: total,
      unique: uniqueNames.length,
      success: success,
      failed: failed,
      skipped: skipped,
      failedArtists: failedArtists,
    );

    AppLogger.info('批量扫描歌手元数据完成',
        data: {'total': total, 'success': success, 'failed': failed, 'skipped': skipped});

    return result;
  }

  /// 获取缺失元数据的歌手列表
  Future<List<String>> getMissingArtists(List<String> artistNames) async {
    final missing = <String>[];
    for (final name in artistNames) {
      final key = name.trim();
      if (key.isEmpty) continue;
      final cached = _getFromMemory(key) ?? await _loadFromPrefs(key);
      if (cached == null || !cached.hasImage || !cached.hasBio) {
        missing.add(key);
      }
    }
    return missing;
  }

  /// 简易 HTTP 客户端（用于 Wikipedia API）
  final _httpClient = _SimpleHttpClient();
}

/// 批量扫描结果统计
class BatchScanResult {
  final int total;
  final int unique;
  final int success;
  final int failed;
  final int skipped;
  final List<String> failedArtists;

  const BatchScanResult({
    required this.total,
    required this.unique,
    required this.success,
    required this.failed,
    required this.skipped,
    required this.failedArtists,
  });

  double get successRate => unique == 0 ? 0 : success / unique;

  String get summary =>
      '共 $unique 个歌手，成功 $success，失败 $failed，跳过 $skipped';
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
