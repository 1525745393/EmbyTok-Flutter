// 主骨架页：底部导航栏 + 页面切换

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'feed_view.dart';

// 页面索引常量
const int _indexFeed = 0;
const int _indexSearch = 1;
const int _indexFavorites = 2;
const int _indexHistory = 3;
const int _indexSettings = 4;

// 主骨架：包含底部导航的入口页
class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key});

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  int _currentIndex = _indexFeed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          FeedView(),
          _SearchPlaceholder(),
          _FavoritesPlaceholder(),
          _HistoryPlaceholder(),
          _SettingsPlaceholder(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: const Color(0xFFE91E63),
        unselectedItemColor: Colors.white60,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // 根据路由跳转，便于保持浏览器 URL 与状态同步（若需要）
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
    );
  }
}

// 以下为占位页：稍后由具体任务替换为完整实现

class _SearchPlaceholder extends StatelessWidget {
  const _SearchPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('搜索'),
      ),
      body: const Center(
        child: Text(
          '功能待实现',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
}

class _FavoritesPlaceholder extends StatelessWidget {
  const _FavoritesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('收藏'),
      ),
      body: const Center(
        child: Text(
          '功能待实现',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
}

class _HistoryPlaceholder extends StatelessWidget {
  const _HistoryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('观看历史'),
      ),
      body: const Center(
        child: Text(
          '功能待实现',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('设置'),
      ),
      body: const Center(
        child: Text(
          '功能待实现',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
}
