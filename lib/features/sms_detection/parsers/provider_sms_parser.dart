import '../domain/entities/transaction_candidate.dart';
import '../domain/services/confidence_calculator.dart';
import '../domain/services/financial_sms_parser.dart';

/// Shared, privacy-preserving helpers for provider-specific SMS parsers.
/// Only normalized candidate fields leave the parser; the raw message is never
/// retained by this class.
abstract class ProviderSmsParser implements FinancialSmsParser {
  ProviderSmsParser({required this.providerName, required this.marker});

  final String providerName;
  final String marker;
  final _confidence = const ConfidenceCalculator();

  static final amountPattern = RegExp(r'\$(\d{1,9})(?:[,.](\d{1,2}))?');
  static final timestampPattern = RegExp(
    r'(\d{2}/\d{2}/(?:\d{2}|\d{4})\s+\d{2}:\d{2}:\d{2})(?::\d{3})?',
  );

  @override
  bool canParse({required String sender, required String message}) =>
      message
              .toLowerCase()
              .replaceAll(RegExp(r'\s+'), '')
              .contains(marker.toLowerCase().replaceAll(' ', '')) &&
      matchesTransaction(message);

  bool matchesTransaction(String message);

  ParsedProviderMessage? parseProviderMessage(String message);

  @override
  TransactionCandidate? parse({
    required String sender,
    required String message,
    required DateTime receivedAt,
  }) {
    final parsed = parseProviderMessage(message);
    if (parsed == null) return null;
    final amount = amountPattern.firstMatch(message);
    if (amount == null) return null;
    final whole = int.tryParse(amount.group(1)!);
    if (whole == null || whole < 0) return null;
    final fraction = (amount.group(2) ?? '').padRight(2, '0');
    final amountMinor = whole * 100 + (int.tryParse(fraction) ?? 0);
    if (amountMinor <= 0) return null;
    final timestamp = _parseTimestamp(parsed.timestamp, receivedAt);
    final confidence = _confidence.score(
      provider: true,
      type: true,
      amount: true,
      currency: true,
      merchant: parsed.counterpartyName != null,
      validTimestamp: timestamp.valid,
    );
    return TransactionCandidate(
      type: parsed.type,
      amountMinor: amountMinor,
      currency: 'USD',
      provider: providerName,
      transactionDate: timestamp.value,
      providerTransactionAt: timestamp.providerValue,
      confidence: confidence,
      merchant: parsed.counterpartyName,
    );
  }

  ({DateTime value, DateTime? providerValue, bool valid}) _parseTimestamp(
    String? raw,
    DateTime fallback,
  ) {
    if (raw == null) return (value: fallback, providerValue: null, valid: false);
    final match = timestampPattern.firstMatch(raw);
    if (match == null) return (value: fallback, providerValue: null, valid: false);
    final parts = RegExp(
      r'^(\d{2})/(\d{2})/(\d{2,4})\s+(\d{2}):(\d{2}):(\d{2})$',
    ).firstMatch(match.group(1)!);
    if (parts == null) return (value: fallback, providerValue: null, valid: false);
    final day = int.parse(parts.group(1)!);
    final month = int.parse(parts.group(2)!);
    var year = int.parse(parts.group(3)!);
    if (year < 100) year += year >= 70 ? 1900 : 2000;
    final hour = int.parse(parts.group(4)!);
    final minute = int.parse(parts.group(5)!);
    final second = int.parse(parts.group(6)!);
    try {
      final value = DateTime(year, month, day, hour, minute, second);
      final valid = value.year == year &&
          value.month == month &&
          value.day == day &&
          value.hour == hour &&
          value.minute == minute &&
          value.second == second;
      return (
        value: valid ? value : fallback,
        providerValue: valid ? value : null,
        valid: valid,
      );
    } on FormatException {
      return (value: fallback, providerValue: null, valid: false);
    }
  }
}

class ParsedProviderMessage {
  const ParsedProviderMessage({
    required this.type,
    required this.timestamp,
    this.counterpartyName,
  });

  final CandidateType type;
  final String? timestamp;
  final String? counterpartyName;
}

String? normalizeCounterparty(String raw) {
  final value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (value.isEmpty || RegExp(r'^\+?\d+$').hasMatch(value)) return null;
  final name = value.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
  return name.isEmpty ? null : name;
}
