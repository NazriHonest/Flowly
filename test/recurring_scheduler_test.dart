import 'package:flutter_test/flutter_test.dart';
import 'package:flowly/features/recurring/domain/entities/recurring_transaction.dart';
import 'package:flowly/features/recurring/domain/services/recurrence_scheduler.dart';
import 'package:flowly/features/transactions/domain/entities/transaction.dart';

void main() {
  const scheduler = RecurrenceScheduler();
  test('weekly recurrence becomes due and advances seven days', () {
    final item = RecurringTransaction(
      title: 'Rent',
      amountMinor: 1000,
      type: TransactionType.expense,
      category: 'Bills',
      accountId: 1,
      frequency: 'weekly',
      nextOccurrence: DateTime(2026, 1, 1),
    );
    expect(scheduler.isDue(item, DateTime(2026, 1, 1)), isTrue);
    expect(scheduler.nextAfter(item), DateTime(2026, 1, 8));
  });
}
