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

/// Last.fm 歌手信息（简介 + 头像大图）
class LastFmArtistInfo {
  final String bio;
  final String? imageUrl;

  const LastFmArtistInfo({required this.bio, this.imageUrl});
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
      if (bio == null || bio.isEmpty) {
        return _artistCache[key] = null;
      }
      if (bio.length > 200) bio = '${bio.substring(0, 200)}…';
      info = LastFmArtistInfo(bio: bio, imageUrl: imageUrl);
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
