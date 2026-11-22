// 批次6（P3）个人中心入口与退出文案回归测试
//
// - P3-6：切换账号入口仅在群晖已登录时展示；纯视频/未登录会话不展示空群晖弹窗入口
// - P3-2：退出按钮与确认弹窗文案与「全量登出（群晖 + Emby）」实际动作一致

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/providers/synology_music_provider.dart';
import 'package:embytok_flutter/providers/synology_playback_provider.dart';
import 'package:embytok_flutter/views/profile_view.dart';

class _FakeAuthNotifier extends SynologyAuthNotifier {
  _FakeAuthNotifier(super.ref, {required bool loggedIn}) {
    state = SynologyAuthState(
      isLoggedIn: loggedIn,
      serverUrl: loggedIn ? 'http://nas.test:5000' : null,
      account: loggedIn ? 'tester' : null,
      sid: loggedIn ? 'mock-sid' : null,
    );
  }
}

class _FakeMusicNotifier extends SynologyMusicNotifier {
  _FakeMusicNotifier(super.ref) : super();
}

class _FakePlaybackNotifier extends SynologyPlaybackNotifier {
  _FakePlaybackNotifier(super.ref) : super();
}

Widget _buildProfile(bool loggedIn) {
  return ProviderScope(
    overrides: [
      synologyAuthProvider.overrideWith((ref) => _FakeAuthNotifier(ref, loggedIn: loggedIn)),
      synologyMusicProvider.overrideWith((ref) => _FakeMusicNotifier(ref)),
      synologyPlaybackProvider
          .overrideWith((ref) => _FakePlaybackNotifier(ref)),
    ],
    child: MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: const ProfileView(showBackButton: false),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ListView 懒加载：退出按钮位于列表底部，需滚动进入视口才会挂载
  Future<void> scrollToLogout(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('退出全部账号'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('群晖已登录：显示切换账号入口，退出按钮文案为「退出全部账号」',
      (tester) async {
    await tester.pumpWidget(_buildProfile(true));
    await tester.pumpAndSettle();

    expect(find.text('切换账号'), findsOneWidget);
    await scrollToLogout(tester);
    expect(find.text('退出全部账号'), findsOneWidget);
    expect(find.text('退出群晖登录'), findsNothing,
        reason: '全量登出动作不应再使用「退出群晖登录」文案');
  });

  testWidgets('未登录群晖：隐藏切换账号入口，避免点开空群晖弹窗', (tester) async {
    await tester.pumpWidget(_buildProfile(false));
    await tester.pumpAndSettle();

    expect(find.text('切换账号'), findsNothing);
  });

  testWidgets('退出弹窗说明将同时退出群晖与视频服务器账号', (tester) async {
    await tester.pumpWidget(_buildProfile(true));
    await tester.pumpAndSettle();

    await scrollToLogout(tester);
    await tester.tap(find.text('退出全部账号'));
    await tester.pumpAndSettle();

    expect(find.text('退出登录'), findsOneWidget);
    expect(find.textContaining('视频服务器'), findsOneWidget,
        reason: '弹窗需说明全量登出会同时退出视频服务器，与 logoutAllAccounts 动作一致');
  });
}
