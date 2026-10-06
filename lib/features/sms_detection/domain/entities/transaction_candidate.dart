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
    this.counterpartyPhone,
    this.reference,
    this.categorySuggestion,
    this.semantics = CandidateSemantics.ordinary,
    this.transferDirection,
    this.accountHintHash,
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

  /// Transient normalized recipient number, if a provider supplied one.
  /// It is intentionally not persisted with a financial transaction.
  final String? counterpartyPhone;
  final String? reference;
  final String? categorySuggestion;
  final CandidateSemantics semantics;
  final TransferObservationDirection? transferDirection;

  /// One-way digest of a normalized masked account identifier. The original
  /// identifier is deliberately not retained beyond parsing.
  final String? accountHintHash;
}

enum CandidateType { expense, income, transfer }

enum CandidateSemantics { ordinary, internalTransfer }

enum TransferObservationDirection { outgoing, incoming }
