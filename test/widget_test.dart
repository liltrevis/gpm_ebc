import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gpm_ebc/core/theme.dart';

void main() {
  testWidgets('Le theme de l\'application se construit', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Center(child: Text('GPM-2EBC'))),
      ),
    );
    expect(find.text('GPM-2EBC'), findsOneWidget);
  });
}
