import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:embytok_flutter/widgets/video/danmaku_overlay.dart';

/// P2-2 回归测试：弹幕回退 seek 后应重新发射新位置之后的弹幕
/// （修复前 _emitCursor 只增不减，回退后弹幕流缺失直到重新推进）。
///
/// 时序说明：发射走 Timer.periodic(500ms)，渲染走帧回调。
/// 步进须用小步多次 pump 才能让 timer 回调的 setState 落到渲染帧上。
void main() {
  // 步进 600ms（跨过 500ms 周期边界）+ 渲染一帧
  Future<void> advance(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump();
  }

  testWidgets('回退 seek：清空已发射弹幕并重新发射回退点之后的弹幕', (tester) async {
    final pos = ValueNotifier<int>(0);
    // 弹幕池：A=10s、B=35s、C=42s（按 startMs 排序）
    const danmakus = [
      DanmakuItem(text: '弹幕A', startMs: 10000, y: 0.2),
      DanmakuItem(text: '弹幕B', startMs: 35000, y: 0.3),
      DanmakuItem(text: '弹幕C', startMs: 42000, y: 0.4),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DanmakuOverlay(positionMs: pos, danmakus: danmakus),
      ),
    ));

    // 初始（0s）：无弹幕
    expect(find.text('弹幕A'), findsNothing);

    // 推进到 10s：A 发射
    pos.value = 10000;
    await advance(tester);
    expect(find.text('弹幕A'), findsOneWidget);

    // 推进到 35s：B 发射（A 已移出屏）
    pos.value = 35000;
    await advance(tester);
    expect(find.text('弹幕B'), findsOneWidget);
    expect(find.text('弹幕A'), findsNothing);

    // 推进到 40s：C 发射（B 移动中）
    pos.value = 40000;
    await advance(tester);
    expect(find.text('弹幕C'), findsOneWidget);

    // 回退 seek 到 33s：帧回调检测回退 → 清空已发射弹幕（不跨 timer 周期）
    pos.value = 33000;
    await tester.pump();
    await tester.pump();
    expect(find.text('弹幕A'), findsNothing);
    expect(find.text('弹幕B'), findsNothing);
    expect(find.text('弹幕C'), findsNothing);

    // 回退后重新发射 [33s, 37s] 窗口内弹幕：B(35s) 应重新出现；
    // A(10s) 已出现过且早于回退点，不重放。
    await advance(tester);
    expect(find.text('弹幕B'), findsOneWidget,
        reason: '回退 seek 后 35s 弹幕应重新发射（修复前 cursor 不回退导致缺失）');
    expect(find.text('弹幕A'), findsNothing, reason: '已出现的旧弹幕不应重放');

    // 卸载，清理 Ticker/Timer
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
