// 应用入口：GoRouter 路由配置 + 登录守卫 + 主题
// 阶段 1：接入 Material Design 3 动态色彩系统（seed 粉色 0xFFE91E63）
// 阶段 2/3：后续逐步替换组件内硬编码颜色和尺寸 → colorScheme / theme tokens

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import 'theme/app_theme.dart';
import 'providers/providers.dart';
import 'views/favorites_view.dart';
import 'views/history_view.dart';
import 'views/home_scaffold.dart';
import 'views/item_detail_view.dart';
import 'views/login_view.dart';
import 'views/search_view.dart';
import 'views/settings_view.dart';

class EmbyTokApp extends ConsumerWidget {
  const EmbyTokApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 读取登录状态
    final isLoggedIn = ref.watch(
      authProvider.select((s) => s.isAuthenticated),
    );
    // 读取主题模式（'dark' | 'light' | 'system'）
    final themeMode = ref.watch(themeModeProvider);

    // GoRouter 路由配置
    final router = GoRouter(
      initialLocation: isLoggedIn ? '/' : '/login',
      redirect: (BuildContext context, GoRouterState state) {
        final goingToLogin = state.matchedLocation == '/login';
        if (!isLoggedIn && !goingToLogin) {
          return '/login';
        }
        if (isLoggedIn && goingToLogin) {
          return '/';
        }
        return null;
      },
      routes: [
        // 登录
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginView(),
        ),
        // 首页（视频流 + 底部导航）
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScaffold(),
        ),
        // 搜索
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchView(),
        ),
        // 收藏
        GoRoute(
          path: '/favorites',
          builder: (context, state) => const FavoritesView(),
        ),
        // 历史
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryView(),
        ),
        // 设置
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsView(),
        ),
        // 媒体项详情页：/item/:itemId
        GoRoute(
          path: '/item/:itemId',
          builder: (context, state) {
            final itemId = state.pathParameters['itemId'] ?? '';
            // 支持通过 extra 传入已加载的 MediaItem，避免重复请求
            final initialItem = state.extra is MediaItem
                ? state.extra as MediaItem
                : null;
            return ItemDetailView(
              itemId: itemId,
              initialItem: initialItem,
            );
          },
        ),
      ],
    );

    return MaterialApp.router(
      title: 'EmbyTok',
      debugShowCheckedModeBanner: false,
      // 亮色主题（用户在设置中选择 light 时生效）
      theme: buildLightTheme(),
      // 暗色主题（默认 dark / system 下的暗色外观）
      darkTheme: buildDarkTheme(),
      // 根据用户选择自动切换（默认跟随系统）
      themeMode: parseThemeMode(themeMode),
      routerConfig: router,
    );
  }
}
