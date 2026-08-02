// RecommendView Widget 测试：验证错误提示通过 ref.listenManual 触发，
// 不在 build 路径中重复注册 postFrameCallback。
//
// 核心修复场景（spec: 推荐页错误提示不在 build 中触发副作用）：
// 1. error 从 null 变为非空 → 弹 SnackBar + 调用 clearError
// 2. 多次 rebuild（state 不变化）→ 不重复触发 SnackBar
// 3. error 被 clearError 清除后，rebuild 不重复调用 clearError
// 4. 连续两次不同 error → clearError 被调用两次
//
// 测试模式：
// - 用 _FakeRecommendNotifier 绕过真实加载逻辑，直接控制 state.error
// - 用 libraryListProvider.overrideWith 永不返回，避免触发 LibrarySelector
// - 通过 clearErrorCount 计数验证副作用触发次数（避免 SnackBar 时序不确定性）

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/views/recommend_view.dart';

/// 模拟 RecommendNotifier：绕过真实加载逻辑，测试直接控制 state.error
///
/// 通过 override load/loadMore/refresh 为空实现，避免触发真实 HTTP 请求。
/// 通过 clearErrorCount 计数验证副作用触发次数。
class _FakeRecommendNotifier extends RecommendNotifier {
  _FakeRecommendNotifier(Ref ref) : super(ref);

  /// clearError 调用计数（用于验证副作用触发次数）
  int clearErrorCount = 0;

  // 覆盖真实加载逻辑：测试通过 setError 直接控制 state
  @override
  Future<void> load() async {}

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> refresh() async {}

  @override
  void clearError() {
    clearErrorCount++;
    state = state.copyWith(error: null);
  }

  /// 测试辅助：直接设置 error 字段，触发 ref.listenManual 回调
  void setError(String? error) {
    state = state.copyWith(error: error);
  }
}

void main() {
  late _FakeRecommendNotifier fakeNotifier;

  /// 构建带 overrides 的 ProviderScope
  ///
  /// - recommendProvider 用 _FakeRecommendNotifier（避免真实加载）
  /// - libraryListProvider 永不返回（保持 loading，避免触发 LibrarySelector 弹窗）
  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        recommendProvider.overrideWith((ref) {
          fakeNotifier = _FakeRecommendNotifier(ref);
          return fakeNotifier;
        }),
        libraryListProvider.overrideWith((ref) async {
          // 永不返回，保持 loading 状态，避免触发 LibrarySelector
          await Completer<void>().future;
          return const <Library>[];
        }),
      ],
      child: const MaterialApp(
        home: RecommendView(),
      ),
    );
  }

  group('RecommendView 错误提示（ref.listenManual 模式）', () {
    testWidgets('error 从 null 变为非空时弹出 SnackBar 并调用 clearError',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // 初始状态：无 SnackBar，clearError 未被调用
      expect(find.byType(SnackBar), findsNothing);
      expect(fakeNotifier.clearErrorCount, 0);

      // 触发 error 状态变化
      fakeNotifier.setError('加载推荐失败');
      // pump 触发 ref.listenManual 回调（同步）+ 注册 postFrameCallback
      await tester.pump();
      // 再 pump 一帧执行 postFrameCallback → 弹 SnackBar + clearError
      await tester.pump();

      // 验证 SnackBar 已弹出
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('加载推荐失败'), findsOneWidget);

      // 验证 clearError 被调用一次（副作用只触发一次）
      expect(fakeNotifier.clearErrorCount, 1);
    });

    testWidgets('多次 rebuild 不重复触发副作用（state 不变化时）',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // 初始状态：无 SnackBar
      expect(find.byType(SnackBar), findsNothing);
      expect(fakeNotifier.clearErrorCount, 0);

      // 多次 rebuild（state 不变化，仅触发 build 方法）
      // 旧实现会在每次 build 中调用 _maybeShowError → 注册 postFrameCallback
      // 新实现通过 ref.listenManual 只在 state 变化时触发，rebuild 不注册
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      // 验证：无 SnackBar，clearError 未被调用
      expect(find.byType(SnackBar), findsNothing);
      expect(fakeNotifier.clearErrorCount, 0);
    });

    testWidgets('error 被 clearError 清除后，rebuild 不重复调用 clearError',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // 第一次设置 error → 弹 SnackBar + clearError
      fakeNotifier.setError('错误一');
      await tester.pump();
      await tester.pump(); // 执行 postFrameCallback

      // clearError 已被调用一次（SnackBar 可能仍可见，但副作用只触发一次）
      expect(fakeNotifier.clearErrorCount, 1);

      // 多次 rebuild，error 已为 null（被 clearError 清除）
      // ref.listenManual 只在 state 变化时触发，rebuild 不触发
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      // 验证：clearError 仍只被调用一次（rebuild 不重复触发副作用）
      expect(fakeNotifier.clearErrorCount, 1);
    });

    testWidgets('连续两次不同 error 触发两次 clearError',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // 第一次 error
      fakeNotifier.setError('错误一');
      await tester.pump();
      await tester.pump();
      expect(fakeNotifier.clearErrorCount, 1);

      // 第二次 error（state 从 error=null 变为 error='错误二'）
      fakeNotifier.setError('错误二');
      await tester.pump();
      await tester.pump();
      expect(fakeNotifier.clearErrorCount, 2);
    });

    testWidgets('error 从非空变为空（手动清除）不触发 SnackBar',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // 设置 error → 触发 SnackBar + clearError
      fakeNotifier.setError('错误信息');
      await tester.pump();
      await tester.pump();
      expect(fakeNotifier.clearErrorCount, 1);

      // 手动设置 error 为空字符串
      fakeNotifier.setError('');
      await tester.pump();
      await tester.pump();

      // clearError 不应被再次调用（error 为空时回调提前返回）
      expect(fakeNotifier.clearErrorCount, 1);
    });
  });

  group('RecommendView 全面屏适配（P0-1）', () {
    testWidgets('_buildBody 外层必须包 SafeArea，bottom=true 用于避让系统手势条',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // 推荐页 Scaffold 的 body 是 _RecommendViewState.build 生成的第一个 widget
      // 其必须以 SafeArea 开头，且 bottom=true（避免末行卡片被系统横条挡住）
      final recommendView = find.byType(RecommendView);
      expect(recommendView, findsOneWidget);

      // 通过 Element 树拿到 RecommendView.build 返回的 Scaffold
      final Scaffold scaffold = tester.widget(find.descendant(
        of: recommendView,
        matching: find.byType(Scaffold),
      ));

      // Scaffold.body 应该直接是 SafeArea
      final body = scaffold.body;
      expect(body, isA<SafeArea>(),
          reason: 'P0-1: 推荐页 body 外层必须包 SafeArea，用于全面屏底部手势条避让');

      final SafeArea safeArea = body as SafeArea;
      expect(safeArea.bottom, isTrue,
          reason: 'SafeArea.bottom=true 才能避让系统手势条');
      expect(safeArea.top, isFalse,
          reason: 'SafeArea.top=false：AppBar 已自动避开刘海，不需要额外 top 安全区');
    });
  });
}
