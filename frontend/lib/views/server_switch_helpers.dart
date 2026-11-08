// 服务器切换公共逻辑（登录页「快速切换」与服务器管理页共用）
//
// P3 修复（登录界面审查 F3/F4/F7）：两处切换实现此前各自演化——sid 有效性校验、
// 跨类型对端会话清理、两步验证（OTP）处理都只在 servers_view 一侧修过，导致
// 登录页快速切换行为不一致（sid 过期假成功、双登录残留、2FA 账号无法切换）。
// 这里把三件事收敛为单点实现，两个调用方只保留各自的激活状态时序：
//   - 登录页：登录成功后才 touch / setActive（失败保持原服务器激活）；
//   - 服务器管理页：进入即 touch / setActive（沿用既有语义）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../providers/auth_provider.dart';
import '../providers/server_registry_provider.dart';
import '../providers/synology_auth_provider.dart';
import '../services/synology_audio_api.dart';
import '../utils/logger.dart';

/// 注册表里没有保存密码时抛出，调用方据此提示「请编辑后重试」
class MissingSavedPasswordException implements Exception {
  const MissingSavedPasswordException();
  @override
  String toString() => '未保存该服务器的密码（或会话已过期），请编辑后重试';
}

/// 读取注册表中已保存的服务器密码（读失败按「没有密码」处理）
Future<String?> readSavedServerPassword(
    FlutterSecureStorage storage, String serverId) async {
  try {
    return await storage.read(key: serverPasswordKey(serverId));
  } catch (e) {
    AppLogger.warn('读取服务器密码失败', data: {'error': e.toString()});
    return null;
  }
}

/// 跨类型切换前清理对端会话，避免双登录残留。
///
/// 切群晖前清 Emby token、切 Emby/Plex 前清群晖 sid；同类型切换不清理
/// （新登录会覆盖旧会话）。
Future<void> purgeCounterpartSession(WidgetRef ref, ServerProfile server) async {
  if (server.kind == ServerKind.synology) {
    if (ref.read(authProvider).isAuthenticated) {
      await ref.read(authProvider.notifier).logout();
    }
  } else {
    if (ref.read(synologyAuthProvider).isLoggedIn) {
      await ref.read(synologyAuthProvider.notifier).logout();
    }
  }
}

/// 请求两步验证码的回调；返回 null / 空串表示用户取消
typedef OtpCodeRequester = Future<String?> Function();

/// 群晖登录：优先用保存的 sid 恢复会话（并做一次轻量校验），
/// sid 无效或未保存时回退密码登录；账号启用 2FA 时经 [requestOtp] 取码重试。
///
/// 成功返回后会把新的 sid 回写注册表，供下次免密恢复。
Future<void> loginSynologyTarget(
  WidgetRef ref,
  ServerProfile server,
  FlutterSecureStorage storage, {
  OtpCodeRequester? requestOtp,
}) async {
  final synoAuth = ref.read(synologyAuthProvider.notifier);
  final registry = ref.read(serverRegistryProvider.notifier);

  String? sid;
  try {
    sid = await storage.read(key: serverSynoSidKey(server.id));
  } catch (e) {
    AppLogger.warn('读取 Synology 会话失败', data: {'error': e.toString()});
  }

  if (sid != null && sid.isNotEmpty) {
    await synoAuth.restoreSession(
      serverUrl: server.resolveUrl(),
      account: server.username,
      sid: sid,
    );
    // 会话恢复是本地乐观置位，不校验 sid 有效性（NAS 重启/会话过期时
    // 会显示「已切换」实际未登录）；用一次轻量 API 调用验证，失败则清除
    // 假登录态并回退密码登录。
    try {
      await synoAuth.api.getGenres();
      return;
    } catch (_) {
      // 失败路径只用 clearInvalidSession()（清状态+持久化，不切服务模式），
      // 不可调 logout()——logout 会清空登录态并 setMode(video)。
      await synoAuth.clearInvalidSession();
    }
  }

  final password = await readSavedServerPassword(storage, server.id);
  if (password == null || password.isEmpty) {
    throw const MissingSavedPasswordException();
  }
  await _loginWithOtp(synoAuth, server, password, requestOtp);

  final current = ref.read(synologyAuthProvider);
  if (current.sid != null && current.sid!.isNotEmpty) {
    await registry.update(server, synoSid: current.sid);
  }
}

Future<void> _loginWithOtp(
  SynologyAuthNotifier notifier,
  ServerProfile server,
  String password,
  OtpCodeRequester? requestOtp,
) async {
  try {
    await notifier.login(
      serverUrl: server.resolveUrl(),
      account: server.username,
      password: password,
    );
  } on SynologyOtpRequiredException {
    final code = requestOtp == null ? null : await requestOtp();
    if (code == null || code.trim().isEmpty) rethrow;
    await notifier.login(
      serverUrl: server.resolveUrl(),
      account: server.username,
      password: password,
      otpCode: code.trim(),
    );
  }
}

/// 群晖两步验证验证码输入对话框；取消返回 null。
///
/// 注意：不创建 TextEditingController——showDialog 的 Future 在 route pop 时
/// 即完成，此时退场动画仍在跑，TextField 仍持有 controller，此时 dispose 会
/// 抛「used after being disposed」。用 onChanged 收集到局部变量即可。
Future<String?> showSynologyOtpDialog(BuildContext context) async {
  var input = '';
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('两步验证'),
      content: TextField(
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: '验证码',
          hintText: '群晖 Authenticator 生成的 6 位数字',
        ),
        onChanged: (v) => input = v,
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, input),
          child: const Text('确认'),
        ),
      ],
    ),
  );
  if (result == null || result.trim().isEmpty) return null;
  return result.trim();
}
