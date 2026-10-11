import 'recurring_transaction.dart';

class RecurringOccurrence {
  const RecurringOccurrence({required this.schedule, required this.date});

  final RecurringTransaction schedule;
  final DateTime date;
}

class MonthlyRecurringCommitments {
  const MonthlyRecurringCommitments({
    required this.month,
    required this.scheduledExpensesMinor,
    required this.scheduledIncomeMinor,
  });

  final DateTime month;
  final int scheduledExpensesMinor;
  final int scheduledIncomeMinor;

  int get expectedNetMinor => scheduledIncomeMinor - scheduledExpensesMinor;
}
