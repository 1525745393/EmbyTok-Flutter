// 观看历史记录 Provider：使用 Map 结构存储，支持持久化

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 观看历史条目：记录单个媒体的观看进度
class WatchHistoryEntry {
  final String itemId;
  final int position; // 当前播放位置（秒）
  final int duration; // 视频总时长（秒）
  final DateTime lastWatchedAt; // 最后观看时间
  final String? itemTitle; // 媒体标题（用于历史列表显示）
  final String? thumbnailUrl; // 缩略图 URL（用于历史列表显示）

  const WatchHistoryEntry({
    required this.itemId,
    required this.position,
    required this.duration,
    required this.lastWatchedAt,
    this.itemTitle,
    this.thumbnailUrl,
  });

  /// 从 JSON 反序列化
  factory WatchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return WatchHistoryEntry(
      itemId: json['itemId'] as String? ?? '',
      position: json['position'] as int? ?? 0,
      duration: json['duration'] as int? ?? 0,
      lastWatchedAt: json['lastWatchedAt'] == null
          ? DateTime.now()
          : DateTime.parse(json['lastWatchedAt'] as String),
      itemTitle: json['itemTitle'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'position': position,
        'duration': duration,
        'lastWatchedAt': lastWatchedAt.toIso8601String(),
        'itemTitle': itemTitle,
        'thumbnailUrl': thumbnailUrl,
      };

  /// 复制并更新部分字段
  WatchHistoryEntry copyWith({
    String? itemId,
    int? position,
    int? duration,
    DateTime? lastWatchedAt,
    String? itemTitle,
    String? thumbnailUrl,
  }) {
    return WatchHistoryEntry(
      itemId: itemId ?? this.itemId,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      itemTitle: itemTitle ?? this.itemTitle,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }
}

/// 观看历史状态：使用 Map 存储，key 为 itemId
class WatchHistoryState {
  final Map<String, WatchHistoryEntry> history;
  final bool isLoading;
  final String? error;

  const WatchHistoryState({
    this.history = const {},
    this.isLoading = false,
    this.error,
  });

  WatchHistoryState copyWith({
    Map<String, WatchHistoryEntry>? history,
    bool? isLoading,
    String? error,
  }) {
    return WatchHistoryState(
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// 观看历史 Notifier：管理观看进度记录
class WatchHistoryNotifier extends StateNotifier<WatchHistoryState> {
  static const String _storageKey = 'watch_history';

  WatchHistoryNotifier() : super(const WatchHistoryState()) {
    loadFromStorage();
  }

  /// 从本地存储加载历史记录
  Future<void> loadFromStorage() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        state = const WatchHistoryState(isLoading: false);
        return;
      }

      final map = json.decode(raw) as Map<String, dynamic>;
      final history = <String, WatchHistoryEntry>{};
      map.forEach((key, value) {
        history[key] = WatchHistoryEntry.fromJson(
          Map<String, dynamic>.from(value as Map),
        );
      });

      state = WatchHistoryState(history: history, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '加载观看历史失败: $e',
      );
    }
  }

  /// 记录观看进度
  /// [itemId] 媒体项 ID
  /// [position] 当前播放位置（秒）
  /// [duration] 视频总时长（秒）
  /// [itemTitle] 媒体标题（可选，用于历史列表显示）
  /// [thumbnailUrl] 缩略图 URL（可选，用于历史列表显示）
  Future<void> recordProgress(
    String itemId,
    int position,
    int duration, {
    String? itemTitle,
    String? thumbnailUrl,
  }) async {
    // 获取现有记录的标题和缩略图，如果新参数为空则保留旧值
    final existing = state.history[itemId];

    final entry = WatchHistoryEntry(
      itemId: itemId,
      position: position,
      duration: duration,
      lastWatchedAt: DateTime.now(),
      itemTitle: itemTitle ?? existing?.itemTitle,
      thumbnailUrl: thumbnailUrl ?? existing?.thumbnailUrl,
    );

    final newHistory = Map<String, WatchHistoryEntry>.from(state.history);
    newHistory[itemId] = entry;

    state = state.copyWith(history: newHistory);
    await _saveToStorage(newHistory);
  }

  /// 获取指定媒体的观看进度
  /// 返回 null 表示没有记录
  WatchHistoryEntry? getProgress(String itemId) {
    return state.history[itemId];
  }

  /// 获取按时间排序的历史列表（最新的在前）
  List<WatchHistoryEntry> getSortedList() {
    final entries = state.history.values.toList();
    entries.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
    return entries;
  }

  /// 清空所有观看历史
  Future<void> clearHistory() async {
    state = const WatchHistoryState();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {
      // 忽略删除失败
    }
  }

  /// 保存到本地存储
  Future<void> _saveToStorage(Map<String, WatchHistoryEntry> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = history.map((key, value) => MapEntry(key, value.toJson()));
      await prefs.setString(_storageKey, json.encode(data));
    } catch (_) {
      // 忽略保存失败
    }
  }
}

/// 顶层 Provider
final watchHistoryProvider = StateNotifierProvider<WatchHistoryNotifier,
    WatchHistoryState>((ref) => WatchHistoryNotifier());
