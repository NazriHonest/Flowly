import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowly/core/database/app_database.dart';
import 'package:flowly/features/accounts/domain/entities/account.dart';
import 'package:flowly/features/export/data/export_service.dart';
import 'package:flowly/features/transactions/domain/entities/transaction.dart';

void main() {
  final service = ExportService(AppDatabase.forTesting('unused.db'));
  const accounts = [
    Account(id: 1, name: 'Main Account', openingBalanceMinor: 0),
    Account(id: 2, name: 'Savings', openingBalanceMinor: 0),
  ];
  final records = [
    Transaction(
      id: 1,
      amountMinor: 120000,
      type: TransactionType.income,
      title: 'Salary',
      category: 'Salary',
      accountId: 1,
      date: DateTime(2026, 10, 12),
    ),
    Transaction(
      id: 2,
      amountMinor: 4500,
      type: TransactionType.expense,
      title: '=HYPERLINK("bad")',
      category: 'Food, groceries',
      accountId: 1,
      date: DateTime(2026, 10, 11),
      notes: 'Milk, bread\nand fruit',
    ),
    Transaction(
      id: 3,
      amountMinor: 20000,
      type: TransactionType.transfer,
      title: 'Savings transfer',
      category: 'Internal Transfer',
      accountId: 1,
      destinationAccountId: 2,
      date: DateTime(2026, 10, 10),
    ),
    Transaction(
      id: 4,
      amountMinor: 99999,
      type: TransactionType.expense,
      title: 'Ignored candidate',
      category: 'Other',
      accountId: 1,
      date: DateTime(2026, 10, 9),
      status: ReviewStatus.ignored,
    ),
  ];

  test('summary classifies transfers without changing net cash flow', () async {
    final prepared = await service.prepareFromRecords(
      ExportFormat.csv,
      const ExportFilter(),
      records,
      accounts: accounts,
      generatedAt: DateTime(2026, 10, 13),
    );

    expect(prepared.summary.incomeMinor, 120000);
    expect(prepared.summary.expenseMinor, 4500);
    expect(prepared.summary.transferMinor, 20000);
    expect(prepared.summary.netMinor, 115500);
    expect(prepared.summary.transactionCount, 3);
    expect(prepared.rows.last.typeLabel, 'Transfer');
    expect(prepared.rows.last.movement, 'Main Account → Savings');
  });

  test('CSV is escaped, human-readable, and formula-safe', () async {
    final prepared = await service.prepareFromRecords(
      ExportFormat.csv,
      const ExportFilter(),
      records,
      accounts: accounts,
      generatedAt: DateTime(2026, 10, 13),
    );
    final csv = utf8.decode(prepared.bytes);
    final rows = const CsvToListConverter().convert(csv);

    expect(rows.first, [
      'Date',
      'Description',
      'Transaction Type',
      'Category',
      'Source Account',
      'Destination Account',
      'Amount (USD)',
      'Notes',
    ]);
    expect(rows[2][1], startsWith("'="));
    expect(rows[2][3], 'Food, groceries');
    expect(rows[2][7], 'Milk, bread\nand fruit');
    expect(rows[3][2], 'Transfer');
    expect(rows[3][4], 'Main Account');
    expect(rows[3][5], 'Savings');
    expect(rows[3][6], 200);
    expect(csv, isNot(contains('account_id')));
  });

  test('XLSX has native sheets and numeric amount cells', () async {
    final prepared = await service.prepareFromRecords(
      ExportFormat.excel,
      const ExportFilter(),
      records,
      accounts: accounts,
      generatedAt: DateTime(2026, 10, 13),
    );
    expect(prepared.filename, endsWith('.xlsx'));
    expect(prepared.bytes.take(2), [0x50, 0x4b]);

    final workbook = Excel.decodeBytes(prepared.bytes);
    expect(workbook.tables.keys, containsAll(['Summary', 'Transactions']));
    final transactionSheet = workbook.tables['Transactions']!;
    expect(transactionSheet.rows.first[2]!.value, TextCellValue('Type'));
    final amount = transactionSheet.rows[1][6]!.value;
    expect(amount, anyOf(isA<IntCellValue>(), isA<DoubleCellValue>()));
    expect(switch (amount) {
      IntCellValue() => amount.value.toDouble(),
      DoubleCellValue() => amount.value,
      _ => null,
    }, 1200.0);
    expect(transactionSheet.rows[3][2]!.value, TextCellValue('Transfer'));
  });

  test('PDF is generated for empty and multi-page reports', () async {
    final empty = await service.prepareFromRecords(
      ExportFormat.pdf,
      const ExportFilter(),
      const [],
      accounts: accounts,
      generatedAt: DateTime(2026, 10, 13),
    );
    expect(ascii.decode(empty.bytes.take(4).toList()), '%PDF');

    final many = List.generate(
      120,
      (index) => Transaction(
        amountMinor: 100 + index,
        type: index.isEven ? TransactionType.income : TransactionType.expense,
        title: 'Transaction $index with a reasonably long description',
        category: 'Category',
        accountId: 1,
        date: DateTime(2026, 10, 13).subtract(Duration(days: index)),
      ),
    );
    final large = await service.prepareFromRecords(
      ExportFormat.pdf,
      const ExportFilter(),
      many,
      accounts: accounts,
      generatedAt: DateTime(2026, 10, 13),
    );
    expect(large.rows, hasLength(120));
    expect(large.bytes.length, greaterThan(empty.bytes.length * 2));
    final pdfSource = latin1.decode(large.bytes, allowInvalid: true);
    expect(
      RegExp(r'/Type\s*/Page\b').allMatches(pdfSource).length,
      greaterThan(1),
    );
  });

  test('all formats retain the same canonical rows', () async {
    final prepared = await Future.wait(
      ExportFormat.values.map(
        (format) => service.prepareFromRecords(
          format,
          const ExportFilter(),
          records,
          accounts: accounts,
          generatedAt: DateTime(2026, 10, 13),
        ),
      ),
    );
    expect(prepared.map((item) => item.rows.length).toSet(), {3});
    expect(prepared.map((item) => item.summary.netMinor).toSet(), {115500});
  });
}
