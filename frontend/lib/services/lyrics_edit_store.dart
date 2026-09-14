// 本地歌词编辑存储（PRD #22）
//
// 用户手动编辑/粘贴的 LRC 歌词按歌曲 id 存 SharedPreferences，
// 优先级最高（NAS LRC / LRCLIB 之前）。

import 'package:shared_preferences/shared_preferences.dart';

class LyricsEditStore {
  static const _prefix = 'syno_lyrics_edited_';

  String _key(String songId) => '$_prefix$songId';

  /// 读用户编辑过的歌词；无则 null
  Future<String?> read(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key(songId));
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  /// 保存用户编辑的歌词（空字符串视为清除）
  Future<void> save(String songId, String text) async {
    final prefs = await SharedPreferences.getInstance();
    if (text.trim().isEmpty) {
      await prefs.remove(_key(songId));
    } else {
      await prefs.setString(_key(songId), text);
    }
  }

  /// 清除某首歌的编辑歌词
  Future<void> clear(String songId) async {
    await save(songId, '');
  }
}

final lyricsEditStore = LyricsEditStore();
