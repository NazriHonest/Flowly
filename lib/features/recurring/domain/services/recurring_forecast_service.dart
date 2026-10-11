import '../../../transactions/domain/entities/transaction.dart';
import '../entities/recurring_forecast.dart';
import '../entities/recurring_transaction.dart';
import 'recurrence_scheduler.dart';

class RecurringForecastService {
  const RecurringForecastService({
    this.scheduler = const RecurrenceScheduler(),
  });

  final RecurrenceScheduler scheduler;

  List<RecurringOccurrence> upcoming(
    Iterable<RecurringTransaction> schedules, {
    required DateTime from,
    int days = 30,
  }) {
    final start = _startOfDay(from);
    final end = start.add(Duration(days: days));
    final occurrences = <RecurringOccurrence>[];

    for (final schedule in schedules) {
      for (final date in scheduler.occurrencesBetween(
        schedule,
        start: start,
        end: end,
      )) {
        occurrences.add(RecurringOccurrence(schedule: schedule, date: date));
      }
    }

    occurrences.sort((first, second) {
      final byDate = first.date.compareTo(second.date);
      return byDate != 0
          ? byDate
          : first.schedule.title.compareTo(second.schedule.title);
    });
    return List.unmodifiable(occurrences);
  }

  MonthlyRecurringCommitments commitments(
    Iterable<RecurringTransaction> schedules,
    DateTime month,
  ) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(
      month.year,
      month.month + 1,
    ).subtract(const Duration(microseconds: 1));
    var expenses = 0;
    var income = 0;

    for (final schedule in schedules) {
      final count = scheduler
          .occurrencesBetween(
            schedule,
            start: start,
            end: end,
            fromScheduleStart: true,
          )
          .length;
      if (schedule.type == TransactionType.income) {
        income += schedule.amountMinor * count;
      } else if (schedule.type == TransactionType.expense) {
        expenses += schedule.amountMinor * count;
      }
    }

    return MonthlyRecurringCommitments(
      month: start,
      scheduledExpensesMinor: expenses,
      scheduledIncomeMinor: income,
    );
  }

  DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
