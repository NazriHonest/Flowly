import '../../../transactions/domain/entities/transaction.dart';
import '../entities/budget.dart';

/// Central budget-period calculation shared by every budget summary.
abstract final class BudgetSpendingCalculator {
  static int spent(
    Budget budget,
    Iterable<Transaction> transactions, {
    DateTime? asOf,
  }) => countedTransactions(budget, transactions, asOf: asOf).fold<int>(
    0,
    (sum, transaction) => sum + transaction.amountMinor,
  );

  /// Transactions that contribute to [budget] in its active period.
  ///
  /// Keeping this filter public lets details and summaries present the same
  /// category, status, type and date eligibility rules.
  static Iterable<Transaction> countedTransactions(
    Budget budget,
    Iterable<Transaction> transactions, {
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    return transactions
        .where(
          (transaction) =>
              transaction.status == ReviewStatus.confirmed &&
              transaction.type == TransactionType.expense &&
              transaction.category == budget.category &&
              isInCurrentPeriod(transaction.date, budget, asOf: now),
        );
  }

  static bool isInCurrentPeriod(
    DateTime date,
    Budget budget, {
    DateTime? asOf,
  }) {
    final now = (asOf ?? DateTime.now()).toLocal();
    final transactionDate = date.toLocal();
    final today = _dateOnly(now);
    final naturalStart = switch (budget.period) {
      'weekly' => today.subtract(const Duration(days: 6)),
      'yearly' => DateTime(now.year),
      _ => DateTime(now.year, now.month),
    };
    final configuredStart = budget.startDate == null
        ? null
        : _dateOnly(budget.startDate!.toLocal());
    final start = configuredStart != null && configuredStart.isAfter(naturalStart)
        ? configuredStart
        : naturalStart;

    return !transactionDate.isBefore(start) && !transactionDate.isAfter(now);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
