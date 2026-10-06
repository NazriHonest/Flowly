import '../domain/entities/transaction_candidate.dart';
import 'provider_sms_parser.dart';

class DeeqtoonParser extends ProviderSmsParser {
  DeeqtoonParser() : super(providerName: 'DEEQTOON', marker: 'DEEQTOON');

  static final _structure = RegExp(
    r'USD\s+[\d.,]+\s+ayaa\s+(dhigatay|kala\s+baxday)\s+koontadaada\s+bangiga\s+ee\s*\(([A-Z0-9*X]+)\).*?xilliga\s*:\s*([^,]+).*?DEEQTOON',
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
      r'^(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (match == null) return null;
    var hour = int.parse(match.group(4)!);
    final pm = match.group(7)!.toUpperCase() == 'PM';
    if (hour == 12) hour = 0;
    if (pm) hour += 12;
    final value = DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
      hour,
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
    return value.month == int.parse(match.group(2)!) &&
            value.day == int.parse(match.group(1)!)
        ? value
        : null;
  }
}
