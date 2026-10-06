import '../../../transactions/domain/entities/transaction.dart';
import 'transaction_candidate.dart';

enum SmsTransferObservationStatus { pending, attached, rejected }

enum SmsTransferSaveOutcome { created, attached, pending, duplicate }

class SmsTransferObservation {
  const SmsTransferObservation({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.mappedAccountId,
    required this.direction,
    required this.amountMinor,
    required this.currency,
    required this.smsReceivedAt,
    required this.source,
    required this.status,
    this.transactionId,
    this.linkedAccountId,
    this.providerTransactionAt,
  });

  final int id;
  final int? transactionId;
  final int providerId;
  final String providerName;
  final int mappedAccountId;
  final int? linkedAccountId;
  final TransferObservationDirection direction;
  final int amountMinor;
  final String currency;
  final DateTime smsReceivedAt;
  final DateTime? providerTransactionAt;
  final TransactionSource source;
  final SmsTransferObservationStatus status;
}
