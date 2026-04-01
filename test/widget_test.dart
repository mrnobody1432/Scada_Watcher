import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scada_alarm_client/main.dart';

void main() {
  testWidgets('SCADA app loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ScadaAlarmApp()));
    await tester.pumpAndSettle();

    // Verify app title exists
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
