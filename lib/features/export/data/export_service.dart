import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/database/app_database.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../accounts/domain/entities/account.dart';
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

enum ExportFormat { csv, excel, pdf }

extension ExportFormatDetails on ExportFormat {
  String get label => switch (this) {
    ExportFormat.csv => 'CSV',
    ExportFormat.excel => 'Excel',
    ExportFormat.pdf => 'PDF',
  };
  String get extension => switch (this) {
    ExportFormat.csv => 'csv',
    ExportFormat.excel => 'xlsx',
    ExportFormat.pdf => 'pdf',
  };
  String get mimeType => switch (this) {
    ExportFormat.csv => 'text/csv',
    ExportFormat.excel =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ExportFormat.pdf => 'application/pdf',
  };
}

class ExportRow {
  const ExportRow({
    required this.date,
    required this.description,
    required this.type,
    required this.category,
    required this.sourceAccount,
    required this.destinationAccount,
    required this.amountMinor,
    required this.notes,
  });

  final DateTime date;
  final String description;
  final TransactionType type;
  final String category;
  final String sourceAccount;
  final String? destinationAccount;
  final int amountMinor;
  final String notes;

  String get typeLabel => switch (type) {
    TransactionType.income => 'Income',
    TransactionType.expense => 'Expense',
    TransactionType.transfer => 'Transfer',
  };

  String get movement => type == TransactionType.transfer
      ? '$sourceAccount → ${destinationAccount ?? 'Unavailable account'}'
      : sourceAccount;

  int get signedAmountMinor => switch (type) {
    TransactionType.income => amountMinor.abs(),
    TransactionType.expense => -amountMinor.abs(),
    TransactionType.transfer => amountMinor.abs(),
  };
}

class ExportSummary {
  const ExportSummary({
    required this.incomeMinor,
    required this.expenseMinor,
    required this.transferMinor,
    required this.transactionCount,
  });

  final int incomeMinor;
  final int expenseMinor;
  final int transferMinor;
  final int transactionCount;
  int get netMinor => incomeMinor - expenseMinor;
}

class PreparedExport {
  PreparedExport({
    required this.format,
    required this.filter,
    required this.filename,
    required this.bytes,
    required this.printablePdfBytes,
    required this.generatedAt,
    required this.periodLabel,
    required this.accountFilterLabel,
    required List<Transaction> records,
    required List<ExportRow> rows,
    required this.summary,
  }) : records = List.unmodifiable(records),
       rows = List.unmodifiable(rows);

  final ExportFormat format;
  final ExportFilter filter;
  final String filename;
  final Uint8List bytes;
  final Uint8List printablePdfBytes;
  final DateTime generatedAt;
  final String periodLabel;
  final String accountFilterLabel;
  final List<Transaction> records;
  final List<ExportRow> rows;
  final ExportSummary summary;

  int get incomeMinor => summary.incomeMinor;
  int get expenseMinor => summary.expenseMinor;
}

/// Produces every format from one immutable, confirmed transaction snapshot.
class ExportService {
  ExportService(this._database);

  final AppDatabase _database;

  Future<List<Transaction>> records(ExportFilter filter) async {
    return (await _database.transactions()).where((transaction) {
      if (transaction.status != ReviewStatus.confirmed) return false;
      if (filter.start != null && transaction.date.isBefore(filter.start!)) {
        return false;
      }
      if (filter.end != null &&
          transaction.date.isAfter(
            DateTime(
              filter.end!.year,
              filter.end!.month,
              filter.end!.day,
              23,
              59,
              59,
              999,
            ),
          )) {
        return false;
      }
      if (filter.accountId != null &&
          transaction.accountId != filter.accountId &&
          transaction.destinationAccountId != filter.accountId) {
        return false;
      }
      if (filter.category != null && transaction.category != filter.category) {
        return false;
      }
      return filter.type == null || transaction.type == filter.type;
    }).toList();
  }

  Future<PreparedExport> prepare(
    ExportFormat format,
    ExportFilter filter,
  ) async {
    final snapshot = List<Transaction>.unmodifiable(await records(filter));
    final accounts = await _database.accounts(includeArchived: true);
    return prepareFromRecords(format, filter, snapshot, accounts: accounts);
  }

