// 播放事件流（客户端本地持久化，供播放统计聚合）
//
// Audio Station 无服务端播放历史接口。每次成功开始播放一首歌，
// 追加一条 PlayEvent（songId/title/artist/album/时长/时间戳）。
// 最多保留 5000 条，超出淘汰最旧。统计页据此聚合。

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'syno_accounts_provider.dart';

const String _kStorageKey = 'play_events_v1';
const int _kMaxRecords = 5000;

/// 单条播放事件
class PlayEvent {
  const PlayEvent({
    required this.songId,
    required this.title,
    this.artist = '',
    this.album = '',
    this.durationSeconds = 0,
    required this.playedAtMs,
  });

  factory PlayEvent.fromJson(Map<String, dynamic> j) => PlayEvent(
        songId: j['songId'] as String? ?? '',
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? '',
        album: j['album'] as String? ?? '',
        durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? 0,
        playedAtMs: (j['playedAtMs'] as num?)?.toInt() ?? 0,
      );

  final String songId;
  final String title;
  final String artist;
  final String album;
  final int durationSeconds;
  final int playedAtMs;

  Map<String, dynamic> toJson() => {
        'songId': songId,
        'title': title,
        'artist': artist,
        'album': album,
        'durationSeconds': durationSeconds,
        'playedAtMs': playedAtMs,
      };
}

final playEventsProvider =
    StateNotifierProvider<PlayEventsNotifier, List<PlayEvent>>(
  (ref) => PlayEventsNotifier(),
);

class PlayEventsNotifier extends StateNotifier<List<PlayEvent>> {
  PlayEventsNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await accountScopedKey(_kStorageKey);
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
      state = list
          .map((e) => PlayEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      state = const [];
    }
  }

  /// 切换账号后重新加载该账号的播放事件
  Future<void> reload() async {
    state = const [];
    await _load();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await accountScopedKey(_kStorageKey);
      await prefs.setString(
        key,
        jsonEncode(state.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  /// 记录一次播放
  Future<void> add(PlayEvent event) async {
    state = [event, ...state].take(_kMaxRecords).toList();
    await _persist();
  }

  /// 清空全部统计数据
  Future<void> clear() async {
    state = const [];
    await _persist();
  }
}
