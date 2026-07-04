// 应用入口：GoRouter 路由配置 + 登录守卫 + 主题
// 阶段 1：接入 Material Design 3 动态色彩系统（seed 粉色 0xFFE91E63）
// 阶段 2/3：后续逐步替换组件内硬编码颜色和尺寸 → colorScheme / theme tokens
//
// v1.123.3 hotfix：GoRouter 不再在 build 内创建
// 之前版本在 ConsumerWidget.build 中每次重建都 new GoRouter()，
// 登录成功时 isLoggedIn 变化触发 rebuild，旧 router 被新 router 替换，
// MaterialApp.router 的路由栈瞬间清空 → 表现为白屏。
// 修复方案：GoRouter 单例通过 Provider 管理，用 ChangeNotifier 桥接 Riverpod
// 状态变化作为 refreshListenable，redirect 始终通过 ref.read 读取最新状态。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// GoRouter 单例 Provider：只创建一次，避免每次 build 重建路由实例
final goRouterProvider = Provider<GoRouter>((ref) {
  // 创建一个 ChangeNotifier 作为桥接：当登录状态变化时通知 GoRouter 刷新 redirect
  final refreshNotifier = ChangeNotifier();
  // 监听登录状态变化，触发 GoRouter 重定向
  final authSub = ref.listen(
    authProvider.select((s) => s.isAuthenticated),
    (_, __) => refreshNotifier.notifyListeners(),
  );
  // provider 销毁时清理资源
  ref.onDispose(() {
    authSub.close();
    refreshNotifier.dispose();
  });

  final router = GoRouter(
    // 初始路由：读取初始登录状态决定
    initialLocation: ref.read(authProvider).isAuthenticated ? '/' : '/login',
    // 登录状态变化时自动触发 redirect 重新评估
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      // redirect 中始终读取最新登录状态
      final isLoggedIn = ref.read(authProvider).isAuthenticated;
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

  // provider 被销毁时（整个app退出）自动清理 router
  ref.onDispose(router.dispose);
  return router;
});

class EmbyTokApp extends ConsumerWidget {
  const EmbyTokApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 读取主题模式（'dark' | 'light' | 'system'）
    final themeMode = ref.watch(themeModeProvider);
    // 通过 provider 获取 GoRouter 单例——不会在每次 build 时重建
    final router = ref.watch(goRouterProvider);

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
      // 全面屏手势适配：用 builder 把整个 router 包到 AnnotatedRegion 中，
      // 让状态栏 / 导航栏前景色跟随当前主题的 brightness 切换。
      // child 是 MaterialApp 内部构建的 Navigator + Router，Theme.of 在此已可用。
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: systemOverlayStyleOf(context),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
