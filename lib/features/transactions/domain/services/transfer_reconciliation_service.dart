import '../entities/transaction.dart';

/// Pure, deliberately conservative transfer matching. Matching is only strong
/// when independent receipt-time evidence exists; legacy records remain a
/// candidate for an explicit user decision.
class TransferReconciliationService {
  static const _strongWindow = Duration(minutes: 15);
  static const _possibleWindow = Duration(hours: 2);

  TransferMatch? strongestFor({
    required Transaction outgoing,
    required Iterable<Transaction> transactions,
    required String outgoingCurrency,
    required String Function(int accountId) currencyForAccount,
  }) {
    final matches = candidatesFor(
      outgoing: outgoing,
      transactions: transactions,
      outgoingCurrency: outgoingCurrency,
      currencyForAccount: currencyForAccount,
    ).where((match) => match.confidence == TransferMatchConfidence.strong);
    return matches.length == 1 ? matches.single : null;
  }

  List<TransferMatch> candidatesFor({
    required Transaction outgoing,
    required Iterable<Transaction> transactions,
    required String outgoingCurrency,
    required String Function(int accountId) currencyForAccount,
  }) {
    if (outgoing.type != TransactionType.expense ||
        outgoing.status != ReviewStatus.confirmed) {
      return const [];
    }
    return transactions
        .where(
          (incoming) => _compatible(
            outgoing,
            incoming,
            outgoingCurrency,
            currencyForAccount,
          ),
        )
        .map(
          (incoming) => TransferMatch(
            outgoing: outgoing,
            incoming: incoming,
            confidence: _confidence(outgoing, incoming),
          ),
        )
        .toList(growable: false);
  }

  bool _compatible(
    Transaction outgoing,
    Transaction incoming,
    String currency,
    String Function(int accountId) currencyForAccount,
  ) =>
      incoming.id != outgoing.id &&
      incoming.type == TransactionType.income &&
      incoming.status == ReviewStatus.confirmed &&
      incoming.accountId != outgoing.accountId &&
      incoming.amountMinor == outgoing.amountMinor &&
      currencyForAccount(incoming.accountId) == currency &&
      _distance(outgoing, incoming) <= _possibleWindow;

  TransferMatchConfidence _confidence(
    Transaction outgoing,
    Transaction incoming,
  ) {
    // An inbox receipt time is the only time source that is independent of
    // provider-supplied content.  Never auto-link legacy records merely
    // because their display/provider times happen to be close.
    final receiptDistance = _distance(outgoing, incoming, receiptOnly: true);
    final hasIndependentProviderEvidence =
        outgoing.providerTransactionAt != null &&
        incoming.providerTransactionAt != null &&
        _distance(outgoing, incoming, providerOnly: true) <= _strongWindow;
    return receiptDistance <= _strongWindow && hasIndependentProviderEvidence
        ? TransferMatchConfidence.strong
        : TransferMatchConfidence.possible;
  }

  Duration _distance(
    Transaction first,
    Transaction second, {
    bool receiptOnly = false,
    bool providerOnly = false,
  }) {
    final a = first.smsReceivedAt;
    final b = second.smsReceivedAt;
    if (a != null && b != null) return a.difference(b).abs();
    if (receiptOnly) return const Duration(days: 999);
    final providerA = first.providerTransactionAt;
    final providerB = second.providerTransactionAt;
    if (providerA != null && providerB != null) {
      return providerA.difference(providerB).abs();
    }
    if (providerOnly) return const Duration(days: 999);
    return first.date.difference(second.date).abs();
  }
}

enum TransferMatchConfidence { strong, possible }

class TransferMatch {
  const TransferMatch({
    required this.outgoing,
    required this.incoming,
    required this.confidence,
  });
  final Transaction outgoing;
  final Transaction incoming;
  final TransferMatchConfidence confidence;
}
