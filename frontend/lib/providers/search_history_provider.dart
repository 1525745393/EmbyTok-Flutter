/// 搜索历史 Provider：本地持久化最近 10 条搜索关键词

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// 搜索历史 Notifier：自动持久化到 SharedPreferences
class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kStorageKeySearchHistory);
      if (raw == null || raw.isEmpty) {
        state = const [];
        return;
      }
      final list = (json.decode(raw) as List<dynamic>).cast<String>();
      state = list;
    } catch (_) {
      state = const [];
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kStorageKeySearchHistory, json.encode(state));
    } catch (_) {}
  }

  /// 添加一条搜索关键词（若已存在则移到最前）
  void add(String keyword) {
    final clean = keyword.trim();
    if (clean.isEmpty) return;
    final list = List<String>.from(state)
      ..removeWhere((s) => s == clean)
      ..insert(0, clean);
    if (list.length > kMaxSearchHistory) list.length = kMaxSearchHistory;
    state = list;
    _persist();
  }

  /// 删除一条搜索关键词
  void remove(String keyword) {
    final list = List<String>.from(state)..remove(keyword);
    state = list;
    _persist();
  }

  /// 清空所有搜索历史
  void clear() {
    state = const [];
    _persist();
  }
}

/// 顶层搜索历史 Provider
final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>(
        (ref) => SearchHistoryNotifier());
