import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  test('daily Excel report summarizes sales and profit from HPP', () {
    final sales = [
      SaleRecord(
        receiptNumber: '0001',
        soldAt: DateTime(2026, 11, 12, 9, 15),
        items: const [
          SaleLine(
            productName: 'Roti, "Manis"',
            quantity: 2,
            unitPrice: 5000,
            unitCost: 3000,
          ),
          SaleLine(productName: 'Air Mineral', quantity: 1, unitPrice: 5000),
        ],
        total: 15000,
        cashReceived: 20000,
      ),
      SaleRecord(
        receiptNumber: '0002',
        soldAt: DateTime(2026, 11, 11, 14),
        items: const [
          SaleLine(
            productName: 'Kopi',
            quantity: 1,
            unitPrice: 7000,
            unitCost: 4000,
          ),
        ],
        total: 7000,
        cashReceived: 10000,
      ),
    ];

    final bytes = generateDailySalesXlsx(sales, DateTime(2026, 11, 12));
    final workbook = Excel.decodeBytes(bytes);
    final summary = workbook.tables['Ringkasan']!;
    final details = workbook.tables['Rincian Transaksi']!;

    expect(_integerCell(summary, 'B5'), 1);
    expect(_integerCell(summary, 'B6'), 15000);
    expect(_integerCell(summary, 'B7'), 6000);
    expect(_integerCell(summary, 'B8'), 4000);
    expect(_integerCell(summary, 'B9'), 1);
    expect(
      details.cell(CellIndex.indexByString('D5')).value,
      isA<TextCellValue>().having(
        (value) => value.value.text,
        'product name',
        'Roti, "Manis"',
      ),
    );
    expect(_integerCell(details, 'J5'), 4000);
    expect(
      details.cell(CellIndex.indexByString('G6')).value,
      isA<TextCellValue>().having(
        (value) => value.value.text,
        'missing HPP label',
        'Belum ada HPP',
      ),
    );
    expect(details.maxRows, 6);
  });

  test('old sale lines without saved HPP remain readable', () {
    final line = SaleLine.fromMap({
      'productName': 'Produk lama',
      'quantity': 1,
      'unitPrice': 10000,
    });

    expect(line.unitCost, isNull);
    expect(line.grossProfit, isNull);
  });
}

int _integerCell(Sheet sheet, String address) {
  final value = sheet.cell(CellIndex.indexByString(address)).value;
  expect(value, isA<IntCellValue>());
  return (value! as IntCellValue).value;
}
