import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/file_source.dart';

/// 文件源列表状态（P0 第二批）
///
/// 持久化到 SharedPreferences，启动时恢复。
/// 默认包含一个"手机媒体库"本地源，不可删除。
class FileSourcesNotifier extends StateNotifier<List<FileSource>> {
  FileSourcesNotifier() : super([]) {
    _load();
  }

  static const _key = 'file_sources_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      // 默认本地源
      state = [
        const FileSource(
          id: 'local_default',
          type: FileSourceType.local,
          name: '手机媒体库',
        ),
      ];
      return;
    }
    final list = (json.decode(raw) as List)
        .map((e) => FileSource.fromJson(e as Map<String, dynamic>))
        .toList();
    // 确保默认本地源存在
    if (!list.any((e) => e.id == 'local_default')) {
      list.insert(
        0,
        const FileSource(
          id: 'local_default',
          type: FileSourceType.local,
          name: '手机媒体库',
        ),
      );
    }
    state = list;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(state.map((e) => e.toJson()).toList()));
  }

  Future<void> add(FileSource source) async {
    state = [...state, source];
    await _save();
  }

  Future<void> update(FileSource source) async {
    state = [
      for (final s in state) if (s.id == source.id) source else s,
    ];
    await _save();
  }

  Future<void> remove(String id) async {
    if (id == 'local_default') return; // 默认本地源不可删
    state = state.where((s) => s.id != id).toList();
    await _save();
  }
}

final fileSourcesProvider =
    StateNotifierProvider<FileSourcesNotifier, List<FileSource>>(
  (_) => FileSourcesNotifier(),
);
