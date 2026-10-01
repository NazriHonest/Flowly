import '../domain/entities/transaction_candidate.dart';
import 'provider_sms_parser.dart';

class JeebParser extends ProviderSmsParser {
  JeebParser() : super(providerName: 'JEEB', marker: '[-JEEB-]');

  @override
  bool matchesTransaction(String message) {
    return RegExp(r'ayaad\s+ka\s+heshay', caseSensitive: false).hasMatch(message) ||
        RegExp(r'ayaad\s+u\s+dirtay', caseSensitive: false).hasMatch(message);
  }

  @override
  ParsedProviderMessage? parseProviderMessage(String message) {
    final incomingMatch = RegExp(r'ayaad\s+ka\s+heshay', caseSensitive: false)
        .firstMatch(message);
    final outgoingMatch = RegExp(
      r'ayaad\s+u\s+dirtay',
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
