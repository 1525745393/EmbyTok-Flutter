// 主骨架页：底部导航栏 + 页面切换
// 沉浸式体验：底部导航栏跟随 toolbarVisibilityProvider 平滑展开/折叠
//
// 系统返回键拦截：HomeScaffold 的 PopScope 拦截系统返回键。
// - 在非 Feed Tab 上按返回键 → 回到 Feed Tab
// - 在 Feed Tab 上按返回键 → 弹出退出确认对话框
//
// 注意：依赖 AndroidManifest 中 android:enableOnBackInvokedCallback="true"
// 才会把系统返回键事件传给 Flutter（Android 13+ 默认行为）

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
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      // 拦截系统返回键，弹出退出确认对话框
      // canPop=false 让 PopScope 接管返回事件，Flutter 不会自动退出 App
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;

        // 在 Feed 之外的 Tab 上按返回键，先回到 Feed
        if (_currentIndex != _indexFeed) {
          setState(() {
            _currentIndex = _indexFeed;
          });
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
        // 架构调整：使用 Stack 让内容 fill 全屏，底部导航栏用 Positioned 叠加
        body: Stack(
          children: [
            // 页面内容：feed 页面让视频延伸到屏幕边缘，其他页面预留底部导航栏高度
            Positioned.fill(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  // Feed 页面：全屏展示
                  const FeedView(),
                  // 其他普通页面：内容需要避开底部导航栏
                  for (int i = 1; i < 5; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: kBottomNavHeight + bottomPadding,
                      ),
                      child: [
                        const SizedBox.shrink(), // 占位
                        const SearchView(),
                        const FavoritesView(),
                        const HistoryView(),
                        const SettingsView(),
                      ][i],
                    ),
                ],
              ),
            ),
            // 底部导航栏：半透明渐变叠加在页面之上
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
                            currentIndex: _currentIndex,
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
                              setState(() {
                                _currentIndex = index;
                              });
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
            ),
          ],
        ),
      ),
    );
  }
}
