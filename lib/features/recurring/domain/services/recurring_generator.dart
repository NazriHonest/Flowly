import '../../../../core/database/app_database.dart';
import 'recurrence_scheduler.dart';
import '../../../notifications/data/local_notification_service.dart';

class RecurringGenerator {
  const RecurringGenerator(
    this._database, {
    this.scheduler = const RecurrenceScheduler(),
  });
  final AppDatabase _database;
  final RecurrenceScheduler scheduler;
  Future<int> generateDue(DateTime now) async {
    var generated = 0;
    for (final item in await _database.recurringTransactions()) {
      var occurrence = item.nextOccurrence;
      var guard = 0;
      while (item.enabled && !occurrence.isAfter(now) && guard++ < 10000) {
        if (item.endDate?.isBefore(occurrence) == true) break;
        final next = scheduler.nextAfter(item, occurrence: occurrence);
        if (await _database.generateRecurringOccurrence(
          item,
          occurrence,
          next,
        )) {
          generated++;
          await _database.createNotification(
            'Recurring transaction generated',
            '${item.title} was added to your transactions.',
          );
          await LocalNotificationService.instance.show(
            event: 'recurring',
            id: item.id! ^ occurrence.millisecondsSinceEpoch,
            title: 'Recurring transaction generated',
            body: '${item.title} was added to your transactions.',
          );
        }
        if (!next.isAfter(occurrence)) break;
        occurrence = next;
      }
    }
    return generated;
  }
}
