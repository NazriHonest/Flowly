import '../../../transactions/domain/entities/transaction.dart';

class BudgetLimitSnapshot {
  const BudgetLimitSnapshot({
    required this.budgetId,
    required this.start,
    required this.end,
    required this.amountMinor,
    required this.category,
    required this.period,
  });

  final int budgetId;
  final DateTime start;
  final DateTime end;
  final int amountMinor;
  final String category;
  final String period;
}

class BudgetHistoryPeriod {
  const BudgetHistoryPeriod({
    required this.start,
    required this.end,
    required this.label,
    required this.category,
    required this.spentMinor,
    required this.limitMinor,
    required this.transactions,
    required this.isCurrent,
  });

  final DateTime start;
  final DateTime end;
  final String label;
  final String category;
  final int spentMinor;
  final int? limitMinor;
  final List<Transaction> transactions;
  final bool isCurrent;

  double? get ratio => limitMinor == null
      ? null
      : limitMinor == 0
      ? (spentMinor == 0 ? 0 : double.infinity)
      : spentMinor / limitMinor!;
}

class BudgetHistory {
  const BudgetHistory(this.periods);

  final List<BudgetHistoryPeriod> periods;

  List<BudgetHistoryPeriod> get previous =>
      periods.where((period) => !period.isCurrent).toList(growable: false);
}
