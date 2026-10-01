import '../entities/transaction_candidate.dart';

abstract interface class FinancialSmsParser {
  bool canParse({required String sender, required String message});

  TransactionCandidate? parse({
    required String sender,
    required String message,
    required DateTime receivedAt,
  });
}
