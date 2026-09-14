// LRCLIB 在线歌词源（PRD #22 三级降级：NAS LRC → LRCLIB → 无）
//
// LRCLIB：免费开源歌词库 https://lrclib.net
// GET /api/get?artist_name=&track_name=&album_name=&duration=
// 返回 syncedLyrics（LRC）优先，否则 plainLyrics。

import 'dart:convert';

import 'package:dio/dio.dart';

import '../utils/logger.dart';

class LrclibService {
  LrclibService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {'User-Agent': 'EmbyTok-Flutter/1.0 (private music app)'},
    ));
  }
  late final Dio _dio;

  /// 内存缓存：artist|title|album → 歌词（含 null，避免重复请求未收录）
  final Map<String, String?> _cache = {};

  /// 查询歌词。命中返回 LRC 文本；未命中或失败返回 null。
  Future<String?> fetchLyrics({
    required String artist,
    required String title,
    String? album,
    int? durationSec,
  }) async {
    final a = artist.trim();
    final t = title.trim();
    if (a.isEmpty || t.isEmpty) return null;
    final key = '$a|$t|${album ?? ''}';
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        'https://lrclib.net/api/get',
        queryParameters: {
          'artist_name': a,
          'track_name': t,
          if (album != null && album.isNotEmpty) 'album_name': album,
          if (durationSec != null && durationSec > 0) 'duration': durationSec,
        },
      );
      final data = resp.data;
      String? result;
      if (data != null) {
        final synced = data['syncedLyrics'] as String?;
        if (synced != null && synced.trim().isNotEmpty) {
          result = synced;
        } else {
          final plain = data['plainLyrics'] as String?;
          if (plain != null && plain.trim().isNotEmpty) result = plain;
        }
      }
      _cache[key] = result;
      return result;
    } on DioException catch (e) {
      // 404 = 未收录，静默（不缓存，下次可重试）
      if (e.response?.statusCode == 404) return null;
      AppLogger.warn('LRCLIB 查询失败', data: {'err': e.message});
      return null;
    } catch (e) {
      AppLogger.warn('LRCLIB 查询异常', data: {'err': e.toString()});
      return null;
    }
  }
}

final lrclibService = LrclibService();
