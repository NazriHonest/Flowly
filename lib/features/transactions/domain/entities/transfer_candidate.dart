import 'transaction.dart';

enum TransferCandidateStatus { possible, linked, rejected }

class TransferCandidate {
  const TransferCandidate({
    required this.id,
    required this.outgoing,
    required this.incoming,
    required this.confidence,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
  });

  final int id;
  final Transaction outgoing;
  final Transaction incoming;
  final String confidence;
  final TransferCandidateStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
}
