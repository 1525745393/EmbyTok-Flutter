// Last.fm 音乐元数据服务：歌手头像/简介、专辑封面
//
// 用途：群晖 Audio Station 数据缺歌手图/简介/部分专辑封面时，
// 用 Last.fm 免费 API 补充（需用户提供 API Key，见设置页）。
//
// 说明：
// - 免费 Key 限速 5 req/s，本服务带内存缓存 + 尽力而为（失败静默降级）
// - 未配置 Key 时服务不创建（Provider 返回 null），不影响主流程
// - API 文档：https://www.last.fm/api/show/artist.getinfo

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/logger.dart';

/// Last.fm 歌手信息（简介 + 头像大图 + 相似歌手）
///
/// [bio] 可空：Last.fm 很多歌手有头像但无简介，此时仍返回头像，
/// 简介由调用方回退 Wikipedia 等兜底来源。
class LastFmArtistInfo {

  const LastFmArtistInfo({
    this.bio,
    this.imageUrl,
    this.similarArtists = const [],
  });
  final String? bio;
  final String? imageUrl;

  /// 相似歌手列表（名称 + 头像 URL）
  final List<LastFmSimilarArtist> similarArtists;
}

/// Last.fm 相似歌手
class LastFmSimilarArtist {

  const LastFmSimilarArtist({
    required this.name,
    this.imageUrl,
    this.url,
  });
  final String name;
  final String? imageUrl;
  final String? url;
}

class LastFmService {
  LastFmService({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  /// 会话级内存缓存：歌手名 → 结果（null 表示已查询无结果）
  final Map<String, LastFmArtistInfo?> _artistCache = {};

  /// 专辑封面缓存：'artist|album' → URL（null 表示无结果）
  final Map<String, String?> _albumCache = {};

  static const _timeout = Duration(seconds: 6);
  static const _base = 'https://ws.audioscrobbler.com/2.0/';

  /// 获取歌手头像与简介（Last.fm artist.getinfo）
  ///
  /// 返回 null 表示歌手在 Last.fm 无记录或网络失败（调用方回退其他来源）。
  Future<LastFmArtistInfo?> fetchArtistInfo(String artistName) async {
    final key = artistName.trim();
    if (key.isEmpty) return null;
    if (_artistCache.containsKey(key)) return _artistCache[key];

    LastFmArtistInfo? info;
    try {
      final uri = Uri.parse(_base).replace(queryParameters: {
        'method': 'artist.getinfo',
        'artist': key,
        'api_key': apiKey,
        'format': 'json',
        'autocorrect': '1',
      });
      final resp = await _client.get(uri).timeout(_timeout);
      if (resp.statusCode != 200) return _artistCache[key] = null;
      final json =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      // Last.fm 错误响应也是 HTTP 200，需检查 error 字段
      if (json['error'] != null) return _artistCache[key] = null;
      final artist = json['artist'] as Map<String, dynamic>?;
      if (artist == null) return _artistCache[key] = null;

      // 头像：优先最大尺寸（extralarge/mega），小图兜底
      String? imageUrl;
      final images = artist['image'] as List<dynamic>? ?? const [];
      for (final img in images.reversed) {
        final entry = img as Map<String, dynamic>?;
        final url = entry?['#text'] as String?;
        if (url != null && url.isNotEmpty) {
          imageUrl = url;
          break;
        }
      }
      // 简介：summary 优先，content 回退，去 HTML 标签
      final bioMap = artist['bio'] as Map<String, dynamic>?;
      var bio = bioMap?['summary'] as String?;
      if (bio == null || bio.trim().isEmpty) {
        bio = bioMap?['content'] as String?;
      }
      if (bio != null) bio = _stripHtml(bio).trim();
      if (bio != null && bio.length > 200) bio = '${bio.substring(0, 200)}…';

      // 相似歌手：解析 similar.artist[] 字段
      final similarArtists = <LastFmSimilarArtist>[];
      final similarMap = artist['similar'] as Map<String, dynamic>?;
      final similarList = similarMap?['artist'] as List<dynamic>?;
      if (similarList != null && similarList.isNotEmpty) {
        for (final item in similarList.take(10)) {
          final entry = item as Map<String, dynamic>?;
          if (entry == null) continue;
          final name = entry['name'] as String?;
          if (name == null || name.isEmpty) continue;
          // 头像：取最大尺寸
          String? artistImageUrl;
          final images = entry['image'] as List<dynamic>? ?? const [];
          for (final img in images.reversed) {
            final imgEntry = img as Map<String, dynamic>?;
            final url = imgEntry?['#text'] as String?;
            if (url != null && url.isNotEmpty) {
              artistImageUrl = url;
              break;
            }
          }
          similarArtists.add(LastFmSimilarArtist(
            name: name,
            imageUrl: artistImageUrl,
            url: entry['url'] as String?,
          ));
        }
      }

      // 头像或简介任一存在即返回（Last.fm 常见「有图无简介」歌手，
      // 此时简介由调用方回退 Wikipedia 等来源）
      if ((bio == null || bio.isEmpty) &&
          (imageUrl == null || imageUrl.isEmpty)) {
        return _artistCache[key] = null;
      }
      info = LastFmArtistInfo(
        bio: (bio == null || bio.isEmpty) ? null : bio,
        imageUrl: imageUrl,
        similarArtists: similarArtists,
      );
    } catch (e) {
      AppLogger.warn('Last.fm 获取歌手信息失败',
          data: {'artist': key, 'error': e.toString()});
    }
    _artistCache[key] = info;
    return info;
  }

  /// 获取专辑封面（Last.fm album.getinfo）
  ///
  /// 返回 null 表示无记录或失败（调用方回退群晖原生封面）。
  Future<String?> fetchAlbumCover({
    required String artist,
    required String album,
  }) async {
    final key = '${artist.trim()}|${album.trim()}';
    if (_albumCache.containsKey(key)) return _albumCache[key];

    String? imageUrl;
    try {
      final uri = Uri.parse(_base).replace(queryParameters: {
        'method': 'album.getinfo',
        'artist': artist.trim(),
        'album': album.trim(),
        'api_key': apiKey,
        'format': 'json',
        'autocorrect': '1',
      });
      final resp = await _client.get(uri).timeout(_timeout);
      if (resp.statusCode != 200) return _albumCache[key] = null;
      final json =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (json['error'] != null) return _albumCache[key] = null;
      final albumJson = json['album'] as Map<String, dynamic>?;
      final images = albumJson?['image'] as List<dynamic>? ?? const [];
      for (final img in images.reversed) {
        final entry = img as Map<String, dynamic>?;
        final url = entry?['#text'] as String?;
        if (url != null && url.isNotEmpty) {
          imageUrl = url;
          break;
        }
      }
    } catch (e) {
      AppLogger.warn('Last.fm 获取专辑封面失败',
          data: {'album': key, 'error': e.toString()});
    }
    _albumCache[key] = imageUrl;
    return imageUrl;
  }

  /// 移除 Last.fm 简介中的 HTML 标签（<a href>、<br> 等）
  String _stripHtml(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void dispose() {
    _client.close();
  }
}
