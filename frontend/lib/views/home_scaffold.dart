// 主骨架页：底部导航栏 + 页面切换

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'continue_watching_view.dart';
import 'feed_view.dart';
import 'favorites_view.dart';
import 'genres_browse_view.dart';
import 'next_up_view.dart';
import 'people_browse_view.dart';
import 'search_view.dart';
import 'settings_view.dart';

// 页面索引常量
const int _indexFeed = 0;
const int _indexSearch = 1;
const int _indexFavorites = 2;
const int _indexBrowse = 3;
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
          SearchView(),
          FavoritesView(),
          BrowseHubView(),
          SettingsView(),
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
            case _indexBrowse:
              context.go('/browse');
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
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: '浏览',
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

// 浏览中心页：提供各种分类入口（继续观看、Next Up、类型、演员、工作室）
class BrowseHubView extends StatelessWidget {
  const BrowseHubView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          '浏览',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 继续观看
          _SectionCard(
            title: '继续观看',
            subtitle: '接着看上次暂停的内容',
            icon: Icons.play_circle_fill,
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const ContinueWatchingView()),
              );
            },
          ),
          const SizedBox(height: 12),
          // Next Up
          _SectionCard(
            title: '下一步看什么',
            subtitle: '剧集下一集',
            icon: Icons.skip_next,
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const NextUpView()),
              );
            },
          ),
          const SizedBox(height: 12),
          // 类型
          _SectionCard(
            title: '类型',
            subtitle: '动作、科幻、喜剧…',
            icon: Icons.category,
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const GenresBrowseView()),
              );
            },
          ),
          const SizedBox(height: 12),
          // 演员与导演
          _SectionCard(
            title: '演员与导演',
            subtitle: '按人物浏览作品',
            icon: Icons.people_alt_outlined,
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const PeopleBrowseView()),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE91E63).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFFE91E63), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
