import '../../../transactions/domain/entities/transaction.dart';
import '../entities/spending_allowance.dart';

abstract final class SpendingAllowanceCalculator {
  static AllowancePeriod periodFor(AllowancePeriodType type, DateTime at) {
    final local = at.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    return switch (type) {
      AllowancePeriodType.daily => AllowancePeriod(
        day,
        DateTime(day.year, day.month, day.day + 1),
      ),
      AllowancePeriodType.weekly => () {
        final daysSinceSaturday =
            (day.weekday - DateTime.saturday + 7) % 7;
        final start = DateTime(day.year, day.month, day.day - daysSinceSaturday);
        return AllowancePeriod(
          start,
          DateTime(start.year, start.month, start.day + 7),
        );
      }(),
      AllowancePeriodType.monthly => AllowancePeriod(
        DateTime(local.year, local.month),
        DateTime(local.year, local.month + 1),
      ),
    };
  }

  static Iterable<Transaction> eligibleTransactions(
    Iterable<Transaction> transactions,
    AllowancePeriod period,
  ) => transactions.where((transaction) {
    final date = transaction.date.toLocal();
    return transaction.status == ReviewStatus.confirmed &&
        transaction.type == TransactionType.expense &&
        !date.isBefore(period.start) &&
        date.isBefore(period.end);
  });

  static SpendingAllowanceSummary calculate({
    required AllowancePeriodType type,
    required int allowanceMinor,
    required Iterable<Transaction> transactions,
    required DateTime at,
  }) {
    final period = periodFor(type, at);
    final spent = eligibleTransactions(transactions, period).fold<int>(
      0,
      (sum, transaction) => sum + transaction.amountMinor,
    );
    return SpendingAllowanceSummary(
      type: type,
      period: period,
      limitMinor: allowanceMinor,
      spentMinor: spent,
    );
  }
}
