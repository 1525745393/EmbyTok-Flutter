import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/file_source.dart';

/// 文件源列表状态（P0 第二批）
///
/// 持久化到 SharedPreferences，启动时恢复。
/// 默认包含一个"手机媒体库"本地源，不可删除。
///
/// batch48-F1：SMB/WebDAV 密码不随列表 JSON 明文落 SharedPreferences，
/// 单独存 FlutterSecureStorage（key 见 [_pwdKey]），列表中 config 剥离 password；
/// 加载时按源 id 从安全存储恢复，旧版明文一次性迁移删除。
class FileSourcesNotifier extends StateNotifier<List<FileSource>> {
  FileSourcesNotifier() : super([]) {
    _load();
  }

  static const _key = 'file_sources_v1';

  /// 密码映射（源 id → 密码）在安全存储中的 key
  static const _pwdKey = 'file_sources_pwd_v1';

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
    // batch48-F1：从安全存储按源 id 恢复密码；检测到旧明文（SharedPreferences
    // 列表里仍含 password 且安全存储无对应值）时触发一次性迁移重存剥离版
    final pwdMap = await _readPwdMap();
    var hasLegacy = false;
    final restored = list.map((s) {
      final cfg = Map<String, String>.from(s.config);
      final legacyPwd = cfg['password'];
      if (legacyPwd != null && legacyPwd.isNotEmpty) {
        if (pwdMap[s.id] == null) hasLegacy = true;
        final pwd = pwdMap[s.id] ?? legacyPwd;
        if (pwd.isNotEmpty) {
          cfg['password'] = pwd;
        } else {
          cfg.remove('password');
        }
      } else {
        final pwd = pwdMap[s.id];
        if (pwd != null && pwd.isNotEmpty) {
          cfg['password'] = pwd;
        }
      }
      return s.copyWith(config: cfg);
    }).toList();
    state = restored;
    if (hasLegacy) {
      await _save();
    }
  }

  Future<void> _save() async {
    // batch48-F1：密码剥离出 SharedPreferences，改存安全存储，避免 NAS 凭据明文落盘
    final pwdMap = <String, String>{};
    final redacted = state.map((s) {
      final cfg = Map<String, String>.from(s.config);
      final pwd = cfg['password'];
      if (pwd != null && pwd.isNotEmpty) {
        pwdMap[s.id] = pwd;
      }
      cfg.remove('password');
      return s.copyWith(config: cfg);
    }).toList();
    const ss = FlutterSecureStorage();
    await ss.write(key: _pwdKey, value: json.encode(pwdMap));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(redacted.map((e) => e.toJson()).toList()));
  }

  /// 读取安全存储中的密码映射（源 id → 密码）
  Future<Map<String, String>> _readPwdMap() async {
    const ss = FlutterSecureStorage();
    try {
      final raw = await ss.read(key: _pwdKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      return {};
    }
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

  /// 切换启用/禁用（P0 增强）：禁用后媒体库隐藏该源影片
  Future<void> toggleEnabled(String id) async {
    state = [
      for (final s in state)
        if (s.id == id) s.copyWith(enabled: !s.enabled) else s,
    ];
    await _save();
  }

  /// 更新扫描状态（P0 增强）
  Future<void> updateScanStatus(String id, FileSourceStatus status, {int? videoCount}) async {
    state = [
      for (final s in state)
        if (s.id == id)
          s.copyWith(
            status: status,
            videoCount: videoCount ?? s.videoCount,
            lastScanAt: status == FileSourceStatus.connected ? DateTime.now() : s.lastScanAt,
          )
        else
          s,
    ];
    await _save();
  }
}

final fileSourcesProvider =
    StateNotifierProvider<FileSourcesNotifier, List<FileSource>>(
  (_) => FileSourcesNotifier(),
);
