// 本地演员详情页错误态"重试"入口回归测试
//
// 背景：
// - 错误态（TMDB 请求失败/无网络）原本只有一行"暂无法获取演员信息"，
//   没有任何重试入口，用户只能退出页面重进。
// - 修复：错误态 Column 内补一个 TextButton.icon(icon: Icons.refresh, label: '重试')，
//   onPressed 里 setState(_loading=true) 后重新调用 _load()。
//
// 本测试断言：
// 1. 无网络时错误态文案与"重试"按钮都存在；
// 2. 点击"重试"后不抛异常（无 key 时 TmdbService 返回 null，仍回错误态）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/local_video_provider.dart';
import 'package:embytok_flutter/views/local/person_detail_view.dart';

/// 测试用 LocalVideoNotifier：直接把 state 置空，避免 initState 触盘扫库。
class _FakeLocalVideoNotifier extends LocalVideoNotifier {
  _FakeLocalVideoNotifier(super.ref) {
    state = const LocalVideoState(items: []);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('本地演员详情：错误态显示重试按钮，点击后不崩溃', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localVideoProvider.overrideWith(_FakeLocalVideoNotifier.new),
        ],
        child: const MaterialApp(
          home: PersonDetailPage(personId: 1, name: '测试演员'),
        ),
      ),
    );

    // 触发 _load()：test 环境 HTTP 走 400 mock → TmdbService 内部 catch 返回 null → 错误态
    // 需 pump 超过 8s 超时，让 getPersonDetails/getPersonCredits 的 future 完成
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));

    // 错误态文案与"重试"按钮都存在
    expect(find.text('暂无法获取演员信息'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    // 点击重试：进入 loading 态再回错误态，不应抛异常
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));

    expect(tester.takeException(), isNull,
        reason: '点击重试不应抛异常（_load 内部已 try-catch）');
  });
}
