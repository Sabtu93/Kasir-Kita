import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('blocks payment when drawer cash cannot cover change', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaymentDialog(
            total: 100,
            availableCash: 50,
            formatRupiah: (amount) => 'Rp$amount',
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '151');
    await tester.pump();

    final completeButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Selesaikan'),
    );
    expect(completeButton.onPressed, isNull);
    expect(find.text('Kas untuk kembalian tidak mencukupi.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '150');
    await tester.pump();

    final updatedButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Selesaikan'),
    );
    expect(updatedButton.onPressed, isNotNull);
  });
}
