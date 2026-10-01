/// An in-memory, normalized result of financial-message processing.
///
/// It deliberately has no raw message property. Callers must discard the SMS
/// body as soon as this candidate has been created.
class TransactionCandidate {
  const TransactionCandidate({
    required this.type,
    required this.amountMinor,
    required this.currency,
    required this.provider,
    required this.transactionDate,
    required this.confidence,
    this.providerTransactionAt,
    this.merchant,
    this.reference,
    this.categorySuggestion,
  });

  final CandidateType type;
  final int amountMinor;
  final String currency;
  final String provider;
  final DateTime transactionDate;
  /// Null when no trustworthy provider timestamp was present in the SMS.
  final DateTime? providerTransactionAt;
  final double confidence;
  final String? merchant;
  final String? reference;
  final String? categorySuggestion;
}

enum CandidateType { expense, income, transfer }
