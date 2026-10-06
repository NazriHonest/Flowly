import '../domain/entities/transaction_candidate.dart';
import 'provider_sms_parser.dart';

class AgroBankParser extends ProviderSmsParser {
  AgroBankParser() : super(providerName: 'AGROBANK', marker: 'BURAAQ');

  static final _structure = RegExp(
    r'USD\s+[\d.,]+\s+ayaa\s+(dhigatay|kala\s+baxday)\s+koontadaada\s+bangiga\s+ee\s*\(([A-Z0-9*X]+)\).*?xilliga\s*:\s*([^,]+).*?BURAAQ',
    caseSensitive: false,
  );

  @override
  bool matchesTransaction(String message) => _structure.hasMatch(message);

  @override
  ParsedProviderMessage? parseProviderMessage(String message) {
    final match = _structure.firstMatch(message);
    if (match == null) return null;
    final incoming = match.group(1)!.toLowerCase() == 'dhigatay';
    return ParsedProviderMessage(
      type: incoming ? CandidateType.income : CandidateType.expense,
      timestamp: match.group(3),
      semantics: CandidateSemantics.internalTransfer,
      transferDirection: incoming
          ? TransferObservationDirection.incoming
          : TransferObservationDirection.outgoing,
      accountHintHash: safeAccountHintHash(match.group(2)!),
    );
  }

  @override
  DateTime? parseProviderTimestamp(String raw) {
    final match = RegExp(
      r'^(\d{1,2})-([A-Za-z]{3})-(\d{2})\s+(\d{1,2}):(\d{2}):(\d{2})$',
    ).firstMatch(raw.trim());
    if (match == null) return null;
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final month = months[match.group(2)!.toLowerCase()];
    if (month == null) return null;
    final value = DateTime(
      2000 + int.parse(match.group(3)!),
      month,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
    return value.month == month && value.day == int.parse(match.group(1)!)
        ? value
        : null;
  }
}
