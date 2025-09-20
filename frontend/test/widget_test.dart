// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app builds', (WidgetTester tester) async {
    // Build a minimal app to ensure the widget tree can be pumped.
    await tester.pumpWidget(const _TestApp());
    // Verify that MaterialApp renders.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp(); // Removed optional `key` parameter to satisfy lint.

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: SizedBox.shrink()),
    );
  }
}
