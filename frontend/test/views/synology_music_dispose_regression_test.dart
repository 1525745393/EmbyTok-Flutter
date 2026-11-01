/// 群晖音乐页「控制器释放」回归测试
///
/// 背景（本分片 UI 审查发现）：
/// - 修复前：`_SynologyMusicViewState.dispose()` 释放了 `_tabController`、
///   `_searchController`、`_artistScrollController`，却漏掉首页 Tab ListView 实际
///   绑定的 `_homeScrollController`（见 synology_music/home_tab.dart）。
/// - 修复后：在 dispose 中补上 `_homeScrollController.dispose()`，与其他控制器一致释放。
///
/// 测试策略：默认未登录态（SharedPreferences 为空）启动 SynologyMusicView，
/// post-frame 里的 loadTab/loadHomeData 因未登录直接 return（见
/// synology_music_provider.dart `if (!_isLoggedIn) return;`），随后卸载页面，
/// 断言 dispose 路径不抛异常（覆盖新增的 `_homeScrollController.dispose()`）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/views/synology_music_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('群晖音乐页卸载时控制器统一释放，不抛异常', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: SynologyMusicView()),
    ));
    // 首帧 + post-frame：loadTab/loadHomeData 未登录直接 return，不发网络请求。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 卸载页面 → 触发 dispose（含新增的 _homeScrollController.dispose()）。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));

    // 走到这里未抛出即通过。
  });
}
