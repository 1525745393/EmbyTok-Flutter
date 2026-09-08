// 服务器注册表：多服务器统一管理（Emby / Plex / 群晖 Audio Station）
//
// - ServerProfile：服务器配置（不含密码，密码按 server_password_<id> 存安全存储）
// - ServerRegistryNotifier：列表 CRUD + 激活 + 默认 + 内外网地址
// - 网络模式：auto（内网优先）/ internal / external，resolveUrl() 统一解析
//
// 设计：不重写 authProvider / synologyAuthProvider 的会话逻辑，
// 注册表只负责「配置管理」，激活切换时由调用方用凭据调对应登录。

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';
import 'auth_provider.dart' show secureStorageProvider;

/// 服务器类型（与服务模式正交：服务模式决定首页内容，类型决定登录协议）
enum ServerKind {
  emby('Emby', 'emby'),
  plex('Plex', 'plex'),
  synology('群晖音乐', 'synology');

  const ServerKind(this.label, this.storageValue);

  final String label;
  final String storageValue;

  static ServerKind fromStorage(String? value) {
    return switch (value) {
      'plex' => ServerKind.plex,
      'synology' => ServerKind.synology,
      _ => ServerKind.emby,
    };
  }
}

/// 网络模式：地址选择策略
enum NetworkMode {
  auto('自动', 'auto'),
  internal('内网', 'internal'),
  external('外网', 'external');

  const NetworkMode(this.label, this.storageValue);

  final String label;
  final String storageValue;

  static NetworkMode fromStorage(String? value) {
    return switch (value) {
      'internal' => NetworkMode.internal,
      'external' => NetworkMode.external,
      _ => NetworkMode.auto,
    };
  }
}

/// 服务器配置条目
class ServerProfile {
  final String id;
  final ServerKind kind;

  /// 显示名称（如「家里的 Emby」）
  final String name;

  /// 主地址（必填，也是 auto 模式下内网优先的兜底）
  final String url;

  /// 内网地址（可选，auto 模式优先使用）
  final String? internalUrl;

  /// 外网地址（可选，external 模式使用）
  final String? externalUrl;

  final String username;
  final NetworkMode networkMode;
  final bool isDefault;
  final DateTime lastUsed;

  const ServerProfile({
    required this.id,
    required this.kind,
    required this.name,
    required this.url,
    this.internalUrl,
    this.externalUrl,
    required this.username,
    this.networkMode = NetworkMode.auto,
    this.isDefault = false,
    required this.lastUsed,
  });

  /// 按网络模式解析实际连接地址（auto：内网优先，无内网地址用主地址）
  /// 同时防御性补全 http:// 协议（用户可能只填 IP/主机名）
  String resolveUrl() {
    final raw = switch (networkMode) {
      NetworkMode.internal => (internalUrl?.isNotEmpty ?? false)
          ? internalUrl!
          : url,
      NetworkMode.external => (externalUrl?.isNotEmpty ?? false)
          ? externalUrl!
          : url,
      NetworkMode.auto => (internalUrl?.isNotEmpty ?? false) ? internalUrl! : url,
    };
    return _ensureScheme(raw);
  }

  /// 无协议前缀时补 http://（端口由各 API 层按类型补默认值）
  static String _ensureScheme(String url) {
    final u = url.trim();
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    return 'http://$u';
  }

