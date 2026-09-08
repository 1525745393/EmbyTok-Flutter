// 最近播放记录（客户端本地持久化，PRD 首页核心模块）
//
// Audio Station 无服务端播放历史接口，播放记录必须客户端本地存储。
// 存储字段：mediaId、mediaType（song/album/playlist）、title、subtitle、
// coverUrl、lastPlayTime（毫秒时间戳）。最多保留 8 条，按最后播放时间倒序。
//
// 播放新内容时调用 add()，已存在则更新时间；超过 8 条淘汰最旧记录。
// 无记录时首页整个模块隐藏（不显示空状态）。

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kStorageKey = 'recent_playbacks_v1';
const int _kMaxRecords = 8;

/// 播放记录类型
enum RecentPlaybackType { song, album, playlist }

/// 单条最近播放记录
class RecentPlayback {
  final String mediaId;
  final RecentPlaybackType mediaType;
  final String title;
  final String subtitle;
  final String? coverUrl;
  final int lastPlayTime; // 毫秒时间戳

  const RecentPlayback({
    required this.mediaId,
    required this.mediaType,
    required this.title,
    this.subtitle = '',
    this.coverUrl,
    required this.lastPlayTime,
  });

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'mediaType': mediaType.name,
        'title': title,
        'subtitle': subtitle,
        'coverUrl': coverUrl,
        'lastPlayTime': lastPlayTime,
      };

  factory RecentPlayback.fromJson(Map<String, dynamic> json) {
    return RecentPlayback(
      mediaId: json['mediaId'] as String? ?? '',
      mediaType: RecentPlaybackType.values.firstWhere(
        (e) => e.name == json['mediaType'],
        orElse: () => RecentPlaybackType.song,
      ),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      lastPlayTime: (json['lastPlayTime'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 最近播放记录 Provider
final recentPlaybacksProvider =
    StateNotifierProvider<RecentPlaybacksNotifier, List<RecentPlayback>>(
  (ref) => RecentPlaybacksNotifier(),
);

class RecentPlaybacksNotifier extends StateNotifier<List<RecentPlayback>> {
  RecentPlaybacksNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStorageKey);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
      state = list
          .map((e) => RecentPlayback.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // 存储损坏时清空，不影响主流程
      state = const [];
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStorageKey, jsonEncode(state));
    } catch (_) {}
  }

  /// 添加或更新一条播放记录（已存在则更新时间，移到最前）
  Future<void> add(RecentPlayback record) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = RecentPlayback(
      mediaId: record.mediaId,
      mediaType: record.mediaType,
      title: record.title,
      subtitle: record.subtitle,
      coverUrl: record.coverUrl,
      lastPlayTime: now,
    );

    // 移除已存在的同 mediaId 记录
    final filtered = state
        .where((e) =>
            !(e.mediaId == updated.mediaId && e.mediaType == updated.mediaType))
        .toList();

    // 新记录插到最前，超过上限淘汰最旧
    final next = [updated, ...filtered].take(_kMaxRecords).toList();
    state = next;
    await _persist();
  }

  /// 移除一条记录（长按菜单「移除该记录」）
  Future<void> remove(String mediaId, RecentPlaybackType mediaType) async {
    state = state
        .where((e) => !(e.mediaId == mediaId && e.mediaType == mediaType))
        .toList();
    await _persist();
  }

  /// 清空全部记录
  Future<void> clear() async {
    state = const [];
    await _persist();
  }
}
