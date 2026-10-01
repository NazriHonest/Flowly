import '../entities/recurring_transaction.dart';

class RecurrenceScheduler {
  const RecurrenceScheduler();
  DateTime nextAfter(RecurringTransaction item) {
    switch (item.frequency) {
      case 'weekly':
        return item.nextOccurrence.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(
          item.nextOccurrence.year,
          item.nextOccurrence.month + 1,
          item.nextOccurrence.day,
        );
      case 'yearly':
        return DateTime(
          item.nextOccurrence.year + 1,
          item.nextOccurrence.month,
          item.nextOccurrence.day,
        );
      default:
        return item.nextOccurrence.add(const Duration(days: 1));
    }
  }

  bool isDue(RecurringTransaction item, DateTime now) =>
      item.enabled && !item.nextOccurrence.isAfter(now);
}
