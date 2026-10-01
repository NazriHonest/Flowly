import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../entities/transaction_candidate.dart';

class DuplicateDetector {
  const DuplicateDetector();

  /// A one-way fingerprint. It is safe to persist, unlike a raw message body.
  String fingerprint(TransactionCandidate candidate) {
    final input = <String>[
      candidate.provider.trim().toLowerCase(),
      candidate.reference?.trim().toLowerCase() ?? '',
      candidate.amountMinor.toString(),
      candidate.currency.toUpperCase(),
      candidate.type.name,
      candidate.transactionDate.toUtc().millisecondsSinceEpoch.toString(),
    ].join('|');
    return sha256.convert(utf8.encode(input)).toString();
  }
}
