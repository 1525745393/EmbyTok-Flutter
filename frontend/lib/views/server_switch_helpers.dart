// 服务器切换公共逻辑（登录页「快速切换」与服务器管理页共用）
//
// P3 修复（登录界面审查 F3/F4/F7）：两处切换实现此前各自演化——sid 有效性校验、
// 两步验证（OTP）处理都只在 servers_view 一侧修过，导致登录页快速切换行为不一致
// （sid 过期假成功、2FA 账号无法切换）。这里把公共路径收敛为单点实现，
// 两个调用方只保留各自的激活状态时序：
//   - 登录页：登录成功后才 touch / setActive（失败保持原服务器激活）；
//   - 服务器管理页：进入即 touch / setActive（沿用既有语义）。
//
// 阶段 1-B 3b-2：跨类型切换不再登出对端会话，对端账号后台保留（多会话并行）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../providers/auth_provider.dart';
import '../providers/server_registry_provider.dart';
import '../providers/service_mode_provider.dart';
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

/// 群晖密码登录；遇两步验证（[SynologyOtpRequiredException]）时经 [requestOtp]
/// 取码后带 `otpCode` 重试。取码被取消则把原始 OTP 异常向上抛。
///
/// 供服务器切换与账号切换 sheet（切换/添加账号）共用同一 OTP 回退路径。
Future<void> loginSynoWithOtp(
  SynologyAuthNotifier notifier, {
  required String serverUrl,
  required String account,
  required String password,
  OtpCodeRequester? requestOtp,
}) async {
  try {
    await notifier.login(
      serverUrl: serverUrl,
      account: account,
      password: password,
    );
  } on SynologyOtpRequiredException {
    final code = requestOtp == null ? null : await requestOtp();
    if (code == null || code.trim().isEmpty) rethrow;
    await notifier.login(
      serverUrl: serverUrl,
      account: account,
      password: password,
      otpCode: code.trim(),
    );
  }
}

Future<void> _loginWithOtp(
  SynologyAuthNotifier notifier,
  ServerProfile server,
  String password,
  OtpCodeRequester? requestOtp,
) =>
    loginSynoWithOtp(
      notifier,
      serverUrl: server.resolveUrl(),
      account: server.username,
      password: password,
      requestOtp: requestOtp,
    );

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

/// 提取 host 用于登录状态匹配（地址可能带端口/协议差异）。
String hostOf(String url) {
  try {
    return Uri.parse(url).host;
  } catch (_) {
    return url;
  }
}

/// 删除注册表服务器前，若它正是当前已登录的活会话，则登出对应认证 Provider。
///
/// 匹配口径与服务器管理页「登录态展示」一致：按 host 相等判定（协议/端口差异
/// 不影响）。仅清匹配的那一路；不匹配或未登录时不动任何会话。
Future<void> logoutMatchingSession(WidgetRef ref, ServerProfile server) async {
  switch (server.kind) {
    case ServerKind.emby:
    case ServerKind.jellyfin:
    case ServerKind.plex:
      final auth = ref.read(authProvider);
      if (auth.isAuthenticated &&
          auth.embyServerUrl != null &&
          hostOf(auth.embyServerUrl!) == hostOf(server.url)) {
        await ref.read(authProvider.notifier).logout();
      }
    case ServerKind.synology:
      final syno = ref.read(synologyAuthProvider);
      if (syno.isLoggedIn &&
          syno.serverUrl != null &&
          hostOf(syno.serverUrl!) == hostOf(server.url)) {
        await ref.read(synologyAuthProvider.notifier).logout();
      }
  }
}

/// 判断注册表条目当前是否处于在线（已登录）状态。
///
/// 视频类（Emby/Jellyfin/Plex）：优先按条目 id 命中多会话槽；未命中时回退
/// 当前激活槽的 host 匹配（兼容旧 url 槽 / 历史数据）。群晖为单 current 模型，
/// 按当前群晖会话的 host + 账号匹配。
bool isRegistryServerOnline(
  ServerProfile server,
  AuthState auth,
  bool Function(String sessionKey) isVideoSessionOnline,
  SynologyAuthState synoAuth,
) {
  switch (server.kind) {
    case ServerKind.emby:
    case ServerKind.jellyfin:
    case ServerKind.plex:
      if (isVideoSessionOnline(server.id)) return true;
      return auth.isAuthenticated &&
          auth.embyServerUrl != null &&
          hostOf(auth.embyServerUrl!) == hostOf(server.url);
    case ServerKind.synology:
      return synoAuth.isLoggedIn &&
          synoAuth.serverUrl != null &&
          hostOf(synoAuth.serverUrl!) == hostOf(server.url) &&
          (synoAuth.account == null || synoAuth.account == server.username);
  }
}

