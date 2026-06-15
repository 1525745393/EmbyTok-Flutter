// 观看历史：本地持久化，保留最近播放的条目

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../utils/constants.dart';

// 观看历史状态
class WatchHistoryState {
  final List<WatchHistoryItem> items;
  final bool isLoading;
  final String? error;

  const WatchHistoryState({
    this.items = const <WatchHistoryItem>[],
    this.isLoading = false,
    this.error,
  });

  WatchHistoryState copyWith({
    List<WatchHistoryItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return WatchHistoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// 观看历史 Notifier
class WatchHistoryNotifier extends StateNotifier<WatchHistoryState> {
  WatchHistoryNotifier() : super(const WatchHistoryState()) {
    load();
  }

  // 从本地存储加载
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kStorageKeyHistory);
      if (raw == null || raw.isEmpty) {
        state = const WatchHistoryState();
        return;
      }
      final list = json.decode(raw) as List<dynamic>;
      final items = list
          .map((e) =>
              WatchHistoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
      state = WatchHistoryState(items: items);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '加载观看历史失败',
      );
    }
  }

  // 新增 / 更新一条观看记录
  Future<void> upsert({
    required String itemId,
    required String itemTitle,
    String? thumbnailUrl,
    required int progressSeconds,
    required int totalSeconds,
  }) async {
    final now = DateTime.now();
    final newItem = WatchHistoryItem(
      itemId: itemId,
      itemTitle: itemTitle,
      thumbnailUrl: thumbnailUrl,
      watchedAt: now,
      progressSeconds: progressSeconds,
      totalSeconds: totalSeconds,
    );

    final list = List<WatchHistoryItem>.from(state.items)
      ..removeWhere((e) => e.itemId == itemId)
      ..insert(0, newItem);

    // 只保留最近 100 条
    if (list.length > 100) list.length = 100;

    state = state.copyWith(items: list);
    await _persist(list);
  }

  // 清除全部历史
  Future<void> clear() async {
    state = const WatchHistoryState();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kStorageKeyHistory);
    } catch (_) {}
  }

  Future<void> _persist(List<WatchHistoryItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = items.map((e) => e.toJson()).toList();
      await prefs.setString(kStorageKeyHistory, json.encode(data));
    } catch (_) {}
  }
}

// 顶层 Provider
final watchHistoryProvider = StateNotifierProvider<WatchHistoryNotifier,
    WatchHistoryState>((ref) => WatchHistoryNotifier());
