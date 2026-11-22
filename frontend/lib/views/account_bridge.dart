// 群晖双存储桥接同步（注册表 ↔ 群晖账号列表）
//
// 背景：群晖账号此前分别写在 serverRegistryProvider（注册表/快速切换）与
// synoAccountsProvider（账号切换 sheet）两套存储，三条保存链路各写一边，
// 列表与凭据互相不可见。本文件提供最小桥接：任一侧写入/删除时按统一的
// host+端口端点口径同步另一侧；单侧写入失败只记日志，不阻断主流程。
// 注意：本轮不收敛为单一事实源（另立专项），两套 Provider 结构保持不变。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/server_registry_provider.dart';
import '../providers/syno_accounts_provider.dart';
import '../utils/logger.dart';

/// 从 URL 提取 host 作为默认显示名
String _hostName(String url) {
  try {
    return Uri.parse(url).host;
  } catch (_) {
    return url;
  }
}

/// 注册表群晖条目 → 群晖账号列表同步。
///
/// 非群晖类型直接返回；账号列表已存在同端点+用户名账号时，`addAccount`
/// 会更新其密码。`password` 为 null/空表示未记住密码，不写入凭据。
Future<void> bridgeRegistryToAccounts(
  WidgetRef ref,
  ServerProfile profile,
  String? password,
) async {
  if (profile.kind != ServerKind.synology) return;
  try {
    await ref.read(synoAccountsProvider.notifier).addAccount(
          serverUrl: profile.url,
          username: profile.username,
          password: password ?? '',
        );
  } catch (e) {
    AppLogger.warn('注册表同步群晖账号列表失败', data: {'error': e.toString()});
  }
}

/// 群晖账号 → 注册表同步。
///
/// 按 kind=群晖 + 用户名 + host+端口匹配现有注册表条目：命中则更新，否则新增。
Future<void> bridgeAccountToRegistry(
  WidgetRef ref, {
  required String serverUrl,
  required String username,
  String? password,
}) async {
  final registry = ref.read(serverRegistryProvider.notifier);
  final servers = ref.read(serverRegistryProvider);
  ServerProfile? existing;
  for (final s in servers) {
    if (s.kind == ServerKind.synology &&
        s.username == username &&
        sameEndpoint(s.url, serverUrl)) {
      existing = s;
      break;
    }
  }
  final profile = ServerProfile(
    id: existing?.id ?? 'srv_${DateTime.now().microsecondsSinceEpoch}',
    kind: ServerKind.synology,
    name: existing?.name ?? _hostName(serverUrl),
    url: serverUrl,
    internalUrl: existing?.internalUrl,
    externalUrl: existing?.externalUrl,
    username: username,
    networkMode: existing?.networkMode ?? NetworkMode.auto,
    isDefault: existing?.isDefault ?? servers.isEmpty,
    lastUsed: DateTime.now(),
    libraryIds: existing?.libraryIds ?? const <String>[],
  );
  try {
    if (existing != null) {
      await registry.update(profile, password: password);
    } else {
      await registry.add(profile, password: password);
    }
  } catch (e) {
    AppLogger.warn('群晖账号同步服务器注册表失败', data: {'error': e.toString()});
  }
}

/// 删除注册表群晖条目时，同步删除账号列表中同端点+用户名的账号。
Future<void> bridgeRemoveRegistryToAccounts(
  WidgetRef ref,
  ServerProfile profile,
) async {
  if (profile.kind != ServerKind.synology) return;
  final accounts = ref.read(synoAccountsProvider);
  for (final a in accounts.accounts) {
    if (a.username == profile.username &&
        sameEndpoint(a.serverUrl, profile.url)) {
      try {
        await ref
            .read(synoAccountsProvider.notifier)
            .remove(a.accountId, bypassGuard: true);
      } catch (e) {
        AppLogger.warn('注册表删除联动群晖账号失败', data: {'error': e.toString()});
      }
      return;
    }
  }
}

/// 删除群晖账号时，同步删除注册表中同端点+用户名的群晖条目。
Future<void> bridgeRemoveAccountToRegistry(
  WidgetRef ref,
  SynoAccount account,
) async {
  final servers = ref.read(serverRegistryProvider);
  for (final s in servers) {
    if (s.kind == ServerKind.synology &&
        s.username == account.username &&
        sameEndpoint(s.url, account.serverUrl)) {
      try {
        await ref.read(serverRegistryProvider.notifier).remove(s.id);
      } catch (e) {
        AppLogger.warn('账号删除联动注册表失败', data: {'error': e.toString()});
      }
      return;
    }
  }
}