/// 列表置顶排序：在线条目在前（组内按最近使用时间倒序），未登录条目在后
/// 并保持注册表原有相对顺序。纯函数，不改持久化顺序。
List<ServerProfile> sortServersByOnline(
  List<ServerProfile> servers,
  bool Function(ServerProfile server) isOnline,
) {
  final online = servers.where(isOnline).toList()
    ..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
  final offline = servers.where((s) => !isOnline(s)).toList();
  return [...online, ...offline];
}

/// 取消在线勾选：登出对应会话（仅清会话 token/sid，不删除注册表保存的
/// 密码/sid；凭据保留以便下次凭保存凭据恢复）。
///
/// - 视频类：按条目 id 定位会话槽登出，不影响其他在线槽；id 槽未命中时
///   兜底登出 host 匹配的当前激活槽；
/// - 群晖：仅当条目正是当前群晖会话时登出（单 current 模型，非当前条目不动）。
Future<void> logoutRegistrySession(WidgetRef ref, ServerProfile server) async {
  switch (server.kind) {
    case ServerKind.emby:
    case ServerKind.jellyfin:
    case ServerKind.plex:
      final notifier = ref.read(authProvider.notifier);
      if (notifier.isSessionOnline(server.id)) {
        await notifier.logoutSession(server.id);
        return;
      }
      final auth = ref.read(authProvider);
      final current = notifier.activeSessionId;
      if (current != null &&
          auth.isAuthenticated &&
          auth.embyServerUrl != null &&
          hostOf(auth.embyServerUrl!) == hostOf(server.url)) {
        await notifier.logoutSession(current);
      }
    case ServerKind.synology:
      final syno = ref.read(synologyAuthProvider);
      if (syno.isLoggedIn &&
          syno.serverUrl != null &&
          hostOf(syno.serverUrl!) == hostOf(server.url) &&
          (syno.account == null || syno.account == server.username)) {
        await ref.read(synologyAuthProvider.notifier).logout();
      }
  }
}

/// 注册表服务器切换结果
enum ServerSwitchOutcome {
  /// 切换成功
  switched,

  /// 目标服务器未保存密码，无法自动登录
  missingPassword,
}

/// 统一的注册表服务器切换编排（登录页快速切换 / 服务器管理页共用）。
///
/// 顺序不变量（P1 修复）：**先登录目标成功，再更新激活态**。
/// 旧实现先清对端会话再登录目标，目标失败时会把当前可用会话一并销毁
/// （用户被踢回登录页）。本函数把顺序收敛为：
/// 1. 登录目标（群晖走 sid 恢复 + 校验 + 密码回退 + OTP；视频类读保存密码）；
/// 2. 成功后才 touch/setActive、服务模式联动；**跨类型对端会话保留**
///    （阶段 1-B 多会话并行，对端会话后台保留，不再跨类型登出）；
/// 3. 目标登录失败时异常向上抛，对端会话保持不变。
///
/// 视频类无保存密码时返回 [ServerSwitchOutcome.missingPassword]，不抛异常。
Future<ServerSwitchOutcome> switchRegistryServer(
  WidgetRef ref,
  ServerProfile server,
  FlutterSecureStorage storage, {
  OtpCodeRequester? requestOtp,
}) async {
  if (server.kind == ServerKind.synology) {
    await loginSynologyTarget(
      ref,
      server,
      storage,
      requestOtp: requestOtp,
    );
  } else {
    final password = await readSavedServerPassword(storage, server.id);
    if (password == null || password.isEmpty) {
      return ServerSwitchOutcome.missingPassword;
    }
    await ref.read(authProvider.notifier).login(
          server.resolveUrl(),
          server.username,
          password,
          serverId: server.id,
        );
  }

  // 登录成功后更新激活态与服务模式联动；跨类型对端会话保留（多会话并行），
  // 失败时不会执行到这里，对端会话保持不变。
  await ref.read(serverRegistryProvider.notifier).touch(server.id);
  await ref.read(activeServerIdProvider.notifier).setActive(server.id);

  // 账号类型与服务模式联动：群晖 → 音乐，Emby/Jellyfin/Plex → 视频
  final modeNotifier = ref.read(serviceModeProvider.notifier);
  if (server.kind == ServerKind.synology) {
    if (ref.read(serviceModeProvider) != AppServiceMode.music) {
      await modeNotifier.setMode(AppServiceMode.music);
    }
  } else if (ref.read(serviceModeProvider) != AppServiceMode.video) {
    await modeNotifier.setMode(AppServiceMode.video);
  }

  return ServerSwitchOutcome.switched;
}
