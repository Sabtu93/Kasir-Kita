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
    expect(find.byKey(const ValueKey('header-clock')), findsOneWidget);
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
    await tester.enterText(find.byKey(const ValueKey('customer-name')), 'Siti');
    await tester.enterText(
      find.byKey(const ValueKey('cash-received')),
      '100000',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selesaikan'));
    await tester.pumpAndSettle();

    expect(
      find.text('Transaksi #0001 berhasil. Kembalian Rp27.500'),
      findsOneWidget,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('kasir_kita_sales_v1_kasir01'), isNotNull);
    expect(preferences.getString('kasir_kita_sales_v1'), isNull);
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

  testWidgets('products are isolated between accounts', (tester) async {
    await tester.pumpWidget(const MinimarketApp());
    await tester.pumpAndSettle();

    await _registerAccount(tester);
    await _addCustomProduct(tester, 'Produk Akun Satu');
    await _closeStore(tester);

    await _registerAccount(tester, accountId: 'kasir02', shopName: 'Toko Dua');
    await tester.enterText(find.byType(TextField).first, 'Produk Akun Satu');
    await tester.pumpAndSettle();
    expect(find.text('Produk Akun Satu'), findsOneWidget);

    await _addCustomProduct(tester, 'Produk Akun Dua');
    await _closeStore(tester);

    await _loginAccount(tester, 'kasir01');
    await _startStore(tester);
    await tester.enterText(find.byType(TextField).first, 'Produk Akun Satu');
    await tester.pumpAndSettle();
    expect(find.text('Produk Akun Satu'), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).first, 'Produk Akun Dua');
    await tester.pumpAndSettle();
    expect(find.text('Produk Akun Dua'), findsOneWidget);
    await _closeStore(tester);

    await _loginAccount(tester, 'kasir02');
    await _startStore(tester);
    await tester.enterText(find.byType(TextField).first, 'Produk Akun Dua');
    await tester.pumpAndSettle();
    expect(find.text('Produk Akun Dua'), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).first, 'Produk Akun Satu');
    await tester.pumpAndSettle();
    expect(find.text('Produk Akun Satu'), findsOneWidget);
  });

  testWidgets('legacy products move to the first account', (tester) async {
    SharedPreferences.setMockInitialValues({
      'kasir_kita_products_v1': '[{"name":"Produk Lama","category":"Khusus","hpp":3000,"imageData":null,"price":5000,"stock":4}]',
    });
    await tester.pumpWidget(const MinimarketApp());
    await tester.pumpAndSettle();

    await _registerAccount(tester);
    await tester.enterText(find.byType(TextField).first, 'Produk Lama');
    await tester.pumpAndSettle();
    expect(find.text('Produk Lama'), findsNWidgets(2));

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('kasir_kita_products_v1_kasir01'),
      contains('Produk Lama'),
    );
    expect(preferences.getString('kasir_kita_products_v1'), isNull);
  });
}

Future<void> _registerAccount(
  WidgetTester tester, {
  String accountId = 'kasir01',
  String shopName = 'Toko Saya',
}) async {
  await tester.tap(find.text('Belum punya akun? Daftar akun'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('shop-name')), shopName);
  await tester.enterText(find.byKey(const ValueKey('account-id')), accountId);
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
  expect(find.text(shopName), findsOneWidget);
}

Future<void> _loginAccount(WidgetTester tester, String accountId) async {
  await tester.tap(find.text(accountId));
  await tester.enterText(
    find.byKey(const ValueKey('account-password')),
    'rahasia123',
  );
  await tester.tap(find.text('Masuk'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

Future<void> _addCustomProduct(WidgetTester tester, String name) async {
  await tester.tap(find.text('Tambah'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('product-name')), name);
  await tester.enterText(
    find.byKey(const ValueKey('product-category')),
    'Khusus Akun',
  );
  await tester.enterText(find.byKey(const ValueKey('product-hpp')), '3000');
  await tester.enterText(find.byKey(const ValueKey('product-price')), '5000');
  await tester.enterText(find.byKey(const ValueKey('product-stock')), '12');
  await tester.tap(find.text('Simpan produk'));
  await tester.pumpAndSettle();
}

Future<void> _closeStore(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Tutup toko'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tutup toko').last);
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
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
