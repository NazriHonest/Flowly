import '../entities/recurring_transaction.dart';

class RecurrenceScheduler {
  const RecurrenceScheduler();

  DateTime nextAfter(RecurringTransaction item, {DateTime? occurrence}) {
    final current = occurrence ?? item.nextOccurrence;
    final anchor = item.startDate ?? item.nextOccurrence;
    switch (item.frequency) {
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'monthly':
        return _clampedDate(
          current.year,
          current.month + 1,
          anchor.day,
          current,
        );
      case 'yearly':
        return _clampedDate(
          current.year + 1,
          anchor.month,
          anchor.day,
          current,
        );
      default:
        return current.add(const Duration(days: 1));
    }
  }

  /// Returns projected schedule dates without persisting transactions.
  ///
  /// [fromScheduleStart] is used for a complete calendar-month forecast. The
  /// upcoming timeline instead starts at the schedule's next ungenerated date.
  List<DateTime> occurrencesBetween(
    RecurringTransaction item, {
    required DateTime start,
    required DateTime end,
    bool fromScheduleStart = false,
  }) {
    if (!item.enabled || end.isBefore(start)) return const [];

    var occurrence = fromScheduleStart
        ? item.startDate ?? item.nextOccurrence
        : item.nextOccurrence;
    final scheduleStart = item.startDate;
    final results = <DateTime>[];
    var guard = 0;

    while (!occurrence.isAfter(end) && guard++ < 50000) {
      final withinStart = !occurrence.isBefore(start);
      final afterScheduleStart =
          scheduleStart == null || !occurrence.isBefore(scheduleStart);
      final beforeScheduleEnd =
          item.endDate == null || !occurrence.isAfter(item.endDate!);

      if (withinStart && afterScheduleStart && beforeScheduleEnd) {
        results.add(occurrence);
      }
      if (!beforeScheduleEnd) break;

      final next = nextAfter(item, occurrence: occurrence);
      if (!next.isAfter(occurrence)) break;
      occurrence = next;
    }

    return List.unmodifiable(results);
  }

  bool isDue(RecurringTransaction item, DateTime now) =>
      item.enabled && !item.nextOccurrence.isAfter(now);

  DateTime _clampedDate(
    int year,
    int month,
    int preferredDay,
    DateTime timeSource,
  ) {
    final normalized = DateTime(year, month);
    final lastDay = DateTime(normalized.year, normalized.month + 1, 0).day;
    return DateTime(
      normalized.year,
      normalized.month,
      preferredDay.clamp(1, lastDay),
      timeSource.hour,
      timeSource.minute,
      timeSource.second,
      timeSource.millisecond,
      timeSource.microsecond,
    );
  }
}
