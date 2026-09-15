// 播放页位置记忆读取（与 PlaybackShell 共用同一份存储）
//
// 结构：{ source: { 列表首itemId: { "idx": 索引, "last": 上次视频id } } }
// 关注页/发现页在网格中标记「上次看到」的视频，点击后由
// PlaybackShell._restoreFromMemory 恢复到上次位置。

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';
import 'logger.dart';

class PlaybackPositionMemory {
  const PlaybackPositionMemory._();

  /// 读取某数据源 + 列表（以首 item id 为签名）中上次观看的视频 id
  ///
  /// 返回 null 表示该列表没有位置记录。
  static Future<String?> lastWatchedItemId({
    required String source,
    required String listSignature,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kStorageKeyPlaybackShellPosition);
      if (raw == null || raw.isEmpty) return null;
      final root = jsonDecode(raw);
      if (root is! Map<String, dynamic>) return null;
      final bySource = root[source];
      if (bySource is! Map<String, dynamic>) return null;
      final entry = bySource[listSignature];
      if (entry is! Map<String, dynamic>) return null;
      final last = entry['last'];
      return last is String && last.isNotEmpty ? last : null;
    } catch (e) {
      AppLogger.error('读取播放位置记忆失败', error: e);
      return null;
    }
  }
}
