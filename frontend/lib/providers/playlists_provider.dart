// 本地歌单管理（PRD #21）V1
//
// 纯本地歌单（SharedPreferences，按账号分桶）：
// - 歌单 CRUD（新建/重命名/删除）
// - 歌单详情：加歌/删歌/清空/播放全部
// - 后续可对接 NAS AudioStation Playlist API 做服务端同步

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/audio_models.dart';
import 'syno_accounts_provider.dart' show accountScopedKey;

/// 一个本地歌单
class LocalPlaylist {
  const LocalPlaylist({
    required this.id,
    required this.name,
    required this.createdAtMs,
    required this.songs,
  });

  factory LocalPlaylist.fromJson(Map<String, dynamic> j) => LocalPlaylist(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        createdAtMs: (j['createdAtMs'] as num?)?.toInt() ?? 0,
        songs: (j['songs'] as List<dynamic>? ?? [])
            .map((e) => AudioSong.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String name;
  final int createdAtMs;
  final List<AudioSong> songs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAtMs': createdAtMs,
        'songs': songs.map((s) => s.toJson()).toList(),
      };

  LocalPlaylist copyWith({
    String? name,
    List<AudioSong>? songs,
  }) =>
      LocalPlaylist(
        id: id,
        name: name ?? this.name,
        createdAtMs: createdAtMs,
        songs: songs ?? this.songs,
      );
}

class PlaylistsNotifier extends StateNotifier<List<LocalPlaylist>> {
  PlaylistsNotifier() : super(const []) {
    _load();
  }

  static const _kKey = 'syno_local_playlists_v1';

  Future<String> get _scopedKey async => accountScopedKey(_kKey);

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _scopedKey;
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
      state = list
          .map((e) => LocalPlaylist.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      state = const [];
    }
  }

  /// 切换账号后重新加载
  Future<void> reload() async {
    state = const [];
    await _load();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _scopedKey;
      await prefs.setString(
          key, jsonEncode(state.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  /// 新建歌单，返回新建的歌单
  Future<LocalPlaylist> create(String name) async {
    final pl = LocalPlaylist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? '未命名歌单' : name.trim(),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      songs: const [],
    );
    state = [...state, pl];
    await _persist();
    return pl;
  }

  Future<void> rename(String id, String name) async {
    state = state
        .map((p) => p.id == id ? p.copyWith(name: name.trim()) : p)
        .toList();
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _persist();
  }

  /// 向歌单加歌（按 song.id 去重）
  Future<void> addSong(String playlistId, AudioSong song) async {
    state = state.map((p) {
      if (p.id != playlistId) return p;
      if (p.songs.any((s) => s.id == song.id)) return p;
      return p.copyWith(songs: [...p.songs, song]);
    }).toList();
    await _persist();
  }

  Future<void> removeSong(String playlistId, String songId) async {
    state = state.map((p) {
      if (p.id != playlistId) return p;
      return p.copyWith(
          songs: p.songs.where((s) => s.id != songId).toList());
    }).toList();
    await _persist();
  }

  Future<void> clearSongs(String playlistId) async {
    state = state
        .map((p) => p.id == playlistId ? p.copyWith(songs: const []) : p)
        .toList();
    await _persist();
  }
}

final playlistsProvider =
    StateNotifierProvider<PlaylistsNotifier, List<LocalPlaylist>>(
        (ref) => PlaylistsNotifier());
