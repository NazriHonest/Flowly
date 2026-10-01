import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/database/app_database.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../transactions/domain/entities/transaction.dart';

class ExportFilter {
  const ExportFilter({
    this.start,
    this.end,
    this.accountId,
    this.category,
    this.type,
  });
  final DateTime? start;
  final DateTime? end;
  final int? accountId;
  final String? category;
  final TransactionType? type;
}

/// Exports normalized financial records only. Raw messages are intentionally
/// not read by this service.
class ExportService {
  ExportService(this._database);
  final AppDatabase _database;

  Future<List<Transaction>> _records(
    ExportFilter filter,
  ) async => (await _database.transactions()).where((t) {
    if (filter.start != null && t.date.isBefore(filter.start!)) return false;
    if (filter.end != null &&
        t.date.isAfter(filter.end!.add(const Duration(days: 1)))) {
      return false;
    }
    if (filter.accountId != null && t.accountId != filter.accountId) {
      return false;
    }
    if (filter.category != null && t.category != filter.category) return false;
    return filter.type == null || t.type == filter.type;
  }).toList();

  Future<File> csv(ExportFilter filter) async {
    final records = await _records(filter);
    String q(Object? value) => '"${'$value'.replaceAll('"', '""')}"';
    final lines = <String>[
      'id,date,type,amount_minor,title,category,account_id,destination_account_id,source,status,notes',
      ...records.map(
        (t) => [
          t.id,
          t.date.toIso8601String(),
          t.type.name,
          t.amountMinor,
          t.title,
          t.category,
          t.accountId,
          t.destinationAccountId ?? '',
          t.source.name,
          t.status.name,
          t.notes,
        ].map(q).join(','),
      ),
    ];
    return _write('transactions.csv', utf8.encode(lines.join('\n')));
  }

  Future<File> pdf(ExportFilter filter) async {
    final records = await _records(filter);
    final income = records
        .where((e) => e.type == TransactionType.income)
        .fold(0, (int a, e) => a + e.amountMinor);
    final expenses = records
        .where((e) => e.type == TransactionType.expense)
        .fold(0, (int a, e) => a + e.amountMinor);
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Header(level: 0, child: pw.Text('Flowly financial report')),
          pw.Text('Generated ${DateTime.now().toLocal()}'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['Income', 'Expenses', 'Net', 'Records'],
            data: [
              [
                MoneyFormatter.format(income),
                MoneyFormatter.format(expenses),
                MoneyFormatter.format(income - expenses),
                '${records.length}',
              ],
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text('Transactions', style: pw.TextStyle(fontSize: 18)),
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Type', 'Title', 'Category', 'Amount'],
            data: records
                .map(
                  (t) => [
                    t.date.toIso8601String().split('T').first,
                    t.type.name,
                    t.title,
                    t.category,
                    MoneyFormatter.format(t.amountMinor),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    return _write('financial-report.pdf', await document.save());
  }

  /// SpreadsheetML opens in Excel/LibreOffice and preserves independent
  /// summary, transaction, account, category, budget and goal worksheets.
  Future<File> xlsx(ExportFilter filter) async {
    final records = await _records(filter);
    final accounts = await _database.accounts();
    final categories = await _database.categories();
    final budgets = await _database.budgets();
    final goals = await _database.goals();
    String cell(Object? value) =>
        '<Cell><Data ss:Type="String">${_xml('$value')}</Data></Cell>';
    String worksheet(String name, List<List<Object?>> rows) =>
        '<Worksheet ss:Name="$name"><Table>${rows.map((row) => '<Row>${row.map(cell).join()}</Row>').join()}</Table></Worksheet>';
    final income = records
        .where((e) => e.type == TransactionType.income)
        .fold(0, (int a, e) => a + e.amountMinor);
    final expense = records
        .where((e) => e.type == TransactionType.expense)
        .fold(0, (int a, e) => a + e.amountMinor);
    final xml =
        '''<?xml version="1.0"?><Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
${worksheet('Summary', [
          ['Metric', 'Value'],
          ['Income', MoneyFormatter.format(income)],
          ['Expenses', MoneyFormatter.format(expense)],
          ['Net', MoneyFormatter.format(income - expense)],
          ['Transactions', records.length],
        ])}
${worksheet('Transactions', [
          ['Id', 'Date', 'Type', 'Amount minor', 'Title', 'Category', 'Account'],
          ...records.map((t) => [t.id, t.date.toIso8601String(), t.type.name, t.amountMinor, t.title, t.category, t.accountId]),
        ])}
${worksheet('Accounts', [
          ['Name', 'Type', 'Currency', 'Opening balance'],
          ...accounts.map((a) => [a.name, a.type, a.currency, a.openingBalanceMinor]),
        ])}
${worksheet('Categories', [
          ['Name', 'Type'],
          ...categories.map((c) => [c.name, c.type]),
        ])}
${worksheet('Budgets', [
          ['Name', 'Category', 'Amount', 'Period'],
          ...budgets.map((b) => [b.name, b.category, b.amountMinor, b.period]),
        ])}
${worksheet('Goals', [
          ['Name', 'Target', 'Current', 'Target date'],
          ...goals.map((g) => [g.name, g.targetMinor, g.currentMinor, g.targetDate?.toIso8601String() ?? '']),
        ])}
</Workbook>''';
    return _write('flowly-export.xml', utf8.encode(xml));
  }

  Future<File> _write(String name, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
