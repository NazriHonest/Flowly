import 'package:flutter_test/flutter_test.dart';
import 'package:flowly/features/recurring/domain/entities/recurring_transaction.dart';
import 'package:flowly/features/recurring/domain/services/recurrence_scheduler.dart';
import 'package:flowly/features/recurring/domain/services/recurring_forecast_service.dart';
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

  test('daily, monthly and yearly schedules produce upcoming occurrences', () {
    final schedules = [
      _schedule('Daily', 'daily', DateTime(2026, 1, 1)),
      _schedule('Monthly', 'monthly', DateTime(2026, 1, 2)),
      _schedule('Yearly', 'yearly', DateTime(2026, 1, 3)),
    ];
    final occurrences = const RecurringForecastService().upcoming(
      schedules,
      from: DateTime(2026, 1, 1),
      days: 3,
    );

    expect(
      occurrences.where((item) => item.schedule.title == 'Daily'),
      hasLength(4),
    );
    expect(
      occurrences.where((item) => item.schedule.title == 'Monthly'),
      hasLength(1),
    );
    expect(
      occurrences.where((item) => item.schedule.title == 'Yearly'),
      hasLength(1),
    );
  });

  test('month-end and leap-year dates retain their original anchor', () {
    final monthEnd = _schedule('Month end', 'monthly', DateTime(2024, 1, 31));
    final february = scheduler.nextAfter(monthEnd);
    final march = scheduler.nextAfter(monthEnd, occurrence: february);
    expect(february, DateTime(2024, 2, 29));
    expect(march, DateTime(2024, 3, 31));

    final leapDay = _schedule('Leap day', 'yearly', DateTime(2024, 2, 29));
    expect(scheduler.nextAfter(leapDay), DateTime(2025, 2, 28));
    expect(
      scheduler.nextAfter(leapDay, occurrence: DateTime(2027, 2, 28)),
      DateTime(2028, 2, 29),
    );
  });

  test('boundaries and paused schedules are respected', () {
    final ended = RecurringTransaction(
      title: 'Ended',
      amountMinor: 1000,
      type: TransactionType.expense,
      category: 'Bills',
      accountId: 1,
      frequency: 'daily',
      startDate: DateTime(2026, 1, 2),
      nextOccurrence: DateTime(2026, 1, 2),
      endDate: DateTime(2026, 1, 3),
    );
    final paused = _schedule(
      'Paused',
      'daily',
      DateTime(2026, 1, 1),
      enabled: false,
    );

    expect(
      scheduler.occurrencesBetween(
        ended,
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 5),
      ),
      [DateTime(2026, 1, 2), DateTime(2026, 1, 3)],
    );
    expect(
      scheduler.occurrencesBetween(
        paused,
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 5),
      ),
      isEmpty,
    );
  });

  test('monthly commitments count every valid occurrence', () {
    final weeklyExpense = _schedule(
      'Weekly expense',
      'weekly',
      DateTime(2026, 1, 1),
      amountMinor: 2000,
    );
    final monthlyIncome = RecurringTransaction(
      title: 'Salary',
      amountMinor: 100000,
      type: TransactionType.income,
      category: 'Salary',
      accountId: 1,
      frequency: 'monthly',
      startDate: DateTime(2026, 1, 15),
      nextOccurrence: DateTime(2026, 1, 15),
    );
    final pausedExpense = _schedule(
      'Paused',
      'daily',
      DateTime(2026, 1, 1),
      amountMinor: 99999,
      enabled: false,
    );
    final service = const RecurringForecastService();
    final commitments = service.commitments([
      weeklyExpense,
      monthlyIncome,
      pausedExpense,
    ], DateTime(2026, 1));

    expect(commitments.scheduledExpensesMinor, 10000);
    expect(commitments.scheduledIncomeMinor, 100000);
    expect(commitments.expectedNetMinor, 90000);
    expect(weeklyExpense.nextOccurrence, DateTime(2026, 1, 1));
  });
}

RecurringTransaction _schedule(
  String title,
  String frequency,
  DateTime date, {
  int amountMinor = 1000,
  bool enabled = true,
}) => RecurringTransaction(
  title: title,
  amountMinor: amountMinor,
  type: TransactionType.expense,
  category: 'Bills',
  accountId: 1,
  frequency: frequency,
  startDate: date,
  nextOccurrence: date,
  enabled: enabled,
);
