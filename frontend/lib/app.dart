// 应用入口：GoRouter 路由配置 + 登录守卫 + 主题

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../utils/colors.dart';
import 'providers/providers.dart';
import 'views/favorites_view.dart';
import 'views/history_view.dart';
import 'views/home_scaffold.dart';
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
      ],
    );

    return MaterialApp.router(
      title: 'EmbyTok',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.pinkAccent,
        useMaterial3: true,
        scaffoldBackgroundColor: backgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundColor,
          foregroundColor: textPrimary,
        ),
      ),
      routerConfig: router,
    );
  }
}
