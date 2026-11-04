// 回归测试：VideoPlayerWidget 统一控制句柄（currentPlayerControlProvider）归属
//
// 缺陷（P2-1 句柄竞争）：initState postFrame 无条件注册句柄，预加载的相邻页
// 会抢占当前页句柄；dispose 无条件置 null，非当前页释放会误清空当前页句柄，
// 导致横屏控制层拿到错误句柄（或空句柄）时播放/进度控制失效。
//
// 修复：仅当前页注册；didUpdateWidget 随 isCurrentPage 变化同步句柄归属
// （变当前页→注册、变非当前页→compare-and-set 注销）；dispose 仅当句柄
// 仍指向自身时才置 null。
//
// 测试边界：playbackUrl 为空的 MediaItem 使 _canPlayVideo=false，
// 不触发原生播放器初始化（测试环境无平台实现），句柄注册逻辑独立可测。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/widgets/video/video_player_widget.dart';

MediaItem _fakeItem(String id) => MediaItem(id: id, title: 'item-$id', type: 'Video');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('非当前页不注册句柄，当前页注册句柄', (tester) async {
    SharedPreferences.setMockInitialValues({});

    // 非当前页：预加载的相邻页不抢占句柄
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: VideoPlayerWidget(
            key: const ValueKey('player'),
            item: _fakeItem('a'),
            isCurrentPage: false,
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50)); // postFrame 注册回调
    var container = ProviderScope.containerOf(
      tester.element(find.byType(VideoPlayerWidget)),
    );
    expect(container.read(currentPlayerControlProvider), isNull,
        reason: '非当前页（预加载相邻页）不得注册统一控制句柄');

    // 当前页：注册句柄
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: VideoPlayerWidget(
            key: const ValueKey('player'),
            item: _fakeItem('a'),
            isCurrentPage: true,
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    container = ProviderScope.containerOf(
      tester.element(find.byType(VideoPlayerWidget)),
    );
    expect(container.read(currentPlayerControlProvider), isNotNull,
        reason: '当前页应注册统一控制句柄，供横屏覆盖层调用');
  });

  testWidgets('isCurrentPage 变化时同步句柄归属（注册/注销）', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    Widget scope({required bool isCurrentPage}) => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VideoPlayerWidget(
                key: const ValueKey('player'),
                item: _fakeItem('a'),
                isCurrentPage: isCurrentPage,
              ),
            ),
          ),
        );

    // 初始为非当前页：不注册
    await tester.pumpWidget(scope(isCurrentPage: false));
    await tester.pump(const Duration(milliseconds: 50));
    expect(container.read(currentPlayerControlProvider), isNull);

    // 变为当前页：didUpdateWidget 同步注册
    await tester.pumpWidget(scope(isCurrentPage: true));
    await tester.pump(const Duration(milliseconds: 50));
    expect(container.read(currentPlayerControlProvider), isNotNull,
        reason: '变当前页时应注册句柄');

    // 变回非当前页：didUpdateWidget 同步注销
    await tester.pumpWidget(scope(isCurrentPage: false));
    await tester.pump(const Duration(milliseconds: 50));
    expect(container.read(currentPlayerControlProvider), isNull,
        reason: '变非当前页时应注销句柄（compare-and-set）');

    // 卸载 + 推进时钟：让变非当前页时启动的 800ms 延迟释放 timer 到期
    // （回调带 _isDisposed/mounted 守卫，到期安全退出，不留 pending timer）
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 900));
  });

  testWidgets('非当前页 dispose 不清空当前页句柄（compare-and-set）', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    Widget twoPlayers({required bool showB}) => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 800,
                child: Column(
                  children: [
                    // A：当前页，持有句柄
                    Expanded(
                      child: VideoPlayerWidget(
                        key: const ValueKey('playerA'),
                        item: _fakeItem('a'),
                        isCurrentPage: true,
                      ),
                    ),
                    // B：非当前页（预加载相邻页）
                    if (showB)
                      Expanded(
                        child: VideoPlayerWidget(
                          key: const ValueKey('playerB'),
                          item: _fakeItem('b'),
                          isCurrentPage: false,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(twoPlayers(showB: true));
    await tester.pump(const Duration(milliseconds: 50));
    expect(container.read(currentPlayerControlProvider), isNotNull,
        reason: '前置：当前页 A 已注册句柄');

    // 卸载非当前页 B：其 dispose 不得清空 A 持有的句柄
    await tester.pumpWidget(twoPlayers(showB: false));
    await tester.pump(const Duration(milliseconds: 50));
    expect(container.read(currentPlayerControlProvider), isNotNull,
        reason: '非当前页 dispose 不应清空当前页句柄（修复前无条件 state=null 会误清）');

    // 卸载当前页 A：句柄最终清空
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SizedBox.shrink()),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    expect(container.read(currentPlayerControlProvider), isNull,
        reason: '当前页 dispose 后句柄应清空');
  });
}
