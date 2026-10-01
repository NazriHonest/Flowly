import 'package:flutter_test/flutter_test.dart';
import 'package:flowly/core/formatters/money_formatter.dart';
import 'package:flowly/features/transactions/domain/entities/transaction.dart';

void main() {
  test('money is stored in minor units and formatted centrally', () {
    expect(MoneyFormatter.format(2450), 'KSh24.50');
  });

  test('transaction mapping preserves normalized data only', () {
    final transaction = Transaction(
      amountMinor: 1250,
      type: TransactionType.expense,
      title: 'Groceries',
      category: 'Groceries',
      accountId: 1,
      date: DateTime(2026, 9, 27),
    );
    expect(transaction.amountMinor, 1250);
    expect(transaction.notes, isEmpty);
  });
}
