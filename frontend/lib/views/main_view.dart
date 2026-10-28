// 主框架页面（PRD：底部 Tab 导航 — 首页 / 音乐库 / 我的）
//
// 底部 NavigationBar 3 个 Tab：
// - 首页：推荐内容（快捷入口 + 最近播放 + 最近添加 + 我的锁定 + ...）
// - 音乐库：歌曲/专辑/歌手/歌单分类浏览
// - 我的：个人中心
//
// Mini 播放条在所有 Tab 中统一显示（底部导航栏上方）。
// 使用 IndexedStack 保持各 Tab 状态，切换不重新加载。

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
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
      // 跳过此版本：用户主动忽略后不再弹
      final skipped = prefs.getString('update_skipped_ver') ?? '';
      if (skipped == v.version) return;
      if (!mounted) return;
      // 查找 APK 附件
      final apkAssets = v.assets.where((a) => a.isApk).toList();
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('发现新版本 v${v.version}'),
          content: Text(
            '有可用更新。\n\n${v.body.isNotEmpty ? v.body : v.name}',
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            TextButton(
              onPressed: () {
                prefs.setString('update_skipped_ver', v.version);
                Navigator.pop(ctx);
              },
              child: const Text('跳过此版本'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('稍后'),
            ),
            FilledButton(
              onPressed: () {
                prefs.setString('update_shown_ver', v.version);
                Navigator.pop(ctx);
                if (apkAssets.isNotEmpty) {
                  // 直接开始下载
                  _directDownload(v, apkAssets.first);
                } else {
                  context.push('/settings');
                }
              },
              child: Text(apkAssets.isNotEmpty ? '下载安装' : '去更新'),
            ),
          ],
        ),
      );
    } catch (_) {
      // 静默检查失败不打扰用户
    }
  }

  /// 直接下载 APK（从启动弹窗触发）
  void _directDownload(ReleaseInfo release, ReleaseAsset apkAsset) {
    final scheme = Theme.of(context).colorScheme;
    final updateService = ref.read(updateCheckServiceProvider);
    final progress = ValueNotifier<double>(0);
    final status = ValueNotifier<String>('准备下载...');
    // batch136-F1 取消按钮真正取消下载：downloadApk 支持 CancelToken，
    // 之前取消只关闭对话框、下载仍在后台跑完并占用流量/存储
    final cancelToken = CancelToken();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            final savePath = await updateService.downloadApk(
              apkAsset,
              version: release.version,
              onProgress: (p) {
                progress.value = p;
                status.value = p >= 0
                    ? '${(p * 100).toStringAsFixed(0)}%'
                    : '下载中...';
              },
              cancelToken: cancelToken,
              expectedSha256: release.sha256Digest,
            );
            if (!ctx.mounted || cancelToken.isCancelled) return;
            Navigator.pop(ctx);
            // 下载完成，弹窗提示安装
            showDialog<void>(
              context: context,
              builder: (ic) => AlertDialog(
                title: const Text('下载完成'),
                content: Text('版本 ${release.version} 已下载完成，是否立即安装？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ic),
                    child: const Text('稍后安装'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ic);
                      // 安装 APK
                      OpenFilex.open(savePath,
                          type: 'application/vnd.android.package-archive');
                    },
                    child: const Text('立即安装'),
                  ),
                ],
              ),
            );
          } catch (e) {
            // 用户主动取消：静默关闭，不弹失败提示
            if (cancelToken.isCancelled) {
              if (ctx.mounted) Navigator.pop(ctx);
              return;
            }
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('下载失败：$e'), backgroundColor: scheme.error),
            );
          }
        });
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.downloading, size: 28, color: scheme.primary),
                  const SizedBox(width: 12),
                  const Text('正在下载更新', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (_, p, __) => LinearProgressIndicator(value: p > 0 ? p : null),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (_, s, __) => Text(s, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelToken.cancel('用户取消下载');
                Navigator.pop(ctx);
              },
              child: const Text('取消'),
            ),
          ],
        );
      },
    ).then((_) {
      progress.dispose();
      status.dispose();
    });
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
            // 底栏只显示图标，不显示中文标题（label 保留用于无障碍语义）
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
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
