import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/main.dart';

void main() {
  testWidgets('app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EmbyTokApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
