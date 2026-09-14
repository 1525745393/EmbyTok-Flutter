// 群晖多账号管理（PRD #30）
//
// 同一台 NAS 可保存多个账号（username/password），快速切换。
// - 账号列表持久化到 SharedPreferences（元数据）
// - 密码 / sid 存安全存储（FlutterSecureStorage）
// - 切换账号：用新账号凭证 login 拿 sid → restoreSession → 重载音乐库
// - 默认账号：启动时自动登录

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';
import 'auth_provider.dart' show secureStorageProvider;

/// 一个已保存的群晖账号
class SynoAccount {
  const SynoAccount({
    required this.accountId,
    required this.serverUrl,
    required this.username,
    this.isDefault = false,
    this.lastUsedAtMs = 0,
  });

  factory SynoAccount.fromJson(Map<String, dynamic> j) => SynoAccount(
        accountId: j['accountId'] as String? ?? '',
        serverUrl: j['serverUrl'] as String? ?? '',
        username: j['username'] as String? ?? '',
        isDefault: j['isDefault'] as bool? ?? false,
        lastUsedAtMs: (j['lastUsedAtMs'] as num?)?.toInt() ?? 0,
      );

  final String accountId;
  final String serverUrl;
  final String username;
  final bool isDefault;
  final int lastUsedAtMs;

  Map<String, dynamic> toJson() => {
        'accountId': accountId,
        'serverUrl': serverUrl,
        'username': username,
        'isDefault': isDefault,
        'lastUsedAtMs': lastUsedAtMs,
      };

  SynoAccount copyWith({bool? isDefault, int? lastUsedAtMs}) => SynoAccount(
        accountId: accountId,
        serverUrl: serverUrl,
        username: username,
        isDefault: isDefault ?? this.isDefault,
        lastUsedAtMs: lastUsedAtMs ?? this.lastUsedAtMs,
      );
}

class SynoAccountsState {
  const SynoAccountsState({
    this.accounts = const [],
    this.currentAccountId,
  });
  final List<SynoAccount> accounts;
  final String? currentAccountId;

  SynoAccount? get current {
    for (final a in accounts) {
      if (a.accountId == currentAccountId) return a;
    }
    return null;
  }
}

const _kListKey = 'syno_accounts_v1';
const _kCurrentKey = 'syno_account_current_v1';

class SynoAccountsNotifier extends StateNotifier<SynoAccountsState> {
  SynoAccountsNotifier(this._ref) : super(SynoAccountsState()) {
    _secure = _ref.read(secureStorageProvider);
    _load();
  }
  final Ref _ref;
  late final dynamic _secure;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kListKey);
      final list = raw == null
          ? <SynoAccount>[]
          : (jsonDecode(raw) as List<dynamic>)
              .map((e) => SynoAccount.fromJson(e as Map<String, dynamic>))
              .toList();
      state = SynoAccountsState(
        accounts: list,
        currentAccountId: prefs.getString(_kCurrentKey),
      );
    } catch (_) {
      state = SynoAccountsState();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kListKey, jsonEncode(state.accounts.map((e) => e.toJson()).toList()));
    if (state.currentAccountId == null) {
      await prefs.remove(_kCurrentKey);
    } else {
      await prefs.setString(_kCurrentKey, state.currentAccountId!);
    }
  }

  String _pwdKey(String accountId) => 'syno_pwd_$accountId';

  /// 保存一个新账号（login 成功后调用）
  Future<SynoAccount> addAccount({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final id = '${serverUrl.hashCode}_${username.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
    final account = SynoAccount(
      accountId: id,
      serverUrl: serverUrl,
      username: username,
      lastUsedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    // 密码存安全存储
    try {
      await _secure.write(key: _pwdKey(id), value: password);
    } catch (_) {}
    state = SynoAccountsState(
      accounts: [...state.accounts, account],
      currentAccountId: state.currentAccountId ?? id,
    );
    await _persist();
    AppLogger.info('已保存账号', data: {'user': username});
    return account;
  }

  /// 读取账号密码（安全存储）
  Future<String?> readPassword(String accountId) async {
    try {
      return await _secure.read(key: _pwdKey(accountId));
    } catch (_) {
      return null;
    }
  }

  /// 标记当前账号
  void setCurrent(String accountId) {
    final list = state.accounts
        .map((a) => a.accountId == accountId
            ? a.copyWith(lastUsedAtMs: DateTime.now().millisecondsSinceEpoch)
            : a)
        .toList();
    state = SynoAccountsState(accounts: list, currentAccountId: accountId);
    _persist();
  }

  /// 设为默认
  Future<void> setDefault(String accountId) async {
    final list = state.accounts
        .map((a) => a.copyWith(isDefault: a.accountId == accountId))
        .toList();
    state = SynoAccountsState(accounts: list, currentAccountId: state.currentAccountId);
    await _persist();
  }

  /// 删除账号（不能删当前账号；UI 层保证）
  Future<void> remove(String accountId) async {
    try {
      await _secure.delete(key: _pwdKey(accountId));
    } catch (_) {}
    state = SynoAccountsState(
      accounts: state.accounts.where((a) => a.accountId != accountId).toList(),
      currentAccountId: state.currentAccountId == accountId
          ? null
          : state.currentAccountId,
    );
    await _persist();
  }
}

final synoAccountsProvider =
    StateNotifierProvider<SynoAccountsNotifier, SynoAccountsState>((ref) {
  return SynoAccountsNotifier(ref);
});
