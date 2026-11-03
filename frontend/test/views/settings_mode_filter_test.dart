/// 设置页服务模式分组过滤测试
///
/// 验证「模式分组对称隐藏」：
/// - 音乐模式：不显示 视频库/规则筛选/播放/字幕/统计 分组与「视频方向」项，
///   保留 音乐服务/存储/外观（主题）/关于
///   （「服务器与账户」分区已整体迁移至登录页 LoginView，设置页不再展示）
/// - 视频模式（默认）：显示 视频库/统计 等视频相关分组，隐藏 音乐服务
///   （与登录页账号类型↔模式对称联动一致）
///
/// 注意：设置页为 ListView（懒加载），屏幕外分组不会构建，
/// 通过分步滚动收集全列表出现过的分组标题再断言。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/views/settings_view.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Widget wrap() {
    return const ProviderScope(
      child: MaterialApp(home: SettingsView()),
    );
  }

  /// 从顶部分步滚动到底，收集全列表出现过的分组标题
  Future<Set<String>> collectVisibleSections(
      WidgetTester tester, List<String> targets) async {
    final found = <String>{};
    final scrollable = find.byType(Scrollable).first;
    // 先滚到顶部
    await tester.drag(scrollable, const Offset(0, 5000));
    await tester.pumpAndSettle();
    for (int i = 0; i < 50; i++) {
      for (final t in targets) {
        if (find.text(t).evaluate().isNotEmpty) found.add(t);
      }
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    // 底部再收集一次
    for (final t in targets) {
      if (find.text(t).evaluate().isNotEmpty) found.add(t);
    }
    return found;
  }

  testWidgets('视频模式（默认）：显示视频分组，隐藏音乐服务', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 设置页分组已重排：
    // - 视频库/规则筛选(二级)/播放/字幕 保留，音乐服务隐藏（模式分组对称）
    // - "统计"已并入"通用工具"（不再独立分组）
    // - "服务器与账户"分区已整体迁移至登录页 LoginView（batch126）
    final found = await collectVisibleSections(
        tester, ['视频库', '规则筛选', '播放', '字幕', '音乐服务']);

    for (final section in ['视频库', '规则筛选', '播放', '字幕']) {
      expect(found, contains(section), reason: '视频模式应显示「$section」');
    }
    expect(found, isNot(contains('音乐服务')),
        reason: '视频模式不应显示「音乐服务」分组（与音乐侧隐藏视频分组对称）');
  });

  testWidgets('音乐模式：隐藏视频相关分组，保留音乐服务', (tester) async {
    SharedPreferences.setMockInitialValues({'app_service_mode': 'music'});
    await tester.pumpWidget(wrap());
    // 等待 ServiceModeNotifier._loadFromStorage 完成
    await tester.pumpAndSettle();

    final found = await collectVisibleSections(tester, [
      '视频库', '规则筛选', '播放', '字幕', '视频方向',
      '音乐服务', '存储与缓存', '外观', '关于',
    ]);

    // 视频相关分组隐藏
    for (final section in ['视频库', '规则筛选', '播放', '字幕', '视频方向']) {
      expect(found, isNot(contains(section)),
          reason: '音乐模式不应显示「$section」');
    }
    // 音乐库与通用分组保留（「服务器与账户」已整体迁移至登录页，不再出现）
    for (final section in ['音乐服务', '存储与缓存', '外观', '关于']) {
      expect(found, contains(section), reason: '音乐模式应保留「$section」');
    }
  });
}
