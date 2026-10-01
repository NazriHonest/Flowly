import '../domain/entities/transaction_candidate.dart';
import 'provider_sms_parser.dart';

class EvcPlusParser extends ProviderSmsParser {
  EvcPlusParser() : super(providerName: 'EVC Plus', marker: '[-EVCPLUS-]');

  @override
  bool matchesTransaction(String message) {
    return RegExp(r'ayaad\s+uwareejisay', caseSensitive: false).hasMatch(message) ||
        RegExp(r'ka\s+heshay', caseSensitive: false).hasMatch(message);
  }

  @override
  ParsedProviderMessage? parseProviderMessage(String message) {
    final incomingMatch = RegExp(r'ka\s+heshay', caseSensitive: false)
        .firstMatch(message);
    final outgoingMatch = RegExp(
      r'ayaad\s+uwareejisay',
      caseSensitive: false,
    ).firstMatch(message);
    final incoming = incomingMatch != null;
    final phraseMatch = incoming ? incomingMatch : outgoingMatch;
    if (phraseMatch == null) return null;
    final remainder = message.substring(phraseMatch.end);
    final comma = remainder.indexOf(',');
    final counterparty = comma < 0 ? remainder : remainder.substring(0, comma);
    return ParsedProviderMessage(
      type: incoming ? CandidateType.income : CandidateType.expense,
      timestamp: ProviderSmsParser.timestampPattern.firstMatch(remainder)?.group(1),
      counterpartyName: normalizeCounterparty(counterparty),
    );
  }
}
