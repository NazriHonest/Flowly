import '../../../transactions/domain/entities/transaction.dart';
import '../entities/account.dart';

/// Canonical current-balance calculation for every account presentation.
///
/// Only confirmed financial records affect a balance. A reconciled SMS pair is
/// represented by one confirmed transfer and an ignored counterpart, so it is
/// counted exactly once; unlinking restores the original confirmed expense and
/// income records, which produces the same net account effect.
class AccountBalanceCalculator {
  const AccountBalanceCalculator._();

  static int current(Account account, Iterable<Transaction> transactions) {
    var balance = account.openingBalanceMinor;
    final accountId = account.id;

    for (final transaction in transactions) {
      if (transaction.status != ReviewStatus.confirmed) {
        continue;
      }

      switch (transaction.type) {
        case TransactionType.income:
          if (transaction.accountId == accountId) {
            balance += transaction.amountMinor;
          }
        case TransactionType.expense:
          if (transaction.accountId == accountId) {
            balance -= transaction.amountMinor;
          }
        case TransactionType.transfer:
          if (transaction.accountId == accountId) {
            balance -= transaction.amountMinor;
          }
          if (transaction.destinationAccountId == accountId) {
            balance += transaction.amountMinor;
          }
      }
    }

    return balance;
  }
}
