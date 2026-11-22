import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../providers/service_mode_provider.dart';
import '../utils/logger.dart';

/// 遗留单槽凭据键（旧版本按「单服务器」存的 server/username/password）。
///
/// 新实现凭据按服务器 id 分桶存注册表（`server_password_<id>`）与群晖账号
/// 列表（`syno_pwd_<id>`），不再写这三个槽；保留键名仅用于统一登出时清理
/// 旧版本升级残留。
const kLegacySecureServer = 'embytok_secure_server';
const kLegacySecureUsername = 'embytok_secure_username';
const kLegacySecurePassword = 'embytok_secure_password';

/// 退出全部已登录账号（群晖 Audio Station + Emby），供设置页与个人中心共用。
///
/// 历史问题：设置页退出登录按 serviceMode 二选一（music→只退群晖、video→
/// 只退 Emby），另一账号登录态残留，路由守卫判定「任一登录」不跳 /login，
/// 用户点退出后 App 仍在（半退出状态）。此处统一全退：
/// 1. 音乐模式先停播放，避免登出后音乐续响；
/// 2. 群晖登出（内部会把服务模式回退到 video）；
/// 3. Emby 登出（未登录时内部静默跳过，幂等安全）；
/// 4. 清理旧版本遗留单槽凭据；
/// 5. 两者均登出后，路由守卫检测全部未登录，统一重定向 /login。
Future<void> logoutAllAccounts(WidgetRef ref) async {
  if (ref.read(serviceModeProvider) == AppServiceMode.music) {
    await ref.read(synologyPlaybackProvider.notifier).stop();
  }
  await ref.read(synologyAuthProvider.notifier).logout();
  await ref.read(authProvider.notifier).logout();
  await _clearLegacyCredentialSlots(ref);
}

/// 清理旧版本遗留的单槽凭据三件套；注册表按 id 保存的密码不在此清除。
Future<void> _clearLegacyCredentialSlots(WidgetRef ref) async {
  try {
    final storage = ref.read(secureStorageProvider);
    for (final key in const [
      kLegacySecureServer,
      kLegacySecureUsername,
      kLegacySecurePassword,
    ]) {
      await storage.delete(key: key);
    }
  } catch (e) {
    AppLogger.warn('清理遗留单槽凭据失败', data: {'error': e.toString()});
  }
}
