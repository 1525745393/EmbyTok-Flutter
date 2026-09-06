// 歌手简介服务：从 Wikipedia REST API 获取歌手简介（带内存缓存）
//
// 背景：群晖 Audio Station 的歌手数据只有名字/评分，无简介字段。
// 这里用免费的 Wikipedia REST Summary API（无需 key）按歌手名查询简介，
// 失败（无条目/网络异常）时返回 null，UI 回退显示「暂无简介」。
//
// 缓存：内存 Map（会话级），重复查询不重复请求；命中后直接返回。
// 注意：该服务为尽力而为（best-effort），任何异常都静默返回 null，
// 不影响音乐库主流程。

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/logger.dart';

/// 歌手简介查询结果
class ArtistInfo {
  final String bio;
  final String? thumbnailUrl;

  const ArtistInfo({required this.bio, this.thumbnailUrl});
}

class ArtistInfoService {
  ArtistInfoService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// 会话级内存缓存：歌手名 → 简介（null 表示已查询过但无结果）
  final Map<String, ArtistInfo?> _cache = {};

  static const _timeout = Duration(seconds: 6);

  /// 获取歌手简介（中文优先，失败回退英文；均失败返回 null）
  ///
  /// [artistName] 歌手名（如「周杰伦」「Taylor Swift」）。
  Future<ArtistInfo?> fetchArtistInfo(String artistName) async {
    final key = artistName.trim();
    if (key.isEmpty) return null;
    // 缓存命中（含「已确认无结果」的 null）
    if (_cache.containsKey(key)) return _cache[key];

    ArtistInfo? info;
    try {
      info = await _fetchFromLang(key, 'zh');
    } catch (e) {
      AppLogger.warn('获取歌手中文简介失败',
          data: {'artist': key, 'error': e.toString()});
    }
    if (info == null) {
      try {
        info = await _fetchFromLang(key, 'en');
      } catch (e) {
        AppLogger.warn('获取歌手英文简介失败',
            data: {'artist': key, 'error': e.toString()});
      }
    }
    _cache[key] = info;
    return info;
  }

  /// 从指定语言 Wikipedia 获取简介
  Future<ArtistInfo?> _fetchFromLang(String artistName, String lang) async {
    final encoded = Uri.encodeComponent(artistName);
    final url = Uri.parse(
        'https://$lang.wikipedia.org/api/rest_v1/page/summary/$encoded');
    final resp = await _client
        .get(url, headers: const {'User-Agent': 'EmbyTok-Flutter/1.0'})
        .timeout(_timeout);
    if (resp.statusCode != 200) return null;
    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    // 重定向到别的条目（如消歧义页）时无 extract
    final extract = json['extract'] as String?;
    if (extract == null || extract.trim().isEmpty) return null;
    // 截断过长的简介（UI 展示 3 行以内）
    final bio = extract.trim().length > 200
        ? '${extract.trim().substring(0, 200)}…'
        : extract.trim();
    final thumb = json['thumbnail'] as Map<String, dynamic>?;
    return ArtistInfo(
      bio: bio,
      thumbnailUrl: thumb?['source'] as String?,
    );
  }

  void dispose() {
    _client.close();
  }
}
