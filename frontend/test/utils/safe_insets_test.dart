// safe_insets 单元测试
//
// 验证物理安全区取值工具的正确性。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/utils/safe_insets.dart';

void main() {
  group('SafeInsets', () {
    testWidgets('of 返回 EdgeInsets 类型', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final insets = SafeInsets.of(context);
              expect(insets, isA<EdgeInsets>());
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('topOf 返回 double 类型', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final top = SafeInsets.topOf(context);
              expect(top, isA<double>());
              expect(top >= 0, true);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('bottomOf 返回 double 类型', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final bottom = SafeInsets.bottomOf(context);
              expect(bottom, isA<double>());
              expect(bottom >= 0, true);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('leftOf 返回 double 类型', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final left = SafeInsets.leftOf(context);
              expect(left, isA<double>());
              expect(left >= 0, true);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('rightOf 返回 double 类型', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final right = SafeInsets.rightOf(context);
              expect(right, isA<double>());
              expect(right >= 0, true);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('无安全区时返回零值', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final insets = SafeInsets.of(context);
              expect(insets.left, 0);
              expect(insets.top, 0);
              expect(insets.right, 0);
              expect(insets.bottom, 0);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('取 padding 和 viewPadding 的最大值', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(top: 20, bottom: 10),
              viewPadding: EdgeInsets.only(top: 44, bottom: 34),
            ),
            child: Builder(
              builder: (context) {
                final insets = SafeInsets.of(context);
                expect(insets.top, 44);
                expect(insets.bottom, 34);
                expect(insets.left, 0);
                expect(insets.right, 0);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('padding 大于 viewPadding 时取 padding', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(top: 50, left: 20),
              viewPadding: EdgeInsets.only(top: 30, left: 10),
            ),
            child: Builder(
              builder: (context) {
                final insets = SafeInsets.of(context);
                expect(insets.top, 50);
                expect(insets.left, 20);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('四边都有安全区时正确计算', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(left: 5, top: 10, right: 15, bottom: 20),
              viewPadding: EdgeInsets.only(left: 15, top: 25, right: 35, bottom: 45),
            ),
            child: Builder(
              builder: (context) {
                final insets = SafeInsets.of(context);
                expect(insets.left, 15);
                expect(insets.top, 25);
                expect(insets.right, 35);
                expect(insets.bottom, 45);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('topOf/bottomOf/leftOf/rightOf 与 of 一致', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(left: 10, top: 20, right: 30, bottom: 40),
              viewPadding: EdgeInsets.zero,
            ),
            child: Builder(
              builder: (context) {
                final insets = SafeInsets.of(context);
                expect(SafeInsets.topOf(context), insets.top);
                expect(SafeInsets.bottomOf(context), insets.bottom);
                expect(SafeInsets.leftOf(context), insets.left);
                expect(SafeInsets.rightOf(context), insets.right);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    });
  });
}
