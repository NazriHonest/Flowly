import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
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

/// Exports normalized financial records only.
///
/// Raw financial SMS messages are intentionally never read or exported by
/// this service.
class ExportService {
  ExportService(this._database);

  final AppDatabase _database;

  Future<List<Transaction>> _records(ExportFilter filter) async {
    return (await _database.transactions()).where((transaction) {
      if (filter.start != null && transaction.date.isBefore(filter.start!)) {
        return false;
      }

      if (filter.end != null &&
          transaction.date.isAfter(filter.end!.add(const Duration(days: 1)))) {
        return false;
      }

      if (filter.accountId != null &&
          transaction.accountId != filter.accountId) {
        return false;
      }

      if (filter.category != null && transaction.category != filter.category) {
        return false;
      }

      return filter.type == null || transaction.type == filter.type;
    }).toList();
  }

  Future<File> csv(ExportFilter filter) async {
    final records = await _records(filter);

    String q(Object? value) => '"${'$value'.replaceAll('"', '""')}"';

    final lines = <String>[
      'id,date,type,amount_minor,title,category,account_id,destination_account_id,source,status,notes',
      ...records.map(
        (transaction) => [
          transaction.id,
          transaction.date.toIso8601String(),
          transaction.type.name,
          transaction.amountMinor,
          transaction.title,
          transaction.category,
          transaction.accountId,
          transaction.destinationAccountId ?? '',
          transaction.source.name,
          transaction.status.name,
          transaction.notes,
        ].map(q).join(','),
      ),
    ];

    return _write('transactions.csv', utf8.encode(lines.join('\n')));
  }