  Future<PreparedExport> prepareFromRecords(
    ExportFormat format,
    ExportFilter filter,
    List<Transaction> sourceRecords, {
    required List<Account> accounts,
    DateTime? generatedAt,
  }) async {
    final records = List<Transaction>.unmodifiable(
      sourceRecords.where((record) => record.status == ReviewStatus.confirmed),
    );
    final accountNames = <int, String>{
      for (final account in accounts)
        if (account.id != null) account.id!: account.name,
    };
    String accountName(int? id) => id == null
        ? 'Unavailable account'
        : accountNames[id] ?? 'Unavailable account';
    final rows = List<ExportRow>.unmodifiable(
      records.map(
        (record) => ExportRow(
          date: record.date,
          description: record.title,
          type: record.type,
          category: record.category,
          sourceAccount: accountName(record.accountId),
          destinationAccount: record.destinationAccountId == null
              ? null
              : accountName(record.destinationAccountId),
          amountMinor: record.amountMinor.abs(),
          notes: record.notes,
        ),
      ),
    );
    final summary = _summary(rows);
    final now = generatedAt ?? DateTime.now();
    final period = _periodLabel(filter);
    final accountFilter = filter.accountId == null
        ? 'All accounts'
        : accountName(filter.accountId);
    final printable = await _buildPdf(
      rows: rows,
      summary: summary,
      filter: filter,
      generatedAt: now,
      periodLabel: period,
      accountFilterLabel: accountFilter,
    );
    final bytes = switch (format) {
      ExportFormat.csv => csvBytes(rows),
      ExportFormat.excel => xlsxBytes(
        rows: rows,
        summary: summary,
        filter: filter,
        generatedAt: now,
        periodLabel: period,
        accountFilterLabel: accountFilter,
      ),
      ExportFormat.pdf => printable,
    };
    final stamp = DateFormat('yyyy-MM-dd').format(now);
    return PreparedExport(
      format: format,
      filter: filter,
      filename: 'spenflo-transaction-report-$stamp.${format.extension}',
      bytes: bytes,
      printablePdfBytes: printable,
      generatedAt: now,
      periodLabel: period,
      accountFilterLabel: accountFilter,
      records: records,
      rows: rows,
      summary: summary,
    );
  }

  ExportSummary _summary(List<ExportRow> rows) => ExportSummary(
    incomeMinor: rows
        .where((row) => row.type == TransactionType.income)
        .fold(0, (sum, row) => sum + row.amountMinor),
    expenseMinor: rows
        .where((row) => row.type == TransactionType.expense)
        .fold(0, (sum, row) => sum + row.amountMinor),
    transferMinor: rows
        .where((row) => row.type == TransactionType.transfer)
        .fold(0, (sum, row) => sum + row.amountMinor),
    transactionCount: rows.length,
  );

  Uint8List csvBytes(List<ExportRow> rows) {
    final values = <List<Object?>>[
      const [
        'Date',
        'Description',
        'Transaction Type',
        'Category',
        'Source Account',
        'Destination Account',
        'Amount (USD)',
        'Notes',
      ],
      ...rows.map(
        (row) => <Object?>[
          DateFormat('yyyy-MM-dd').format(row.date),
          _csvSafe(row.description),
          row.typeLabel,
          _csvSafe(row.category),
          _csvSafe(row.sourceAccount),
          _csvSafe(row.destinationAccount ?? ''),
          (row.signedAmountMinor / 100).toStringAsFixed(2),
          _csvSafe(row.notes),
        ],
      ),
    ];
    return Uint8List.fromList(
      utf8.encode(const ListToCsvConverter().convert(values)),
    );
  }

  String _csvSafe(String value) {
    final leftTrimmed = value.trimLeft();
    if (leftTrimmed.isNotEmpty &&
        const {'=', '+', '-', '@'}.contains(leftTrimmed[0])) {
      return "'$value";
    }
    if (value.startsWith('\t') || value.startsWith('\r')) return "'$value";
    return value;
  }

