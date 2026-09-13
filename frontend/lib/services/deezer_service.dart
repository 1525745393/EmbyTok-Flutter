// Deezer 音乐元数据服务
//
// 歌手简介功能 V1.1
// Deezer 作为多源降级的补源，提供歌手头像和简介。
//
// 特点：
// - 无需 API Key，直接调用公开接口
// - 头像图片质量高（最大 1000x1000），适合作为头像补源
// - 简介多为英文，中文覆盖率较低
//
// API 文档：https://developers.deezer.com/api

import 'dart:convert';
import 'dart:io';

import '../utils/logger.dart';

/// Deezer 歌手信息
class DeezerArtistInfo {
  /// 歌手名称
  final String name;

  /// 歌手头像 URL（小图 56x56）
  final String? pictureSmall;

  /// 歌手头像 URL（中图 250x250）
  final String? pictureMedium;

  /// 歌手头像 URL（大图 500x500）
  final String? pictureBig;

  /// 歌手头像 URL（超大图 1000x1000）
  final String? pictureXl;

  /// 专辑数量
  final int? nbAlbum;

  /// 粉丝数量
  final int? nbFan;

  /// 歌手简介
  final String? description;

  const DeezerArtistInfo({
    required this.name,
    this.pictureSmall,
    this.pictureMedium,
    this.pictureBig,
    this.pictureXl,
    this.nbAlbum,
    this.nbFan,
    this.description,
  });

  /// 获取最佳质量的头像 URL
  String? get bestImageUrl =>
      pictureXl ?? pictureBig ?? pictureMedium ?? pictureSmall;

  /// 是否有头像
  bool get hasImage => bestImageUrl != null && bestImageUrl!.isNotEmpty;

  /// 是否有简介
  bool get hasBio => description != null && description!.isNotEmpty;

  factory DeezerArtistInfo.fromJson(Map<String, dynamic> json) {
    return DeezerArtistInfo(
      name: json['name'] as String? ?? '',
      pictureSmall: json['picture_small'] as String?,
      pictureMedium: json['picture_medium'] as String?,
      pictureBig: json['picture_big'] as String?,
      pictureXl: json['picture_xl'] as String?,
      nbAlbum: json['nb_album'] as int?,
      nbFan: json['nb_fan'] as int?,
      description: json['description'] as String?,
    );
  }
}

/// Deezer 服务
class DeezerService {
  DeezerService({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  /// 会话级内存缓存：歌手名 → 结果（null 表示已查询无结果）
  final Map<String, DeezerArtistInfo?> _artistCache = {};

  static const _timeout = Duration(seconds: 8);
  static const _base = 'https://api.deezer.com';

  /// 获取歌手信息（先搜索，再获取详情）
  ///
  /// 返回 null 表示歌手在 Deezer 无记录或网络失败。
  Future<DeezerArtistInfo?> fetchArtistInfo(String artistName) async {
    final key = artistName.trim();
    if (key.isEmpty) return null;
    if (_artistCache.containsKey(key)) return _artistCache[key];

    DeezerArtistInfo? info;
    try {
      // 1. 搜索歌手
      final searchResult = await _searchArtist(key);
      if (searchResult.isEmpty) {
        _artistCache[key] = null;
        return null;
      }

      // 2. 取第一个匹配结果的 ID
      final firstArtist = searchResult.first;
      final artistId = firstArtist['id'];
      if (artistId == null) {
        _artistCache[key] = null;
        return null;
      }

      // 3. 获取歌手详情
      info = await _getArtistDetail(artistId.toString());
    } catch (e) {
      AppLogger.warn('Deezer 获取歌手信息失败',
          data: {'artist': key, 'error': e.toString()});
    }

    _artistCache[key] = info;
    return info;
  }

  /// 搜索歌手（返回多个匹配结果，用于同名歌手选择）
  ///
  /// 返回最多 [limit] 个搜索结果，每个结果包含歌手名和头像 URL。
  Future<List<DeezerArtistInfo>> searchArtists(
    String query, {
    int limit = 10,
  }) async {
    final key = query.trim();
    if (key.isEmpty) return [];

    try {
      final searchResult = await _searchArtist(key, limit: limit);
      if (searchResult.isEmpty) return [];

      final results = <DeezerArtistInfo>[];
      for (final item in searchResult.take(limit)) {
        final name = item['name'] as String?;
        if (name == null || name.isEmpty) continue;

        // 头像：Deezer API 直接返回 picture_xl/picture_big/picture_medium/picture_small 字段
        // 取最大尺寸的头像
        results.add(DeezerArtistInfo(
          name: name,
          pictureXl: item['picture_xl'] as String?,
          pictureBig: item['picture_big'] as String?,
          pictureMedium: item['picture_medium'] as String?,
          pictureSmall: item['picture_small'] as String?,
          nbFan: item['nb_fan'] as int?,
          nbAlbum: item['nb_album'] as int?,
        ));
      }

      return results;
    } catch (e) {
      AppLogger.warn('Deezer 搜索歌手失败',
          data: {'query': key, 'error': e.toString()});
      return [];
    }
  }

  /// 搜索歌手
  Future<List<Map<String, dynamic>>> _searchArtist(
    String artistName, {
    int limit = 10,
  }) async {
    final encoded = Uri.encodeComponent(artistName);
    final url = Uri.parse('$_base/search/artist?q=$encoded&limit=$limit');

    final request = await _client.getUrl(url).timeout(_timeout);
    final response = await request.close().timeout(_timeout);

    if (response.statusCode != 200) return [];

    final responseBody = await response.transform(utf8.decoder).join();
    final json = jsonDecode(responseBody) as Map<String, dynamic>;

    final data = json['data'] as List<dynamic>?;
    if (data == null || data.isEmpty) return [];

    return data
        .map((e) => e as Map<String, dynamic>)
        .toList(growable: false);
  }

  /// 获取歌手详情
  Future<DeezerArtistInfo?> _getArtistDetail(String artistId) async {
    final url = Uri.parse('$_base/artist/$artistId');

    final request = await _client.getUrl(url).timeout(_timeout);
    final response = await request.close().timeout(_timeout);

    if (response.statusCode != 200) return null;

    final responseBody = await response.transform(utf8.decoder).join();
    final json = jsonDecode(responseBody) as Map<String, dynamic>;

    // Deezer 错误响应
    if (json['error'] != null) return null;

    return DeezerArtistInfo.fromJson(json);
  }

  /// 释放资源
  void dispose() {
    _client.close();
  }
}
