// 回归测试：P3-7 ProfileView 顶栏返回按钮仅在独立路由显示
//
// 旧实现：Tab 页（MainView）点「我的」后 AppBar 上的返回箭头执行 context.go('/')，
// 重建 MainView 使 _currentIndex 归 0，用户被从「我的」Tab 弹回首页 Tab。
// 修复：ProfileView 增加 showBackButton 参数——Tab 内传 false（不渲染返回箭头），
// 独立路由页 /profile 保持默认 true。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/providers/synology_music_provider.dart';
import 'package:embytok_flutter/providers/synology_playback_provider.dart';
import 'package:embytok_flutter/views/profile_view.dart';

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

class _FakeMusicNotifier extends SynologyMusicNotifier {
  _FakeMusicNotifier(super.ref) : super();
}

class _FakePlaybackNotifier extends SynologyPlaybackNotifier {
  _FakePlaybackNotifier(super.ref) : super();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildView({required bool showBackButton}) {
    return ProviderScope(
      overrides: [
        synologyAuthProvider.overrideWith((ref) => _FakeAuthNotifier(ref)),
        synologyMusicProvider.overrideWith((ref) => _FakeMusicNotifier(ref)),
        synologyPlaybackProvider
            .overrideWith((ref) => _FakePlaybackNotifier(ref)),
      ],
      child: MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: ProfileView(showBackButton: showBackButton),
      ),
    );
  }

  testWidgets('Tab 内不显示返回箭头，独立路由保留返回箭头', (tester) async {
    // Tab 页内（MainView 传 showBackButton: false）
    await tester.pumpWidget(buildView(showBackButton: false));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.text('个人中心'), findsOneWidget);

    // 独立路由页（/profile 默认 true）
    await tester.pumpWidget(buildView(showBackButton: true));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });
}
