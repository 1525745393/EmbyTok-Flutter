// 主骨架页：底部导航栏 + 页面切换
// 底部导航栏简化为3个标签：首页、收藏、设置
// 搜索和历史通过 FeedView 顶部操作栏的图标按钮访问（覆盖层页面）
//
// 系统返回键拦截：HomeScaffold 的 PopScope 拦截系统返回键。
// - 在覆盖层页面（搜索/历史）上按返回键 → 回到 Feed
// - 在非 Feed Tab 上按返回键 → 回到 Feed Tab
// - 在 Feed Tab 上按返回键 → 弹出退出确认对话框

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../utils/constants.dart';
import 'feed_view.dart';
import 'search_view.dart';
import 'favorites_view.dart';
import 'history_view.dart';
import 'settings_view.dart';

// 主骨架：包含底部导航的入口页
class HomeScaffold extends ConsumerStatefulWidget {
  const HomeScaffold({super.key});

  @override
  ConsumerState<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends ConsumerState<HomeScaffold> {
  @override
  Widget build(BuildContext context) {
    // 监听页面导航状态
    final pageNavState = ref.watch(pageNavigationProvider);
    // 监听工具栏可见性：用于驱动底部导航栏的折叠动画
    final toolbarVisible = ref.watch(toolbarVisibilityProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final scheme = Theme.of(context).colorScheme;

    // 当前显示的页面索引
    // 覆盖层页面（搜索/历史）使用独立索引，底部导航栏保持原位
    final currentIndex = pageNavState.currentIndex;

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;

        // 如果在覆盖层页面（搜索/历史），返回到 Feed
        if (pageNavState.isOverlayPage) {
          ref.read(pageNavigationNotifierProvider).backToFeed();
          return;
        }

        // 在 Feed 之外的 Tab 上按返回键，先回到 Feed
        if (currentIndex != 0) {
          ref.read(pageNavigationNotifierProvider).goToPage(0);
          return;
        }

        // 在 Feed 上按返回键，弹出退出确认
        final result = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: scheme.surface,
            title: const Text('退出应用？'),
            content: const Text('确定要退出吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('取消', style: TextStyle(color: scheme.onSurface)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                ),
                child: const Text('退出'),
              ),
            ],
          ),
        );

        if (result == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: Stack(
          children: [
            // 页面内容
            Positioned.fill(
              child: IndexedStack(
                // 覆盖层页面显示在 Feed 之上，不切换底部导航
                index: pageNavState.isOverlayPage ? 0 : currentIndex,
                children: [
                  // 索引 0: Feed 页面（全屏展示）
                  const FeedView(),
                  // 索引 1: 收藏页面（预留底部导航栏高度）
                  Padding(
                    padding: EdgeInsets.only(bottom: kBottomNavHeight + bottomPadding),
                    child: const FavoritesView(),
                  ),
                  // 索引 2: 设置页面（预留底部导航栏高度）
                  Padding(
                    padding: EdgeInsets.only(bottom: kBottomNavHeight + bottomPadding),
                    child: const SettingsView(),
                  ),
                ],
              ),
            ),
            // 覆盖层页面：搜索和历史（全屏覆盖，不预留底部导航栏空间）
// 使用 useScaffold: false 避免 Scaffold 嵌套和 Navigator.pop 冲突
            if (pageNavState.isOverlayPage)
              Positioned.fill(
                child: IndexedStack(
                  // search=3, history=4，映射到覆盖层索引 0/1
                  index: currentIndex == 3 ? 0 : 1,
                  children: const [
                    SearchView(useScaffold: false),
                    HistoryView(useScaffold: false),
                  ],
                ),
              ),
            // 底部导航栏：只在非覆盖层页面时显示
            if (!pageNavState.isOverlayPage)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: kToolbarAnimMs),
                  curve: Curves.easeOut,
                  height: toolbarVisible ? kBottomNavHeight + bottomPadding : 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: kToolbarAnimMs),
                    opacity: toolbarVisible ? 1.0 : 0.0,
                    child: ClipRect(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Container(
                          height: kBottomNavHeight + bottomPadding,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                scheme.surface,
                                scheme.surface.withOpacity(0.0),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.only(bottom: bottomPadding),
                            child: BottomNavigationBar(
                              currentIndex: currentIndex,
                              type: BottomNavigationBarType.fixed,
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              selectedItemColor: scheme.primary,
                              unselectedItemColor: scheme.onSurfaceVariant,
                              selectedFontSize: 12,
                              unselectedFontSize: 12,
                              showSelectedLabels: true,
                              showUnselectedLabels: true,
                              onTap: (index) {
                                ref.read(pageNavigationNotifierProvider).goToPage(index);
                              },
                              items: const [
                                BottomNavigationBarItem(
                                  icon: Icon(Icons.home_outlined),
                                  activeIcon: Icon(Icons.home),
                                  label: '首页',
                                ),
                                BottomNavigationBarItem(
                                  icon: Icon(Icons.favorite_border),
                                  activeIcon: Icon(Icons.favorite),
                                  label: '收藏',
                                ),
                                BottomNavigationBarItem(
                                  icon: Icon(Icons.settings_outlined),
                                  activeIcon: Icon(Icons.settings),
                                  label: '设置',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
