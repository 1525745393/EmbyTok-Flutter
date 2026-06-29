// 应用入口：GoRouter 路由配置 + 登录守卫 + 主题
// 阶段 1：接入 Material Design 3 动态色彩系统（seed 粉色 0xFFE91E63）
// 阶段 2/3：后续逐步替换组件内硬编码颜色和尺寸 → colorScheme / theme tokens

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import 'theme/app_theme.dart';
import 'providers/providers.dart';
import 'views/actors_view.dart';
import 'views/boxset_detail_view.dart';
import 'views/favorites_view.dart';
import 'views/history_view.dart';
import 'views/home_scaffold.dart';
import 'views/item_detail_view.dart';
import 'views/login_view.dart';
import 'views/person_detail_view.dart';
import 'views/recommend_view.dart';
import 'views/search_view.dart';
import 'views/settings_view.dart';
import 'widgets/video_page_item.dart';

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
        // 支持 ?initialId=<itemId>：从网格/搜索/演员详情等入口跳转到指定视频
        GoRoute(
          path: '/',
          builder: (context, state) {
            final initialId = state.uri.queryParameters['initialId'];
            return HomeScaffold(initialItemId: initialId);
          },
        ),
        // 搜索：独立路由（深层链接场景），按返回键跳回首页
        GoRoute(
          path: '/search',
          builder: (context, state) => PopScope(
            canPop: false,
            onPopInvoked: (didPop) {
              if (didPop) return;
              GoRouter.of(context).go('/');
            },
            child: const SearchView(),
          ),
        ),
        // 收藏
        GoRoute(
          path: '/favorites',
          builder: (context, state) => PopScope(
            canPop: false,
            onPopInvoked: (didPop) {
              if (didPop) return;
              GoRouter.of(context).go('/');
            },
            child: const FavoritesView(),
          ),
        ),
        // 历史
        GoRoute(
          path: '/history',
          builder: (context, state) => PopScope(
            canPop: false,
            onPopInvoked: (didPop) {
              if (didPop) return;
              GoRouter.of(context).go('/');
            },
            child: const HistoryView(),
          ),
        ),
        // 演员
        GoRoute(
          path: '/actors',
          builder: (context, state) => PopScope(
            canPop: false,
            onPopInvoked: (didPop) {
              if (didPop) return;
              GoRouter.of(context).go('/');
            },
            child: const ActorsView(),
          ),
        ),
        // 推荐：独立路由（PR #57），与 FeedType / video_list_provider 完全解耦
        GoRoute(
          path: '/recommend',
          builder: (context, state) => PopScope(
            canPop: true,
            child: const RecommendView(),
          ),
        ),
        // 设置
        GoRoute(
          path: '/settings',
          builder: (context, state) => PopScope(
            canPop: false,
            onPopInvoked: (didPop) {
              if (didPop) return;
              GoRouter.of(context).go('/');
            },
            child: const SettingsView(),
          ),
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
        // 演员/人物详情页：/person/:personId
        GoRoute(
          path: '/person/:personId',
          builder: (context, state) {
            final personId = state.pathParameters['personId'] ?? '';
            // 支持通过 extra 传入已加载的 MediaItem
            final person = state.extra is MediaItem
                ? state.extra as MediaItem
                : MediaItem(
                    id: personId,
                    title: '',
                    type: 'Person',
                  );
            return PersonDetailView(person: person);
          },
        ),
        // 合集/剧集详情页：/boxset/:boxsetId
        GoRoute(
          path: '/boxset/:boxsetId',
          builder: (context, state) {
            final boxsetId = state.pathParameters['boxsetId'] ?? '';
            final item = state.extra is MediaItem
                ? state.extra as MediaItem
                : MediaItem(
                    id: boxsetId,
                    title: '',
                    type: 'Boxset',
                  );
            return BoxsetDetailView(item: item);
          },
        ),
        // 视频播放页：/play/:itemId - 支持滑动切换视频列表
        GoRoute(
          path: '/play/:itemId',
          builder: (context, state) {
            final itemId = state.pathParameters['itemId'] ?? '';
            MediaItem item;
            List<MediaItem> items = [];
            String source = 'feed'; // PR #83：完播率 source 标签
            // 支持两种 extra 格式：MediaItem（单视频）或 Map（含 items 列表）
            if (state.extra is Map<String, dynamic>) {
              final extra = state.extra as Map<String, dynamic>;
              item = extra['item'] as MediaItem? ??
                  MediaItem(id: itemId, title: '', type: 'Video');
              items = (extra['items'] as List<MediaItem>?) ?? [];
              source = extra['source'] as String? ?? 'feed';
            } else if (state.extra is MediaItem) {
              item = state.extra as MediaItem;
            } else {
              item = MediaItem(id: itemId, title: '', type: 'Video');
            }
            return PlaybackShell(
              item: item,
              items: items,
              onBack: () => context.pop(),
              source: source, // PR #83
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
