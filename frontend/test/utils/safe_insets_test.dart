import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/utils/safe_insets.dart';

void main() {
  group('SafeInsets', () {
    // 用 MediaQuery 注入自定义 data，Builder 暴露 context 供断言
    Widget wrapWith(MediaQueryData data, Widget child) {
      return MediaQuery(data: data, child: Builder(builder: (_) => child));
    }

    testWidgets('沉浸式下 padding=0 时返回 viewPadding', (tester) async {
      const viewPadding = EdgeInsets.only(top: 44, bottom: 34);
      EdgeInsets? result;
      await tester.pumpWidget(
        wrapWith(
          const MediaQueryData(
            padding: EdgeInsets.zero,
            viewPadding: viewPadding,
          ),
          Builder(builder: (ctx) {
            result = SafeInsets.of(ctx);
            return const SizedBox();
          }),
        ),
      );
      expect(result, viewPadding);
    });

    testWidgets('非沉浸式下 padding==viewPadding 时返回 padding', (tester) async {
      const inset = EdgeInsets.only(top: 44, bottom: 34);
      EdgeInsets? result;
      await tester.pumpWidget(
        wrapWith(
          const MediaQueryData(padding: inset, viewPadding: inset),
          Builder(builder: (ctx) {
            result = SafeInsets.of(ctx);
            return const SizedBox();
          }),
        ),
      );
      expect(result, inset);
    });

    testWidgets('padding > viewPadding 时返回 padding', (tester) async {
      const padding = EdgeInsets.all(20);
      const viewPadding = EdgeInsets.all(10);
      EdgeInsets? result;
      await tester.pumpWidget(
        wrapWith(
          const MediaQueryData(padding: padding, viewPadding: viewPadding),
          Builder(builder: (ctx) {
            result = SafeInsets.of(ctx);
            return const SizedBox();
          }),
        ),
      );
      expect(result, padding);
    });

    testWidgets('横屏左右刘海：viewPadding 左右非 0 时正确返回', (tester) async {
      const viewPadding = EdgeInsets.only(left: 60, right: 40);
      double? left;
      double? right;
      await tester.pumpWidget(
        wrapWith(
          const MediaQueryData(
            padding: EdgeInsets.zero,
            viewPadding: viewPadding,
          ),
          Builder(builder: (ctx) {
            left = SafeInsets.leftOf(ctx);
            right = SafeInsets.rightOf(ctx);
            return const SizedBox();
          }),
        ),
      );
      expect(left, 60);
      expect(right, 40);
    });
  });
}
