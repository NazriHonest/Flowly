import '../domain/entities/transaction_candidate.dart';
import 'provider_sms_parser.dart';

class EvcPlusParser extends ProviderSmsParser {
  EvcPlusParser() : super(providerName: 'EVC Plus', marker: '[-EVCPLUS-]');

  static final _uWareejisay = RegExp(
    r'ayaad\s+u\s*wareejisay\s+(.+?)\s*\(\s*(\+?\d+)\s*\)',
    caseSensitive: false,
  );
  static final _uDirtay = RegExp(
    r'ayaad\s+u\s+dirtay\s+(.+?)\s*\(\s*(\+?\d+)\s*\)\s*(?:via\s+[^,]+)?\s*,?',
    caseSensitive: false,
  );
  static final _reference = RegExp(
    r'\btixraac\s*:\s*([A-Za-z0-9-]+)',
    caseSensitive: false,
  );
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
        _uWareejisay.hasMatch(message) ||
        _uDirtay.hasMatch(message) ||
        RegExp(r'ka\s+heshay', caseSensitive: false).hasMatch(message);
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
      r'ka\s+heshay',
      caseSensitive: false,
    ).firstMatch(message);
    if (incomingMatch != null) {
      final remainder = message.substring(incomingMatch.end);
      final comma = remainder.indexOf(',');
      final counterparty = comma < 0
          ? remainder
          : remainder.substring(0, comma);
      return ParsedProviderMessage(
        type: CandidateType.income,
        timestamp: ProviderSmsParser.timestampPattern
            .firstMatch(remainder)
            ?.group(1),
        counterpartyName: normalizeCounterparty(counterparty),
      );
    }

    // Keep the two real EVC outgoing families explicit. Matching permits
    // harmless whitespace variation without broadening into an amount-only
    // financial-message detector.
    final outgoingMatch =
        _uWareejisay.firstMatch(message) ?? _uDirtay.firstMatch(message);
    if (outgoingMatch == null) return null;
    return ParsedProviderMessage(
      type: CandidateType.expense,
      timestamp: ProviderSmsParser.timestampPattern
          .firstMatch(message)
          ?.group(1),
      counterpartyName: normalizeCounterparty(outgoingMatch.group(1)!),
      counterpartyPhone: outgoingMatch.group(2),
      reference: _reference.firstMatch(message)?.group(1),
    );
  }
}
