import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('cashier can add a product to the cart', (tester) async {
    await tester.pumpWidget(const MinimarketApp());
    await tester.pumpAndSettle();

    await _registerAccount(tester);
    expect(find.text('Toko Saya'), findsOneWidget);
    expect(find.text('Daftar Produk'), findsOneWidget);
    expect(find.byTooltip('Unduh laporan penjualan'), findsOneWidget);
    await tester.tap(find.byTooltip('Unduh laporan penjualan'));
    await tester.pumpAndSettle();
    expect(find.text('Laporan bulanan'), findsOneWidget);
    await tester.tap(find.text('Laporan bulanan'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih tanggal dalam bulan laporan'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Beras Setra Ramos 5kg'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beras Setra Ramos 5kg'));
    await tester.pumpAndSettle();

    expect(find.text('1 item di keranjang'), findsOneWidget);
    expect(find.text('Rp72.500'), findsNWidgets(2));
    expect(find.text('Lihat Pesanan'), findsOneWidget);

    await tester.tap(find.text('Lihat Pesanan'));
    await tester.pumpAndSettle();

    expect(find.text('Pesanan'), findsOneWidget);
    expect(find.text('Beras Setra Ramos 5kg'), findsNWidgets(2));
    expect(find.text('Bayar Sekarang'), findsOneWidget);

    await tester.tap(find.text('Bayar Sekarang'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '100000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selesaikan'));
    await tester.pumpAndSettle();

    expect(
      find.text('Transaksi #0001 berhasil. Kembalian Rp27.500'),
      findsOneWidget,
    );
  });

  testWidgets('new products and accounts are saved on this device', (
    tester,
  ) async {
    await tester.pumpWidget(const MinimarketApp());
    await tester.pumpAndSettle();
    await _registerAccount(tester);

    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('product-name')),
      'Teh Botol',
    );
    await tester.enterText(
      find.byKey(const ValueKey('product-category')),
      'Minuman Dingin',
    );
    await tester.enterText(find.byKey(const ValueKey('product-hpp')), '3000');
    await tester.enterText(find.byKey(const ValueKey('product-price')), '5000');
    await tester.enterText(find.byKey(const ValueKey('product-stock')), '12');
    await tester.tap(find.text('Simpan produk'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Teh Botol');
    await tester.pumpAndSettle();

    expect(find.text('Teh Botol'), findsNWidgets(2));
    expect(find.text('Minuman Dingin'), findsOneWidget);
    expect(find.text('HPP Rp3.000'), findsOneWidget);
    expect(find.text('Rp5.000'), findsOneWidget);

    await tester.tap(find.byTooltip('Tutup toko'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tutup toko').last);
    await tester.pumpAndSettle();
    expect(find.text('kasir01'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('account-id')), 'kasir01');
    await tester.enterText(
      find.byKey(const ValueKey('account-password')),
      'rahasia123',
    );
    await tester.tap(find.text('Masuk'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await _startStore(tester);
    await tester.enterText(find.byType(TextField).first, 'Teh Botol');
    await tester.pumpAndSettle();

    expect(find.text('Teh Botol'), findsNWidgets(2));
    expect(find.text('HPP Rp3.000'), findsOneWidget);
  });
}

Future<void> _registerAccount(WidgetTester tester) async {
  await tester.tap(find.text('Belum punya akun? Daftar akun'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('shop-name')), 'Toko Saya');
  await tester.enterText(find.byKey(const ValueKey('account-id')), 'kasir01');
  await tester.enterText(
    find.byKey(const ValueKey('account-password')),
    'rahasia123',
  );
  await tester.enterText(
    find.byKey(const ValueKey('account-confirm-password')),
    'rahasia123',
  );
  await tester.ensureVisible(find.text('Buat akun'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Buat akun'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
  await _startStore(tester);
  expect(find.text('Toko Saya'), findsOneWidget);
}

Future<void> _startStore(WidgetTester tester) async {
  expect(find.text('Buka toko'), findsOneWidget);
  final cashField = find.byType(TextField).last;
  await tester.tap(cashField);
  await tester.enterText(cashField, '200000');
  await tester.pump();
  final startButton = tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Mulai toko'),
  );
  expect(startButton.onPressed, isNotNull);
  await tester.tap(find.text('Mulai toko'));
  await tester.pumpAndSettle();
  expect(find.text('Buka toko'), findsNothing);
}
