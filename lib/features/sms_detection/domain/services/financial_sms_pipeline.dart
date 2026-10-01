import '../entities/transaction_candidate.dart';
import 'confidence_calculator.dart';
import 'duplicate_detector.dart';
import 'financial_message_detector.dart';
import 'financial_sms_parser_registry.dart';

class FinancialSmsPipeline {
  const FinancialSmsPipeline(this._registry);
  final FinancialSmsParserRegistry _registry;
  static const _detector = FinancialMessageDetector();
  static const _confidence = ConfidenceCalculator();
  static const _duplicates = DuplicateDetector();
  DetectionResult? process({
    required String sender,
    required String message,
    required DateTime receivedAt,
  }) {
    if (!_detector.isPotentialFinancialMessage(sender, message)) return null;
    final candidate = _registry.parse(
      sender: sender,
      message: message,
      receivedAt: receivedAt,
    );
    if (candidate == null) return null;
    return DetectionResult(
      candidate,
      _duplicates.fingerprint(candidate),
      _confidence.disposition(candidate.confidence),
    );
  }
}

class DetectionResult {
  const DetectionResult(this.candidate, this.fingerprint, this.disposition);
  final TransactionCandidate candidate;
  final String fingerprint;
  final DetectionDisposition disposition;
}
