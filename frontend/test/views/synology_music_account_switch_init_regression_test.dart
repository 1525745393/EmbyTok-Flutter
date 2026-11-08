// 回归测试：审查报告未闭合候选「_globalInitDone 在 logout/login 后音乐数据残留」
//
// 旧实现：static bool _globalInitDone 一次性置位，切换群晖账号后重新进入音乐页
// 不重新初始化，Provider 里仍是上一账号的专辑/歌曲（登出不清音乐数据）。
// 修复：以账号指纹（serverUrl|account）判断是否需要初始化，账号变化时重新加载。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/providers/synology_music_provider.dart';
import 'package:embytok_flutter/providers/synology_playback_provider.dart';
import 'package:embytok_flutter/views/synology_music_view.dart';

/// 可变账号的假认证 Notifier（模拟登出后登录另一个群晖账号）
class _MutableAuthNotifier extends SynologyAuthNotifier {
  _MutableAuthNotifier(super.ref) : super() {
    switchAccount('account-a');
  }

  void switchAccount(String account) {
    state = SynologyAuthState(
      isLoggedIn: true,
      serverUrl: 'http://nas.local:5000',
      account: account,
      sid: 'sid-$account',
    );
  }
}

/// 计数假音乐库 Notifier：记录 loadTab / loadHomeData 被调用次数，不触发网络
class _CountingMusicNotifier extends SynologyMusicNotifier {
  _CountingMusicNotifier(super.ref) : super();

  int loadTabCalls = 0;
  int loadHomeCalls = 0;

  @override
  Future<void> loadTab(SynologyMusicTab tab, {bool force = false}) async {
    loadTabCalls++;
    state = state.copyWith(isLoading: false);
  }

  @override
  Future<void> loadHomeData({bool force = false}) async {
    loadHomeCalls++;
  }
}

/// 假播放 Notifier：restorePlayback 不触碰平台播放器
class _NoopPlaybackNotifier extends SynologyPlaybackNotifier {
  _NoopPlaybackNotifier(super.ref) : super();

  @override
  Future<void> restorePlayback() async {}
}

/// 宿主：只重建 SynologyMusicView 的 State（换 UniqueKey），不重建 ProviderScope，
/// 从而让假 Notifier 实例保持同一份，可跨重建统计调用次数
class _ViewHost extends StatefulWidget {
  const _ViewHost({super.key});
  @override
  State<_ViewHost> createState() => _ViewHostState();
}

class _ViewHostState extends State<_ViewHost> {
  Widget? _child = const SynologyMusicView(
    key: ValueKey('first'),
    showBackButton: true,
    initialTab: SynologyMusicTab.albums,
  );

  void recreate() {
    setState(() {
      _child = SynologyMusicView(
        key: UniqueKey(),
        showBackButton: true,
        initialTab: SynologyMusicTab.albums,
      );
    });
  }

  @override
  Widget build(BuildContext context) =>
      _child ?? const SizedBox.shrink();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('切换群晖账号后音乐页重新初始化；同账号重建不重复加载', (tester) async {
    late _MutableAuthNotifier auth;
    late _CountingMusicNotifier music;
    final hostKey = GlobalKey<_ViewHostState>();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        synologyAuthProvider.overrideWith((ref) {
          auth = _MutableAuthNotifier(ref);
          return auth;
        }),
        synologyMusicProvider.overrideWith((ref) {
          music = _CountingMusicNotifier(ref);
          return music;
        }),
        synologyPlaybackProvider
            .overrideWith((ref) => _NoopPlaybackNotifier(ref)),
      ],
      child: MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: _ViewHost(key: hostKey),
      ),
    ));

    // 账号 A：首次进入 → 全局初始化执行（4 个 loadTab + loadHomeData）
    await tester.pumpAndSettle();
    expect(music.loadTabCalls, 4);
    expect(music.loadHomeCalls, 1);

    // 同账号重建视图（如从其他页面返回）：不重复加载（Provider 数据仍有效）
    hostKey.currentState!.recreate();
    await tester.pumpAndSettle();
    expect(music.loadTabCalls, 4, reason: '同账号不应重复初始化');

    // 切换为账号 B 后重建视图：账号指纹变化 → 重新初始化加载新账号数据
    auth.switchAccount('account-b');
    hostKey.currentState!.recreate();
    await tester.pumpAndSettle();
    expect(music.loadTabCalls, 8, reason: '换账号后应重新初始化，避免残留上一账号数据');
    expect(music.loadHomeCalls, 2);
  });
}
