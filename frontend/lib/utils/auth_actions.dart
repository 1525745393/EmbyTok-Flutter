import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../providers/service_mode_provider.dart';

/// 退出全部已登录账号（群晖 Audio Station + Emby），供设置页与个人中心共用。
///
/// 历史问题：设置页退出登录按 serviceMode 二选一（music→只退群晖、video→
/// 只退 Emby），另一账号登录态残留，路由守卫判定「任一登录」不跳 /login，
/// 用户点退出后 App 仍在（半退出状态）。此处统一全退：
/// 1. 音乐模式先停播放，避免登出后音乐续响；
/// 2. 群晖登出（内部会把服务模式回退到 video）；
/// 3. Emby 登出（未登录时内部静默跳过，幂等安全）；
/// 4. 两者均登出后，路由守卫检测全部未登录，统一重定向 /login。
Future<void> logoutAllAccounts(WidgetRef ref) async {
  if (ref.read(serviceModeProvider) == AppServiceMode.music) {
    await ref.read(synologyPlaybackProvider.notifier).stop();
  }
  await ref.read(synologyAuthProvider.notifier).logout();
  await ref.read(authProvider.notifier).logout();
}
