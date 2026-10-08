
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show Color;

import '../utils/logger.dart';

/// 弹弹Play（dandanplay）弹幕源 API
///
/// 文档：https://api.dandanplay.net/
/// 流程：
/// 1. 根据影片名搜索 anime ID
/// 2. 根据 anime ID 获取 episode 列表
/// 3. 根据 episode ID 获取弹幕
class DandanplayApi {
  static const String _base = 'https://api.dandanplay.net';
  final Dio _dio = Dio(BaseOptions(
    baseUrl: _base,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    headers: {
      'Accept': 'application/json',
      'User-Agent': 'EmbyTok/1.0',
    },
  ));

  /// 根据影片名搜索，返回 episodeId 列表
  Future<int?> searchEpisodeId(String animeName) async {
    try {
      final resp = await _dio.get('/v2/search/episodes', queryParameters: {
        'anime': animeName,
      });
      final list = resp.data['animes'] as List?;
      if (list == null || list.isEmpty) return null;
      final first = list.first as Map<String, dynamic>;
      final episodes = first['episodes'] as List?;
      if (episodes == null || episodes.isEmpty) return null;
      return episodes.first['episodeId'] as int?;
    } catch (e) {
      AppLogger.warn('dandanplay 搜索失败', data: {'error': e.toString()});
      return null;
    }
  }

  /// 获取弹幕列表
  Future<List<DanmakuEntry>> fetchComments(int episodeId) async {
    try {
      final resp = await _dio.get('/v2/comment/$episodeId');
      final comments = resp.data['comments'] as List?;
      if (comments == null) return [];
      return comments.map((c) {
        final parts = (c as String).split(',');
        // 格式："time,type,color,uid"
        final time = double.tryParse(parts[0]) ?? 0;
        final type = int.tryParse(parts[1]) ?? 0; // 0滚动 1顶端 2底端
        final color = int.tryParse(parts[2]) ?? 0xFFFFFF;
        final text = parts.length > 3 ? parts.sublist(3).join(',') : '';
        return DanmakuEntry(
          timeMs: (time * 1000).round(),
          text: text,
          color: Color(color | 0xFF000000),
          type: type,
        );
      }).toList();
    } catch (e) {
      AppLogger.warn('dandanplay 获取弹幕失败', data: {'error': e.toString()});
      return [];
    }
  }
}

/// 弹幕条目（从 API 解析后）
class DanmakuEntry { // 0滚动 1顶端 2底端

  const DanmakuEntry({
    required this.timeMs,
    required this.text,
    required this.color,
    required this.type,
  });
  final int timeMs;
  final String text;
  final Color color;
  final int type;
}
