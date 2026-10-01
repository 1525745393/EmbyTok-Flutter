import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 本地媒体库模式开关（P0）
///
/// true 表示用户选择了"本地媒体库"入口，无需登录 Emby 服务器。
/// 路由守卫据此视为已登录状态；首页媒体库 Tab 显示 LocalVideoView。
final localModeProvider = StateProvider<bool>((ref) => false);
