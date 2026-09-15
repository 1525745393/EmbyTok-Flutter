// 主框架页面（PRD：底部 Tab 导航 — 首页 / 音乐库 / 我的）
//
// 底部 NavigationBar 3 个 Tab：
// - 首页：推荐内容（快捷入口 + 最近播放 + 最近添加 + 我的锁定 + ...）
// - 音乐库：歌曲/专辑/歌手/歌单分类浏览
// - 我的：个人中心
//
// Mini 播放条在所有 Tab 中统一显示（底部导航栏上方）。
// 使用 IndexedStack 保持各 Tab 状态，切换不重新加载。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/synology_auth_provider.dart';
import '../providers/synology_music_provider.dart';
import '../providers/app_preferences_providers.dart';
import '../services/update_check_service.dart';
import 'profile_view.dart';
import 'synology_music_view.dart';
import 'music/mini_player_bar.dart';

class MainView extends ConsumerStatefulWidget {
  const MainView({super.key});

  @override
  ConsumerState<MainView> createState() => _MainViewState();
}

class _MainViewState extends ConsumerState<MainView> {
  int _currentIndex = 0;

  // 3 个 Tab 页面，使用 IndexedStack 保持状态
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      // 首页：隐藏顶部分类 TabBar，只显示推荐内容
      const SynologyMusicView(
        showBackButton: false,
        initialTab: SynologyMusicTab.home,
        showTabBar: false,
        showMiniPlayer: false,
      ),
      // 音乐库：显示顶部分类 TabBar，默认歌曲 Tab
      const SynologyMusicView(
        showBackButton: false,
        initialTab: SynologyMusicTab.songs,
        showTabBar: true,
        showMiniPlayer: false,
      ),
      // 我的：个人中心
      const ProfileView(),
    ];
    // 启动后静默检查更新（有新版本才提示，同一版本只弹一次）
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoCheckUpdate());
  }

  Future<void> _autoCheckUpdate() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    try {
      final svc = ref.read(updateCheckServiceProvider);
      final ver = ref.read(appVersionProvider);
      final cur = ver.maybeWhen(data: (v) => v, orElse: () => '0.0.0');
      final plus = cur.indexOf('+');
      final currentVer = plus > 0 ? cur.substring(0, plus) : cur;
      final result = await svc.checkForUpdate(currentVer);
      if (!mounted || !result.hasUpdate || result.latestRelease == null) return;
      // 同一版本只提示一次（点「去更新」后才记录，点「稍后」下次仍提醒）
      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.getString('update_shown_ver') ?? '';
      if (shown == result.latestRelease!.version) return;
      if (!mounted) return;
      final v = result.latestRelease!;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('发现新版本 v${v.version}'),
          content: const Text('有可用更新，前往设置检查更新并下载安装。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('稍后'),
            ),
            FilledButton(
              onPressed: () {
                prefs.setString('update_shown_ver', v.version);
                Navigator.pop(ctx);
                context.push('/settings');
              },
              child: const Text('去更新'),
            ),
          ],
        ),
      );
    } catch (_) {
      // 静默检查失败不打扰用户
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(synologyAuthProvider);

    // 未登录时直接显示音乐库视图（会显示未登录提示）
    if (!auth.isLoggedIn) {
      return const SynologyMusicView(showBackButton: false);
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
          // Mini 播放条（所有 Tab 统一显示）
          const MiniPlayerBar(),
          // 底部导航栏
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: '首页',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
                label: '音乐库',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: '我的',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
