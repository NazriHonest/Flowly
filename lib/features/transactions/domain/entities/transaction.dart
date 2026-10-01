enum TransactionType { expense, income, transfer }

enum TransactionSource { manual, smsLive, smsImport, recurring }

enum ReviewStatus { confirmed, needsReview, ignored }

/// Money is always stored in minor units.  For a transfer [accountId] is the
/// account money leaves and [destinationAccountId] is the account it enters.
class Transaction {
  const Transaction({
    this.id,
    required this.amountMinor,
    required this.type,
    required this.title,
    required this.category,
    required this.accountId,
    this.destinationAccountId,
    required this.date,
    this.source = TransactionSource.manual,
    this.status = ReviewStatus.confirmed,
    this.notes = '',
    this.providerTransactionAt,
    this.smsReceivedAt,
    this.createdAt,
  });

  final int? id;
  final int amountMinor;
  final int accountId;
  final int? destinationAccountId;
  final TransactionType type;
  final String title;
  final String category;
  final String notes;
  final DateTime date;
  final TransactionSource source;
  final ReviewStatus status;
  /// Null when the provider did not supply a valid embedded transaction time.
  final DateTime? providerTransactionAt;
  /// The Android inbox receipt time, retained only as normalized metadata.
  final DateTime? smsReceivedAt;
  /// When Flowly persisted this normalized transaction.
  final DateTime? createdAt;

  bool get isTransfer => type == TransactionType.transfer;
}
