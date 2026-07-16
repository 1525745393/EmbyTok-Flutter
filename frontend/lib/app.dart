// 应用入口：GoRouter 路由配置 + 登录守卫 + 主题
// 阶段 1：接入 Material Design 3 动态色彩系统（seed 粉色 0xFFE91E63）
// 阶段 2/3：后续逐步替换组件内硬编码颜色和尺寸 → colorScheme / theme tokens

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../utils/logger.dart';
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

/// 桥接 Riverpod 认证状态到 GoRouter 的 refreshListenable
/// 当认证状态变化时调用 notify() 触发 GoRouter 重新评估 redirect
class _AuthRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

class EmbyTokApp extends ConsumerStatefulWidget {
  const EmbyTokApp({super.key});

  @override
  ConsumerState<EmbyTokApp> createState() => _EmbyTokAppState();
}

class _EmbyTokAppState extends ConsumerState<EmbyTokApp> {
  final _refreshNotifier = _AuthRefreshNotifier();
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/',
      refreshListenable: _refreshNotifier,
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = ref.read(
          authProvider.select((s) => s.isAuthenticated),
        );
        final goingToLogin = state.matchedLocation == '/login';
        // 路由守卫日志：记录重定向决策
        if (!isLoggedIn && !goingToLogin) {
          AppLogger.debug('路由守卫', data: {
            'from': state.matchedLocation,
            'to': '/login',
            'reason': '未登录',
          });
          return '/login';
        }
        if (isLoggedIn && goingToLogin) {
          AppLogger.debug('路由守卫', data: {
            'from': state.matchedLocation,
            'to': '/',
            'reason': '已登录，跳转首页',
          });
          return '/';
        }
        return null;
      },
      routes: _buildRoutes(),
    );
  }

  @override
  void dispose() {
    _refreshNotifier.dispose();
    super.dispose();
  }

  /// 构建路由表（静态配置，不依赖 widget 状态）
  List<RouteBase> _buildRoutes() {
    return [
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
            // 尝试 pop 保留浏览历史，失败则回到首页
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              GoRouter.of(context).go('/');
            }
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
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              GoRouter.of(context).go('/');
            }
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
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              GoRouter.of(context).go('/');
            }
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
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              GoRouter.of(context).go('/');
            }
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
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              GoRouter.of(context).go('/');
            }
          },
          child: const SettingsView(),
        ),
      ),
      // 媒体项详情页：/item/:itemId（自定义上滑转场动画）
      GoRoute(
        path: '/item/:itemId',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: _buildItemDetail(context, state),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
      // 演员/人物详情页：/person/:personId（自定义上滑转场动画）
      GoRoute(
        path: '/person/:personId',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: _buildPersonDetail(context, state),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
      // 合集/剧集详情页：/boxset/:boxsetId（自定义上滑转场动画）
      GoRoute(
        path: '/boxset/:boxsetId',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: _buildBoxsetDetail(context, state),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
      // 视频播放页：/play/:itemId - 支持滑动切换视频列表（自定义上滑转场动画）
      GoRoute(
        path: '/play/:itemId',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: _buildPlayback(context, state),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
    ];
  }

  /// 详情页统一上滑转场动画
  static Widget _slideUpTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    );
  }

  Widget _buildItemDetail(BuildContext context, GoRouterState state) {
    final itemId = state.pathParameters['itemId'] ?? '';
    final initialItem = state.extra is MediaItem
        ? state.extra as MediaItem
        : null;
    return ItemDetailView(itemId: itemId, initialItem: initialItem);
  }

  Widget _buildPersonDetail(BuildContext context, GoRouterState state) {
    final personId = state.pathParameters['personId'] ?? '';
    MediaItem person;
    String? personType;
    final extra = state.extra;
    if (extra is Map) {
      person = extra['item'] as MediaItem? ??
          MediaItem(id: personId, title: '', type: 'Person');
      personType = extra['personType'] as String?;
    } else if (extra is MediaItem) {
      person = extra;
    } else {
      person = MediaItem(id: personId, title: '', type: 'Person');
    }
    return PersonDetailView(person: person, personType: personType);
  }

  Widget _buildBoxsetDetail(BuildContext context, GoRouterState state) {
    final boxsetId = state.pathParameters['boxsetId'] ?? '';
    final item = state.extra is MediaItem
        ? state.extra as MediaItem
        : MediaItem(id: boxsetId, title: '', type: 'Boxset');
    return BoxsetDetailView(item: item);
  }

  Widget _buildPlayback(BuildContext context, GoRouterState state) {
    final itemId = state.pathParameters['itemId'] ?? '';
    MediaItem item;
    List<MediaItem> items = [];
    if (state.extra is Map<String, dynamic>) {
      final extra = state.extra as Map<String, dynamic>;
      item = extra['item'] as MediaItem? ??
          MediaItem(id: itemId, title: '', type: 'Video');
      items = (extra['items'] as List<MediaItem>?) ?? [];
    } else if (state.extra is MediaItem) {
      item = state.extra as MediaItem;
    } else {
      item = MediaItem(id: itemId, title: '', type: 'Video');
    }
    return PlaybackShell(
      item: item,
      items: items,
      onBack: () => context.pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 监听认证状态变化，触发 GoRouter 重新评估 redirect
    ref.listen(authProvider.select((s) => s.isAuthenticated), (prev, next) {
      if (prev != next) {
        AppLogger.debug('认证状态变化', data: {'isLoggedIn': next});
        _refreshNotifier.notify();
      }
    });

    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'EmbyTok',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: parseThemeMode(themeMode),
      routerConfig: _router,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: systemOverlayStyleOf(context),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