  /// Generates the PDF in memory.
  ///
  /// This is used by Android/iOS print preview so the user can preview,
  /// print, or save the report before Flowly writes/shares a separate file.
  Future<Uint8List> pdfBytes(ExportFilter filter) async {
    final records = await _records(filter);

    final income = records
        .where((transaction) => transaction.type == TransactionType.income)
        .fold<int>(0, (sum, transaction) => sum + transaction.amountMinor);

    final expenses = records
        .where((transaction) => transaction.type == TransactionType.expense)
        .fold<int>(0, (sum, transaction) => sum + transaction.amountMinor);

    final net = income - expenses;

    final sortedRecords = [...records]
      ..sort((a, b) => b.date.compareTo(a.date));

    final document = pw.Document(
      title: 'SpenFlo Financial Report',
      author: 'SpenFlo',
      subject: 'Financial report',
      creator: 'SpenFlo',
    );

    final generatedAt = DateTime.now();
    final dateFormatter = DateFormat('MMM d, yyyy');
    final dateTimeFormatter = DateFormat('MMM d, yyyy • h:mm a');

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 36, 32, 36),
        header: (context) {
          if (context.pageNumber == 1) {
            return pw.SizedBox();
          }

          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            margin: const pw.EdgeInsets.only(bottom: 18),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.6),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'SPENFLO',
                  style: pw.TextStyle(
                    color: PdfColors.green800,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.Text(
                  'Financial report',
                  style: const pw.TextStyle(
                    color: PdfColors.grey600,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 18),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.6),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated by SpenFlo',
                style: const pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 8,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
        build: (context) => [
          _buildPdfReportHeader(
            generatedAt: generatedAt,
            formatter: dateTimeFormatter,
          ),

          pw.SizedBox(height: 24),

          _buildPdfSummary(
            income: income,
            expenses: expenses,
            net: net,
            recordCount: records.length,
          ),

          pw.SizedBox(height: 22),

          _buildPdfFilterSummary(filter: filter, dateFormatter: dateFormatter),

          pw.SizedBox(height: 26),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Transactions',
                    style: pw.TextStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey900,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    '${records.length} ${records.length == 1 ? 'record' : 'records'} included',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 10),

          if (sortedRecords.isEmpty)
            _buildPdfEmptyState()
          else
            _buildTransactionTable(sortedRecords, dateFormatter),
        ],
      ),
    );

    return document.save();
  }

  /// Creates a physical PDF file when a file is required by another
  /// workflow such as sharing.
  Future<File> pdf(ExportFilter filter) async {
    final bytes = await pdfBytes(filter);

    return _write('financial-report.pdf', bytes);
  }

  pw.Widget _buildPdfReportHeader({
    required DateTime generatedAt,
    required DateFormat formatter,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 46,
          height: 46,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: PdfColors.green800,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Text(
            'S',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 23,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),

        pw.SizedBox(width: 14),

        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'SpenFlo',
                style: pw.TextStyle(
                  fontSize: 21,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Financial Report',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Generated ${formatter.format(generatedAt)}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfSummary({
    required int income,
    required int expenses,
    required int net,
    required int recordCount,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: _pdfSummaryMetric(
              label: 'INCOME',
              value: MoneyFormatter.format(income),
              color: PdfColors.green700,
            ),
          ),
          _pdfVerticalDivider(),
          pw.Expanded(
            child: _pdfSummaryMetric(
              label: 'EXPENSES',
              value: MoneyFormatter.format(expenses),
              color: PdfColors.red700,
            ),
          ),
          _pdfVerticalDivider(),
          pw.Expanded(
            child: _pdfSummaryMetric(
              label: 'NET',
              value: MoneyFormatter.format(net),
              color: net >= 0 ? PdfColors.green700 : PdfColors.red700,
            ),
          ),
          _pdfVerticalDivider(),
          pw.Expanded(
            child: _pdfSummaryMetric(
              label: 'RECORDS',
              value: '$recordCount',
              color: PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfSummaryMetric({
    required String label,
    required String value,
    required PdfColor color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey600,
              letterSpacing: 0.7,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfVerticalDivider() {
    return pw.Container(width: 0.7, height: 30, color: PdfColors.grey300);
  }

  pw.Widget _buildPdfFilterSummary({
    required ExportFilter filter,
    required DateFormat dateFormatter,
  }) {
    final values = <String>[];

    if (filter.start != null) {
      if (filter.end != null) {
        values.add(
          '${dateFormatter.format(filter.start!)} – '
          '${dateFormatter.format(filter.end!)}',
        );
      } else {
        values.add('From ${dateFormatter.format(filter.start!)}');
      }
    } else {
      values.add('All dates');
    }

    if (filter.accountId != null) {
      values.add('Selected account');
    }

    if (filter.category != null) {
      values.add(filter.category!);
    }

    if (filter.type != null) {
      values.add(_displayEnumName(filter.type!.name));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Report scope',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 7),
        pw.Wrap(
          spacing: 6,
          runSpacing: 6,
          children: values
              .map(
                (value) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
                  ),
                  child: pw.Text(
                    value,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  pw.Widget _buildTransactionTable(
    List<Transaction> records,
    DateFormat dateFormatter,
  ) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder(
        horizontalInside: const pw.BorderSide(
          color: PdfColors.grey300,
          width: 0.5,
        ),
        bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.6),
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.05),
        1: const pw.FlexColumnWidth(0.9),
        2: const pw.FlexColumnWidth(1.8),
        3: const pw.FlexColumnWidth(1.35),
        4: const pw.FlexColumnWidth(1.1),
      },
      headers: const ['Date', 'Type', 'Title', 'Category', 'Amount'],
      data: records
          .map(
            (transaction) => [
              dateFormatter.format(transaction.date),
              _displayEnumName(transaction.type.name),
              transaction.title,
              transaction.category,
              MoneyFormatter.format(transaction.amountMinor),
            ],
          )
          .toList(),
    );
  }

  pw.Widget _buildPdfEmptyState() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'No transactions',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'No transactions matched the selected export filters.',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  String _displayEnumName(String value) {
    if (value.isEmpty) return value;

    final words = value
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll('_', ' ')
        .split(' ');

    return words
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
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
        .where((transaction) => transaction.type == TransactionType.income)
        .fold<int>(0, (sum, transaction) => sum + transaction.amountMinor);

    final expense = records
        .where((transaction) => transaction.type == TransactionType.expense)
        .fold<int>(0, (sum, transaction) => sum + transaction.amountMinor);

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
          ...records.map((transaction) => [transaction.id, transaction.date.toIso8601String(), transaction.type.name, transaction.amountMinor, transaction.title, transaction.category, transaction.accountId]),
        ])}
${worksheet('Accounts', [
          ['Name', 'Type', 'Currency', 'Opening balance'],
          ...accounts.map((account) => [account.name, account.type, account.currency, account.openingBalanceMinor]),
        ])}
${worksheet('Categories', [
          ['Name', 'Type'],
          ...categories.map((category) => [category.name, category.type]),
        ])}
${worksheet('Budgets', [
          ['Name', 'Category', 'Amount', 'Period'],
          ...budgets.map((budget) => [budget.name, budget.category, budget.amountMinor, budget.period]),
        ])}
${worksheet('Goals', [
          ['Name', 'Target', 'Current', 'Target date'],
          ...goals.map((goal) => [goal.name, goal.targetMinor, goal.currentMinor, goal.targetDate?.toIso8601String() ?? '']),
        ])}
</Workbook>''';

    return _write('spenflo-export.xml', utf8.encode(xml));
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
