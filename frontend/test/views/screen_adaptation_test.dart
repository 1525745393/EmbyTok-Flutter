// 屏幕适配回归测试：验证关键页面在各种比例/刘海屏下不溢出
//
// 覆盖场景：
// 1. 小屏（320×568，iPhone SE 1 代）：音乐库未登录态
// 2. 刘海屏（390×844 + 顶部 47 / 底部 34 安全区）：音乐库已登录 + mini player
// 3. 刘海屏全屏播放页（竖屏 + 横屏）：封面约束 + 控制按钮不溢出
// 4. 小屏全屏播放页：控制按钮 FittedBox 缩放生效
//
// 判定：任何 RenderFlex overflow / 布局异常都会以 FlutterError 抛出，
// 测试通过 tester.takeException() 断言无异常。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/audio_models.dart';
import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/views/synology_full_player.dart';
import 'package:embytok_flutter/views/synology_music_view.dart';

/// 假认证 Notifier：跳过真实登录，构造后可手动置为已登录
class _FakeAuthNotifier extends SynologyAuthNotifier {
  _FakeAuthNotifier(super.ref) : super() {
    state = const SynologyAuthState(
      isLoggedIn: true,
      serverUrl: 'http://192.168.1.6:5000',
      account: 'tester',
      sid: 'mock-sid',
    );
  }
}

/// 假音乐库 Notifier：不触发网络加载
class _FakeMusicNotifier extends SynologyMusicNotifier {
  _FakeMusicNotifier(super.ref) : super();
}

/// 假播放 Notifier：直接持有播放中的曲目，不触发播放器
class _FakePlaybackNotifier extends SynologyPlaybackNotifier {
  _FakePlaybackNotifier(super.ref) : super() {
    const song = AudioSong(
      id: 'music_1',
      title: '测试歌曲标题测试歌曲标题',
      tag: const AudioSongTag(artist: '测试歌手'),
    );
    state = const SynologyPlaybackState(
      currentSong: song,
      queue: [song],
      currentIndex: 0,
      isPlaying: true,
      isLoading: false,
      position: Duration(seconds: 65),
      duration: Duration(minutes: 4, seconds: 20),
      coverUrl: null,
    );
  }
}

/// 断言无布局溢出；ink_sparkle 为 Flutter 3.47.2 SDK 已知 shader 兼容缺陷，
/// 与业务布局无关，忽略该异常（详见 README 已知失败说明）。
void expectNoOverflow(WidgetTester tester, String reason) {
  final e = tester.takeException();
  if (e == null) return;
  if (e.toString().contains('ink_sparkle')) return;
  expect(e, isNull, reason: reason);
}

void main() {
  setUp(() {
    // SharedPreferences mock：SynologyAuthNotifier 构造会异步恢复会话
    SharedPreferences.setMockInitialValues({});
  });

  /// 设置模拟设备尺寸与安全区（刘海屏模拟）
  void setPhone(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    tester.view.padding = FakeViewPadding(
      left: padding.left,
      top: padding.top,
      right: padding.right,
      bottom: padding.bottom,
    );
    addTearDown(tester.view.reset);
  }

  Widget buildMusicView({required bool loggedIn}) {
    return ProviderScope(
      overrides: [
        if (loggedIn) ...[
          synologyAuthProvider.overrideWith((ref) => _FakeAuthNotifier(ref)),
          synologyMusicProvider.overrideWith((ref) => _FakeMusicNotifier(ref)),
          synologyPlaybackProvider
              .overrideWith((ref) => _FakePlaybackNotifier(ref)),
        ],
      ],
      child: const MaterialApp(home: SynologyMusicView()),
    );
  }

  testWidgets('小屏 320×568：音乐库未登录态不溢出', (tester) async {
    setPhone(tester, size: const Size(320, 568));
    await tester.pumpWidget(buildMusicView(loggedIn: false));
    await tester.pumpAndSettle();

    // 未登录态：提示文案可见
    expect(find.text('登录后可浏览和播放 NAS 上的音乐'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: '小屏未登录态不应有布局溢出');
  });

  testWidgets('刘海屏 390×844：已登录 + mini player 不溢出', (tester) async {
    setPhone(
      tester,
      size: const Size(390, 844),
      padding: const EdgeInsets.only(top: 47, bottom: 34),
    );
    await tester.pumpWidget(buildMusicView(loggedIn: true));
    await tester.pumpAndSettle();

    // 渐变头部标题可见（未被状态栏遮挡）
    expect(find.text('群晖音乐'), findsOneWidget);
    // mini player 曲目标题可见
    expect(find.text('测试歌曲标题测试歌曲标题'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: '刘海屏已登录态不应有布局溢出');
  });

  testWidgets('刘海屏 390×844：全屏播放页（竖屏）不溢出', (tester) async {
    setPhone(
      tester,
      size: const Size(390, 844),
      padding: const EdgeInsets.only(top: 47, bottom: 34),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          synologyPlaybackProvider.overrideWith((ref) => _FakePlaybackNotifier(ref)),
        ],
        child: MaterialApp(
          // M2 涟漪（InkRipple）不加载 ink_sparkle shader，规避 Flutter 3.47.2
          // SDK 已知 shader 兼容缺陷（测试侧规避，不改产品主题）
          theme: ThemeData(
            splashFactory: InkRipple.splashFactory,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showFullPlayerSheet(context),
                  child: const Text('打开播放页'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开播放页'));
    // 旋转封面为无限动画，不能 pumpAndSettle，用固定帧推进
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('测试歌曲标题测试歌曲标题'), findsOneWidget);
    expectNoOverflow(tester, '刘海屏全屏播放页（竖屏）不应溢出');
  });

  testWidgets('刘海屏横屏 844×390：全屏播放页不溢出', (tester) async {
    setPhone(
      tester,
      size: const Size(844, 390),
      padding: const EdgeInsets.only(top: 24, bottom: 21),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          synologyPlaybackProvider.overrideWith((ref) => _FakePlaybackNotifier(ref)),
        ],
        child: MaterialApp(
          // M2 涟漪（InkRipple）不加载 ink_sparkle shader，规避 Flutter 3.47.2
          // SDK 已知 shader 兼容缺陷（测试侧规避，不改产品主题）
          theme: ThemeData(
            splashFactory: InkRipple.splashFactory,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showFullPlayerSheet(context),
                  child: const Text('打开播放页'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开播放页'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expectNoOverflow(tester, '横屏全屏播放页不应溢出（封面受高度约束）');
  });

  testWidgets('小屏 320×568：全屏播放页控制按钮不溢出（FittedBox 缩放）',
      (tester) async {
    setPhone(tester, size: const Size(320, 568));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          synologyPlaybackProvider.overrideWith((ref) => _FakePlaybackNotifier(ref)),
        ],
        child: MaterialApp(
          // M2 涟漪（InkRipple）不加载 ink_sparkle shader，规避 Flutter 3.47.2
          // SDK 已知 shader 兼容缺陷（测试侧规避，不改产品主题）
          theme: ThemeData(
            splashFactory: InkRipple.splashFactory,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showFullPlayerSheet(context),
                  child: const Text('打开播放页'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开播放页'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // 播放/暂停按钮可见
    expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);
    expectNoOverflow(tester, '小屏全屏播放页控制按钮不应溢出');
  });
}