  Uint8List xlsxBytes({
    required List<ExportRow> rows,
    required ExportSummary summary,
    required ExportFilter filter,
    required DateTime generatedAt,
    required String periodLabel,
    required String accountFilterLabel,
  }) {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Summary');
    final summarySheet = workbook['Summary'];
    final transactions = workbook['Transactions'];
    final emerald = ExcelColor.fromHexString('#079669');
    final emeraldSoft = ExcelColor.fromHexString('#DDF5EC');
    final white = ExcelColor.white;
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: white,
      backgroundColorHex: emerald,
      verticalAlign: VerticalAlign.Center,
    );
    final labelStyle = CellStyle(bold: true, backgroundColorHex: emeraldSoft);
    final moneyStyle = CellStyle(
      numberFormat: CustomNumericNumFormat(
        formatCode: '\$#,##0.00;[Red]-\$#,##0.00',
      ),
    );

    summarySheet.appendRow([TextCellValue('SpenFlo Transaction Report')]);
    summarySheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
      bold: true,
      fontSize: 18,
      fontColorHex: emerald,
    );
    final summaryRows = <List<CellValue?>>[
      [TextCellValue('Reporting period'), TextCellValue(periodLabel)],
      [TextCellValue('Account filter'), TextCellValue(accountFilterLabel)],
      [
        TextCellValue('Category filter'),
        TextCellValue(filter.category ?? 'All categories'),
      ],
      [
        TextCellValue('Transaction type'),
        TextCellValue(
          filter.type == null ? 'All types' : _typeLabel(filter.type!),
        ),
      ],
      [TextCellValue('Currency'), TextCellValue('USD')],
      [TextCellValue('Generated'), DateTimeCellValue.fromDateTime(generatedAt)],
      [
        TextCellValue('Total Income'),
        DoubleCellValue(summary.incomeMinor / 100),
      ],
      [
        TextCellValue('Total Expenses'),
        DoubleCellValue(-(summary.expenseMinor / 100)),
      ],
      [TextCellValue('Net Cash Flow'), DoubleCellValue(summary.netMinor / 100)],
      [
        TextCellValue('Total Transfers'),
        DoubleCellValue(summary.transferMinor / 100),
      ],
      [
        TextCellValue('Transaction count'),
        IntCellValue(summary.transactionCount),
      ],
    ];
    for (final row in summaryRows) {
      summarySheet.appendRow(row);
    }
    for (var row = 1; row <= summaryRows.length; row++) {
      summarySheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
              .cellStyle =
          labelStyle;
      if (row >= 7 && row <= 10) {
        summarySheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
                .cellStyle =
            moneyStyle;
      }
    }
    summarySheet.setColumnWidth(0, 24);
    summarySheet.setColumnWidth(1, 32);

    const headings = [
      'Date',
      'Description',
      'Type',
      'Category',
      'Account',
      'Destination Account',
      'Amount (USD)',
      'Notes',
    ];
    transactions.appendRow(headings.map(TextCellValue.new).toList());
    for (var column = 0; column < headings.length; column++) {
      transactions
              .cell(
                CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
              )
              .cellStyle =
          headerStyle;
    }
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final rowBackground = index.isOdd
          ? ExcelColor.fromHexString('#F3F7F6')
          : ExcelColor.white;
      transactions.appendRow([
        DateCellValue(
          year: row.date.year,
          month: row.date.month,
          day: row.date.day,
        ),
        TextCellValue(row.description),
        TextCellValue(row.typeLabel),
        TextCellValue(row.category),
        TextCellValue(row.sourceAccount),
        TextCellValue(row.destinationAccount ?? ''),
        DoubleCellValue(row.signedAmountMinor / 100),
        TextCellValue(row.notes),
      ]);
      for (var column = 0; column < headings.length; column++) {
        transactions
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: column,
                rowIndex: index + 1,
              ),
            )
            .cellStyle = CellStyle(
          backgroundColorHex: rowBackground,
        );
      }
      final amount = transactions.cell(
        CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: index + 1),
      );
      amount.cellStyle = moneyStyle.copyWith(
        backgroundColorHexVal: rowBackground,
        fontColorHexVal: switch (row.type) {
          TransactionType.income => ExcelColor.fromHexString('#16733A'),
          TransactionType.expense => ExcelColor.fromHexString('#B42318'),
          TransactionType.transfer => ExcelColor.fromHexString('#334155'),
        },
      );
      transactions
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: index + 1))
          .cellStyle = CellStyle(
        backgroundColorHex: rowBackground,
        numberFormat: NumFormat.standard_14,
      );
    }
    final widths = [14.0, 28.0, 14.0, 20.0, 22.0, 22.0, 16.0, 34.0];
    for (var column = 0; column < widths.length; column++) {
      transactions.setColumnWidth(column, widths[column]);
    }
    return Uint8List.fromList(workbook.encode()!);
  }

  Future<Uint8List> _buildPdf({
    required List<ExportRow> rows,
    required ExportSummary summary,
    required ExportFilter filter,
    required DateTime generatedAt,
    required String periodLabel,
    required String accountFilterLabel,
  }) async {
    final document = pw.Document(
      title: 'SpenFlo Transaction Report',
      author: 'SpenFlo',
      subject: 'Financial transaction report',
      creator: 'SpenFlo',
    );
    final sorted = [...rows]..sort((a, b) => b.date.compareTo(a.date));
    final date = DateFormat('MMM d, yyyy');
    document.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.fromLTRB(28, 32, 28, 32),
        ),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'SPENFLO  |  TRANSACTION REPORT',
                    style: pw.TextStyle(
                      color: PdfColors.green800,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(periodLabel, style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 7),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey400, width: .5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'USD  |  $periodLabel',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
        build: (_) => [
          _pdfHeader(generatedAt, periodLabel),
          pw.SizedBox(height: 16),
          _pdfScope(filter, accountFilterLabel),
          pw.SizedBox(height: 16),
          _pdfSummary(summary),
          pw.SizedBox(height: 22),
          pw.Text(
            'Transactions',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            '${rows.length} confirmed ${rows.length == 1 ? 'transaction' : 'transactions'}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 9),
          if (sorted.isEmpty)
            _pdfEmpty()
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'DATE',
                'DESCRIPTION',
                'TYPE',
                'CATEGORY',
                'ACCOUNT / MOVEMENT',
                'AMOUNT',
              ],
              data: sorted
                  .map(
                    (row) => [
                      date.format(row.date),
                      _pdfText(row.description),
                      row.typeLabel,
                      _pdfText(row.category),
                      _pdfText(row.movement.replaceAll('→', 'to')),
                      _displayAmount(row),
                    ],
                  )
                  .toList(),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.green800,
              ),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
              headerAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(
                fontSize: 7.2,
                color: PdfColors.grey900,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  color: PdfColors.grey300,
                  width: .4,
                ),
                bottom: pw.BorderSide(color: PdfColors.grey400, width: .5),
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(.9),
                1: pw.FlexColumnWidth(1.35),
                2: pw.FlexColumnWidth(.75),
                3: pw.FlexColumnWidth(1),
                4: pw.FlexColumnWidth(1.4),
                5: pw.FlexColumnWidth(.85),
              },
              cellAlignments: const {5: pw.Alignment.centerRight},
              headerAlignments: const {5: pw.Alignment.centerRight},
              textStyleBuilder: (column, _, rowNumber) {
                if (column != 5) return null;
                final type = sorted[rowNumber - 1].type;
                return pw.TextStyle(
                  fontSize: 7.2,
                  fontWeight: pw.FontWeight.bold,
                  color: switch (type) {
                    TransactionType.income => PdfColors.green800,
                    TransactionType.expense => PdfColors.red700,
                    TransactionType.transfer => PdfColors.blueGrey700,
                  },
                );
              },
            ),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _pdfHeader(DateTime generatedAt, String periodLabel) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 42,
        height: 42,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          color: PdfColors.green800,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          'S',
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      pw.SizedBox(width: 12),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'SPENFLO',
              style: pw.TextStyle(
                color: PdfColors.green800,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            pw.Text(
              'Transaction Report',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),
            pw.Text(
              periodLabel,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'Generated',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          pw.Text(
            DateFormat('MMM d, yyyy').format(generatedAt),
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Currency: USD', style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    ],
  );

  pw.Widget _pdfScope(ExportFilter filter, String accountFilterLabel) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey300, width: .5),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(child: _pdfScopeItem('ACCOUNT', accountFilterLabel)),
            pw.Expanded(
              child: _pdfScopeItem(
                'CATEGORY',
                filter.category ?? 'All categories',
              ),
            ),
            pw.Expanded(
              child: _pdfScopeItem(
                'TYPE',
                filter.type == null ? 'All types' : _typeLabel(filter.type!),
              ),
            ),
          ],
        ),
      );

  pw.Widget _pdfScopeItem(String label, String value) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        value,
        maxLines: 2,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );

  pw.Widget _pdfSummary(ExportSummary summary) {
    final metrics = [
      ('TOTAL INCOME', MoneyFormatter.format(summary.incomeMinor, code: 'USD')),
      (
        'TOTAL EXPENSES',
        MoneyFormatter.format(summary.expenseMinor, code: 'USD'),
      ),
      ('NET CASH FLOW', MoneyFormatter.format(summary.netMinor, code: 'USD')),
      (
        'TOTAL TRANSFERS',
        MoneyFormatter.format(summary.transferMinor, code: 'USD'),
      ),
      ('TRANSACTIONS', '${summary.transactionCount}'),
    ];
    return pw.Row(
      children: metrics
          .map(
            (metric) => pw.Expanded(
              child: pw.Container(
                margin: const pw.EdgeInsets.only(right: 4),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: .5),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      metric.$1,
                      style: const pw.TextStyle(
                        fontSize: 5.8,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      metric.$2,
                      style: pw.TextStyle(
                        fontSize: 8.2,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  pw.Widget _pdfEmpty() => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(24),
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Text(
      'No confirmed transactions matched the selected filters.',
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
    ),
  );

  String _displayAmount(ExportRow row) => switch (row.type) {
    TransactionType.income => MoneyFormatter.signed(
      row.amountMinor,
      code: 'USD',
      negative: false,
    ),
    TransactionType.expense => MoneyFormatter.signed(
      row.amountMinor,
      code: 'USD',
      negative: true,
    ),
    TransactionType.transfer => MoneyFormatter.format(
      row.amountMinor,
      code: 'USD',
    ),
  };

  /// The PDF built-in print font is WinAnsi. CSV and XLSX retain full UTF-8;
  /// printable output replaces unsupported code points instead of clipping or
  /// failing an otherwise valid report.
  String _pdfText(String value) =>
      value.replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\x7E\xA0-\xFF]'), '?');

  String _periodLabel(ExportFilter filter) {
    final formatter = DateFormat('MMM d, yyyy');
    if (filter.start == null && filter.end == null) return 'All dates';
    if (filter.start != null && filter.end != null) {
      return '${formatter.format(filter.start!)} – ${formatter.format(filter.end!)}';
    }
    if (filter.start != null) return 'From ${formatter.format(filter.start!)}';
    return 'Through ${formatter.format(filter.end!)}';
  }

  String _typeLabel(TransactionType type) => switch (type) {
    TransactionType.income => 'Income',
    TransactionType.expense => 'Expense',
    TransactionType.transfer => 'Transfer',
  };

  Future<Uint8List> pdfBytes(
    ExportFilter filter, {
    List<Transaction>? snapshot,
  }) async {
    final prepared = await prepareFromRecords(
      ExportFormat.pdf,
      filter,
      snapshot ?? await records(filter),
      accounts: await _database.accounts(includeArchived: true),
    );
    return prepared.bytes;
  }

  Future<File> csv(ExportFilter filter) async {
    final prepared = await prepare(ExportFormat.csv, filter);
    return _write(prepared.filename, prepared.bytes);
  }

  Future<File> pdf(ExportFilter filter) async {
    final prepared = await prepare(ExportFormat.pdf, filter);
    return _write(prepared.filename, prepared.bytes);
  }

  Future<File> xlsx(ExportFilter filter) async {
    final prepared = await prepare(ExportFormat.excel, filter);
    return _write(prepared.filename, prepared.bytes);
  }

  Future<File> _write(String name, List<int> bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
