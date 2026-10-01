/// Privacy-safe comparison of normalized timestamps. It never accepts or logs
/// a raw SMS body, sender, or counterparty.
class SmsTimestampDiagnostics {
  const SmsTimestampDiagnostics({this.unexpectedDifference = const Duration(hours: 6)});

  final Duration unexpectedDifference;

  Duration? difference({
    required DateTime? providerTransactionAt,
    required DateTime? smsReceivedAt,
  }) {
    if (providerTransactionAt == null || smsReceivedAt == null) return null;
    return providerTransactionAt.difference(smsReceivedAt).abs();
  }

  bool hasUnexpectedDifference({
    required DateTime? providerTransactionAt,
    required DateTime? smsReceivedAt,
  }) {
    final value = difference(
      providerTransactionAt: providerTransactionAt,
      smsReceivedAt: smsReceivedAt,
    );
    return value != null && value > unexpectedDifference;
  }
}
