import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('login screen shows branding and password visibility toggle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          accountIds: const [],
          onLogin: (_, _) async => null,
          onRegister: (_, _, _, _) async => null,
        ),
      ),
    );

    expect(find.text('Kasir Kita'), findsOneWidget);
    expect(find.text('Selamat datang 👋'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-id')), findsOneWidget);

    var passwordField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('account-password')),
        matching: find.byType(TextField),
      ),
    );
    expect(passwordField.obscureText, isTrue);

    await tester.tap(find.byTooltip('Tampilkan kata sandi'));
    await tester.pump();

    passwordField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('account-password')),
        matching: find.byType(TextField),
      ),
    );
    expect(passwordField.obscureText, isFalse);
  });
}
