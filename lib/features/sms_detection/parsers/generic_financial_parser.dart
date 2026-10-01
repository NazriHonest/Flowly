import '../domain/entities/transaction_candidate.dart';
import '../domain/services/confidence_calculator.dart';
import '../domain/services/financial_sms_parser.dart';

/// Conservative fallback parser for user-supplied, fixture-backed adapters.
/// It never identifies a real financial provider from an invented format.
class GenericFinancialParser implements FinancialSmsParser {
  GenericFinancialParser({this.providerName = 'Generic'});
  final String providerName;
  final _confidence = const ConfidenceCalculator();

  static final _amount = RegExp(r'(?<!\d)(\d{1,9})(?:[,.](\d{1,2}))?');
  static final _currency = RegExp(
    r'\b(USD|KES|SOS|EUR|GBP)\b',
    caseSensitive: false,
  );

  @override
  bool canParse({required String sender, required String message}) {
    final normalized = message.toLowerCase();
    return _amount.hasMatch(normalized) &&
        (normalized.contains('paid') ||
            normalized.contains('sent') ||
            normalized.contains('received') ||
            normalized.contains('deposit'));
  }

  @override
  TransactionCandidate? parse({
    required String sender,
    required String message,
    required DateTime receivedAt,
  }) {
    final amount = _amount.firstMatch(message);
    if (amount == null) return null;
    final whole = int.tryParse(amount.group(1)!);
    if (whole == null || whole <= 0) return null;
    final fraction = (amount.group(2) ?? '').padRight(2, '0');
    final minor = whole * 100 + (int.tryParse(fraction) ?? 0);
    final normalized = message.toLowerCase();
    final type =
        normalized.contains('received') || normalized.contains('deposit')
        ? CandidateType.income
        : CandidateType.expense;
    final currency =
        _currency.firstMatch(message)?.group(1)?.toUpperCase() ?? 'UNKNOWN';
    final confidence = _confidence.score(
      provider: sender.isNotEmpty,
      type: true,
      amount: true,
      currency: _currency.hasMatch(message),
      validTimestamp: true,
    );
    return TransactionCandidate(
      type: type,
      amountMinor: minor,
      currency: currency,
      provider: providerName,
      transactionDate: receivedAt,
      confidence: confidence,
    );
  }
}
