import '../domain/entities/transaction_candidate.dart';
import 'provider_sms_parser.dart';

class JeebParser extends ProviderSmsParser {
  JeebParser() : super(providerName: 'JEEB', marker: '[-JEEB-]');

  static final _bankDeposit = RegExp(
    r'ku\s+shubtey\s+bank\s+account-kaaga\s*:\s*([A-Z0-9*X]+)',
    caseSensitive: false,
  );
  static final _bankWithdrawal = RegExp(
    r'kala\s+baxday\s+\$?[\d.,]+\s+xisaabtaada\s+bangiga\s+no\s*:\s*([A-Z0-9*X]+)',
    caseSensitive: false,
  );

  @override
  bool matchesTransaction(String message) {
    return _bankDeposit.hasMatch(message) ||
        _bankWithdrawal.hasMatch(message) ||
        RegExp(
          r'ayaad\s+ka\s+heshay',
          caseSensitive: false,
        ).hasMatch(message) ||
        RegExp(r'ayaad\s+u\s+dirtay', caseSensitive: false).hasMatch(message);
  }

  @override
  ParsedProviderMessage? parseProviderMessage(String message) {
    final bankDeposit = _bankDeposit.firstMatch(message);
    if (bankDeposit != null) {
      return ParsedProviderMessage(
        type: CandidateType.expense,
        timestamp: null,
        semantics: CandidateSemantics.internalTransfer,
        transferDirection: TransferObservationDirection.outgoing,
        accountHintHash: safeAccountHintHash(bankDeposit.group(1)!),
      );
    }
    final bankWithdrawal = _bankWithdrawal.firstMatch(message);
    if (bankWithdrawal != null) {
      return ParsedProviderMessage(
        type: CandidateType.income,
        timestamp: null,
        semantics: CandidateSemantics.internalTransfer,
        transferDirection: TransferObservationDirection.incoming,
        accountHintHash: safeAccountHintHash(bankWithdrawal.group(1)!),
      );
    }
    final incomingMatch = RegExp(
      r'ayaad\s+ka\s+heshay',
      caseSensitive: false,
    ).firstMatch(message);
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
      timestamp: ProviderSmsParser.timestampPattern
          .firstMatch(remainder)
          ?.group(1),
      counterpartyName: normalizeCounterparty(counterparty),
    );
  }
}
