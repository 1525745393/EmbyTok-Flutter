import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地视频评论（v1）
///
/// 说明：Emby / Jellyfin 服务器不提供用户评论 API（已核实），
/// 因此 v1 评论仅保存在本机（SharedPreferences），按 itemId 组织，
/// 不跨设备同步。UI 层需向用户明示此限制。
class VideoComment {
  const VideoComment({
    required this.id,
    required this.itemId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String itemId;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemId': itemId,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  factory VideoComment.fromJson(Map<String, dynamic> json) => VideoComment(
        id: json['id'] as String,
        itemId: json['itemId'] as String,
        text: json['text'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// 视频本地评论状态：itemId -> 评论列表（新评论在前）
class VideoCommentsNotifier
    extends StateNotifier<Map<String, List<VideoComment>>> {
  VideoCommentsNotifier() : super(const <String, List<VideoComment>>{});

  static const String _prefsKey = 'video_local_comments_v1';
  bool _loaded = false;

  /// 从本地存储恢复（幂等，仅首次生效）
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        state = map.map(
          (k, v) => MapEntry(
            k,
            (v as List)
                .map((e) => VideoComment.fromJson(e as Map<String, dynamic>))
                .toList(),
          ),
        );
      } catch (_) {
        // 损坏数据：丢弃并以空表继续
        state = const <String, List<VideoComment>>{};
      }
    }
    _loaded = true;
  }

  List<VideoComment> commentsFor(String itemId) =>
      state[itemId] ?? const <VideoComment>[];

  int countFor(String itemId) => state[itemId]?.length ?? 0;

  Future<void> addComment(String itemId, String text) async {
    final trimmed = text.trim();
    if (itemId.isEmpty || trimmed.isEmpty) return;
    final comment = VideoComment(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      itemId: itemId,
      text: trimmed,
      createdAt: DateTime.now(),
    );
    final existing = state[itemId] ?? const <VideoComment>[];
    state = {...state, itemId: [comment, ...existing]};
    await _persist();
  }

  Future<void> removeComment(String itemId, String commentId) async {
    final list = state[itemId];
    if (list == null || list.isEmpty) return;
    final updated = list.where((c) => c.id != commentId).toList();
    if (updated.length == list.length) return;
    final next = {...state};
    if (updated.isEmpty) {
      next.remove(itemId);
    } else {
      next[itemId] = updated;
    }
    state = next;
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final map = state.map(
      (k, v) => MapEntry(k, v.map((c) => c.toJson()).toList()),
    );
    await prefs.setString(_prefsKey, jsonEncode(map));
  }
}

/// 视频本地评论 provider
final videoCommentsProvider = StateNotifierProvider<
    VideoCommentsNotifier, Map<String, List<VideoComment>>>((ref) {
  final notifier = VideoCommentsNotifier();
  // 延迟加载，避免启动路径阻塞
  Future.microtask(notifier.load);
  return notifier;
});
