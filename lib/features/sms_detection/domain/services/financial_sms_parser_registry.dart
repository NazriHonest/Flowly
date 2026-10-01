import '../entities/transaction_candidate.dart';
import 'financial_sms_parser.dart';

class FinancialSmsParserRegistry {
  const FinancialSmsParserRegistry(this.parsers);
  final List<FinancialSmsParser> parsers;

  TransactionCandidate? parse({
    required String sender,
    required String message,
    required DateTime receivedAt,
  }) {
    for (final parser in parsers) {
      if (!parser.canParse(sender: sender, message: message)) continue;
      final result = parser.parse(
        sender: sender,
        message: message,
        receivedAt: receivedAt,
      );
      if (result != null) return result;
    }
    return null;
  }
}