  ServerProfile copyWith({
    String? name,
    String? url,
    String? internalUrl,
    String? externalUrl,
    String? username,
    NetworkMode? networkMode,
    bool? isDefault,
    DateTime? lastUsed,
  }) {
    return ServerProfile(
      id: id,
      kind: kind,
      name: name ?? this.name,
      url: url ?? this.url,
      internalUrl: internalUrl ?? this.internalUrl,
      externalUrl: externalUrl ?? this.externalUrl,
      username: username ?? this.username,
      networkMode: networkMode ?? this.networkMode,
      isDefault: isDefault ?? this.isDefault,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  // ---- 序列化（密码/sid 不入 JSON） ----

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.storageValue,
        'name': name,
        'url': url,
        'internalUrl': internalUrl,
        'externalUrl': externalUrl,
        'username': username,
        'networkMode': networkMode.storageValue,
        'isDefault': isDefault,
        'lastUsed': lastUsed.toIso8601String(),
      };

  factory ServerProfile.fromJson(Map<String, dynamic> json) {
    return ServerProfile(
      id: json['id'] as String? ?? '',
      kind: ServerKind.fromStorage(json['kind'] as String?),
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      internalUrl: json['internalUrl'] as String?,
      externalUrl: json['externalUrl'] as String?,
      username: json['username'] as String? ?? '',
      networkMode: NetworkMode.fromStorage(json['networkMode'] as String?),
      isDefault: json['isDefault'] as bool? ?? false,
      lastUsed: DateTime.tryParse(json['lastUsed'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// 存储键
const kStorageKeyServerRegistry = 'server_registry_v1';
const kStorageKeyActiveServerId = 'active_server_id';

/// 密码存储 key（安全存储，按服务器 id 隔离）
String serverPasswordKey(String id) => 'server_password_$id';

/// 群晖 sid 存储 key（安全存储，按服务器 id 隔离；替代明文 SharedPreferences）
String serverSynoSidKey(String id) => 'server_syno_sid_$id';

/// 服务器注册表 Provider
final serverRegistryProvider =
    StateNotifierProvider<ServerRegistryNotifier, List<ServerProfile>>(
  (ref) => ServerRegistryNotifier(ref),
);

/// 当前激活的服务器 id（null = 未激活）
final activeServerIdProvider = StateNotifierProvider<ActiveServerNotifier, String?>(
  (ref) => ActiveServerNotifier(),
);

/// 当前激活的服务器配置（watch 注册表 + 激活 id）
final activeServerProvider = Provider<ServerProfile?>((ref) {
  final id = ref.watch(activeServerIdProvider);
  if (id == null) return null;
  final servers = ref.watch(serverRegistryProvider);
  for (final s in servers) {
    if (s.id == id) return s;
  }
  return null;
});

/// 默认服务器（无默认时取第一个）
final defaultServerProvider = Provider<ServerProfile?>((ref) {
  final servers = ref.watch(serverRegistryProvider);
  for (final s in servers) {
    if (s.isDefault) return s;
  }
  return servers.isEmpty ? null : servers.first;
});

class ServerRegistryNotifier extends StateNotifier<List<ServerProfile>> {
  final Ref _ref;
  late final FlutterSecureStorage _secureStorage;

  ServerRegistryNotifier(this._ref) : super(const []) {
    _secureStorage = _ref.read(secureStorageProvider);
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kStorageKeyServerRegistry);
      if (raw == null || raw.isEmpty) return;
      final list = (json.decode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ServerProfile.fromJson)
          .toList();
      state = list;
      AppLogger.info('服务器注册表恢复', data: {'count': list.length});
    } catch (e) {
      AppLogger.error('恢复服务器注册表失败', error: e);
    }
  }

  /// 添加服务器（密码可选：记住密码时写入安全存储）
  Future<void> add(ServerProfile profile, {String? password, String? synoSid}) async {
    final next = [...state, profile];
    state = next;
    await _persist();
    if (password != null && password.isNotEmpty) {
      await _secureStorage.write(
          key: serverPasswordKey(profile.id), value: password);
    }
    if (synoSid != null && synoSid.isNotEmpty) {
      await _secureStorage.write(
          key: serverSynoSidKey(profile.id), value: synoSid);
    }
  }

  /// 更新服务器（密码/sid 可选更新，null 表示不修改）
  Future<void> update(
    ServerProfile updated, {
    String? password,
    bool clearPassword = false,
    String? synoSid,
    bool clearSynoSid = false,
  }) async {
    state = [
      for (final s in state) s.id == updated.id ? updated : s,
    ];
    await _persist();
    if (clearPassword) {
      await _secureStorage.delete(key: serverPasswordKey(updated.id));
    } else if (password != null && password.isNotEmpty) {
      await _secureStorage.write(
          key: serverPasswordKey(updated.id), value: password);
    }
    if (clearSynoSid) {
      await _secureStorage.delete(key: serverSynoSidKey(updated.id));
    } else if (synoSid != null && synoSid.isNotEmpty) {
      await _secureStorage.write(
          key: serverSynoSidKey(updated.id), value: synoSid);
    }
  }

  /// 删除服务器（同时清理密码/sid 与激活状态）
  Future<void> remove(String id) async {
    state = [for (final s in state) if (s.id != id) s];
    await _persist();
    try {
      await _secureStorage.delete(key: serverPasswordKey(id));
      await _secureStorage.delete(key: serverSynoSidKey(id));
    } catch (_) {}
    // 删除激活的服务器时清除激活状态
    if (_ref.read(activeServerIdProvider) == id) {
      _ref.read(activeServerIdProvider.notifier).setActive(null);
    }
  }

  /// 设为默认（唯一）
  Future<void> setDefault(String id) async {
    state = [
      for (final s in state)
        s.id == id ? s.copyWith(isDefault: true) : s.copyWith(isDefault: false),
    ];
    await _persist();
  }

  /// 更新最近使用时间
  Future<void> touch(String id) async {
    state = [
      for (final s in state)
        s.id == id ? s.copyWith(lastUsed: DateTime.now()) : s,
    ];
    await _persist();
  }

  /// 重新从本地存储加载（测试用）
  Future<void> reload() => _loadFromStorage();

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        kStorageKeyServerRegistry,
        json.encode([for (final s in state) s.toJson()]),
      );
    } catch (e) {
      AppLogger.error('保存服务器注册表失败', error: e);
    }
  }
}

/// 激活服务器 id（持久化）
class ActiveServerNotifier extends StateNotifier<String?> {
  ActiveServerNotifier() : super(null) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(kStorageKeyActiveServerId);
      if (id != null && id.isNotEmpty) state = id;
    } catch (_) {}
  }

  /// 重新从本地存储加载（测试用）
  Future<void> reload() => _loadFromStorage();

  Future<void> setActive(String? id) async {
    state = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null) {
        await prefs.remove(kStorageKeyActiveServerId);
      } else {
        await prefs.setString(kStorageKeyActiveServerId, id);
      }
    } catch (_) {}
  }
}
