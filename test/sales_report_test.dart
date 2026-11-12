import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  test('daily CSV includes only that day and escapes product names', () {
    final sales = [
      SaleRecord(
        receiptNumber: '0001',
        soldAt: DateTime(2026, 11, 12, 9, 15),
        items: const [
          SaleLine(productName: 'Roti, "Manis"', quantity: 2, unitPrice: 5000),
        ],
        total: 10000,
        cashReceived: 20000,
      ),
      SaleRecord(
        receiptNumber: '0002',
        soldAt: DateTime(2026, 11, 11, 14),
        items: const [],
        total: 7000,
        cashReceived: 10000,
      ),
    ];

    final csv = generateDailySalesCsv(sales, DateTime(2026, 11, 12));

    expect(csv, contains('"Roti, ""Manis"""'));
    expect(csv, contains('"TOTAL HARIAN (1 transaksi)"'));
    expect(csv, contains('"10000"'));
    expect(csv, isNot(contains('"0002"')));
  });
}
