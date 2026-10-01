import '../../../transactions/domain/entities/transaction.dart';

class RecurringTransaction {
  const RecurringTransaction({
    this.id,
    required this.title,
    required this.amountMinor,
    required this.type,
    required this.category,
    required this.accountId,
    required this.frequency,
    required this.nextOccurrence,
    this.endDate,
    this.startDate,
    this.notes = '',
    this.enabled = true,
  });
  final int? id, accountId;
  final String title;
  final int amountMinor;
  final TransactionType type;
  final String category, frequency;
  final DateTime nextOccurrence;
  final DateTime? endDate;
  final DateTime? startDate;
  final String notes;
  final bool enabled;
}
