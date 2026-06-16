// 主骨架页：底部导航栏 + 页面切换
// 沉浸式体验：底部导航栏跟随 toolbarVisibilityProvider 平滑展开/折叠

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import 'feed_view.dart';
import 'search_view.dart';
import 'favorites_view.dart';
import 'history_view.dart';
import 'settings_view.dart';

// 页面索引常量
const int _indexFeed = 0;
const int _indexSearch = 1;
const int _indexFavorites = 2;
const int _indexHistory = 3;
const int _indexSettings = 4;

// 主骨架：包含底部导航的入口页
class HomeScaffold extends ConsumerStatefulWidget {
  const HomeScaffold({super.key});

  @override
  ConsumerState<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends ConsumerState<HomeScaffold> {
  int _currentIndex = _indexFeed;

  @override
  Widget build(BuildContext context) {
    // 监听工具栏可见性：用于驱动底部导航栏的折叠动画
    final toolbarVisible = ref.watch(toolbarVisibilityProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          FeedView(),
          SearchView(),
          FavoritesView(),
          HistoryView(),
          SettingsView(),
        ],
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: Duration(milliseconds: kToolbarAnimMs),
        curve: Curves.easeOut,
        height: toolbarVisible ? kBottomNavHeight + bottomPadding : 0,
        child: AnimatedOpacity(
          duration: Duration(milliseconds: kToolbarAnimMs),
          opacity: toolbarVisible ? 1.0 : 0.0,
          child: ClipRect(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Container(
                height: kBottomNavHeight + bottomPadding,
                decoration: const BoxDecoration(
                  color: backgroundColor,
                  border: Border(
                    top: BorderSide(color: dividerColor, width: 0.5),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomPadding),
                  child: BottomNavigationBar(
                    currentIndex: _currentIndex,
                    type: BottomNavigationBarType.fixed,
                    backgroundColor: backgroundColor,
                    selectedItemColor: primaryPink,
                    unselectedItemColor: textTertiary,
                    selectedFontSize: 12,
                    unselectedFontSize: 12,
                    showSelectedLabels: true,
                    showUnselectedLabels: true,
                    onTap: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                      // 根据路由跳转，便于保持浏览器 URL 与状态同步
                      switch (index) {
                        case _indexFeed:
                          context.go('/');
                          break;
                        case _indexSearch:
                          context.go('/search');
                          break;
                        case _indexFavorites:
                          context.go('/favorites');
                          break;
                        case _indexHistory:
                          context.go('/history');
                          break;
                        case _indexSettings:
                          context.go('/settings');
                          break;
                      }
                    },
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home_outlined),
                        activeIcon: Icon(Icons.home),
                        label: '首页',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.search),
                        activeIcon: Icon(Icons.search),
                        label: '搜索',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.favorite_border),
                        activeIcon: Icon(Icons.favorite),
                        label: '收藏',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.history_outlined),
                        activeIcon: Icon(Icons.history),
                        label: '历史',
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
    );
  }
}
