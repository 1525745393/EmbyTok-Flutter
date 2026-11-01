// 首页根组件：按服务模式实时渲染视频流首页或群晖音乐库首页
//
// 服务模式（serviceModeProvider）决定 '/' 首页展示内容：
// - video：EmbyTok 视频流首页（HomeScaffold）
// - music：群晖音乐库界面（MainView）
//
// 必须用 [WidgetRef.watch] 监听 serviceModeProvider：
// 切换服务模式或退出群晖账号（回退视频模式）后首页立即重建；
// 若用 ref.read 一次性读取则不建立监听，需重启 App 才会读到新模式。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_mode_provider.dart';
import 'home_scaffold.dart';
import 'main_view.dart';

/// 首页根：按服务模式实时渲染（视频流 / 群晖音乐库）
class ModeRoot extends ConsumerWidget {
  const ModeRoot({super.key, this.initialItemId});

  /// 从网格/搜索/演员详情等入口跳转到指定视频
  final String? initialItemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(serviceModeProvider);
    if (mode == AppServiceMode.music) {
      return const MainView();
    }
    return HomeScaffold(initialItemId: initialItemId);
  }
}
