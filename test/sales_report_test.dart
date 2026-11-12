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

  test('monthly Excel report includes all sales in the selected month only', () {
    final sales = [
      SaleRecord(
        receiptNumber: '0001',
        soldAt: DateTime(2026, 11, 1, 9),
        items: const [
          SaleLine(
            productName: 'Kopi',
            quantity: 2,
            unitPrice: 5000,
            unitCost: 3000,
          ),
        ],
        total: 10000,
        cashReceived: 15000,
      ),
      SaleRecord(
        receiptNumber: '0002',
        soldAt: DateTime(2026, 11, 30, 18),
        items: const [
          SaleLine(
            productName: 'Teh',
            quantity: 1,
            unitPrice: 7000,
            unitCost: 4000,
          ),
        ],
        total: 7000,
        cashReceived: 10000,
      ),
      SaleRecord(
        receiptNumber: '0003',
        soldAt: DateTime(2026, 12, 1, 8),
        items: const [
          SaleLine(
            productName: 'Air',
            quantity: 1,
            unitPrice: 3000,
            unitCost: 1000,
          ),
        ],
        total: 3000,
        cashReceived: 5000,
      ),
    ];

    final workbook = Excel.decodeBytes(
      generateMonthlySalesXlsx(sales, 2026, 11),
    );
    final summary = workbook.tables['Ringkasan']!;
    final details = workbook.tables['Rincian Transaksi']!;

    expect(_integerCell(summary, 'B5'), 2);
    expect(_integerCell(summary, 'B6'), 17000);
    expect(_integerCell(summary, 'B7'), 10000);
    expect(_integerCell(summary, 'B8'), 7000);
    expect(details.maxRows, 6);
    expect(
      details.cell(CellIndex.indexByString('A5')).value,
      isA<TextCellValue>().having(
        (value) => value.value.text,
        'first transaction date',
        '01/11/2026',
      ),
    );
    expect(
      details.cell(CellIndex.indexByString('A6')).value,
      isA<TextCellValue>().having(
        (value) => value.value.text,
        'last transaction date',
        '30/11/2026',
      ),
    );
  });
}

int _integerCell(Sheet sheet, String address) {
  final value = sheet.cell(CellIndex.indexByString(address)).value;
  expect(value, isA<IntCellValue>());
  return (value! as IntCellValue).value;
}
