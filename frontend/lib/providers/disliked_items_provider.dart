import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用户主动标记"不感兴趣"的 itemId 集合（本地持久化）
///
/// 与 recommend_signals 的系统推断黑名单（低完播率）不同：
/// 本集合来自用户显式负反馈（信息弹层"不感兴趣"按钮），
/// 推荐过滤时与系统黑名单合并生效，收藏项豁免。
class DislikedItemsNotifier extends StateNotifier<Set<String>> {
  DislikedItemsNotifier() : super(const <String>{});

  static const String _prefsKey = 'disliked_item_ids';
  bool _loaded = false;

  /// 从本地存储恢复（幂等，仅首次生效）
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List).cast<String>();
        state = list.toSet();
      } catch (_) {
        // 损坏数据：丢弃并以空集继续
        state = const <String>{};
      }
    }
    _loaded = true;
  }

  bool isDisliked(String itemId) => state.contains(itemId);

  Future<void> dislike(String itemId) async {
    if (itemId.isEmpty || state.contains(itemId)) return;
    state = {...state, itemId};
    await _persist();
  }

  Future<void> removeDislike(String itemId) async {
    if (!state.contains(itemId)) return;
    state = {...state}..remove(itemId);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.toList()));
  }
}

/// 用户显式不感兴趣集合
///
/// 启动时异步恢复；恢复完成前过滤可能短暂读空集，
/// 由 UI 在 dislike 后主动 refresh 推荐流补齐。
final dislikedItemsProvider =
    StateNotifierProvider<DislikedItemsNotifier, Set<String>>((ref) {
  final notifier = DislikedItemsNotifier();
  // 延迟加载，避免启动路径阻塞
  Future.microtask(notifier.load);
  return notifier;
});
